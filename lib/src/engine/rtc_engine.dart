/// The per-session media engine: media event dispatch, peer connection,
/// negotiation, ICE (SPEC §7–§10, §11 orchestration).
///
/// Owner: **Engine** agent. It owns the peer connection and the negotiation
/// state machine; local/remote state lives in the Tracks module and data
/// channels in the Data module.
library;

// Constructor fields are kept for the Engine implementation.
// ignore_for_file: unused_field

import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';

/// One session's media engine. A reconnection creates a new engine.
///
/// Owner: Engine.
class RtcEngine {
  /// Creates an engine. `sendMediaEvent` hands events to signaling; `emit`
  /// publishes client events. [localTracks] and [remote] are owned by the
  /// Tracks module and injected so they can be replaced in tests.
  RtcEngine({
    required this._adapter,
    required this._logger,
    required this._sendMediaEvent,
    required this._emit,
    required this.localTracks,
    required this.remote,
  });

  /// Local tracks and local peer state.
  final LocalTrackRegistry localTracks;

  /// Remote endpoints and tracks.
  final RemoteStore remote;

  final RtcAdapter _adapter;
  final FishjamLogger _logger;
  final void Function(peer.MediaEvent event) _sendMediaEvent;
  final void Function(FishjamEvent event) _emit;

  /// Sends `connect{metadataJson}` (SPEC §3.2).
  void connect(Object? peerMetadata) => throw UnimplementedError('Engine');

  /// Queues [event] for strictly serialized handling (SPEC §7). The future
  /// completes when this event was handled.
  Future<void> handleServerEvent(server.MediaEvent event) =>
      throw UnimplementedError('Engine');

  /// Completes with `Joined` data once `connected` was handled.
  Future<Joined> get joined => throw UnimplementedError('Engine');

  /// The peer connection, created lazily (SPEC §8.4). Used by the Data and
  /// Stats modules.
  Future<RtcPeerConnection> ensurePeerConnection() =>
      throw UnimplementedError('Engine');

  /// The peer connection if it exists.
  RtcPeerConnection? get peerConnection => throw UnimplementedError('Engine');

  /// SPEC §11.1. Returns the new track id.
  Future<String> addTrack(
    RtcMediaTrack track, {
    TrackMetadata? metadata,
    SimulcastConfig simulcastConfig = const SimulcastConfig.disabled(),
    BandwidthLimit maxBandwidth = BandwidthLimit.unlimited,
    RtcMediaStream? stream,
  }) => throw UnimplementedError('Engine');

  /// SPEC §11.2.
  Future<void> removeTrack(String trackId) =>
      throw UnimplementedError('Engine');

  /// SPEC §11.3.
  Future<void> replaceTrack(String trackId, RtcMediaTrack? track) =>
      throw UnimplementedError('Engine');

  /// Runs a batchable negotiating command for the Data module (SPEC §16):
  /// [apply] creates the channels on the peer connection.
  Future<void> negotiate(Future<void> Function(RtcPeerConnection pc) apply) =>
      throw UnimplementedError('Engine');

  /// SPEC §11.6.
  void updatePeerMetadata(Object? metadata) =>
      throw UnimplementedError('Engine');

  /// SPEC §11.6.
  void updateTrackMetadata(String trackId, TrackMetadata? metadata) =>
      throw UnimplementedError('Engine');

  /// Sends `disconnect` (SPEC §3.3 step 1). Does not tear down.
  void sendDisconnect() => throw UnimplementedError('Engine');

  /// Fails pending commands, closes the peer connection, cancels
  /// subscriptions. Emits nothing.
  Future<void> close() => throw UnimplementedError('Engine');
}
