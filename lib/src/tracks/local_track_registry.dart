import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/wire.dart';
import 'package:uuid/uuid.dart';

/// All local tracks of a session, plus the local peer's metadata and id.
///
/// Nothing here is reentrant: callers must not overlap operations on one
/// track (the engine serializes them).
class LocalTrackRegistry {
  LocalTrackRegistry({
    required this._logger,
    required this._sendMediaEvent,
    required this._emit,
  });

  final FishjamLogger _logger;
  final void Function(peer.MediaEvent event) _sendMediaEvent;
  final void Function(FishjamEvent event) _emit;
  final Map<String, LocalTrack> _tracks = {};

  static const _uuid = Uuid();

  /// Local peer id; empty until `connected`.
  String peerId = '';

  /// The `peer` part of the local peer's metadata.
  Object? peerMetadata;

  /// The `server` part, as reported in `connected`.
  Object? serverMetadata;

  /// In registration order.
  List<LocalTrack> get tracks => List.unmodifiable(_tracks.values);

  /// Throws [ArgumentError] when [trackId] is unknown.
  LocalTrack byId(String trackId) =>
      _tracks[trackId] ??
      (throw ArgumentError.value(trackId, 'trackId', 'unknown local track'));

  /// Track ids are `<peerId>:<uuid v4>`.
  String newTrackId() => '$peerId:${_uuid.v4()}';

  /// A duplicate id is an [ArgumentError].
  void register(LocalTrack track) {
    if (_tracks.containsKey(track.trackId)) {
      throw ArgumentError.value(track.trackId, 'trackId', 'already registered');
    }
    _tracks[track.trackId] = track;
  }

  /// Throws [ArgumentError] when [trackId] is unknown.
  LocalTrack unregister(String trackId) {
    final track = byId(trackId);
    _tracks.remove(trackId);
    return track;
  }

  bool isPublished(RtcMediaTrack mediaTrack) =>
      _tracks.values.any((t) => t.track?.id == mediaTrack.id);

  Map<String, String> trackIdToMetadataJson() => {
    for (final t in _tracks.values)
      t.trackId: encodeMetadataJson(t.metadata?.toJson()),
  };

  Map<String, peer.MediaEvent_TrackBitrates> trackIdToBitrates() => {
    for (final t in _tracks.values) t.trackId: _trackBitrates(t),
  };

  /// `midToTrackId` for an `sdpOffer`, built from [transceivers] after
  /// `setLocalDescription`. A transceiver is matched by its
  /// sender's media track id; tracks without media keep the mid of their
  /// last answer.
  Future<Map<String, String>> midToTrackId(
    List<RtcRtpTransceiver> transceivers,
  ) async {
    final mapping = <String, String>{};
    for (final transceiver in transceivers) {
      final mid = transceiver.mid;
      if (mid == null) continue;
      final media = transceiver.sender.track;
      if (media == null) continue;
      final owner = _tracks.values
          .where((t) => t.track?.id == media.id)
          .firstOrNull;
      if (owner != null) {
        mapping[mid] = owner.trackId;
      } else {
        _logger.warn(
          'Transceiver $mid sends media track ${media.id} that belongs to '
          'no local track; skipped in midToTrackId',
        );
      }
    }
    for (final t in _tracks.values) {
      if (t.mid case final mid?) mapping.putIfAbsent(mid, () => t.trackId);
    }
    return mapping;
  }

  /// Stores mids from an answer for local tracks. Other ids
  /// belong to remote tracks and are ignored here.
  void applyAnswerMids(Map<String, String> midToTrackId) {
    for (final MapEntry(key: mid, value: trackId) in midToTrackId.entries) {
      _tracks[trackId]?.mid = mid;
    }
  }

  LocalPeer toLocalPeer() => LocalPeer(
    id: peerId,
    metadata: Metadata(peer: peerMetadata, server: serverMetadata),
    tracks: {for (final t in _tracks.values) t.trackId: t.toContext()},
  );

