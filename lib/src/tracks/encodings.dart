/// Send transceiver configuration for local tracks (SPEC §11.1, §12).
///
/// Owner: **Tracks** agent.
library;

import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Builds the [TransceiverInit] for a local track: audio → `sendonly`, no
/// encodings; video → one `{active, maxBitrate}` encoding; simulcast video →
/// `l`/`m`/`h` encodings with scales 4/2/1 (SPEC §12). [maxBandwidth] is
/// already resolved.
///
/// Owner: Tracks.
TransceiverInit sendTransceiverInit({
  required MediaKind kind,
  required SimulcastConfig simulcastConfig,
  required BandwidthLimit maxBandwidth,
  RtcMediaStream? stream,
}) => throw UnimplementedError('Tracks');

/// Applies per-layer limits to encodings that have a rid (SPEC §13.6).
///
/// Owner: Tracks.
List<RtpEncoding> applySimulcastLimits(
  List<RtpEncoding> encodings,
  Map<Variant, int> kbpsPerVariant,
) => throw UnimplementedError('Tracks');
