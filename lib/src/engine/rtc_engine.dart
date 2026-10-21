import 'dart:async';

import 'package:fishjam_client/src/engine/command_queue.dart';
import 'package:fishjam_client/src/engine/negotiation_state.dart';
import 'package:fishjam_client/src/engine/receive_transceivers.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/local_track_registry.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:fishjam_client/src/wire.dart';

/// How the server ended the session through a media event: a server `error`,
/// or `endpointRemoved` for the local peer.
enum EngineEnd { serverError, localPeerRemoved }

/// One session's media engine: media event dispatch, the peer connection,
/// negotiation and ICE. A reconnection creates a new engine.
///
/// Media events and commands run on one [SerialExecutor], so every server
/// event is handled completely before the next one and a command never
/// interleaves with an offer being built.
class RtcEngine {
  /// The callbacks report session-level outcomes the owner of the session
  /// acts on: [onServerError] after `ServerError` was emitted (leave),
  /// [onLocalPeerRemoved] when the server removed this peer,
  /// [onConnectionFailed] after `ConnectionError` was emitted (a retryable
  /// loss). They never run inside an engine task, so they may await engine
  /// work or call [close].
  RtcEngine({
    required this._adapter,
    required this._logger,
    required this._sendMediaEvent,
    required this._emit,
    required this.localTracks,
    required this.remote,
    this.nativeCallTimeout = const Duration(seconds: 10),
    this.iceDisconnectedTimeout = const Duration(seconds: 3),
    this.onServerError,
    this.onLocalPeerRemoved,
    this.onConnectionFailed,
  }) {
    _commands = CommandQueue(
      negotiation: _negotiation,
      executor: _executor,
      perform: _perform,
    );
    // `joined` may fail (close before `connected`) with nobody listening.
    _joined.future.ignore();
  }

  final LocalTrackRegistry localTracks;

  final RemoteStore remote;

  /// Limit for each native call of a negotiation cycle (`createOffer`,
  /// `setLocalDescription`, `setRemoteDescription`).
  final Duration nativeCallTimeout;

  /// How long ICE may stay `disconnected` before it counts as a failure.
  final Duration iceDisconnectedTimeout;

  final void Function(String message)? onServerError;

  final void Function()? onLocalPeerRemoved;

  final void Function(String message)? onConnectionFailed;

  final RtcAdapter _adapter;
  final FishjamLogger _logger;
  final void Function(peer.MediaEvent event) _sendMediaEvent;
  final void Function(FishjamEvent event) _emit;

  final _executor = SerialExecutor();
  final _negotiation = NegotiationStateMachine();
  late final CommandQueue _commands;
  final _joined = Completer<Joined>();

  String? _localPeerId;
  List<IceServer> _iceServers = const [];
  RtcPeerConnection? _pc;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _hasRemoteDescription = false;
  final _pendingCandidates = <IceCandidate>[];

  /// Local candidates gathered while an offer is being prepared; they are
  /// sent right after it. `null` when not holding.
  List<IceCandidate>? _heldLocalCandidates;
  final _groupStreams = <String, RtcMediaStream>{};
  final _ownedStreams = <RtcMediaStream>{};
  bool _failed = false;
  bool _closed = false;
  Timer? _iceDisconnectedTimer;

  void connect(Object? peerMetadata) {
    localTracks.peerMetadata = peerMetadata;
    _send(
      peer.MediaEvent(
        connect: peer.MediaEvent_Connect(
          metadataJson: encodeMetadataJson(peerMetadata),
        ),
      ),
    );
  }

  /// Queues [event] for strictly serialized handling. The future
  /// completes when this event was handled; it never completes with an
  /// error.
  Future<void> handleServerEvent(server.MediaEvent event) =>
      _executor.run(() async {
        if (_closed) return;
        final content = event.whichContent();
        try {
          await _dispatch(content, event);
        } on Object catch (e, st) {
          if (_closed) {
            _logger.debug('Stopped handling ${content.name}: closed');
          } else {
            _logger.error('Failed to handle ${content.name}', e, st);
          }
        }
      });

