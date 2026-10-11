/// Periodic `rtcStatsReport` (SPEC §17).
///
/// Owner: **Data & Stats** agent.
library;

// Constructor fields are kept for the Data & Stats implementation.
// ignore_for_file: unused_field

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Interval between reports.
const statsInterval = Duration(seconds: 10);

/// Builds the report JSON: report id → fields, only `inbound-rtp` and
/// `outbound-rtp` (SPEC §17).
///
/// Owner: Data & Stats.
String buildStatsReportJson(List<RtcStats> stats) =>
    throw UnimplementedError('Data & Stats');

/// Calls `getStats` every [statsInterval] and hands the JSON to `send`.
///
/// Owner: Data & Stats.
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

  /// Starts reporting (idempotent).
  void start() => throw UnimplementedError('Data & Stats');

  /// Stops reporting.
  void stop() => throw UnimplementedError('Data & Stats');
}
