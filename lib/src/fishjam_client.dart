/// The public client facade.
///
/// Owner: **Integrator**. It wires Signaling, Engine, Tracks, Data and Stats
/// together and converts between `flutter_webrtc` types and the internal
/// seam; it holds no protocol logic of its own.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/data/data_channels.dart';
import 'package:fishjam_client/src/engine/rtc_engine.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/signaling/auth.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/reconnect.dart';
import 'package:fishjam_client/src/signaling/signaling_session.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:fishjam_client/src/stats/stats_reporter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:fishjam_client/src/version.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:meta/meta.dart';

/// Connects to a Fishjam room and exchanges media and data.
///
/// ```dart
/// final client = FishjamClient();
/// client.events.listen((event) {
///   switch (event) {
///     case TrackReady(:final track): render(track);
///     default:
///   }
/// });
/// await client.connect(url: fishjamUrl, token: peerToken);
/// ```
class FishjamClient {
  /// Creates a client. The adapter and transport factory exist for tests;
  /// they default to the `flutter_webrtc` adapter and `dart:io` WebSockets.
  ///
  /// This facade converts between `flutter_webrtc` types and the internal
  /// `RtcMediaTrack` seam (`wrapNativeTrack` / `nativeTrackOf`).
  FishjamClient({
    this.debug = false,
    this.reconnect = const ReconnectConfig(),
    @visibleForTesting RtcAdapter? rtcAdapter,
    @visibleForTesting this._transportFactory,
  }) : _adapter = rtcAdapter ?? const FlutterWebrtcAdapter(),
       _logger = FishjamLogger(enabled: debug) {
    _reconnect = ReconnectManager(config: reconnect, host: _Host(this));
    _dataChannels = DataChannelManager(
      logger: _logger,
      negotiate: (apply) => _requireJoined().engine.negotiate(apply),
      emit: _emit,
      localPeerId: () => _session?.localTracks.peerId ?? '',
    );
    _stats = StatsReporter(
      getStats: () async =>
          await _session?.engine.peerConnection?.getStats() ?? const [],
      send: (json) => _session?.signaling.sendStatsReport(json),
      logger: _logger,
    );
  }

  /// Whether SDK logs are emitted (SPEC §21).
  final bool debug;

  /// Reconnection settings (SPEC §6).
  final ReconnectConfig reconnect;

  final RtcAdapter _adapter;
  final SignalingTransportFactory? _transportFactory;
  final FishjamLogger _logger;
  final _events = StreamController<FishjamEvent>.broadcast();
  late final MessageQueue _queue = MessageQueue(
    send: (frame) => _socket?.sendNow(frame),
  );
  late final ReconnectManager _reconnect;
  late final DataChannelManager _dataChannels;
  late final StatsReporter _stats;

  ConnectionStatus _status = ConnectionStatus.idle;

  /// The current session. Replaced on every reconnection attempt; `null`
  /// once the client is disconnected. Reports of other sessions are ignored.
  _Session? _session;

  /// Where queued messages are written: the newest session's socket. It
  /// stays set while that session is torn down, so `disconnect` goes out.
  SignalingSession? _socket;

  /// Settles the pending `connect()` call exactly once.
  Completer<void>? _connecting;
  String _url = '';
  String _token = '';
  bool _disposed = false;

  /// All client events (broadcast).
  Stream<FishjamEvent> get events => _events.stream;

  /// Current connection status (SPEC §3.1).
  ConnectionStatus get status => _status;

  /// Whether a reconnection is in progress.
  bool get isReconnecting => _reconnect.isReconnecting;

  /// Joins the room (SPEC §3.2). Completes on `Joined`; throws
  /// `AuthException`, `JoinException` or `ConnectionException`.
  Future<void> connect({
    required String url,
    required String token,
    Object? peerMetadata,
  }) async {
    if (_disposed) throw StateError('The client was disposed');
    if (_status != ConnectionStatus.idle &&
        _status != ConnectionStatus.disconnected) {
      throw StateError('connect() called while ${_status.name}');
    }
    _url = url;
    _token = token;
    _reconnect.reset();
    _status = ConnectionStatus.connecting;
    final connecting = _connecting = Completer<void>();
    final session = _newSession();
    try {
      await _open(session, peerMetadata);
    } on Object {
      // Reported through `closed`, which settles connect() (SPEC §3.2).
    }
    return await connecting.future;
  }

  /// Leaves the room gracefully (SPEC §3.3). A no-op when not connected.
  Future<void> leave() => _leave(DisconnectReason.left);

