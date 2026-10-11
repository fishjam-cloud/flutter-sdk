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
  /// Creates a client. Subscribe to [events] before calling [connect].
  ///
  /// This facade converts between `flutter_webrtc` types and the internal
  /// `RtcMediaTrack` seam (`wrapNativeTrack` / `nativeTrackOf`).
  FishjamClient({
    bool debug = false,
    ReconnectConfig reconnect = const ReconnectConfig(),
  }) : this.internal(debug: debug, reconnect: reconnect);

  /// A client on a custom WebRTC adapter and socket transport (tests only;
  /// they default to `flutter_webrtc` and `dart:io` WebSockets).
  @internal
  FishjamClient.internal({
    this.debug = false,
    this.reconnect = const ReconnectConfig(),
    RtcAdapter? rtcAdapter,
    this._transportFactory,
  }) : _adapter = rtcAdapter ?? const FlutterWebrtcAdapter(),
       _logger = FishjamLogger(enabled: debug) {
    _reconnect = ReconnectManager(config: reconnect, host: _Host(this));
    _dataChannels = DataChannelManager(
      logger: _logger,
      negotiate: (apply) => _requireAvailable().engine.negotiate(apply),
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

  /// Remote endpoints the app was told about (in `Joined` and later events)
  /// by a session that was lost; reported gone before the next `Joined`
  /// (SPEC §6, D22).
  ({List<Peer> peers, List<Component> components})? _staleRemote;

  /// All client events (broadcast).
  Stream<FishjamEvent> get events => _events.stream;

  /// Current connection status (SPEC §3.1).
  ConnectionStatus get status => _status;

  /// Whether a reconnection is in progress.
  bool get isReconnecting => _reconnect.isReconnecting;

  /// Joins the room (SPEC §3.2). Completes on `Joined`; throws
  /// `AuthException`, `JoinException` or `ConnectionException`, and
  /// `ArgumentError` for a [url] that is not ws, wss, http or https
  /// (see `fishjamUrlFromId`).
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
    peerSocketUrl(url);
    _url = url;
    _token = token;
    _reconnect.reset();
    _staleRemote = null;
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
      _requireAvailable().remote.setTargetEncoding(trackId, variant);

  /// Updates this peer's metadata (SPEC §11.6).
  void updatePeerMetadata(Object? metadata) =>
      _requireAvailable().engine.updatePeerMetadata(metadata);

  /// Updates a local track's metadata (SPEC §11.6).
  void updateTrackMetadata(String trackId, TrackMetadata? metadata) =>
      _requireAvailable().engine.updateTrackMetadata(trackId, metadata);

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
  /// to the session: after a reconnection, create them again. Fails with
  /// `StateError` (and emits nothing) when not joined or reconnecting.
  Future<void> createDataChannels() {
    final error = _unavailable();
    if (error != null) return Future.error(error);
    return _dataChannels.createChannels();
  }

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
      if (_isCurrent(session)) _emit(event);
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
    if (!_isCurrent(session)) return;
    session.roomType = _roomTypeOf(auth.roomType);
    if (!_reconnect.isReconnecting) {
      _emit(AuthSucceeded(roomType: session.roomType));
      _status = ConnectionStatus.authenticated;
    }
    session.engine.connect(peerMetadata);
  }

  void _onJoined(_Session session, Joined joined) {
    if (!_isCurrent(session)) return;
    session.isJoined = true;
    _reportStaleRemoteGone();
    // While reconnecting, the status turns `joined` with `Reconnected`.
    if (!_reconnect.isReconnecting) _status = ConnectionStatus.joined;
    _emit(joined);
    _stats.start();
    final connecting = _connecting;
    if (connecting != null && !connecting.isCompleted) connecting.complete();
    unawaited(_reconnect.onSessionJoined());
  }

  Future<void> _onClosed(_Session session, CloseReason reason) async {
    // Server events received before the close are handled first: an error
    // or the local peer's removal followed by a close ends the session as
    // announced (SPEC §3.4), not as a lost socket.
    await session.lastEvent;
    if (!_isCurrent(session)) return;
    if (session.engine.endedBy case final end?) {
      _endBy(session, end);
      return;
    }
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
    if (!_isCurrent(session)) return;
    unawaited(
      _onRetryableLoss(const RetryableClose(reason: 'peer connection')),
    );
  }

  void _onServerError(_Session session) =>
      _endBy(session, EngineEnd.serverError);

  void _onLocalPeerRemoved(_Session session) =>
      _endBy(session, EngineEnd.localPeerRemoved);

  /// SPEC §3.4: a server error leaves (sending `disconnect`); the removal of
  /// the local peer tears down without sending it. Reached from the engine
  /// callback or from the socket close that follows, whichever is first.
  void _endBy(_Session session, EngineEnd end) {
    if (!_isCurrent(session)) return;
    _reconnect.reset();
    unawaited(switch (end) {
      EngineEnd.serverError => _finish(
        const Disconnected(DisconnectReason.serverError),
        sendDisconnect: true,
      ),
      EngineEnd.localPeerRemoved => _finish(
        const Disconnected(DisconnectReason.peerRemoved),
      ),
    });
  }

  /// A retryable loss of the current session (SPEC §6).
  Future<void> _onRetryableLoss(RetryableClose reason) async {
    final session = _session!;
    final snapshot = ReconnectSnapshot(
      peerMetadata: session.localTracks.peerMetadata,
      tracks: [for (final t in session.localTracks.tracks) t.toContext()],
    );
    if (_reconnect.onRetryableLoss(reason, snapshot)) {
      // From here on the lost session reports nothing (SPEC §6).
      session.isLost = true;
      if (session.isJoined) {
        _staleRemote = (
          peers: session.remote.peers,
          components: session.remote.components,
        );
      }
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
    _staleRemote = null;
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

  /// The joined session for an app operation. Throws `StateError` before
  /// `Joined` and from the moment a connection loss starts a reconnection
  /// until `Reconnected` (SPEC §6).
  _Session _requireAvailable() {
    final error = _unavailable();
    if (error != null) throw error;
    return _session!;
  }

  StateError? _unavailable() {
    if (_status == ConnectionStatus.reconnecting) {
      return StateError('Not available while reconnecting');
    }
    final session = _session;
    if (session == null || !session.isJoined) return StateError('Not joined');
    return null;
  }

  /// Runs [operation] on the joined session; fails with `StateError`
  /// otherwise.
  Future<T> _run<T>(Future<T> Function(_Session session) operation) {
    try {
      return operation(_requireAvailable());
    } on Object catch (e, st) {
      return Future.error(e, st);
    }
  }

  /// Whether reports of [session] still count: it is current and was not
  /// given up for a reconnection.
  bool _isCurrent(_Session session) =>
      identical(_session, session) && !session.isLost;

  /// D22: before a new session's `Joined`, the remote endpoints of the lost
  /// one are reported gone: every track, then every endpoint.
  void _reportStaleRemoteGone() {
    final stale = _staleRemote;
    if (stale == null) return;
    _staleRemote = null;
    for (final tracks in [
      for (final p in stale.peers) p.tracks,
      for (final c in stale.components) c.tracks,
    ]) {
      tracks.values.map(TrackRemoved.new).forEach(_emit);
    }
    for (final peer in stale.peers) {
      _emit(PeerLeft(peer));
    }
    for (final component in stale.components) {
      _emit(ComponentRemoved(component));
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

  /// Whether a reconnection replaces this session; it reports nothing more.
  bool isLost = false;

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
    final session = _client._session;
    if (session == null || !session.isJoined) throw StateError('Not joined');
    await session.engine.addTrack(
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
  void emit(FishjamEvent event) {
    if (event is Reconnected) _client._status = ConnectionStatus.joined;
    _client._emit(event);
  }
}
