/// Bandwidth resolution and splitting (SPEC §13). A direct port of the web
/// SDK's rules; "kbps" means 1024 bps throughout.
///
/// Owner: **Tracks** agent.
library;

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/wire.dart';

/// Bits per second in one kbps.
const bpsPerKbps = 1024;

/// Single-stream video cap in kbps (SPEC §13.1).
const singleStreamCapKbps = 1500;

/// Simulcast caps in kbps per layer (SPEC §13.1).
const Map<Variant, int> simulcastCapsKbps = {
  Variant.low: 150,
  Variant.medium: 500,
  Variant.high: 1500,
};

/// `scaleResolutionDownBy` per simulcast layer (SPEC §12).
const Map<Variant, double> simulcastLayerScale = {
  Variant.low: 4.0,
  Variant.medium: 2.0,
  Variant.high: 1.0,
};

/// Bitrate reported for an audio track without a limit (SPEC §13.5).
const defaultAudioBitrateBps = 50000;

/// Bitrate reported for a video track without a limit (SPEC §13.5).
const int defaultVideoBitrateBps = singleStreamCapKbps * bpsPerKbps;

/// `kbps * 1024`.
int kbpsToBps(int kbps) => kbps * bpsPerKbps;

/// `round(bps / 1024)`.
int bpsToKbps(num bps) => (bps / bpsPerKbps).round();

/// Resolves the limit of a video track (SPEC §13.2, §13.3). Throws
/// [ArgumentError] for a per-layer limit on a non-simulcast track.
BandwidthLimit resolveVideoBandwidth(
  BandwidthLimit requested, {
  required bool simulcast,
  required FishjamLogger logger,
}) {
  if (!simulcast) {
    return switch (requested) {
      SingleBandwidthLimit(:final kbps) => BandwidthLimit.single(
        _resolveAgainstCap(kbps, singleStreamCapKbps, 'single stream', logger),
      ),
      SimulcastBandwidthLimit() => throw ArgumentError.value(
        requested,
        'maxBandwidth',
        'a non-simulcast track expects a single bandwidth limit',
      ),
    };
  }

  final layers = switch (requested) {
    SimulcastBandwidthLimit(:final kbpsPerVariant) => kbpsPerVariant,
    SingleBandwidthLimit(:final kbps) when kbps > 0 => splitSimulcastBudget(
      kbps,
      logger: logger,
    ),
    SingleBandwidthLimit() => const <Variant, int>{},
  };
  return BandwidthLimit.simulcast({
    for (final variant in Variant.values)
      variant: resolveVariantBandwidth(
        variant,
        layers[variant] ?? 0,
        logger: logger,
      ),
  });
}

/// Resolves the limit given to `setTrackBandwidth` (SPEC §13.4): audio limits
/// are applied as given (a map is an [ArgumentError]); video limits go
/// through [resolveVideoBandwidth].
BandwidthLimit resolveTrackBandwidth(
  BandwidthLimit requested, {
  required MediaKind kind,
  required bool simulcast,
  required FishjamLogger logger,
}) {
  if (kind == MediaKind.video) {
    return resolveVideoBandwidth(
      requested,
      simulcast: simulcast,
      logger: logger,
    );
  }
  if (requested is SimulcastBandwidthLimit) {
    throw ArgumentError.value(
      requested,
      'bandwidth',
      'an audio track expects a single bandwidth limit',
    );
  }
  return requested;
}

/// Resolves one simulcast layer's limit against its cap (SPEC §13.3).
int resolveVariantBandwidth(
  Variant variant,
  int kbps, {
  required FishjamLogger logger,
}) =>
    _resolveAgainstCap(kbps, simulcastCapsKbps[variant]!, variant.name, logger);

/// Splits a total budget across the simulcast layers by pixel count
/// (SPEC §13.3); result keys are ordered low, medium, high.
Map<Variant, int> splitSimulcastBudget(
  int kbps, {
  required FishjamLogger logger,
}) {
  final bps = _splitBps([
    for (final v in Variant.values) simulcastLayerScale[v],
  ], kbpsToBps(kbps));
  return {
    for (final (i, variant) in Variant.values.indexed)
      variant: bpsToKbps(bps[i]),
  };
}

/// Splits [kbps] across [encodings] proportionally to
/// `(scale0 / scaleI)^2`; `0` removes every cap (SPEC §13.6).
List<RtpEncoding> splitBandwidth(
  List<RtpEncoding> encodings,
  int kbps, {
  required FishjamLogger logger,
}) {
  if (kbps == 0) {
    return [for (final e in encodings) e.copyWith(clearMaxBitrate: true)];
  }
  if (encodings.isEmpty) {
    logger.error('Cannot limit the bandwidth of a sender without encodings');
    return const [];
  }
  final bps = _splitBps([
    for (final e in encodings) e.scaleResolutionDownBy,
  ], kbpsToBps(kbps));
  return [
    for (final (i, e) in encodings.indexed)
      e.copyWith(maxBitrateBps: bps[i].round()),
  ];
}

/// The `variantBitrates` reported for a track (SPEC §13.5).
List<peer.MediaEvent_VariantBitrate> variantBitrates(
  BandwidthLimit limit,
  MediaKind kind,
) => switch (limit) {
  SingleBandwidthLimit(:final kbps) => [
    peer.MediaEvent_VariantBitrate(
      variant: shared.Variant.VARIANT_UNSPECIFIED,
      bitrate: kbps != 0
          ? kbpsToBps(kbps)
          : kind == MediaKind.audio
          ? defaultAudioBitrateBps
          : defaultVideoBitrateBps,
    ),
  ],
  SimulcastBandwidthLimit(:final kbpsPerVariant) => [
    for (final variant in Variant.values)
      if (kbpsPerVariant[variant] case final kbps?)
        peer.MediaEvent_VariantBitrate(
          variant: variantToProto(variant),
          bitrate: kbpsToBps(kbps),
        ),
  ],
};

int _resolveAgainstCap(int kbps, int cap, String label, FishjamLogger logger) {
  if (kbps <= 0) return cap;
  if (kbps > cap) {
    logger.warn(
      'Desired $label bandwidth of $kbps kbps exceeds the cap of $cap kbps',
    );
    return cap;
  }
  return kbps;
}

/// Solves `x + (k0/k1)^2 x + … + (k0/kn)^2 x = bps` (scales are resolution
/// divisors, squared because bitrate follows pixel count) and returns each
/// layer's share in bps, unrounded.
List<double> _splitBps(List<double?> scales, int bps) {
  final first = scales.first ?? 1;
  final weights = [for (final s in scales) _square(first / (s ?? 1))];
  final x = bps / weights.fold<double>(0, (a, b) => a + b);
  return [for (final w in weights) x * w];
}

double _square(double v) => v * v;
