/// Local audio level from sender statistics (SPEC §18).
///
/// Owner: **Data & Stats** agent.
library;

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// The `audioLevel` of the first `media-source` report of kind `audio`, or
/// `null` (SPEC §18).
///
/// Owner: Data & Stats.
double? audioLevelFromStats(List<RtcStats> stats) =>
    throw UnimplementedError('Data & Stats');
