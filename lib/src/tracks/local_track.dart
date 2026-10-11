/// Local tracks: registry and per-track sender operations (SPEC §10, §11,
/// §13, §18).
///
/// Owner: **Tracks** agent. The Engine drives negotiation and calls into
/// [LocalTrackRegistry]; it never touches senders directly.
library;

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';
import 'package:fishjam_client/src/tracks/encodings.dart';
import 'package:fishjam_client/src/wire.dart';
import 'package:uuid/uuid.dart';

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
/// The methods here act on the sender only and emit nothing; the
/// [LocalTrackRegistry] methods of the same names add the media events and
/// client events of SPEC §11.3–§11.5.
class LocalTrack {
  /// Creates a local track. [maxBandwidth] is already resolved.
  LocalTrack({
    required this.trackId,
    required this.kind,
    required this._track,
    required this.stream,
    required this.metadata,
    required this._simulcastConfig,
    required this._maxBandwidth,
  });

  /// Track id `<peerId>:<uuid>`.
  final String trackId;

  /// Audio or video.
  final MediaKind kind;

  /// Associated stream.
  final RtcMediaStream? stream;

  RtcMediaTrack? _track;
  SimulcastConfig _simulcastConfig;
  BandwidthLimit _maxBandwidth;

  /// Simulcast configuration; enabled/disabled variants follow
  /// [setEncodingActive].
  SimulcastConfig get simulcastConfig => _simulcastConfig;

  /// Current media track; `null` while muted.
  RtcMediaTrack? get track => _track;

  /// Current metadata.
  TrackMetadata? metadata;

  /// Resolved bandwidth limit.
  BandwidthLimit get maxBandwidth => _maxBandwidth;

  /// Mid from the last answer; `null` before the first answer.
  String? mid;

  /// Negotiation status.
  TrackNegotiationStatus negotiationStatus = TrackNegotiationStatus.pending;

  /// Whether a metadata update must be sent after the current answer.
  bool pendingMetadataUpdate = false;

  /// The transceiver sending this track, once added to a connection.
  RtcRtpTransceiver? transceiver;

  /// Immutable snapshot for events and getters.
  LocalTrackContext toContext() => LocalTrackContext(
    trackId: trackId,
    kind: kind,
    rtcTrack: _track,
    rtcStream: stream,
    metadata: metadata,
    simulcastConfig: _simulcastConfig,
    maxBandwidth: _maxBandwidth,
  );

  /// Adds this track as a send transceiver on [pc] (SPEC §11.1). A muted
  /// track gets a transceiver of its kind without media.
  Future<void> addToConnection(RtcPeerConnection pc) async {
    final init = sendTransceiverInit(
      kind: kind,
      simulcastConfig: _simulcastConfig,
      maxBandwidth: _maxBandwidth,
      stream: stream,
    );
    final media = _track;
    transceiver = media != null
        ? await pc.addTransceiverWithTrack(media, init)
        : await pc.addTransceiverOfKind(kind, init);
  }

  /// Replaces the sent media (mute / unmute / replace, SPEC §11.3) and
  /// returns which action happened. Restores state and rethrows when the
  /// sender fails. Without a sender only the stored track changes (the next
  /// [addToConnection] uses it).
  Future<ReplaceAction> replaceTrack(RtcMediaTrack? newTrack) async {
    final oldTrack = _track;
    final action = replaceActionOf(oldTrack, newTrack);
    await _swapInStream(oldTrack, newTrack);
    _track = newTrack;
    final sender = transceiver?.sender;
    if (sender == null) return action;
    try {
      await sender.replaceTrack(newTrack);
    } catch (_) {
      _track = oldTrack;
      await _swapInStream(newTrack, oldTrack);
      rethrow;
    }
    return action;
  }

  Future<void> _swapInStream(RtcMediaTrack? from, RtcMediaTrack? to) async {
    final stream = this.stream;
    if (stream == null) return;
    if (from != null) await stream.removeTrack(from);
    if (to != null) await stream.addTrack(to);
  }