  /// The terminal outcome announced by the server, recorded synchronously
  /// while its event is handled (the first one wins). The session owner
  /// reads it after the events received before a socket close were handled,
  /// so an error followed by a close is a server error, not a lost socket.
  EngineEnd? get endedBy => _endedBy;
  EngineEnd? _endedBy;

  Future<Joined> get joined => _joined.future;

  /// The peer connection, created lazily. Do not call it from inside a
  /// [negotiate] callback: both run on the executor.
  Future<RtcPeerConnection> ensurePeerConnection() =>
      _executor.run(_ensurePeerConnection);

  RtcPeerConnection? get peerConnection => _pc;

  /// Returns the new track id. The audio-only room check belongs to the
  /// caller, which knows the room type.
  Future<String> addTrack(
    RtcMediaTrack track, {
    TrackMetadata? metadata,
    SimulcastConfig simulcastConfig = const SimulcastConfig.disabled(),
    BandwidthLimit maxBandwidth = BandwidthLimit.unlimited,
    RtcMediaStream? stream,
  }) async {
    if (_closed) throw StateError('disconnected');
    if (_localPeerId == null) throw StateError('Not joined yet');
    LocalTrack? added;
    try {
      await _commands.push(
        Command(
          name: 'addTrack',
          completion: CommandCompletion.afterNegotiation,
          batchable: true,
          run: () async {
            if (localTracks.isPublished(track)) {
              throw ArgumentError.value(
                track.id,
                'track',
                'The media track is already published',
              );
            }
            final ownStream = stream == null;
            final trackStream = stream ?? await _streamFor(track, metadata);
            final local = newLocalTrack(
              trackId: localTracks.newTrackId(),
              track: track,
              stream: trackStream,
              metadata: metadata,
              simulcastConfig: simulcastConfig,
              maxBandwidth: maxBandwidth,
              logger: _logger,
            );
            if (ownStream) await trackStream.addTrack(track);
            localTracks.register(local);
            added = local;
            final pc = _pc;
            if (pc != null) await local.addToConnection(pc);
          },
        ),
      );
    } on Object {
      // A track whose addTrack failed never stays published.
      if (added case final failed?) await _discard(failed);
      rethrow;
    }
    final published = added!;
    _emit(LocalTrackAdded(published.toContext()));
    return published.trackId;
  }

  /// Unregisters [track], removes its sender and its media from an
  /// engine-owned stream.
  Future<void> _discard(LocalTrack track) async {
    if (localTracks.tracks.contains(track)) {
      localTracks.unregister(track.trackId);
    }
    if (_closed) return;
    try {
      final sender = track.transceiver?.sender;
      final pc = _pc;
      if (pc != null && sender != null) await pc.removeTrack(sender);
      final media = track.track;
      final stream = track.stream;
      if (media != null && _ownedStreams.contains(stream)) {
        await stream!.removeTrack(media);
      }
    } on Object catch (e, st) {
      _logger.warn('Failed to remove the sender of a failed track', e, st);
    }
  }

  Future<void> removeTrack(String trackId) async {
    localTracks.byId(trackId);
    await _commands.push(
      Command(
        name: 'removeTrack',
        completion: CommandCompletion.afterNegotiation,
        batchable: false,
        run: () async {
          final track = localTracks.byId(trackId);
          final sender = track.transceiver?.sender;
          final pc = _pc;
          if (pc != null && sender != null) await pc.removeTrack(sender);
          localTracks.unregister(trackId);
          final media = track.track;
          final stream = track.stream;
          if (media != null && _ownedStreams.contains(stream)) {
            await stream!.removeTrack(media);
          }
        },
      ),
    );
    _emit(LocalTrackRemoved(trackId));
  }

  /// A non-negotiating command; the registry emits the events, sends
  /// `unmuteTrack` and rolls back on failure.
  Future<void> replaceTrack(String trackId, RtcMediaTrack? track) async {
    localTracks.byId(trackId);
    await _commands.push(
      Command(
        name: 'replaceTrack',
        completion: CommandCompletion.onHandlerDone,
        batchable: false,
        run: () => localTracks.replaceTrack(trackId, track),
      ),
    );
  }