  /// Publishes [track] (SPEC §11.1); returns its track id. Throws
  /// `TrackTypeError` for video in an audio-only room.
  Future<String> addTrack(
    MediaStreamTrack track, {
    TrackMetadata? metadata,
    SimulcastConfig simulcastConfig = const SimulcastConfig.disabled(),
    BandwidthLimit maxBandwidth = BandwidthLimit.unlimited,
  }) {
    if (_session?.roomType == RoomType.audioOnly && track.kind == 'video') {
      throw TrackTypeError();
    }
    return _run(
      (s) => s.engine.addTrack(
        wrapNativeTrack(track),
        metadata: metadata,
        simulcastConfig: simulcastConfig,
        maxBandwidth: maxBandwidth,
      ),
    );
  }

  /// Unpublishes a track (SPEC §11.2).
  Future<void> removeTrack(String trackId) =>
      _run((s) => s.engine.removeTrack(trackId));

  /// Replaces, mutes (`null`) or unmutes a track's media (SPEC §11.3).
  Future<void> replaceTrack(String trackId, MediaStreamTrack? track) => _run(
    (s) => s.engine.replaceTrack(
      trackId,
      track == null ? null : wrapNativeTrack(track),
    ),
  );

  /// Sets a track's bandwidth limit in kbps (SPEC §11.5, §13).
  Future<void> setTrackBandwidth(String trackId, BandwidthLimit bandwidth) =>
      _run((s) => s.localTracks.setTrackBandwidth(trackId, bandwidth));

  /// Sets one simulcast layer's limit in kbps (SPEC §11.5, §13).
  Future<void> setEncodingBandwidth(
    String trackId,
    Variant variant,
    int kbps,
  ) => _run((s) => s.localTracks.setEncodingBandwidth(trackId, variant, kbps));

  /// Starts sending a simulcast layer (SPEC §11.4).
  Future<void> enableTrackEncoding(String trackId, Variant variant) =>
      _run((s) => s.localTracks.enableTrackEncoding(trackId, variant));

  /// Stops sending a simulcast layer (SPEC §11.4).
  Future<void> disableTrackEncoding(String trackId, Variant variant) =>
      _run((s) => s.localTracks.disableTrackEncoding(trackId, variant));

  /// Asks the server to send [variant] of a remote track (SPEC §14.4).
  /// Throws `ArgumentError` for an unknown or non-simulcast track, or a
  /// variant the track does not send.
  void setTargetTrackEncoding(String trackId, Variant variant) =>
      _requireJoined().remote.setTargetEncoding(trackId, variant);

  /// Updates this peer's metadata (SPEC §11.6).
  void updatePeerMetadata(Object? metadata) =>
      _requireJoined().engine.updatePeerMetadata(metadata);

  /// Updates a local track's metadata (SPEC §11.6).
  void updateTrackMetadata(String trackId, TrackMetadata? metadata) =>
      _requireJoined().engine.updateTrackMetadata(trackId, metadata);

  /// This client in the room; `null` before `Joined`.
  LocalPeer? get localPeer {
    final session = _session;
    if (session == null || !session.isJoined) return null;
    return session.localTracks.toLocalPeer();
  }

  /// Other peers by id.
  Map<String, Peer> get remotePeers => {
    for (final p in _session?.remote.peers ?? const <Peer>[]) p.id: p,
  };

  /// Components by id.
  Map<String, Component> get remoteComponents => {
    for (final c in _session?.remote.components ?? const <Component>[]) c.id: c,
  };

  /// Remote tracks by id.
  Map<String, RemoteTrackContext> get remoteTracks =>
      _session?.remote.tracks ?? const {};

  /// Peer connection statistics, optionally for one track.
  Future<List<RtcStats>> getStatistics([MediaStreamTrack? track]) async {
    final pc = _session?.engine.peerConnection;
    if (pc == null) return const [];
    return await pc.getStats(track == null ? null : wrapNativeTrack(track));
  }

  /// Audio level (0.0–1.0) of a local audio track (SPEC §18).
  Future<double?> getLocalTrackAudioLevel(String trackId) async {
    final session = _session;
    if (session == null) return null;
    return await session.localTracks.audioLevel(trackId);
  }

  /// Creates the reliable and lossy data channels (SPEC §16). They belong
  /// to the session: after a reconnection, create them again.
  Future<void> createDataChannels() => _dataChannels.createChannels();

  /// Whether both data channels are open.
  bool get dataChannelsReady => _dataChannels.isReady;

  /// Sends [data] to every other peer (SPEC §16).
  void publishData(Uint8List data, {required bool reliable}) =>
      _dataChannels.publish(data, reliable: reliable);

  /// Data received from other peers on one channel (SPEC §16).
  Stream<Uint8List> dataStream({required bool reliable}) =>
      _dataChannels.dataStream(reliable: reliable);

