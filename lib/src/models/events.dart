/// Events emitted by `FishjamClient.events` (replaces the web SDK's typed
/// event emitter). Owner: Architect.
///
/// The hierarchy is sealed so apps can `switch` exhaustively. Every event
/// carries immutable snapshots taken when it was emitted (SPEC §15).
/// See `docs/parity.md` for the mapping from web SDK event names.
library;

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:meta/meta.dart';

/// Base class of every client event.
@immutable
sealed class FishjamEvent {
  const FishjamEvent();
}

// ---------------------------------------------------------------- connection

/// The server accepted the peer token (SPEC §3.2).
final class AuthSucceeded extends FishjamEvent {
  /// Creates the event.
  const AuthSucceeded({required this.roomType});

  /// Type of the room.
  final RoomType roomType;
}

/// The server rejected the peer token (SPEC §4). Followed by [Disconnected].
final class AuthFailed extends FishjamEvent {
  /// Creates the event.
  const AuthFailed(this.reason);

  /// Why.
  final AuthErrorReason reason;
}

/// The server refused the join (SPEC §4). Followed by [Disconnected].
final class JoinFailed extends FishjamEvent {
  /// Creates the event.
  const JoinFailed(this.reason);

  /// Why.
  final JoinErrorReason reason;
}

/// The client joined the room; emitted once per session, including after a
/// reconnection (SPEC §3.2, §6).
final class Joined extends FishjamEvent {
  /// Creates the event.
  const Joined({
    required this.peerId,
    required this.peers,
    required this.components,
  });

  /// This client's peer id.
  final String peerId;

  /// Other peers already in the room, with their tracks.
  final List<Peer> peers;

  /// Components already in the room, with their tracks.
  final List<Component> components;
}

/// The client is no longer connected. Emitted exactly once per `connect()`
/// that reached the socket, and never during a reconnection.
final class Disconnected extends FishjamEvent {
  /// Creates the event.
  const Disconnected(this.reason, {this.closeCode, this.closeReason});

  /// Why.
  final DisconnectReason reason;

  /// WebSocket close code, when a socket close caused it.
  final int? closeCode;

  /// WebSocket close reason, when a socket close caused it.
  final String? closeReason;
}

/// A retryable connection loss started reconnection (SPEC §6).
final class ReconnectionStarted extends FishjamEvent {
  /// Creates the event.
  const ReconnectionStarted();
}

/// Reconnection completed; tracks were restored if configured (SPEC §6).
final class Reconnected extends FishjamEvent {
  /// Creates the event.
  const Reconnected();
}

/// Every reconnection attempt failed. Followed by [Disconnected].
final class ReconnectionFailed extends FishjamEvent {
  /// Creates the event.
  const ReconnectionFailed();
}

/// The peer connection or ICE failed (SPEC §8.4).
final class ConnectionError extends FishjamEvent {
  /// Creates the event.
  const ConnectionError(this.message);

  /// What failed.
  final String message;
}

/// The server sent an error media event; the client leaves (SPEC §3.4).
final class ServerError extends FishjamEvent {
  /// Creates the event.
  const ServerError(this.message);

  /// The server's message.
  final String message;
}

// ------------------------------------------------------------ remote peers

/// Another peer joined the room.
final class PeerJoined extends FishjamEvent {
  /// Creates the event.
  const PeerJoined(this.peer);

  /// The peer.
  final Peer peer;
}

/// Another peer left the room (after [TrackRemoved] for each of its tracks).
final class PeerLeft extends FishjamEvent {
  /// Creates the event.
  const PeerLeft(this.peer);

  /// The peer, as it was before leaving.
  final Peer peer;
}

/// Another peer updated its metadata.
final class PeerUpdated extends FishjamEvent {
  /// Creates the event.
  const PeerUpdated(this.peer);

  /// The peer.
  final Peer peer;
}

/// A component was added to the room.
final class ComponentAdded extends FishjamEvent {
  /// Creates the event.
  const ComponentAdded(this.component);

  /// The component.
  final Component component;
}

/// A component was removed from the room.
final class ComponentRemoved extends FishjamEvent {
  /// Creates the event.
  const ComponentRemoved(this.component);

  /// The component, as it was before removal.
  final Component component;
}

/// A component's metadata changed.
final class ComponentUpdated extends FishjamEvent {
  /// Creates the event.
  const ComponentUpdated(this.component);

  /// The component.
  final Component component;
}

// ----------------------------------------------------------- remote tracks

/// A remote track was announced; media is not there yet (SPEC §14.2).
final class TrackAdded extends FishjamEvent {
  /// Creates the event.
  const TrackAdded(this.track);

  /// The track.
  final RemoteTrackContext track;
}

/// Media of a remote track arrived and can be rendered (SPEC §14.3).
final class TrackReady extends FishjamEvent {
  /// Creates the event.
  const TrackReady(this.track);

  /// The track, with `track` and `stream` set.
  final RemoteTrackContext track;
}

/// A remote track was removed.
final class TrackRemoved extends FishjamEvent {
  /// Creates the event.
  const TrackRemoved(this.track);