  /// Mutes / unmutes / replaces [trackId]'s media. Emits
  /// `LocalTrackMuted` / `LocalTrackUnmuted` (and sends `unmuteTrack` on
  /// unmute) before the sender is updated; on failure emits the opposite
  /// event and rethrows. On success emits `LocalTrackReplaced`.
  /// Unknown id, or a media track already published by another local
  /// track → [ArgumentError].
  Future<void> replaceTrack(String trackId, RtcMediaTrack? newTrack) async {
    final track = byId(trackId);
    if (newTrack != null &&
        _tracks.values.any((t) => t != track && t.track?.id == newTrack.id)) {
      throw ArgumentError.value(
        newTrack.id,
        'track',
        'already published by another local track',
      );
    }
    final action = replaceActionOf(track.track, newTrack);
    switch (action) {
      case ReplaceAction.mute:
        _emit(LocalTrackMuted(trackId));
      case ReplaceAction.unmute:
        _sendMediaEvent(
          peer.MediaEvent(
            unmuteTrack: peer.MediaEvent_UnmuteTrack(trackId: trackId),
          ),
        );
        _emit(LocalTrackUnmuted(trackId));
      case ReplaceAction.replace:
        break;
    }
    try {
      await track.replaceTrack(newTrack);
    } catch (_) {
      switch (action) {
        case ReplaceAction.mute:
          _emit(LocalTrackUnmuted(trackId));
        case ReplaceAction.unmute:
          _emit(LocalTrackMuted(trackId));
        case ReplaceAction.replace:
          break;
      }
      rethrow;
    }
    _emit(LocalTrackReplaced(trackId, newTrack));
  }

  /// Resolves [limit], applies it to the sender,
  /// stores it, sends `trackBitrates` and emits `LocalTrackBandwidthSet`.
  /// Unknown id or invalid limit → [ArgumentError]; no sender →
  /// [StateError]. Nothing is sent on failure.
  Future<void> setTrackBandwidth(String trackId, BandwidthLimit limit) async {
    final track = byId(trackId);
    final resolved = resolveTrackBandwidth(
      limit,
      kind: track.kind,
      simulcast: track.simulcastConfig.enabled,
      logger: _logger,
    );
    await track.setBandwidth(resolved);
    _sendTrackBitrates(track);
    _emit(LocalTrackBandwidthSet(trackId, resolved));
  }

  /// Resolves [kbps] against the layer cap (video only),
  /// applies it to the layer, sends `trackBitrates` for the whole track and
  /// emits `LocalTrackEncodingBandwidthSet`. Unknown id or missing layer →
  /// [ArgumentError]; no sender → [StateError].
  Future<void> setEncodingBandwidth(
    String trackId,
    Variant variant,
    int kbps,
  ) async {
    final track = byId(trackId);
    final resolved = track.kind == MediaKind.video
        ? resolveVariantBandwidth(variant, kbps, logger: _logger)
        : kbps;
    await track.setEncodingBandwidth(variant, resolved);
    _sendTrackBitrates(track);
    _emit(LocalTrackEncodingBandwidthSet(trackId, variant, resolved));
  }

  Future<void> enableTrackEncoding(String trackId, Variant variant) async {
    await byId(trackId).setEncodingActive(variant, active: true);
    _sendMediaEvent(
      peer.MediaEvent(
        enableTrackVariant: peer.MediaEvent_EnableTrackVariant(
          trackId: trackId,
          variant: variantToProto(variant),
        ),
      ),
    );
    _emit(LocalTrackEncodingEnabled(trackId, variant));
  }

  Future<void> disableTrackEncoding(String trackId, Variant variant) async {
    await byId(trackId).setEncodingActive(variant, active: false);
    _sendMediaEvent(
      peer.MediaEvent(
        disableTrackVariant: peer.MediaEvent_DisableTrackVariant(
          trackId: trackId,
          variant: variantToProto(variant),
        ),
      ),
    );
    _emit(LocalTrackEncodingDisabled(trackId, variant));
  }

  /// `null` for unknown tracks.
  Future<double?> audioLevel(String trackId) =>
      _tracks[trackId]?.audioLevel() ?? Future.value();

  void _sendTrackBitrates(LocalTrack track) =>
      _sendMediaEvent(peer.MediaEvent(trackBitrates: _trackBitrates(track)));

  peer.MediaEvent_TrackBitrates _trackBitrates(LocalTrack track) =>
      peer.MediaEvent_TrackBitrates(
        trackId: track.trackId,
        variantBitrates: variantBitrates(track.maxBandwidth, track.kind),
      );
}
