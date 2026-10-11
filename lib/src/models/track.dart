/// Public track models (SPEC §11, §14, §15). Owner: Architect.
///
/// Track contexts are immutable snapshots. Local and remote tracks are
/// separate types because they share almost no behavior.
library;

import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show MediaStream, MediaStreamTrack;
import 'package:meta/meta.dart';

/// What a track carries, as announced in its metadata.
enum TrackType {
  /// Camera video.
  camera('camera'),

  /// Microphone audio.
  microphone('microphone'),

  /// Screen share video.
  screenShareVideo('screenShareVideo'),

  /// Screen share audio.
  screenShareAudio('screenShareAudio'),

  /// Any other video.
  customVideo('customVideo'),

  /// Any other audio.
  customAudio('customAudio');

  TrackType(this.wireName);

  /// The value used in metadata JSON.
  final String wireName;

  /// The type for [wireName], or `null` when unknown.
  static TrackType? fromWireName(String wireName) {
    for (final t in values) {
      if (t.wireName == wireName) return t;
    }
    return null;
  }
}

/// Metadata attached to a published track, visible to every peer.
@immutable
final class TrackMetadata {
  /// Creates track metadata.
  const TrackMetadata({
    required this.type,
    this.paused = false,
    this.displayName,
  });

  /// What the track carries.
  final TrackType type;

  /// Whether the track is paused (muted) by its owner.
  final bool paused;

  /// The owner's display name, used in recordings.
  final String? displayName;

  /// Parses metadata of the shape `{type, paused, displayName?}`; returns
  /// `null` for anything else.
  static TrackMetadata? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final type = json['type'];
    final paused = json['paused'];
    final displayName = json['displayName'];
    if (type is! String) return null;
    final trackType = TrackType.fromWireName(type);
    if (trackType == null) return null;
    if (paused != null && paused is! bool) return null;
    if (displayName != null && displayName is! String) return null;
    return TrackMetadata(
      type: trackType,
      paused: (paused as bool?) ?? false,
      displayName: displayName as String?,
    );
  }

  /// JSON value sent to the server.
  Map<String, Object?> toJson() => {
    'type': type.wireName,
    'paused': paused,
    if (displayName != null) 'displayName': displayName,
  };

  /// Returns a copy with the given fields replaced.
  TrackMetadata copyWith({
    TrackType? type,
    bool? paused,
    String? displayName,
  }) => TrackMetadata(
    type: type ?? this.type,
    paused: paused ?? this.paused,
    displayName: displayName ?? this.displayName,
  );

  @override
  bool operator ==(Object other) =>
      other is TrackMetadata &&
      other.type == type &&
      other.paused == paused &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(type, paused, displayName);

  @override
  String toString() =>
      'TrackMetadata(type: ${type.wireName}, paused: $paused, '
      'displayName: $displayName)';
}

/// Voice activity of a remote audio track (SPEC §14.5).
enum VadStatus {
  /// Voice detected.
  speech,

  /// No voice detected.
  silence,
}

/// Why the server switched the variant being received. The server does not
/// report a reason today, so this is always `null` in practice; the type is
/// kept for forward compatibility.
enum EncodingReason {
  /// Unknown reason.
  other,

  /// The previously received variant became inactive.
  encodingInactive,

  /// Not enough bandwidth for the previously received variant.
  lowBandwidth,
}

/// Snapshot of a track, local or remote.
@immutable
sealed class TrackContext {
  const TrackContext({required this.trackId});

  /// Track id: `<endpointId>:<uuid>`.
  final String trackId;
}

/// Snapshot of a track published by this client.
final class LocalTrackContext extends TrackContext {
  /// Creates a local track snapshot.
  const LocalTrackContext({
    required super.trackId,
    required this.kind,
    required this.rtcTrack,
    required this.rtcStream,
    required this.metadata,
    required this.simulcastConfig,
    required this.maxBandwidth,
  });

  /// Audio or video.
  final MediaKind kind;

  /// The media track being sent (internal seam); `null` while muted.
  @internal
  final RtcMediaTrack? rtcTrack;

  /// The stream the track is associated with (internal seam).
  @internal
  final RtcMediaStream? rtcStream;

  /// The media track being sent; `null` while muted.
  MediaStreamTrack? get track => nativeTrackOf(rtcTrack);

  /// The stream the track is associated with, e.g. for a local preview.
  MediaStream? get stream => nativeStreamOf(rtcStream);

  /// The track's metadata.
  final TrackMetadata? metadata;

  /// Simulcast configuration.
  final SimulcastConfig simulcastConfig;

  /// Resolved bandwidth limit (SPEC §13).
  final BandwidthLimit maxBandwidth;

  /// Whether the track is muted (no media track is sent).
  bool get isMuted => rtcTrack == null;

  @override
  String toString() => 'LocalTrackContext($trackId, $kind)';
}

/// Snapshot of a track published by another endpoint.
final class RemoteTrackContext extends TrackContext {
  /// Creates a remote track snapshot.
  const RemoteTrackContext({
    required super.trackId,
    required this.endpointId,
    required this.rawMetadata,
    required this.simulcastConfig,
    this.kind,
    this.rtcTrack,
    this.rtcStream,
    this.vadStatus = VadStatus.silence,
    this.encoding,
    this.encodingReason,
  });

  /// Id of the endpoint publishing the track.
  final String endpointId;

  /// Audio or video; `null` until [track] is ready.
  final MediaKind? kind;

  /// The remote media (internal seam); `null` until `TrackReady`.
  @internal
  final RtcMediaTrack? rtcTrack;

  /// The stream the media belongs to (internal seam).
  @internal
  final RtcMediaStream? rtcStream;

  /// The remote media; `null` until `TrackReady`.
  MediaStreamTrack? get track => nativeTrackOf(rtcTrack);

  /// The stream to render (e.g. `RTCVideoRenderer.srcObject`); `null` until
  /// `TrackReady`.
  MediaStream? get stream => nativeStreamOf(rtcStream);

  /// Decoded metadata JSON as sent by the publisher.
  final Object? rawMetadata;

  /// [rawMetadata] parsed as [TrackMetadata], when it has that shape.
  TrackMetadata? get metadata => TrackMetadata.tryParse(rawMetadata);

  /// Simulcast configuration announced by the server.
  final SimulcastConfig simulcastConfig;

  /// Voice activity (audio tracks).
  final VadStatus vadStatus;

  /// The variant currently received (simulcast tracks).
  final Variant? encoding;

  /// Why [encoding] was chosen; currently never reported by the server.
  final EncodingReason? encodingReason;

  /// Whether media has arrived.
  bool get isReady => rtcTrack != null;

  /// Returns a copy with the given fields replaced.
  RemoteTrackContext copyWith({
    MediaKind? kind,
    RtcMediaTrack? rtcTrack,
    RtcMediaStream? rtcStream,
    Object? rawMetadata,
    SimulcastConfig? simulcastConfig,
    VadStatus? vadStatus,
    Variant? encoding,
  }) => RemoteTrackContext(
    trackId: trackId,
    endpointId: endpointId,
    kind: kind ?? this.kind,
    rtcTrack: rtcTrack ?? this.rtcTrack,
    rtcStream: rtcStream ?? this.rtcStream,
    rawMetadata: rawMetadata ?? this.rawMetadata,
    simulcastConfig: simulcastConfig ?? this.simulcastConfig,
    vadStatus: vadStatus ?? this.vadStatus,
    encoding: encoding ?? this.encoding,
    encodingReason: encodingReason,
  );

  @override
  String toString() => 'RemoteTrackContext($trackId from $endpointId)';
}