  /// Runs a batchable negotiating command for the data channels:
  /// [apply] creates the channels on the peer connection. Completes after
  /// the answer of the cycle that carried it. Fails with
  /// `StateError('not connected')` before `connected`.
  Future<void> negotiate(
    Future<void> Function(RtcPeerConnection pc) apply,
  ) async {
    if (!_closed && _localPeerId == null) {
      throw StateError('not connected');
    }
    await _commands.push(
      Command(
        name: 'negotiate',
        completion: CommandCompletion.afterNegotiation,
        batchable: true,
        run: () async {
          await apply(await _ensurePeerConnection());
        },
      ),
    );
  }

  void updatePeerMetadata(Object? metadata) {
    if (_closed) return;
    localTracks.peerMetadata = metadata;
    _send(
      peer.MediaEvent(
        updateEndpointMetadata: peer.MediaEvent_UpdateEndpointMetadata(
          metadataJson: encodeMetadataJson(metadata),
        ),
      ),
    );
    _emit(LocalPeerMetadataChanged(metadata));
  }

  /// Throws [ArgumentError] for an unknown track.
  void updateTrackMetadata(String trackId, TrackMetadata? metadata) {
    final track = localTracks.byId(trackId)..metadata = metadata;
    switch (track.negotiationStatus) {
      case TrackNegotiationStatus.pending:
        // The coming sdpOffer carries it; LocalTrackAdded reports it.
        break;
      case TrackNegotiationStatus.offered:
        track.pendingMetadataUpdate = true;
      case TrackNegotiationStatus.negotiated:
        _sendTrackMetadata(track);
    }
  }

  /// Sends `disconnect`; does not tear down (call [close] after it).
  void sendDisconnect() =>
      _send(peer.MediaEvent(disconnect: peer.MediaEvent_Disconnect()));