  /// Applies an already resolved limit to the sender (SPEC §13.6) and
  /// stores it. Throws [StateError] without a sender.
  Future<void> setBandwidth(BandwidthLimit resolved) async {
    final sender = _requireSender();
    final parameters = sender.getParameters();
    final encodings = switch (resolved) {
      SingleBandwidthLimit() when parameters.encodings.isEmpty => const [
        RtpEncoding(),
      ],
      SingleBandwidthLimit(:final kbps) => splitBandwidth(
        parameters.encodings,
        kbps,
        logger: FishjamLogger.disabled(),
      ),
      SimulcastBandwidthLimit(:final kbpsPerVariant) => applySimulcastLimits(
        parameters.encodings,
        kbpsPerVariant,
      ),
    };
    await sender.setParameters(parameters.copyWith(encodings: encodings));
    _maxBandwidth = resolved;
  }

  /// Applies an already resolved layer limit (SPEC §13.6) and stores it.
  /// Throws [ArgumentError] when the sender has no such layer, [StateError]
  /// without a sender.
  Future<void> setEncodingBandwidth(Variant variant, int resolvedKbps) async {
    await _updateEncoding(
      variant,
      (e) => resolvedKbps > 0
          ? e.copyWith(maxBitrateBps: kbpsToBps(resolvedKbps))
          : e.copyWith(clearMaxBitrate: true),
    );
    if (_maxBandwidth case SimulcastBandwidthLimit(:final kbpsPerVariant)) {
      _maxBandwidth = BandwidthLimit.simulcast({
        ...kbpsPerVariant,
        variant: resolvedKbps,
      });
    }
  }

  /// Activates or deactivates one simulcast layer (SPEC §11.4). Throws
  /// [ArgumentError] when the sender has no such layer, [StateError] without
  /// a sender.
  Future<void> setEncodingActive(
    Variant variant, {
    required bool active,
  }) async {
    await _updateEncoding(variant, (e) => e.copyWith(active: active));
    final enabled = {..._simulcastConfig.enabledVariants};
    active ? enabled.add(variant) : enabled.remove(variant);
    _simulcastConfig = _simulcastConfig.copyWith(
      enabledVariants: [
        for (final v in Variant.values)
          if (enabled.contains(v)) v,
      ],
      disabledVariants: [
        for (final v in Variant.values)
          if (!enabled.contains(v)) v,
      ],
    );
  }

  Future<void> _updateEncoding(
    Variant variant,
    RtpEncoding Function(RtpEncoding) update,
  ) async {
    final sender = _requireSender();
    final parameters = sender.getParameters();
    final index = parameters.encodings.indexWhere(
      (e) => encodingVariant(e) == variant,
    );
    if (index < 0) {
      throw ArgumentError.value(
        variant,
        'variant',
        'track $trackId has no ${variant.name} encoding',
      );
    }
    final encodings = [...parameters.encodings];
    encodings[index] = update(encodings[index]);
    await sender.setParameters(parameters.copyWith(encodings: encodings));
  }

  RtcRtpSender _requireSender() =>
      transceiver?.sender ??
      (throw StateError('track $trackId has no sender yet'));

  /// Audio level from sender stats (SPEC §18): the `audioLevel` of the first
  /// audio `media-source` report, or `null`.
  Future<double?> audioLevel() async {
    final sender = transceiver?.sender;
    if (sender == null) return null;
    try {
      for (final report in await sender.getStats()) {
        if (report.type != 'media-source') continue;
        if (report.values case {'kind': 'audio', 'audioLevel': final num l}) {
          return l.toDouble();
        }
      }
    } on Object catch (_) {
      return null;
    }
    return null;
  }
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

/// What replacing [oldTrack] with [newTrack] means (SPEC §11.3).
ReplaceAction replaceActionOf(
  RtcMediaTrack? oldTrack,
  RtcMediaTrack? newTrack,
) => switch ((oldTrack, newTrack)) {
  (_?, null) => ReplaceAction.mute,
  (null, _?) => ReplaceAction.unmute,
  _ => ReplaceAction.replace,
};

/// All local tracks of a session, plus the local peer's metadata and id.
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
  final Map<String, LocalTrack> _tracks = {};

  static const _uuid = Uuid();

  /// Local peer id; empty until `connected`.
  String peerId = '';

  /// Local peer metadata (`peer` part).
  Object? peerMetadata;

  /// Local peer metadata (`server` part), as reported in `connected`.
  Object? serverMetadata;

  /// Registered tracks in registration order (read-only view).
  List<LocalTrack> get tracks => List.unmodifiable(_tracks.values);

