/// Scriptable [SignalingTransport] for unit tests.
///
/// Records every frame the client sends, lets the test push server messages
/// and close the socket the way the server does.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

/// Default time to wait for an outgoing message in [FakeTransport.nextSent].
const defaultSentTimeout = Duration(seconds: 2);

/// Waits for messages appended to a list, in order.
class _SentCursor {
  int _next = 0;
  final _waiters = <Completer<void>>[];

  void notify() {
    for (final w in _waiters) {
      if (!w.isCompleted) w.complete();
    }
    _waiters.clear();
  }

  Future<PeerMessage> next(
    List<Uint8List> Function() frames,
    Duration timeout,
  ) async {
    // Timer based (no wall clock) so it also works under fake_async.
    while (_next >= frames().length) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('No message sent', timeout),
      );
    }
    return PeerMessage.fromBuffer(frames()[_next++]);
  }
}

/// A fake socket.
class FakeTransport implements SignalingTransport {
  /// Creates a transport; [failConnect] makes [connect] throw.
  FakeTransport({this.failConnect = false, this._onSent});

  /// Whether [connect] throws [TransportException].
  final bool failConnect;

  final void Function(Uint8List)? _onSent;

  /// URL passed to [connect].
  Uri? connectedUrl;

  /// Raw frames sent by the client.
  final List<Uint8List> sent = [];

  /// Whether the client called [close].
  bool closedByClient = false;

  /// Code passed to [close].
  int? clientCloseCode;

  /// Reason passed to [close].
  String? clientCloseReason;

  bool _open = false;
  final _incoming = StreamController<Uint8List>();
  final _closed = Completer<TransportClosed>();
  final _cursor = _SentCursor();

  /// [sent] decoded.
  List<PeerMessage> get sentMessages =>
      sent.map(PeerMessage.fromBuffer).toList();

  @override
  bool get isOpen => _open;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<TransportClosed> get onClose => _closed.future;

  @override
  Future<void> connect(Uri url) async {
    connectedUrl = url;
    if (failConnect) {
      _finish(TransportClosed(error: StateError('connect failed')));
      throw TransportException('Cannot connect to $url');
    }
    _open = true;
  }

  @override
  void send(Uint8List data) {
    if (!_open) return;
    sent.add(data);
    _cursor.notify();
    _onSent?.call(data);
  }

  @override
  Future<void> close([int code = 1000, String? reason]) async {
    closedByClient = true;
    clientCloseCode = code;
    clientCloseReason = reason;
    _finish(TransportClosed(code: code, reason: reason));
  }

  /// The next message sent by the client that was not returned before.
  Future<PeerMessage> nextSent({Duration timeout = defaultSentTimeout}) =>
      _cursor.next(() => sent, timeout);

  /// Delivers a server message to the client.
  void receive(PeerMessage message) => receiveBytes(message.writeToBuffer());

  /// Delivers raw bytes to the client.
  void receiveBytes(List<int> bytes) {
    if (!_open) throw StateError('Transport is not open');
    _incoming.add(Uint8List.fromList(bytes));
  }

  /// The server closes the socket with a close frame.
  void serverClose({int? code = 1000, String? reason}) =>
      _finish(TransportClosed(code: code, reason: reason));

  /// The connection is lost without a close frame.
  void loseConnection([Object? error]) =>
      _finish(TransportClosed(error: error ?? StateError('connection lost')));

  void _finish(TransportClosed closed) {
    if (_closed.isCompleted) return;
    _open = false;
    _closed.complete(closed);
    unawaited(_incoming.close());
  }
}

/// A [SignalingTransportFactory] that creates [FakeTransport]s and keeps
/// them, for tests spanning several sessions (reconnection).
class FakeTransportFactory {
  /// Every transport created so far.
  final List<FakeTransport> created = [];

  int _failures = 0;
  final _cursor = _SentCursor();
  final _log = <Uint8List>[];

  /// The most recently created transport.
  FakeTransport get last => created.last;

  /// Makes the next [count] transports fail to connect.
  void failNextConnects(int count) {
    _failures += count;
  }

  /// Creates a transport (use as `transportFactory: factory.call`).
  FakeTransport call() {
    final fail = _failures > 0;
    if (fail) _failures--;
    final transport = FakeTransport(
      failConnect: fail,
      onSent: (frame) {
        _log.add(frame);
        _cursor.notify();
      },
    );
    created.add(transport);
    return transport;
  }

  /// Frames sent on every transport, in send order.
  List<Uint8List> get allSent => List.unmodifiable(_log);

  /// The next message sent on any transport that was not returned before.
  Future<PeerMessage> nextSent({Duration timeout = defaultSentTimeout}) =>
      _cursor.next(() => _log, timeout);
}