  /// Fails pending commands, closes the peer connection, cancels
  /// subscriptions, releases the streams the engine created. Emits
  /// nothing; failures of work still in flight are treated as
  /// cancellation.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _iceDisconnectedTimer?.cancel();
    _commands.failAll();
    _negotiation.reset();
    if (!_joined.isCompleted) _joined.completeError(StateError('disconnected'));
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final s in subscriptions) {
      await s.cancel();
    }
    await _pc?.close();
    for (final stream in _ownedStreams) {
      try {
        // The media tracks belong to the app: take them out first.
        for (final track in List.of(stream.tracks)) {
          await stream.removeTrack(track);
        }
        await stream.dispose();
      } on Object catch (e, st) {
        _logger.warn('Failed to release a local stream', e, st);
      }
    }
    _ownedStreams.clear();
    _groupStreams.clear();
  }

  Future<void> _dispatch(
    server.MediaEvent_Content content,
    server.MediaEvent event,
  ) async {
    if (_localPeerId == null &&
        content != server.MediaEvent_Content.connected) {
      _logger.debug('Dropped ${content.name} received before connected');
      return;
    }
    switch (content) {
      case server.MediaEvent_Content.connected:
        _onConnected(event.connected);
      case server.MediaEvent_Content.endpointAdded:
        if (_isRemote(event.endpointAdded.endpointId)) {
          remote.endpointAdded(event.endpointAdded);
        }
      case server.MediaEvent_Content.endpointUpdated:
        if (_isRemote(event.endpointUpdated.endpointId)) {
          remote.endpointUpdated(event.endpointUpdated);
        }
      case server.MediaEvent_Content.endpointRemoved:
        if (_isRemote(event.endpointRemoved.endpointId)) {
          remote.endpointRemoved(event.endpointRemoved);
        } else {
          _endedBy ??= EngineEnd.localPeerRemoved;
          _notifyOwner(() => onLocalPeerRemoved?.call());
        }
      case server.MediaEvent_Content.tracksAdded:
        if (_isRemote(event.tracksAdded.endpointId)) {
          _perform(_negotiation.handle(NegotiationInput.remoteTracksAdded));
          remote.tracksAdded(event.tracksAdded);
        }
      case server.MediaEvent_Content.tracksRemoved:
        if (_isRemote(event.tracksRemoved.endpointId)) {
          remote.tracksRemoved(event.tracksRemoved);
        }
      case server.MediaEvent_Content.trackUpdated:
        if (_isRemote(event.trackUpdated.endpointId)) {
          remote.trackUpdated(event.trackUpdated);
        }
      case server.MediaEvent_Content.trackVariantSwitched:
        remote.variantSwitched(event.trackVariantSwitched);
      case server.MediaEvent_Content.trackVariantEnabled:
        remote.variantEnabled(event.trackVariantEnabled);
      case server.MediaEvent_Content.trackVariantDisabled:
        remote.variantDisabled(event.trackVariantDisabled);
      case server.MediaEvent_Content.vadNotification:
        remote.vadNotification(event.vadNotification);
      case server.MediaEvent_Content.error:
        final message = event.error.message;
        _emit(ServerError(message));
        _endedBy ??= EngineEnd.serverError;
        _notifyOwner(() => onServerError?.call(message));
      case server.MediaEvent_Content.offerData:
        await _onOfferData(event.offerData);
      case server.MediaEvent_Content.sdpAnswer:
        await _onSdpAnswer(event.sdpAnswer);
      case server.MediaEvent_Content.candidate:
        await _onRemoteCandidate(event.candidate);
      case server.MediaEvent_Content.notSet:
        _logger.debug('Ignored a media event with unknown content (notSet)');
    }
  }

  /// Events about the local endpoint are ignored entirely: a local
  /// `tracksAdded` must not start a negotiation.
  bool _isRemote(String endpointId) {
    if (endpointId != _localPeerId) return true;
    _logger.debug('Ignored an event about the local endpoint');
    return false;
  }

  void _onConnected(server.MediaEvent_Connected connected) {
    if (_localPeerId != null) {
      _logger.warn('Ignored a second connected event');
      return;
    }
    final peerId = connected.endpointId;
    _iceServers = [
      for (final s in connected.iceServers)
        IceServer(
          urls: List.of(s.urls),
          username: s.username.isEmpty ? null : s.username,
          credential: s.credential.isEmpty ? null : s.credential,
        ),
    ];
    localTracks.peerId = peerId;
    final local = connected.endpointIdToEndpoint[peerId];
    if (local != null) {
      final metadata = Metadata.fromServerJson(
        decodeMetadataJson(
          local.metadataJson,
          onError: (e) => _logger.warn('Undecodable local peer metadata', e),
        ),
      );
      localTracks
        ..peerMetadata = metadata.peer
        ..serverMetadata = metadata.server;
    }
    remote.loadConnected(connected, peerId);
    _localPeerId = peerId;
    _joined.complete(
      Joined(
        peerId: peerId,
        peers: remote.peers,
        components: remote.components,
      ),
    );
  }

  void _perform(List<NegotiationEffect> effects) {
    for (final effect in effects) {
      switch (effect) {
        case NegotiationEffect.none:
          break;
        case NegotiationEffect.sendRenegotiateTracks:
          _send(
            peer.MediaEvent(
              renegotiateTracks: peer.MediaEvent_RenegotiateTracks(),
            ),
          );
        case NegotiationEffect.processNextCommand:
          _commands.pump();
      }
    }
  }

  Future<void> _onOfferData(server.MediaEvent_OfferData offerData) async {
    if (_negotiation.state == NegotiationState.offerSent) {
      _logger.warn(
        'offerData while an offer is in flight; the previous cycle was '
        'abandoned',
      );
    }
    try {
      final pc = await _ensurePeerConnection();
      await syncReceiveTransceivers(pc, offerData.tracksTypes);
      await _commands.drainBatch();
      final offer = await pc.createOffer().timeout(nativeCallTimeout);
      // Native stacks emit candidates during setLocalDescription, before
      // the offer is sent; the server rejects a candidate that precedes it.
      _heldLocalCandidates = [];
      await pc.setLocalDescription(offer).timeout(nativeCallTimeout);
      // Transceivers are snapshots: re-read them to see the new mids.
      final mids = await localTracks.midToTrackId(await pc.getTransceivers());
      if (_closed) return;
      final sdpOffer = peer.MediaEvent_SdpOffer(
        sdp: offer.sdp,
        trackIdToMetadataJson: localTracks.trackIdToMetadataJson().entries,
        trackIdToBitrates: localTracks.trackIdToBitrates().entries,
        midToTrackId: mids.entries,
      );
      for (final track in localTracks.tracks) {
        if (track.negotiationStatus == TrackNegotiationStatus.pending) {
          track.negotiationStatus = TrackNegotiationStatus.offered;
        }
      }
      _send(peer.MediaEvent(sdpOffer: sdpOffer));
      _releaseLocalCandidates();
      _perform(_negotiation.handle(NegotiationInput.offerSent));
    } on Object catch (e, st) {
      _heldLocalCandidates = null;
      _abortCycle('Failed to create the offer', e, st);
    }
  }

  Future<void> _onSdpAnswer(server.MediaEvent_SdpAnswer answer) async {
    final pc = _pc;
    if (_negotiation.state != NegotiationState.offerSent || pc == null) {
      _logger.warn('Ignored sdpAnswer: no offer in flight');
      return;
    }
    final mids = Map.of(answer.midToTrackId);
    localTracks.applyAnswerMids(mids);
    remote.applyAnswerMids(mids);
    try {
      await pc
          .setRemoteDescription(
            SessionDescription(type: SdpType.answer, sdp: answer.sdp),
          )
          .timeout(nativeCallTimeout);
    } on Object catch (e, st) {
      _abortCycle('Failed to apply the answer', e, st);
      return;
    }
    _hasRemoteDescription = true;
    final candidates = List.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in candidates) {
      await _addRemoteCandidate(pc, c);
    }
    if (_closed) return;
    for (final track in localTracks.tracks) {
      if (track.negotiationStatus != TrackNegotiationStatus.offered) continue;
      track.negotiationStatus = TrackNegotiationStatus.negotiated;
      if (track.pendingMetadataUpdate) _sendTrackMetadata(track);
    }
    _commands.completeCycle();
    _perform(_negotiation.handle(NegotiationInput.answerApplied));
  }

  /// A cycle cannot complete: the server waits for an offer
  /// that will not come, or the connection's descriptions are
  /// inconsistent. Fail the cycle's commands and report a connection
  /// failure so the session owner reconnects. After close it is a
  /// cancellation.
  void _abortCycle(String message, Object error, StackTrace stackTrace) {
    if (_closed) {
      _logger.debug('$message: cancelled by close');
      return;
    }
    _logger.error(message, error, stackTrace);
    _commands.failCycle(error);
    _negotiation.reset();
    _connectionFailed('$message: $error');
  }

  void _sendTrackMetadata(LocalTrack track) {
    track.pendingMetadataUpdate = false;
    _send(
      peer.MediaEvent(
        updateTrackMetadata: peer.MediaEvent_UpdateTrackMetadata(
          trackId: track.trackId,
          metadataJson: encodeMetadataJson(track.metadata?.toJson()),
        ),
      ),
    );
    _emit(LocalTrackMetadataChanged(track.trackId, track.metadata));
  }

  /// Runs on the executor.
  Future<RtcPeerConnection> _ensurePeerConnection() async {
    final existing = _pc;
    if (existing != null) return existing;
    if (_closed) throw StateError('disconnected');
    final pc = await _adapter.createPeerConnection(
      RtcConfiguration(iceServers: _iceServers),
    );
    if (_closed) {
      await pc.close();
      throw StateError('disconnected');
    }
    _pc = pc;
    _subscriptions.addAll([
      pc.onIceCandidate.listen(_onLocalCandidate),
      pc.onTrack.listen(_onTrack),
      pc.onIceConnectionState.listen(_onIceConnectionState),
      pc.onConnectionState.listen(_onConnectionState),
    ]);
    for (final track in localTracks.tracks) {
      await track.addToConnection(pc);
    }
    return pc;
  }

  void _onLocalCandidate(IceCandidate c) {
    final held = _heldLocalCandidates;
    if (held != null) {
      held.add(c);
    } else {
      _sendLocalCandidate(c);
    }
  }

  void _releaseLocalCandidates() {
    final held = _heldLocalCandidates ?? const <IceCandidate>[];
    _heldLocalCandidates = null;
    held.forEach(_sendLocalCandidate);
  }

  void _sendLocalCandidate(IceCandidate c) => _send(
    peer.MediaEvent(
      candidate: shared.Candidate(
        candidate: c.candidate,
        sdpMLineIndex: c.sdpMLineIndex,
        sdpMid: c.sdpMid,
        usernameFragment: c.usernameFragment,
      ),
    ),
  );

  void _onTrack(RtcTrackEvent event) {
    try {
      remote.trackReady(event);
    } on Object catch (e, st) {
      _logger.error('Failed to handle a remote track', e, st);
    }
  }

  void _onIceConnectionState(IceConnectionState state) {
    switch (state) {
      case IceConnectionState.disconnected:
        _logger.warn('ICE connection disconnected; requesting renegotiation');
        unawaited(
          _executor.run(() async {
            if (_closed) return;
            _perform(_negotiation.handle(NegotiationInput.iceDisconnected));
          }),
        );
        // The OS reports `failed` only after tens of seconds; a network
        // switch should not keep the call frozen that long.
        _iceDisconnectedTimer ??= Timer(
          iceDisconnectedTimeout,
          () => _connectionFailed(
            'ICE connection disconnected for '
            '${iceDisconnectedTimeout.inMilliseconds} ms',
          ),
        );
      case IceConnectionState.connected || IceConnectionState.completed:
        _iceDisconnectedTimer?.cancel();
        _iceDisconnectedTimer = null;
      case IceConnectionState.failed:
        _connectionFailed('ICE connection failed');
      case _:
        break;
    }
  }

  void _onConnectionState(PeerConnectionState state) {
    if (state == PeerConnectionState.failed) {
      _connectionFailed('Peer connection failed');
    }
  }

  void _connectionFailed(String message) {
    if (_failed || _closed) return;
    _failed = true;
    _emit(ConnectionError(message));
    _notifyOwner(() => onConnectionFailed?.call(message));
  }

  /// Runs an owner callback once every task queued on the executor so far
  /// has finished, never from inside a task.
  void _notifyOwner(void Function() callback) => unawaited(
    _executor.run(() async {}).then((_) {
      try {
        callback();
      } on Object catch (e, st) {
        _logger.error('A session callback failed', e, st);
      }
    }),
  );

  /// Remote candidates wait for a remote description.
  Future<void> _onRemoteCandidate(shared.Candidate c) async {
    final candidate = IceCandidate(
      candidate: c.candidate,
      sdpMLineIndex: c.sdpMLineIndex,
      sdpMid: c.sdpMid.isEmpty ? null : c.sdpMid,
      usernameFragment: c.usernameFragment.isEmpty ? null : c.usernameFragment,
    );
    final pc = _pc;
    if (pc == null || !_hasRemoteDescription) {
      _pendingCandidates.add(candidate);
      return;
    }
    await _addRemoteCandidate(pc, candidate);
  }

  Future<void> _addRemoteCandidate(
    RtcPeerConnection pc,
    IceCandidate candidate,
  ) async {
    try {
      await pc.addIceCandidate(candidate);
    } on Object catch (e, st) {
      _logger.warn('Failed to add a remote ICE candidate', e, st);
    }
  }

  /// The stream a new track is associated with: camera and microphone
  /// share one, screen share video and audio another, any other track gets
  /// its own.
  Future<RtcMediaStream> _streamFor(
    RtcMediaTrack track,
    TrackMetadata? metadata,
  ) async {
    final group = switch (metadata?.type) {
      TrackType.camera || TrackType.microphone => 'camera',
      TrackType.screenShareVideo || TrackType.screenShareAudio => 'screen',
      _ => null,
    };
    final existing = group == null ? null : _groupStreams[group];
    if (existing != null) return existing;
    final stream = await _adapter.createLocalMediaStream(group ?? track.id);
    _ownedStreams.add(stream);
    if (group != null) _groupStreams[group] = stream;
    return stream;
  }

  void _send(peer.MediaEvent event) {
    if (_closed) {
      _logger.debug('Not sent after close: ${event.whichContent().name}');
      return;
    }
    _sendMediaEvent(event);
  }
}
