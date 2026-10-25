import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/audio_output/audio_output_manager.dart';
import 'package:fishjam_client/src/connectivity_network_source.dart';
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
import 'package:fishjam_client/src/signaling/network_change_detector.dart';
import 'package:fishjam_client/src/signaling/network_source.dart';
import 'package:fishjam_client/src/signaling/reconnect.dart';
import 'package:fishjam_client/src/signaling/signaling_session.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:fishjam_client/src/stats/stats_reporter.dart';
import 'package:fishjam_client/src/tracks/local_track_registry.dart';
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
///
/// Room operations fail with `StateError` before `Joined` and while
/// reconnecting.
class FishjamClient {
  // The facade wires signaling, the engine, tracks, data channels and stats
  // together and converts `flutter_webrtc` types at the boundary; it holds
  // no protocol logic of its own.

  /// Subscribe to [events] before calling [connect]: events are not
  /// replayed.
  FishjamClient({
    bool debug = false,
    ReconnectConfig reconnect = const ReconnectConfig(),
  }) : this.internal(
         debug: debug,
         reconnect: reconnect,
         networkSource: ConnectivityNetworkSource(),
         audioOutput: AudioOutputManager.instance,
       );

  /// A client on a custom WebRTC adapter, socket transport and network
  /// source (tests only; they default to `flutter_webrtc`, `dart:io`
  /// WebSockets and no network watching). Without `audioOutput` the audio
  /// mode is never changed.
  @internal
  FishjamClient.internal({
    this.debug = false,
    this.reconnect = const ReconnectConfig(),
    RtcAdapter? rtcAdapter,
    this._transportFactory,
    NetworkSource? networkSource,
    this._audioOutput,
  }) : _adapter = rtcAdapter ?? const FlutterWebrtcAdapter(),
       _logger = FishjamLogger(enabled: debug) {
    _reconnect = ReconnectManager(config: reconnect, host: _Host(this));
    if (networkSource != null && reconnect.isEnabled) {
      _networkChangeDetector = NetworkChangeDetector(
        source: networkSource,
        logger: _logger,
        onChanged: _onNetworkChanged,
      );
    }
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

  /// Whether SDK logs are emitted (through `dart:developer`).
  final bool debug;

  final ReconnectConfig reconnect;

  final AudioOutputManager? _audioOutput;

  /// Whether the audio system was put into communication mode and not yet
  /// returned; kept across reconnections.
  bool _inCommunicationMode = false;
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
  NetworkChangeDetector? _networkChangeDetector;

  ConnectionStatus _status = ConnectionStatus.idle;

  /// The current session. Replaced on every reconnection attempt; `null`
  /// once the client is disconnected. Reports of other sessions are ignored.
  _Session? _session;

  /// Where queued messages are written: the newest session's socket. It
  /// stays set while that session is torn down, so `disconnect` goes out.
  SignalingSession? _socket;

  /// Settles the pending `connect()` call exactly once.
  Completer<void>? _connecting;

  /// Completes after the last ended session finished its teardown and
  /// emitted `Disconnected`. A new `connect()` waits for it. Never fails.
  Future<void> _previousSessionEnded = Future<void>.value();
  String _url = '';
  String _token = '';
  bool _disposed = false;

  /// Remote endpoints the app was told about (in `Joined` and later events)
  /// by a session that was lost; reported gone before the next `Joined`.
  ({List<Peer> peers, List<Component> components})? _staleRemote;

  /// Ids of local tracks the app received `LocalTrackAdded` for, and not yet
  /// `LocalTrackRemoved`. On reconnection only these are reported removed and
  /// restored, because the app does not know about the others.
  final _announcedLocalTracks = <String>{};

  /// All client events (broadcast, not replayed).
  Stream<FishjamEvent> get events => _events.stream;

  ConnectionStatus get status => _status;

  bool get isReconnecting => _reconnect.isReconnecting;

  /// Joins the room. Completes on `Joined`; throws
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
    _announcedLocalTracks.clear();
    _status = ConnectionStatus.connecting;
    unawaited(_networkChangeDetector?.start());
    final connecting = _connecting = Completer<void>();
    unawaited(_openAfterPreviousSessionEnded(_newSession(), peerMetadata));
    return await connecting.future;
  }