  /// Leaves (if connected) and releases every resource. The client cannot
  /// be used afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await leave();
    await _dataChannels.dispose();
    await _events.close();
  }

  // ------------------------------------------------------------ sessions

  /// Creates a session and makes it the current one.
  _Session _newSession() {
    final signaling = SignalingSession(
      transport:
          _transportFactory?.call() ?? WebSocketTransport(logger: _logger),
      queue: _queue,
      logger: _logger,
      sdkVersion: sdkVersion,
    );
    late final _Session session;
    void emit(FishjamEvent event) {
      if (identical(_session, session)) _emit(event);
    }

    final localTracks = LocalTrackRegistry(
      logger: _logger,
      sendMediaEvent: signaling.sendMediaEvent,
      emit: emit,
    );
    final remote = RemoteStore(
      logger: _logger,
      emit: emit,
      sendMediaEvent: signaling.sendMediaEvent,
    );
    final engine = RtcEngine(
      adapter: _adapter,
      logger: _logger,
      sendMediaEvent: signaling.sendMediaEvent,
      emit: emit,
      localTracks: localTracks,
      remote: remote,
      onServerError: (_) => _onServerError(session),
      onLocalPeerRemoved: () => _onLocalPeerRemoved(session),
      onConnectionFailed: (_) => _onConnectionFailed(session),
    );
    session = _Session(signaling, engine, localTracks, remote);
    _session = session;
    _socket = signaling;
    signaling.serverMediaEvents.listen(
      (event) => session.lastEvent = engine.handleServerEvent(event),
    );
    unawaited(signaling.closed.then((reason) => _onClosed(session, reason)));
    unawaited(
      engine.joined.then(
        (joined) => _onJoined(session, joined),
        // The session closed before `connected`; `closed` reports it.
        onError: (Object _) {},
      ),
    );
    return session;
  }

  /// Authenticates [session] and sends `connect` (SPEC §3.2). Throws when
  /// the socket closes first, which `closed` reports too.
  Future<void> _open(_Session session, Object? peerMetadata) async {
    final auth = await session.signaling.open(url: _url, token: _token);
    if (!identical(_session, session)) return;
    session.roomType = _roomTypeOf(auth.roomType);
    if (!_reconnect.isReconnecting) {
      _emit(AuthSucceeded(roomType: session.roomType));
      _status = ConnectionStatus.authenticated;
    }
    session.engine.connect(peerMetadata);
  }

  void _onJoined(_Session session, Joined joined) {
    if (!identical(_session, session)) return;
    session.isJoined = true;
    _status = ConnectionStatus.joined;
    _emit(joined);
    _stats.start();
    final connecting = _connecting;
    if (connecting != null && !connecting.isCompleted) connecting.complete();
    unawaited(_reconnect.onSessionJoined());
  }

  Future<void> _onClosed(_Session session, CloseReason reason) async {
    // Server events received before the close are handled first, with the
    // session callbacks they trigger (an error followed by a close is a
    // server error, SPEC §3.4). The engine runs those callbacks after its
    // queued work and one more event loop turn.
    await session.lastEvent;
    await Future<void>.delayed(Duration.zero);
    if (!identical(_session, session)) return;
    if (_status != ConnectionStatus.joined && !_reconnect.isReconnecting) {
      // Before the first `Joined` nothing is retried (SPEC §3.2).
      await _finish(
        disconnectedFor(reason),
        error: errorEventFor(reason),
        connectError: connectExceptionFor(reason),
      );
    } else if (reason is RetryableClose) {
      await _onRetryableLoss(reason);
    } else {
      _reconnect.onTerminalClose(reason);
      await _finish(disconnectedFor(reason), error: errorEventFor(reason));
    }
  }

  /// The peer connection failed or a negotiation cycle could not complete
  /// (the engine already emitted `ConnectionError`): a retryable loss.
  void _onConnectionFailed(_Session session) {
    if (!identical(_session, session)) return;
    unawaited(
      _onRetryableLoss(const RetryableClose(reason: 'peer connection')),
    );
  }

  void _onServerError(_Session session) {
    if (!identical(_session, session)) return;
    unawaited(_leave(DisconnectReason.serverError));
  }

  /// SPEC §3.4: torn down like `leave()`, without sending `disconnect`.
  void _onLocalPeerRemoved(_Session session) {
    if (!identical(_session, session)) return;
    _reconnect.reset();
    unawaited(_finish(const Disconnected(DisconnectReason.peerRemoved)));
  }

  /// A retryable loss of the current session (SPEC §6).
  Future<void> _onRetryableLoss(RetryableClose reason) async {
    final session = _session!;
    final snapshot = ReconnectSnapshot(
      peerMetadata: session.localTracks.peerMetadata,
      tracks: [for (final t in session.localTracks.tracks) t.toContext()],
    );
    if (_reconnect.onRetryableLoss(reason, snapshot)) {
      _status = ConnectionStatus.reconnecting;
      _stats.stop();
    } else if (_reconnect.state == ReconnectState.failed) {
      await _finish(const Disconnected(DisconnectReason.reconnectionFailed));
    } else {
      await _finish(disconnectedFor(reason));
    }
  }

  Future<void> _leave(DisconnectReason reason) async {
    if (_session == null) return;
    _reconnect.reset();
    await _finish(Disconnected(reason), sendDisconnect: true);
  }

  /// Tears the current session down, then emits [error] (if any) and
  /// [disconnected]. A pending `connect()` fails with [connectError].
  Future<void> _finish(
    Disconnected disconnected, {
    FishjamEvent? error,
    FishjamException? connectError,
    bool sendDisconnect = false,
  }) async {
    final session = _session;
    if (session == null) return;
    _session = null;
    _status = ConnectionStatus.disconnected;
    await _teardown(session, sendDisconnect: sendDisconnect);
    if (error != null) _emit(error);
    _emit(disconnected);
    final connecting = _connecting;
    if (connecting != null && !connecting.isCompleted) {
      connecting.completeError(
        connectError ??
            ConnectionException(
              reason: 'disconnected (${disconnected.reason.name})',
            ),
      );
    }
  }

  /// SPEC §3.3 step 2, in this order: data channels, `disconnect` (when
  /// leaving), peer connection and local streams, socket.
  Future<void> _teardown(
    _Session session, {
    required bool sendDisconnect,
  }) async {
    _stats.stop();
    await _dataChannels.close();
    if (sendDisconnect) session.engine.sendDisconnect();
    await session.engine.close();
    await session.signaling.close();
    if (identical(_socket, session.signaling)) _socket = null;
  }

  _Session _requireJoined() {
    final session = _session;
    if (session == null || !session.isJoined) throw StateError('Not joined');
    return session;
  }

  /// Runs [operation] on the joined session; fails with `StateError`
  /// otherwise.
  Future<T> _run<T>(Future<T> Function(_Session session) operation) {
    try {
      return operation(_requireJoined());
    } on Object catch (e, st) {
      return Future.error(e, st);
    }
  }

  void _emit(FishjamEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  static RoomType _roomTypeOf(PeerMessage_RoomType type) => switch (type) {
    PeerMessage_RoomType.ROOM_TYPE_CONFERENCE => RoomType.conference,
    PeerMessage_RoomType.ROOM_TYPE_AUDIO_ONLY => RoomType.audioOnly,
    PeerMessage_RoomType.ROOM_TYPE_LIVESTREAM => RoomType.livestream,
    _ => RoomType.unspecified,
  };
}

