/// Bandwidth resolution and splitting (SPEC §13). A direct port of the web
/// SDK's rules; "kbps" means 1024 bps throughout.
///
/// Owner: **Tracks** agent.
library;

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

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
///
/// Owner: Tracks.
int kbpsToBps(int kbps) => throw UnimplementedError('Tracks');

/// `round(bps / 1024)`.
///
/// Owner: Tracks.
int bpsToKbps(num bps) => throw UnimplementedError('Tracks');

/// Resolves the limit of a video track (SPEC §13.2, §13.3). Throws
/// [ArgumentError] for a per-layer limit on a non-simulcast track.
///
/// Owner: Tracks.
BandwidthLimit resolveVideoBandwidth(
  BandwidthLimit requested, {
  required bool simulcast,
  required FishjamLogger logger,
}) => throw UnimplementedError('Tracks');

/// Resolves one simulcast layer's limit against its cap (SPEC §13.3).
///
/// Owner: Tracks.
int resolveVariantBandwidth(
  Variant variant,
  int kbps, {
  required FishjamLogger logger,
}) => throw UnimplementedError('Tracks');

/// Splits a total budget across the simulcast layers by pixel count
/// (SPEC §13.3); result keys are ordered low, medium, high.
///
/// Owner: Tracks.
Map<Variant, int> splitSimulcastBudget(
  int kbps, {
  required FishjamLogger logger,
}) => throw UnimplementedError('Tracks');

/// Splits [kbps] across [encodings] proportionally to
/// `(scale0 / scaleI)^2`; `0` removes every cap (SPEC §13.6).
///
/// Owner: Tracks.
List<RtpEncoding> splitBandwidth(
  List<RtpEncoding> encodings,
  int kbps, {
  required FishjamLogger logger,
}) => throw UnimplementedError('Tracks');

/// The `variantBitrates` reported for a track (SPEC §13.5).
///
/// Owner: Tracks.
List<peer.MediaEvent_VariantBitrate> variantBitrates(
  BandwidthLimit limit,
  MediaKind kind,
) => throw UnimplementedError('Tracks');

/// Convenience for [variantBitrates] of a local track snapshot.
///
/// Owner: Tracks.
List<peer.MediaEvent_VariantBitrate> trackVariantBitrates(
  LocalTrackContext track,
) => throw UnimplementedError('Tracks');
