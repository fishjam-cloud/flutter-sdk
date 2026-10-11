/// Local audio level from sender statistics (SPEC §18).
///
/// Owner: **Data & Stats** agent.
library;

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// The `audioLevel` of the first `media-source` report of kind `audio`, or
/// `null` (SPEC §18).
double? audioLevelFromStats(List<RtcStats> stats) {
  for (final report in stats) {
    if (report.type == 'media-source' && report.values['kind'] == 'audio') {
      return switch (report.values['audioLevel']) {
        final num level => level.toDouble(),
        _ => null,
      };
    }
  }
  return null;
}
