import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:meta/meta.dart';

/// An event emitted by `FishjamClient.events`.
///
/// The hierarchy is sealed so apps can `switch` exhaustively. Every event
/// carries immutable snapshots taken when it was emitted.
@immutable
sealed class FishjamEvent {
  const FishjamEvent();
}

// ---------------------------------------------------------------- connection

/// The server accepted the peer token.
final class AuthSucceeded extends FishjamEvent {
  const AuthSucceeded({required this.roomType});

  final RoomType roomType;
}

/// The server rejected the peer token. Followed by [Disconnected].
final class AuthFailed extends FishjamEvent {
  const AuthFailed(this.reason);

  final AuthErrorReason reason;
}

/// The server refused the join. Followed by [Disconnected].
final class JoinFailed extends FishjamEvent {
  const JoinFailed(this.reason);

  final JoinErrorReason reason;
}

/// The client joined the room; emitted once per session, including after a
/// reconnection.
final class Joined extends FishjamEvent {
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
  const Disconnected(this.reason, {this.closeCode, this.closeReason});

  final DisconnectReason reason;

  /// WebSocket close code, when a socket close caused it.
  final int? closeCode;

  /// WebSocket close reason, when a socket close caused it.
  final String? closeReason;
}

/// A retryable connection loss started reconnection.
final class ReconnectionStarted extends FishjamEvent {
  const ReconnectionStarted();
}

/// Reconnection completed; tracks were restored if configured.
final class Reconnected extends FishjamEvent {
  const Reconnected();
}

/// Every reconnection attempt failed. Followed by [Disconnected].
final class ReconnectionFailed extends FishjamEvent {
  const ReconnectionFailed();
}

/// The peer connection or ICE failed.
final class ConnectionError extends FishjamEvent {
  const ConnectionError(this.message);

  /// What failed.
  final String message;
}

/// The server sent an error media event; the client leaves.
final class ServerError extends FishjamEvent {
  const ServerError(this.message);

  /// The server's message.
  final String message;
}

// ------------------------------------------------------------ remote peers

/// Another peer joined the room.
final class PeerJoined extends FishjamEvent {
  const PeerJoined(this.peer);

  final Peer peer;
}

/// Another peer left the room (after [TrackRemoved] for each of its tracks).
final class PeerLeft extends FishjamEvent {
  const PeerLeft(this.peer);

  /// The peer, as it was before leaving.
  final Peer peer;
}

/// Another peer updated its metadata.
final class PeerUpdated extends FishjamEvent {
  const PeerUpdated(this.peer);

  final Peer peer;
}

/// A component was added to the room.
final class ComponentAdded extends FishjamEvent {
  const ComponentAdded(this.component);

  final Component component;
}

/// A component was removed from the room.
final class ComponentRemoved extends FishjamEvent {
  const ComponentRemoved(this.component);

  /// The component, as it was before removal.
  final Component component;
}

/// A component's metadata changed.
final class ComponentUpdated extends FishjamEvent {
  const ComponentUpdated(this.component);

  final Component component;
}

// ----------------------------------------------------------- remote tracks

/// A remote track was announced; media is not there yet.
final class TrackAdded extends FishjamEvent {
  const TrackAdded(this.track);

  final RemoteTrackContext track;
}

/// Media of a remote track arrived and can be rendered.
final class TrackReady extends FishjamEvent {
  const TrackReady(this.track);

  /// The track, with `track` and `stream` set.
  final RemoteTrackContext track;
}

/// A remote track was removed.
final class TrackRemoved extends FishjamEvent {
  const TrackRemoved(this.track);

  /// The track, as it was before removal.
  final RemoteTrackContext track;
}

/// A remote track's metadata changed.
final class TrackUpdated extends FishjamEvent {
  const TrackUpdated(this.track);

  final RemoteTrackContext track;
}

/// The variant received for a simulcast track changed.
final class TrackEncodingChanged extends FishjamEvent {
  const TrackEncodingChanged(this.track);

  /// The track; see `encoding`.
  final RemoteTrackContext track;
}

/// A remote track's enabled/disabled variants changed.
final class TrackVariantsChanged extends FishjamEvent {
  const TrackVariantsChanged(this.track);

  /// The track; see `simulcastConfig`.
  final RemoteTrackContext track;
}

/// Voice activity of a remote track changed.
final class VoiceActivityChanged extends FishjamEvent {
  const VoiceActivityChanged(this.track);

  /// The track; see `vadStatus`.
  final RemoteTrackContext track;
}

/// The client asked the server to send another variant.
final class TargetTrackEncodingRequested extends FishjamEvent {
  const TargetTrackEncodingRequested(this.trackId, this.variant);

  final String trackId;

  final Variant variant;
}

// ------------------------------------------------------------ local tracks

/// A local track was published.
final class LocalTrackAdded extends FishjamEvent {
  const LocalTrackAdded(this.track);

  final LocalTrackContext track;
}

/// A local track was unpublished.
final class LocalTrackRemoved extends FishjamEvent {
  const LocalTrackRemoved(this.trackId);

  final String trackId;
}

/// A local track's media was replaced.
final class LocalTrackReplaced extends FishjamEvent {
  const LocalTrackReplaced(this.trackId, this.rtcTrack);

  final String trackId;

  @internal
  final RtcMediaTrack? rtcTrack;

  /// The new media track, or `null` when muted.
  MediaStreamTrack? get track => nativeTrackOf(rtcTrack);
}

/// A local track was muted by replacing its media with nothing.
final class LocalTrackMuted extends FishjamEvent {
  const LocalTrackMuted(this.trackId);

  final String trackId;
}

/// A muted local track got media again.
final class LocalTrackUnmuted extends FishjamEvent {
  const LocalTrackUnmuted(this.trackId);

  final String trackId;
}

/// A local track's bandwidth limit changed.
final class LocalTrackBandwidthSet extends FishjamEvent {
  const LocalTrackBandwidthSet(this.trackId, this.bandwidth);

  final String trackId;

  /// The resolved limit.
  final BandwidthLimit bandwidth;
}

/// One simulcast layer's bandwidth limit changed.
final class LocalTrackEncodingBandwidthSet extends FishjamEvent {
  const LocalTrackEncodingBandwidthSet(this.trackId, this.variant, this.kbps);

  final String trackId;

  final Variant variant;

  /// The resolved limit in kbps.
  final int kbps;
}

/// A simulcast layer of a local track is sent again.
final class LocalTrackEncodingEnabled extends FishjamEvent {
  const LocalTrackEncodingEnabled(this.trackId, this.variant);

  final String trackId;

  final Variant variant;
}

/// A simulcast layer of a local track is no longer sent.
final class LocalTrackEncodingDisabled extends FishjamEvent {
  const LocalTrackEncodingDisabled(this.trackId, this.variant);

  final String trackId;

  final Variant variant;
}

/// This peer's metadata was updated.
final class LocalPeerMetadataChanged extends FishjamEvent {
  const LocalPeerMetadataChanged(this.metadata);

  final Object? metadata;
}

/// A local track's metadata was sent to the server.
final class LocalTrackMetadataChanged extends FishjamEvent {
  const LocalTrackMetadataChanged(this.trackId, this.metadata);

  final String trackId;

  final TrackMetadata? metadata;
}

// ----------------------------------------------------------- data channels

/// Both data channels are open.
final class DataChannelsReady extends FishjamEvent {
  const DataChannelsReady();
}

/// A data channel failed.
final class DataChannelsError extends FishjamEvent {
  const DataChannelsError(this.error);

  /// What failed.
  final Object error;
}
