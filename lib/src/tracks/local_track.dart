/// Local tracks: registry and per-track sender operations (SPEC §10, §11,
/// §13, §18).
///
/// Owner: **Tracks** agent. The Engine drives negotiation and calls into
/// [LocalTrackRegistry]; it never touches senders directly.
library;

// Constructor fields are kept for the Tracks implementation.
// ignore_for_file: unused_field

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Negotiation status of a local track (SPEC §11.6).
enum TrackNegotiationStatus {
  /// Registered; not yet in an offer.
  pending,

  /// In the `sdpOffer` currently in flight.
  offered,

  /// Acknowledged by an answer.
  negotiated,
}

/// One published track and its sender.
///
/// Owner: Tracks.
class LocalTrack {
  /// Creates a local track. [maxBandwidth] is already resolved.
  LocalTrack({
    required this.trackId,
    required this.kind,
    required this._track,
    required this.stream,
    required this._metadata,
    required this.simulcastConfig,
    required this._maxBandwidth,
  });

  /// Track id `<peerId>:<uuid>`.
  final String trackId;

  /// Audio or video.
  final MediaKind kind;

  /// Associated stream.
  final RtcMediaStream? stream;

  /// Simulcast configuration.
  final SimulcastConfig simulcastConfig;

  final RtcMediaTrack? _track;
  final TrackMetadata? _metadata;
  final BandwidthLimit _maxBandwidth;

  /// Current media track; `null` while muted.
  RtcMediaTrack? get track => throw UnimplementedError('Tracks');

  /// Current metadata.
  TrackMetadata? get metadata => throw UnimplementedError('Tracks');

  /// Resolved bandwidth limit.
  BandwidthLimit get maxBandwidth => throw UnimplementedError('Tracks');

  /// Mid from the last answer; `null` before the first answer.
  String? mid;

  /// Negotiation status.
  TrackNegotiationStatus negotiationStatus = TrackNegotiationStatus.pending;

  /// Whether a metadata update must be sent after the current answer.
  bool pendingMetadataUpdate = false;

  /// The transceiver sending this track, once added to a connection.
  RtcRtpTransceiver? transceiver;

  /// Immutable snapshot for events and getters.
  LocalTrackContext toContext() => throw UnimplementedError('Tracks');

  /// Adds this track as a send transceiver on [pc] (SPEC §11.1).
  Future<void> addToConnection(RtcPeerConnection pc) =>
      throw UnimplementedError('Tracks');

  /// Replaces the sent media (mute / unmute / replace, SPEC §11.3) and
  /// returns which action happened. Restores state when the sender fails.
  Future<ReplaceAction> replaceTrack(RtcMediaTrack? newTrack) =>
      throw UnimplementedError('Tracks');

  /// Applies an already resolved limit to the sender (SPEC §13.6) and
  /// stores it.
  Future<void> setBandwidth(BandwidthLimit resolved) =>
      throw UnimplementedError('Tracks');

  /// Applies an already resolved layer limit (SPEC §13.6) and stores it.
  Future<void> setEncodingBandwidth(Variant variant, int resolvedKbps) =>
      throw UnimplementedError('Tracks');

  /// Activates or deactivates one simulcast layer (SPEC §11.4).
  Future<void> setEncodingActive(Variant variant, {required bool active}) =>
      throw UnimplementedError('Tracks');

  /// Stores new metadata.
  set metadata(TrackMetadata? value) => throw UnimplementedError('Tracks');

  /// Audio level from sender stats (SPEC §18).
  Future<double?> audioLevel() => throw UnimplementedError('Tracks');
}

/// Result of [LocalTrack.replaceTrack].
enum ReplaceAction {
  /// Media removed.
  mute,

  /// Media restored.
  unmute,

  /// Media swapped.
  replace,
}

/// All local tracks of a session, plus the local peer's metadata and id.
///
/// Owner: Tracks.
class LocalTrackRegistry {
  /// Creates an empty registry.
  LocalTrackRegistry({
    required this._logger,
    required this._sendMediaEvent,
    required this._emit,
  });

  final FishjamLogger _logger;
  final void Function(peer.MediaEvent event) _sendMediaEvent;
  final void Function(FishjamEvent event) _emit;

  /// Local peer id; empty until `connected`.
  String peerId = '';

  /// Local peer metadata (`peer` part).
  Object? peerMetadata;

  /// Local peer metadata (`server` part), as reported in `connected`.
  Object? serverMetadata;

  /// Registered tracks in registration order.
  List<LocalTrack> get tracks => throw UnimplementedError('Tracks');

  /// The track with [trackId]; throws [ArgumentError] when unknown.
  LocalTrack byId(String trackId) => throw UnimplementedError('Tracks');

  /// Generates a new track id `<peerId>:<uuid v4>`.
  String newTrackId() => throw UnimplementedError('Tracks');

  /// Registers [track].
  void register(LocalTrack track) => throw UnimplementedError('Tracks');

  /// Unregisters [trackId] and returns the removed track.
  LocalTrack unregister(String trackId) => throw UnimplementedError('Tracks');

  /// Whether [mediaTrack] is already published by some local track.
  bool isPublished(RtcMediaTrack mediaTrack) =>
      throw UnimplementedError('Tracks');

  /// `trackIdToMetadataJson` for an `sdpOffer` (SPEC §10.1).
  Map<String, String> trackIdToMetadataJson() =>
      throw UnimplementedError('Tracks');

  /// `trackIdToBitrates` for an `sdpOffer` (SPEC §10.1).
  Map<String, peer.MediaEvent_TrackBitrates> trackIdToBitrates() =>
      throw UnimplementedError('Tracks');

  /// `midToTrackId` for an `sdpOffer`, built from [transceivers] after
  /// `setLocalDescription` (SPEC §10.1).
  Future<Map<String, String>> midToTrackId(
    List<RtcRtpTransceiver> transceivers,
  ) => throw UnimplementedError('Tracks');

  /// Stores mids from an answer for local tracks (SPEC §10.2).
  void applyAnswerMids(Map<String, String> midToTrackId) =>
      throw UnimplementedError('Tracks');

  /// Snapshot of the local peer.
  LocalPeer toLocalPeer() => throw UnimplementedError('Tracks');

  /// SPEC §11.3: mute / unmute / replace [trackId]'s media, with its media
  /// events and client events; on failure emits the opposite event and
  /// rethrows. Unknown id → [ArgumentError].
  Future<void> replaceTrack(String trackId, RtcMediaTrack? newTrack) =>
      throw UnimplementedError('Tracks');
}