  /// Waits for the previous session to finish its teardown, then opens
  /// [session]. This keeps the event order when the app calls `connect()` from
  /// a `ReconnectionFailed` listener: the old `Disconnected` comes before the
  /// new session starts.
  Future<void> _openAfterPreviousSessionEnded(
    _Session session,
    Object? peerMetadata,
  ) async {
    try {
      await _previousSessionEnded;
      if (_isCurrent(session)) await _open(session, peerMetadata);
    } on Object {
      // Reported through `closed`, which settles connect().
    }
  }

  /// Leaves the room gracefully. A no-op when not connected.
  Future<void> leave() => _leave(DisconnectReason.left);

  /// Publishes [track]; returns its track id. Throws
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

  Future<void> removeTrack(String trackId) =>
      _run((s) => s.engine.removeTrack(trackId));

  /// Replaces, mutes (`null`) or unmutes a track's media.
  Future<void> replaceTrack(String trackId, MediaStreamTrack? track) => _run(
    (s) => s.engine.replaceTrack(
      trackId,
      track == null ? null : wrapNativeTrack(track),
    ),
  );

  /// Sets a track's bandwidth limit in kbps; video limits are clamped to
  /// the caps.
  Future<void> setTrackBandwidth(String trackId, BandwidthLimit bandwidth) =>
      _run((s) => s.localTracks.setTrackBandwidth(trackId, bandwidth));

  /// Sets one simulcast layer's limit in kbps. Throws `ArgumentError` when
  /// the track has no such layer.
  Future<void> setEncodingBandwidth(
    String trackId,
    Variant variant,
    int kbps,
  ) => _run((s) => s.localTracks.setEncodingBandwidth(trackId, variant, kbps));

  Future<void> enableTrackEncoding(String trackId, Variant variant) =>
      _run((s) => s.localTracks.enableTrackEncoding(trackId, variant));

  Future<void> disableTrackEncoding(String trackId, Variant variant) =>
      _run((s) => s.localTracks.disableTrackEncoding(trackId, variant));

  /// Asks the server to send [variant] of a remote track.
  /// Throws `ArgumentError` for an unknown or non-simulcast track, or a
  /// variant the track does not send.
  void setTargetTrackEncoding(String trackId, Variant variant) =>
      _requireAvailable().remote.setTargetEncoding(trackId, variant);

  void updatePeerMetadata(Object? metadata) =>
      _requireAvailable().engine.updatePeerMetadata(metadata);

  void updateTrackMetadata(String trackId, TrackMetadata? metadata) =>
      _requireAvailable().engine.updateTrackMetadata(trackId, metadata);

  /// This client in the room; `null` before `Joined`.
  LocalPeer? get localPeer {
    final session = _session;
    if (session == null || !session.isJoined) return null;
    return session.localTracks.toLocalPeer();
  }

  Map<String, Peer> get remotePeers => {
    for (final p in _session?.remote.peers ?? const <Peer>[]) p.id: p,
  };

  Map<String, Component> get remoteComponents => {
    for (final c in _session?.remote.components ?? const <Component>[]) c.id: c,
  };

  Map<String, RemoteTrackContext> get remoteTracks =>
      _session?.remote.tracks ?? const {};

  /// Optionally for one track only.
  Future<List<RtcStats>> getStatistics([MediaStreamTrack? track]) async {
    final pc = _session?.engine.peerConnection;
    if (pc == null) return const [];
    return await pc.getStats(track == null ? null : wrapNativeTrack(track));
  }

  /// Audio level (0.0–1.0) of a local audio track; `null` when unavailable.
  Future<double?> getLocalTrackAudioLevel(String trackId) async {
    final session = _session;
    if (session == null) return null;
    return await session.localTracks.audioLevel(trackId);
  }

  /// Creates the reliable and lossy data channels. They belong
  /// to the session: after a reconnection, create them again. Fails with
  /// `StateError` (and emits nothing) when not joined or reconnecting.
  Future<void> createDataChannels() {
    final error = _unavailable();
    if (error != null) return Future.error(error);
    return _dataChannels.createChannels();
  }

  bool get dataChannelsReady => _dataChannels.isReady;