/// One socket plus one engine (SPEC §1 "Session").
class _Session {
  _Session(this.signaling, this.engine, this.localTracks, this.remote);

  final SignalingSession signaling;
  final RtcEngine engine;
  final LocalTrackRegistry localTracks;
  final RemoteStore remote;
  RoomType roomType = RoomType.unspecified;

  /// Whether `Joined` was emitted for this session.
  bool isJoined = false;

  /// Whether the session was started by a reconnection attempt.
  bool isReconnectAttempt = false;

  /// Completes when the last server event received so far was handled.
  Future<void> lastEvent = Future.value();
}

/// The [ReconnectManager]'s side effects, kept off the public API.
class _Host implements ReconnectHost {
  _Host(this._client);

  final FishjamClient _client;

  @override
  Future<void> startSession(Object? peerMetadata) async {
    final client = _client;
    final old = client._session;
    // The new session becomes current first, so the old one is torn down
    // silently (no `Disconnected`, D9) and its late reports are ignored.
    final session = client._newSession()..isReconnectAttempt = true;
    if (old != null) {
      // Tracks a previous attempt restored were announced with
      // `LocalTrackAdded`; they go away with that session.
      if (old.isReconnectAttempt) {
        for (final track in old.localTracks.tracks) {
          if (track.negotiationStatus == TrackNegotiationStatus.negotiated) {
            client._emit(LocalTrackRemoved(track.trackId));
          }
        }
      }
      await client._teardown(old, sendDisconnect: false);
    }
    if (!identical(client._session, session)) return;
    try {
      await client._open(session, peerMetadata);
    } on Object {
      // Reported through `closed`.
    }
  }

  @override
  void endSession(DisconnectReason reason) =>
      unawaited(_client._finish(Disconnected(reason)));

  @override
  Future<void> restoreTrack(LocalTrackContext track) async {
    await _client._requireJoined().engine.addTrack(
      track.rtcTrack!,
      metadata: track.metadata,
      simulcastConfig: track.simulcastConfig,
      maxBandwidth: track.maxBandwidth,
    );
  }

  @override
  void holdQueue() => _client._queue.hold();

  @override
  void releaseQueue() => _client._queue.release();

  @override
  void clearQueue() => _client._queue.clear();

  @override
  void emit(FishjamEvent event) => _client._emit(event);
}
