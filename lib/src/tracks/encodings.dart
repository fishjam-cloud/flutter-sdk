import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';

/// Builds the [TransceiverInit] for a local track: audio → `sendonly`, no
/// encodings; video → one `{active, maxBitrate}` encoding; simulcast video →
/// `l`/`m`/`h` encodings with scales 4/2/1. [maxBandwidth] is
/// already resolved; a limit of the wrong shape is an [ArgumentError].
TransceiverInit sendTransceiverInit({
  required MediaKind kind,
  required SimulcastConfig simulcastConfig,
  required BandwidthLimit maxBandwidth,
  RtcMediaStream? stream,
}) {
  final streams = [?stream];
  if (kind == MediaKind.audio) {
    return TransceiverInit(
      direction: TransceiverDirection.sendonly,
      streams: streams,
    );
  }

  final List<RtpEncoding> encodings;
  switch ((simulcastConfig.enabled, maxBandwidth)) {
    case (true, SimulcastBandwidthLimit(:final kbpsPerVariant)):
      encodings = applySimulcastLimits([
        for (final variant in Variant.values)
          RtpEncoding(
            rid: variant.rid,
            active: simulcastConfig.enabledVariants.contains(variant),
            scaleResolutionDownBy: variant == Variant.high
                ? null
                : simulcastLayerScale[variant],
          ),
      ], kbpsPerVariant);
    case (false, SingleBandwidthLimit(:final kbps)):
      encodings = [
        RtpEncoding(maxBitrateBps: kbps > 0 ? kbpsToBps(kbps) : null),
      ];
    case _:
      throw ArgumentError.value(
        maxBandwidth,
        'maxBandwidth',
        simulcastConfig.enabled
            ? 'a simulcast track needs per-layer limits'
            : 'a non-simulcast track expects a single bandwidth limit',
      );
  }
  return TransceiverInit(
    direction: TransceiverDirection.sendonly,
    sendEncodings: encodings,
    streams: streams,
  );
}

/// Applies per-layer limits to encodings that have a rid: the
/// limit in bps, or no limit when it is 0 or missing. Other encodings are
/// returned unchanged.
List<RtpEncoding> applySimulcastLimits(
  List<RtpEncoding> encodings,
  Map<Variant, int> kbpsPerVariant,
) => [
  for (final e in encodings)
    switch (encodingVariant(e)) {
      null => e,
      final variant => switch (kbpsPerVariant[variant] ?? 0) {
        > 0 && final kbps => e.copyWith(maxBitrateBps: kbpsToBps(kbps)),
        _ => e.copyWith(clearMaxBitrate: true),
      },
    },
];

/// The variant of a sender encoding, from its rid; `null` without one.
Variant? encodingVariant(RtpEncoding encoding) => switch (encoding.rid) {
  final rid? => Variant.fromRid(rid),
  null => null,
};