  /// The track, as it was before removal.
  final RemoteTrackContext track;
}

/// A remote track's metadata changed.
final class TrackUpdated extends FishjamEvent {
  /// Creates the event.
  const TrackUpdated(this.track);

  /// The track.
  final RemoteTrackContext track;
}

/// The variant received for a simulcast track changed (SPEC §14.4).
final class TrackEncodingChanged extends FishjamEvent {
  /// Creates the event.
  const TrackEncodingChanged(this.track);

  /// The track; see `encoding`.
  final RemoteTrackContext track;
}

/// A remote track's enabled/disabled variants changed (SPEC §14.4).
final class TrackVariantsChanged extends FishjamEvent {
  /// Creates the event.
  const TrackVariantsChanged(this.track);

  /// The track; see `simulcastConfig`.
  final RemoteTrackContext track;
}

/// Voice activity of a remote track changed (SPEC §14.5).
final class VoiceActivityChanged extends FishjamEvent {
  /// Creates the event.
  const VoiceActivityChanged(this.track);

  /// The track; see `vadStatus`.
  final RemoteTrackContext track;
}

/// The client asked the server to send another variant (SPEC §14.4).
final class TargetTrackEncodingRequested extends FishjamEvent {
  /// Creates the event.
  const TargetTrackEncodingRequested(this.trackId, this.variant);

  /// Remote track id.
  final String trackId;

  /// Requested variant.
  final Variant variant;
}

// ------------------------------------------------------------ local tracks

/// A local track was published (SPEC §11.1).
final class LocalTrackAdded extends FishjamEvent {
  /// Creates the event.
  const LocalTrackAdded(this.track);

  /// The track.
  final LocalTrackContext track;
}

/// A local track was unpublished (SPEC §11.2).
final class LocalTrackRemoved extends FishjamEvent {
  /// Creates the event.
  const LocalTrackRemoved(this.trackId);

  /// Track id.
  final String trackId;
}

/// A local track's media was replaced (SPEC §11.3).
final class LocalTrackReplaced extends FishjamEvent {
  /// Creates the event.
  const LocalTrackReplaced(this.trackId, this.track);

  /// Track id.
  final String trackId;

  /// The new media track, or `null` when muted.
  final RtcMediaTrack? track;
}

/// A local track was muted by replacing its media with nothing (SPEC §11.3).
final class LocalTrackMuted extends FishjamEvent {
  /// Creates the event.
  const LocalTrackMuted(this.trackId);

  /// Track id.
  final String trackId;
}

/// A muted local track got media again (SPEC §11.3).
final class LocalTrackUnmuted extends FishjamEvent {
  /// Creates the event.
  const LocalTrackUnmuted(this.trackId);

  /// Track id.
  final String trackId;
}

/// A local track's bandwidth limit changed (SPEC §11.5).
final class LocalTrackBandwidthSet extends FishjamEvent {
  /// Creates the event.
  const LocalTrackBandwidthSet(this.trackId, this.bandwidth);

  /// Track id.
  final String trackId;

  /// The resolved limit.
  final BandwidthLimit bandwidth;
}

/// One simulcast layer's bandwidth limit changed (SPEC §11.5).
final class LocalTrackEncodingBandwidthSet extends FishjamEvent {
  /// Creates the event.
  const LocalTrackEncodingBandwidthSet(this.trackId, this.variant, this.kbps);

  /// Track id.
  final String trackId;

  /// The layer.
  final Variant variant;

  /// The resolved limit in kbps.
  final int kbps;
}

/// A simulcast layer of a local track is sent again (SPEC §11.4).
final class LocalTrackEncodingEnabled extends FishjamEvent {
  /// Creates the event.
  const LocalTrackEncodingEnabled(this.trackId, this.variant);

  /// Track id.
  final String trackId;

  /// The layer.
  final Variant variant;
}

/// A simulcast layer of a local track is no longer sent (SPEC §11.4).
final class LocalTrackEncodingDisabled extends FishjamEvent {
  /// Creates the event.
  const LocalTrackEncodingDisabled(this.trackId, this.variant);

  /// Track id.
  final String trackId;

  /// The layer.
  final Variant variant;
}

/// This peer's metadata was updated (SPEC §11.6).
final class LocalPeerMetadataChanged extends FishjamEvent {
  /// Creates the event.
  const LocalPeerMetadataChanged(this.metadata);

  /// The new peer metadata.
  final Object? metadata;
}

/// A local track's metadata was sent to the server (SPEC §11.6).
final class LocalTrackMetadataChanged extends FishjamEvent {
  /// Creates the event.
  const LocalTrackMetadataChanged(this.trackId, this.metadata);

  /// Track id.
  final String trackId;

  /// The new metadata.
  final TrackMetadata? metadata;
}

// ----------------------------------------------------------- data channels

/// Both data channels are open (SPEC §16).
final class DataChannelsReady extends FishjamEvent {
  /// Creates the event.
  const DataChannelsReady();
}

/// A data channel failed (SPEC §16).
final class DataChannelsError extends FishjamEvent {
  /// Creates the event.
  const DataChannelsError(this.error);

  /// What failed.
  final Object error;
}
