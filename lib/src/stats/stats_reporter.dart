/// Periodic `rtcStatsReport` (SPEC §17).
///
/// Owner: **Data & Stats** agent.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Interval between reports.
const statsInterval = Duration(seconds: 10);

const _reportedTypes = {'inbound-rtp', 'outbound-rtp'};

/// Builds the report JSON: report id → fields, only `inbound-rtp` and
/// `outbound-rtp` (SPEC §17).
///
/// Every report carries its `id`, `type` and `timestamp` next to the
/// platform's fields. Values JSON cannot represent (`NaN`, infinities) become
/// `null`; other objects become their string form.
String buildStatsReportJson(List<RtcStats> stats) => jsonEncode({
  for (final report in stats)
    if (_reportedTypes.contains(report.type))
      report.id: {
        'timestamp': report.timestampMs,
        for (final MapEntry(:key, :value) in report.values.entries)
          key: _jsonSafe(value),
        'id': report.id,
        'type': report.type,
      },
});

Object? _jsonSafe(Object? value) => switch (value) {
  null || String() || bool() || int() => value,
  final double d => d.isFinite ? d : null,
  final Map<Object?, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries) '$key': _jsonSafe(value),
  },
  final Iterable<Object?> list => [for (final v in list) _jsonSafe(v)],
  _ => value.toString(),
};

/// Calls `getStats` every [statsInterval] and hands the JSON to `send`.
///
/// Reports whose `getStats` is still in flight when [stop] is called are
/// discarded, so nothing is sent after teardown.
class StatsReporter {
  /// Creates a stopped reporter.
  StatsReporter({
    required this._getStats,
    required this._send,
    required this._logger,
  });

  final Future<List<RtcStats>> Function() _getStats;
  final void Function(String json) _send;
  final FishjamLogger _logger;

  Timer? _timer;

  /// Incremented on every [stop]; ticks of an older run are discarded.
  int _run = 0;

  /// Starts reporting (idempotent).
  void start() {
    if (_timer != null) return;
    final run = _run;
    _timer = Timer.periodic(statsInterval, (_) => unawaited(_tick(run)));
  }

  /// Stops reporting.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _run++;
  }

  Future<void> _tick(int run) async {
    final List<RtcStats> stats;
    try {
      stats = await _getStats();
    } on Object catch (error, stackTrace) {
      _logger.warn('Skipping statistics report', error, stackTrace);
      return;
    }
    if (run != _run) return;
    _send(buildStatsReportJson(stats));
  }
}