  /// The track with [trackId]; throws [ArgumentError] when unknown.
  LocalTrack byId(String trackId) =>
      _tracks[trackId] ??
      (throw ArgumentError.value(trackId, 'trackId', 'unknown local track'));

  /// Generates a new track id `<peerId>:<uuid v4>`.
  String newTrackId() => '$peerId:${_uuid.v4()}';

  /// Registers [track]; a duplicate id is an [ArgumentError].
  void register(LocalTrack track) {
    if (_tracks.containsKey(track.trackId)) {
      throw ArgumentError.value(track.trackId, 'trackId', 'already registered');
    }
    _tracks[track.trackId] = track;
  }

  /// Unregisters [trackId] and returns the removed track; throws
  /// [ArgumentError] when unknown.
  LocalTrack unregister(String trackId) {
    final track = byId(trackId);
    _tracks.remove(trackId);
    return track;
  }

  /// Whether [mediaTrack] is already published by some local track.
  bool isPublished(RtcMediaTrack mediaTrack) =>
      _tracks.values.any((t) => t.track?.id == mediaTrack.id);

  /// `trackIdToMetadataJson` for an `sdpOffer` (SPEC §10.1, §2.3).
  Map<String, String> trackIdToMetadataJson() => {
    for (final t in _tracks.values)
      t.trackId: encodeMetadataJson(t.metadata?.toJson()),
  };

  /// `trackIdToBitrates` for an `sdpOffer` (SPEC §10.1).
  Map<String, peer.MediaEvent_TrackBitrates> trackIdToBitrates() => {
    for (final t in _tracks.values) t.trackId: _trackBitrates(t),
  };

  /// `midToTrackId` for an `sdpOffer`, built from [transceivers] after
  /// `setLocalDescription` (SPEC §10.1). A transceiver is matched by its
  /// sender's media track id, falling back to the sender object (a track
  /// muted before its first offer has no media on its sender).
  Future<Map<String, String>> midToTrackId(
    List<RtcRtpTransceiver> transceivers,
  ) async {
    final mapping = <String, String>{};
    for (final transceiver in transceivers) {
      final mid = transceiver.mid;
      if (mid == null) continue;
      final sender = transceiver.sender;
      final media = sender.track;
      final owner = _tracks.values
          .where(
            (t) =>
                (media != null && t.track?.id == media.id) ||
                identical(t.transceiver?.sender, sender),
          )
          .firstOrNull;
      if (owner != null) {
        mapping[mid] = owner.trackId;
      } else if (media != null) {
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

  /// Stores mids from an answer for local tracks (SPEC §10.2). Other ids
  /// belong to remote tracks and are ignored here.
  void applyAnswerMids(Map<String, String> midToTrackId) {
    for (final MapEntry(key: mid, value: trackId) in midToTrackId.entries) {
      _tracks[trackId]?.mid = mid;
    }
  }

  /// Snapshot of the local peer.
  LocalPeer toLocalPeer() => LocalPeer(
    id: peerId,
    metadata: Metadata(peer: peerMetadata, server: serverMetadata),
    tracks: {for (final t in _tracks.values) t.trackId: t.toContext()},
  );

  /// SPEC §11.3: mute / unmute / replace [trackId]'s media. Emits
  /// `LocalTrackMuted` / `LocalTrackUnmuted` (and sends `unmuteTrack` on
  /// unmute) before the sender is updated; on failure emits the opposite
  /// event and rethrows. On success emits `LocalTrackReplaced`.
  /// Unknown id → [ArgumentError].
  Future<void> replaceTrack(String trackId, RtcMediaTrack? newTrack) async {
    final track = byId(trackId);
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

  /// SPEC §11.5: resolves [limit] (SPEC §13), applies it to the sender,
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

  /// SPEC §11.5: resolves [kbps] against the layer cap (video only),
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

  /// SPEC §11.4: activates the layer, sends `enableTrackVariant`, emits
  /// `LocalTrackEncodingEnabled`.
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

  /// SPEC §11.4: deactivates the layer, sends `disableTrackVariant`, emits
  /// `LocalTrackEncodingDisabled` (D3).
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

  /// SPEC §18: the audio level of [trackId]; `null` for unknown tracks.
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
