import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/auth.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

/// Thrown by [SignalingSession.open] when the socket closes before
/// `authenticated` arrives.
final class SignalingClosedException implements Exception {
  const SignalingClosedException(this.reason);

  final CloseReason reason;

  @override
  String toString() => 'SignalingClosedException($reason)';
}

/// One socket session: opens the transport, authenticates, then exchanges
/// media events. Single use; a reconnection creates a new session.
///
/// Outgoing messages that do not bypass the queue go through the
/// shared [MessageQueue], which outlives sessions; the owner of the queue
/// routes its writes to the current session's transport via [sendNow].
class SignalingSession {
  SignalingSession({
    required this._transport,
    required this._queue,
    required this._logger,
    required this._sdkVersion,
  }) {
    // `open` hands this future out; when open fails before anyone awaits it
    // (socket cannot be opened), the error must not surface as unhandled.
    _authenticated.future.ignore();
  }

  final SignalingTransport _transport;
  final MessageQueue _queue;
  final FishjamLogger _logger;
  final String _sdkVersion;

  final _authenticated = Completer<PeerMessage_Authenticated>();
  final _closed = Completer<CloseReason>();
  final _events = StreamController<server.MediaEvent>();
  bool _opened = false;
  bool _closing = false;
  bool _ended = false;
  bool _listening = false;
  bool _incomingDone = false;
  TransportClosed? _transportClosed;

  /// Opens the socket at the peer socket URL for [url], sends `authRequest`
  /// with [token] and completes with the `authenticated` message, after
  /// logging its SDK deprecation status.
  ///
  /// Throws [SignalingClosedException] when the socket closes first (also
  /// after [close]), and [TransportException] when it cannot be opened.
  /// [closed] completes in both cases (unless [close] was called), so it is
  /// the single signal for "this session is gone".
  Future<PeerMessage_Authenticated> open({
    required String url,
    required String token,
  }) async {
    if (_opened) throw StateError('A signaling session can be opened once');
    _opened = true;
    unawaited(_transport.onClose.then(_onTransportClosed));
    try {
      await _transport.connect(peerSocketUrl(url));
    } on TransportException catch (e) {
      // A transport reports its close on a failed connect; do it here too
      // in case it does not, so [closed] always completes.
      _onTransportClosed(TransportClosed(error: e));
      rethrow;
    }
    if (_closing) {
      await _transport.close();
      _onTransportClosed(const TransportClosed(code: 1000));
      return await _authenticated.future;
    }
    _listening = true;
    _transport.incoming.listen(
      _onFrame,
      onDone: () {
        _incomingDone = true;
        _end();
      },
    );
    sendNow(
      PeerMessage(
        authRequest: PeerMessage_AuthRequest(
          token: token,
          sdkVersion: _sdkVersion,
        ),
      ).writeToBuffer(),
    );
    return await _authenticated.future;
  }

  /// Server media events, in arrival order. Done when the session closes.
  Stream<server.MediaEvent> get serverMediaEvents => _events.stream;

  /// Completes once with the classified reason when the socket closes for
  /// any reason other than [close], including before authentication and when
  /// the socket cannot be opened.
  ///
  /// When [serverMediaEvents] has a listener, [closed] completes only after
  /// every event received before the close was delivered and the stream's
  /// done event was handled. A consumer that handles events asynchronously
  /// must therefore finish (or keep its subscription paused) until it is done
  /// with an event before reacting to [closed] — e.g. a server `error`
  /// followed by a close must be handled as an error, not as a lost socket.
  Future<CloseReason> get closed => _closed.future;

  /// Sends a peer media event: immediately when it bypasses the queue,
  /// through the queue otherwise.
  void sendMediaEvent(peer.MediaEvent event) =>
      _send(PeerMessage(peerMediaEvent: event));

  void sendStatsReport(String json) => _send(
    PeerMessage(rtcStatsReport: PeerMessage_RTCStatsReport(data: json)),
  );

  /// Writes an already encoded frame on this session's socket (used by the
  /// queue owner). A no-op when the socket is closed.
  void sendNow(List<int> frame) {
    if (!_transport.isOpen) {
      _logger.debug('Socket is closed; dropping an outgoing message');
      return;
    }
    _transport.send(frame is Uint8List ? frame : Uint8List.fromList(frame));
  }

  /// Closes the socket with code 1000. [closed] does not complete.
  Future<void> close() async {
    _closing = true;
    if (!_opened) unawaited(_events.close());
    await _transport.close();
  }

  void _send(PeerMessage message) {
    final frame = message.writeToBuffer();
    if (bypassesQueue(message)) {
      sendNow(frame);
    } else {
      _queue.enqueue(frame);
    }
  }

  void _onFrame(Uint8List frame) {
    final PeerMessage message;
    try {
      message = PeerMessage.fromBuffer(frame);
    } on Object catch (e) {
      _logger.warn('Dropping an undecodable message', e);
      return;
    }
    switch (message.whichContent()) {
      case PeerMessage_Content.authenticated when !_authenticated.isCompleted:
        _logDeprecation(message.authenticated.sdkDeprecation);
        _authenticated.complete(message.authenticated);
      case PeerMessage_Content.serverMediaEvent when _authenticated.isCompleted:
        _events.add(message.serverMediaEvent);
      case final content:
        _logger.debug('Ignoring an unexpected ${content.name} message');
    }
  }

  void _logDeprecation(PeerMessage_SdkDeprecation deprecation) {
    final status = deprecation.status;
    if (status == PeerMessage_SdkDeprecation_Status.STATUS_DEPRECATED) {
      _logger.warn('SDK $_sdkVersion is deprecated: ${deprecation.message}');
    } else if (status == PeerMessage_SdkDeprecation_Status.STATUS_UNSUPPORTED) {
      _logger.error('SDK $_sdkVersion is unsupported: ${deprecation.message}');
    }
  }

  void _onTransportClosed(TransportClosed transportClosed) {
    _transportClosed ??= transportClosed;
    _end();
  }

  /// Ends the session once the transport closed and every frame received
  /// before the close was handled.
  void _end() {
    final transportClosed = _transportClosed;
    if (_ended || transportClosed == null) return;
    if (_listening && !_incomingDone) return;
    _ended = true;
    final reason = classifyClose(transportClosed);
    _logger.debug('Socket closed: $transportClosed');
    if (!_authenticated.isCompleted) {
      _authenticated.completeError(SignalingClosedException(reason));
    }
    // With a listener, `close()` completes once the done event was
    // delivered, i.e. after every buffered event was handed over.
    final delivered = _events.hasListener ? _events.close() : null;
    if (delivered == null) unawaited(_events.close());
    if (_closing) return;
    if (delivered == null) {
      _closed.complete(reason);
    } else {
      unawaited(delivered.then((_) => _closed.complete(reason)));
    }
  }
}