  /// Sends [data] to every other peer. Throws `StateError` when the channel
  /// is not open.
  void publishData(Uint8List data, {required bool reliable}) =>
      _dataChannels.publish(data, reliable: reliable);

  /// Data received from other peers on one channel. May be listened to
  /// before the channels exist, and survives reconnections.
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

  /// Makes the new session the current one.
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

  /// Authenticates [session] and sends `connect`. Throws when
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
    // Every local track the app was told about belongs to a lost session (the
    // set starts empty at connect()) and went away with it.
    for (final trackId in _announcedLocalTracks.toList()) {
      _emit(LocalTrackRemoved(trackId));
    }
    _stats.start();
    _setCommunicationMode(on: true);
    final connecting = _connecting;
    if (connecting != null && !connecting.isCompleted) connecting.complete();
    unawaited(_reconnect.onSessionJoined());
  }

  Future<void> _onClosed(_Session session, CloseReason reason) async {
    // Server events received before the close are handled first: an error
    // or the local peer's removal followed by a close ends the session as
    // announced, not as a lost socket.
    await session.lastEvent;
    if (!_isCurrent(session)) return;
    if (session.engine.endedBy case final end?) {
      _endBy(session, end);
      return;
    }
    if (_status != ConnectionStatus.joined && !_reconnect.isReconnecting) {
      // Before the first `Joined` nothing is retried.
      await _finish(
        disconnectedFor(reason),
        error: errorEventFor(reason),
        connectError: connectExceptionFor(reason),
      );
    } else if (reason is RetryableClose) {
      _reconnectOrEnd(reason);
    } else {
      _reconnect.onTerminalClose(reason);
      await _finish(disconnectedFor(reason), error: errorEventFor(reason));
    }
  }

  /// The peer connection failed or a negotiation cycle could not complete
  /// (the engine already emitted `ConnectionError`): a retryable loss.
  void _onConnectionFailed(_Session session) {
    if (!_isCurrent(session)) return;
    _reconnectOrEnd(const RetryableClose(reason: 'peer connection'));
  }

  void _onServerError(_Session session) =>
      _endBy(session, EngineEnd.serverError);

  void _onLocalPeerRemoved(_Session session) =>
      _endBy(session, EngineEnd.localPeerRemoved);

  /// A server error leaves (sending `disconnect`); the removal of
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

  /// While joined, losing or switching the network ends the session: the
  /// socket and peer connection are bound to the old network.
  void _onNetworkChanged(NetworkChange change) {
    _logger.debug('Network ${change.name}');
    // Report the loss first so a reconnection exists. The calls below then
    // act on it: online starts an attempt now, offline makes it wait.
    if (_status == ConnectionStatus.joined &&
        change != NetworkChange.available) {
      _reconnectOrEnd(RetryableClose(reason: 'network ${change.name}'));
    }
    if (change == NetworkChange.lost) {
      _reconnect.onNetworkLost();
    } else {
      _reconnect.onNetworkAvailable();
    }
  }

  /// Starts a reconnection or ends the session. Synchronous on purpose:
  /// [_onNetworkChanged] calls the reconnect manager right after and needs the
  /// reconnection to exist. Only ending the session (`_finish`) continues in
  /// the background.
  void _reconnectOrEnd(RetryableClose reason) {
    final session = _session!;
    final snapshot = ReconnectSnapshot(
      peerMetadata: session.localTracks.peerMetadata,
      tracks: [
        for (final t in session.localTracks.tracks)
          if (_announcedLocalTracks.contains(t.trackId)) t.toContext(),
      ],
    );
    if (_reconnect.onRetryableLoss(reason, snapshot)) {
      _markSessionLost(session);
      _status = ConnectionStatus.reconnecting;
      _stats.stop();
    } else if (_reconnect.state == ReconnectState.failed) {
      unawaited(
        _finish(const Disconnected(DisconnectReason.reconnectionFailed)),
      );
    } else {
      unawaited(_finish(disconnectedFor(reason)));
    }
  }

  /// Ignores all later events from [session]. If it had joined, saves its
  /// remote peers and components so they are reported as gone before the
  /// next `Joined` (SPEC §22, D22).
  void _markSessionLost(_Session session) {
    if (session.isLost) return;
    session.isLost = true;
    if (session.isJoined) {
      _staleRemote = (
        peers: session.remote.peers,
        components: session.remote.components,
      );
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
    // Take the pending `connect()` completer before the teardown. The app may
    // call `connect()` again during the teardown (e.g. from a
    // `ReconnectionFailed` listener); that new call must not be failed by
    // this one.
    final connecting = _connecting;
    _connecting = null;
    _networkChangeDetector?.stop();
    final ended = Completer<void>();
    _previousSessionEnded = ended.future;
    try {
      await _teardown(session, sendDisconnect: sendDisconnect);
      _setCommunicationMode(on: false);
      if (error != null) _emit(error);
      _emit(disconnected);
    } finally {
      ended.complete();
    }
    if (connecting != null && !connecting.isCompleted) {
      connecting.completeError(
        connectError ??
            ConnectionException(
              reason: 'disconnected (${disconnected.reason.name})',
            ),
      );
    }
  }

  /// In this order: data channels, `disconnect` (when leaving), peer
  /// connection and local streams, socket. Without [waitForSocket] the
  /// socket close is started but not awaited.
  Future<void> _teardown(
    _Session session, {
    required bool sendDisconnect,
    bool waitForSocket = true,
  }) async {
    _stats.stop();
    await _dataChannels.close();
    if (sendDisconnect) session.engine.sendDisconnect();
    await session.engine.close();
    final socketClosing = session.signaling.close();
    if (waitForSocket) {
      await socketClosing;
    } else {
      // The socket has often failed already, and then so does its close.
      unawaited(
        socketClosing.catchError(
          (Object e) => _logger.debug('Closing the old socket failed: $e'),
        ),
      );
    }
    if (identical(_socket, session.signaling)) _socket = null;
  }

  /// The joined session for an app operation. Throws `StateError` before
  /// `Joined` and from the moment a connection loss starts a reconnection
  /// until `Reconnected`.
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

  /// Before a new session's `Joined`, the remote endpoints of the lost one
  /// are reported gone (every track, then every endpoint), so the new
  /// `Joined` snapshot is the only source of truth.
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
    switch (event) {
      case LocalTrackAdded(:final track):
        _announcedLocalTracks.add(track.trackId);
      case LocalTrackRemoved(:final trackId):
        _announcedLocalTracks.remove(trackId);
      case _:
    }
    if (!_events.isClosed) _events.add(event);
  }

  void _setCommunicationMode({required bool on}) {
    final audioOutput = _audioOutput;
    if (audioOutput == null || _inCommunicationMode == on) return;
    _inCommunicationMode = on;
    unawaited(
      (on
              ? audioOutput.enterCommunicationMode()
              : audioOutput.exitCommunicationMode())
          .catchError((Object e) {
            _logger.warn('Audio communication mode not changed: $e');
          }),
    );
  }

  static RoomType _roomTypeOf(PeerMessage_RoomType type) => switch (type) {
    PeerMessage_RoomType.ROOM_TYPE_CONFERENCE => RoomType.conference,
    PeerMessage_RoomType.ROOM_TYPE_AUDIO_ONLY => RoomType.audioOnly,
    PeerMessage_RoomType.ROOM_TYPE_LIVESTREAM => RoomType.livestream,
    _ => RoomType.unspecified,
  };
}

/// One socket plus one engine.
class _Session {
  _Session(this.signaling, this.engine, this.localTracks, this.remote);

  final SignalingSession signaling;
  final RtcEngine engine;
  final LocalTrackRegistry localTracks;
  final RemoteStore remote;
  RoomType roomType = RoomType.unspecified;

  /// Whether `Joined` was emitted for this session.
  bool isJoined = false;

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
    final old = _client._session;
    // Make the new session current first, so tearing down the old one emits
    // no `Disconnected` and its late events are ignored.
    final session = _client._newSession();
    if (old != null) {
      // The old session may not be marked lost yet (an attempt replaced
      // after its `Joined`).
      _client._markSessionLost(old);
      // Do not wait for the old socket to close: on a dead network the close
      // handshake can take seconds.
      await _client._teardown(old, sendDisconnect: false, waitForSocket: false);
    }
    if (!identical(_client._session, session)) return;
    try {
      await _client._open(session, peerMetadata);
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
