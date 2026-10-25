/// The seam between signaling and the socket. Signaling depends only on
/// [SignalingTransport]; tests use `test/fakes/fake_transport.dart`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fishjam_client/src/logger.dart';
import 'package:meta/meta.dart';

@immutable
final class TransportClosed {
  const TransportClosed({this.code, this.reason, this.error});

  /// WebSocket close code, or `null` when the connection was lost without a
  /// close frame (network loss, pong timeout).
  final int? code;

  final String? reason;

  /// The error that ended the connection, when it did not end with a close
  /// frame.
  final Object? error;

  @override
  String toString() =>
      'TransportClosed(code: $code, reason: $reason, error: $error)';
}

/// Thrown by [SignalingTransport.connect] when the socket cannot be opened.
final class TransportException implements Exception {
  const TransportException(this.message, [this.cause]);

  final String message;

  final Object? cause;

  @override
  String toString() =>
      'TransportException: $message'
      '${cause == null ? '' : ' ($cause)'}';
}

/// A binary, message-oriented, single-use connection to the server.
///
/// Lifecycle: [connect] once → [send] / [incoming] → exactly one
/// [onClose] event, after which [incoming] is done. A new session needs a new
/// transport (see [SignalingTransportFactory]).
abstract interface class SignalingTransport {
  /// Throws [TransportException] when the socket cannot be opened.
  Future<void> connect(Uri url);

  bool get isOpen;

  /// Sends one binary frame. A no-op when the transport is not open.
  void send(Uint8List data);

  /// Binary frames received from the server. Text frames are dropped.
  Stream<Uint8List> get incoming;

  /// Completes once, when the connection ends for any reason (server close,
  /// network loss, liveness timeout or [close]).
  Future<TransportClosed> get onClose;

  Future<void> close([int code = 1000, String? reason]);
}

/// Creates a fresh, unconnected transport for every session.
typedef SignalingTransportFactory = SignalingTransport Function();

/// [SignalingTransport] over `dart:io` WebSockets.
///
/// Sends a ping every [pingInterval]; when no pong arrives within the next
/// interval the socket is closed and [onClose] reports a closure without a
/// code.
final class WebSocketTransport implements SignalingTransport {
  /// Ignored text frames are logged at debug level with [logger].
  WebSocketTransport({
    this.pingInterval = const Duration(seconds: 15),
    this.connectTimeout = const Duration(seconds: 10),
    FishjamLogger? logger,
  }) : _logger = logger ?? FishjamLogger.disabled();

  /// Interval between client pings, and the pong timeout.
  final Duration pingInterval;

  /// Limit for opening the socket: connection, TLS and upgrade together.
  final Duration connectTimeout;

  final FishjamLogger _logger;

  WebSocket? _socket;

  /// Opens [_socket]; its own, so that the connect timeout and [close] can
  /// abort a connect in progress.
  HttpClient? _client;
  final _incoming = StreamController<Uint8List>();
  final _closed = Completer<TransportClosed>();

  @override
  bool get isOpen => _socket?.readyState == WebSocket.open;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<TransportClosed> get onClose => _closed.future;

  @override
  Future<void> connect(Uri url) async {
    if (_client != null) throw StateError('A transport can be used once');
    final client = _client = HttpClient();
    try {
      // Without a limit, a connect started on a network that went away hangs
      // until the OS gives up, which can take minutes.
      _socket =
          await WebSocket.connect(
              url.toString(),
              customClient: client,
            ).timeout(connectTimeout)
            ..pingInterval = pingInterval;
    } on Object catch (e) {
      _finish(TransportClosed(error: e));
      throw TransportException('Cannot connect to $url', e);
    } finally {
      // Aborts a connect that timed out; an open socket no longer belongs to
      // the client.
      client.close(force: true);
    }
    _socket!.listen(
      (data) {
        if (data is Uint8List) {
          _incoming.add(data);
        } else if (data is List<int>) {
          _incoming.add(Uint8List.fromList(data));
        } else {
          _logger.debug('Ignoring a text frame from the server');
        }
      },
      onError: (Object e) => _finish(TransportClosed(error: e)),
      onDone: () => _finish(
        TransportClosed(code: _socket?.closeCode, reason: _socket?.closeReason),
      ),
      cancelOnError: true,
    );
  }

  @override
  void send(Uint8List data) {
    if (isOpen) _socket!.add(data);
  }

  @override
  Future<void> close([int code = 1000, String? reason]) async {
    final socket = _socket;
    if (socket == null) {
      // A connect in progress fails at once instead of opening a socket
      // nobody uses.
      _client?.close(force: true);
      _finish(TransportClosed(code: code, reason: reason));
      return;
    }
    await socket.close(code, reason);
  }

  void _finish(TransportClosed closed) {
    if (_closed.isCompleted) return;
    _closed.complete(closed);
    unawaited(_incoming.close());
  }
}
