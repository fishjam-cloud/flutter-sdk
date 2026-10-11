import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';
import 'package:fishjam_client/src/tracks/encodings.dart';

/// Where a local track is in negotiation; a metadata update is sent only
/// once the track was negotiated.
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
/// `LocalTrackRegistry` methods of the same names add the media events and
/// client events.
class LocalTrack {
  /// [maxBandwidth] is already resolved.
  LocalTrack({
    required this.trackId,
    required this.kind,
    required this._track,
    required this.stream,
    required this.metadata,
    required this._simulcastConfig,
    required this._maxBandwidth,
  });

  final String trackId;

  final MediaKind kind;

  final RtcMediaStream? stream;

  RtcMediaTrack? _track;
  SimulcastConfig _simulcastConfig;
  BandwidthLimit _maxBandwidth;

  /// Simulcast configuration; enabled/disabled variants follow
  /// [setEncodingActive].
  SimulcastConfig get simulcastConfig => _simulcastConfig;

  /// `null` while muted.
  RtcMediaTrack? get track => _track;

  TrackMetadata? metadata;

  BandwidthLimit get maxBandwidth => _maxBandwidth;

  /// Mid from the last answer; `null` before the first answer.
  String? mid;

  TrackNegotiationStatus negotiationStatus = TrackNegotiationStatus.pending;

  /// Whether a metadata update must be sent after the current answer.
  bool pendingMetadataUpdate = false;

  /// The transceiver sending this track, once added to a connection.
  RtcRtpTransceiver? transceiver;

  LocalTrackContext toContext() => LocalTrackContext(
    trackId: trackId,
    kind: kind,
    rtcTrack: _track,
    rtcStream: stream,
    metadata: metadata,
    simulcastConfig: _simulcastConfig,
    maxBandwidth: _maxBandwidth,
  );

  /// Adds this track as a send transceiver on [pc]. A muted
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

  /// Replaces the sent media (mute / unmute / replace) and
  /// returns which action happened. Restores state (stored track and stream)
  /// and rethrows when the stream or the sender fails. Without a sender only
  /// the stored track changes (the next [addToConnection] uses it).
  ///
  /// Not reentrant: callers must not overlap calls on one track (the engine
  /// serializes them in its command queue).
  Future<ReplaceAction> replaceTrack(RtcMediaTrack? newTrack) async {
    final oldTrack = _track;
    final action = replaceActionOf(oldTrack, newTrack);
    try {
      await _swapInStream(oldTrack, newTrack);
      _track = newTrack;
      await transceiver?.sender.replaceTrack(newTrack);
    } catch (_) {
      _track = oldTrack;
      await _restoreStream(oldTrack, newTrack);
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

  /// Puts [oldTrack] back into the stream (and [newTrack] out) whatever
  /// state a failed swap left it in.
  Future<void> _restoreStream(
    RtcMediaTrack? oldTrack,
    RtcMediaTrack? newTrack,
  ) async {
    final stream = this.stream;
    if (stream == null) return;
    final ids = {for (final t in stream.tracks) t.id};
    if (newTrack != null && ids.contains(newTrack.id)) {
      await stream.removeTrack(newTrack);
    }
    if (oldTrack != null && !ids.contains(oldTrack.id)) {
      await stream.addTrack(oldTrack);
    }
  }

  /// Applies an already resolved limit to the sender and
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

  /// Applies an already resolved, positive layer limit and
  /// stores it. Throws [ArgumentError] when the sender has no such layer,
  /// [StateError] without a sender.
  Future<void> setEncodingBandwidth(Variant variant, int resolvedKbps) async {
    await _updateEncoding(
      variant,
      (e) => e.copyWith(maxBitrateBps: kbpsToBps(resolvedKbps)),
    );
    if (_maxBandwidth case SimulcastBandwidthLimit(:final kbpsPerVariant)) {
      _maxBandwidth = BandwidthLimit.simulcast({
        ...kbpsPerVariant,
        variant: resolvedKbps,
      });
    }
  }

  /// Activates or deactivates one simulcast layer. Throws
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

  /// Audio level from sender stats: the `audioLevel` of the first
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

/// A new [LocalTrack] for [track]. Video limits are resolved against the
/// caps (throwing [ArgumentError] for an invalid one, before anything is
/// registered); audio tracks are added without a limit.
LocalTrack newLocalTrack({
  required String trackId,
  required RtcMediaTrack track,
  required RtcMediaStream? stream,
  required TrackMetadata? metadata,
  required SimulcastConfig simulcastConfig,
  required BandwidthLimit maxBandwidth,
  required FishjamLogger logger,
}) => LocalTrack(
  trackId: trackId,
  kind: track.kind,
  track: track,
  stream: stream,
  metadata: metadata,
  simulcastConfig: simulcastConfig,
  maxBandwidth: track.kind == MediaKind.video
      ? resolveVideoBandwidth(
          maxBandwidth,
          simulcast: simulcastConfig.enabled,
          logger: logger,
        )
      : BandwidthLimit.unlimited,
);

/// Result of [LocalTrack.replaceTrack].
enum ReplaceAction { mute, unmute, replace }

ReplaceAction replaceActionOf(
  RtcMediaTrack? oldTrack,
  RtcMediaTrack? newTrack,
) => switch ((oldTrack, newTrack)) {
  (_?, null) => ReplaceAction.mute,
  (null, _?) => ReplaceAction.unmute,
  _ => ReplaceAction.replace,
};
