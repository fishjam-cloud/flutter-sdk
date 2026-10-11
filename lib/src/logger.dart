/// The SDK logger (SPEC §21). Owner: Architect.
library;

import 'dart:developer' as developer;

/// Severity of a log line.
enum LogLevel {
  /// Verbose diagnostics.
  debug(500),

  /// Something unexpected that the SDK recovered from.
  warn(900),

  /// Something failed.
  error(1000);

  LogLevel(this.value);

  /// Numeric level understood by `dart:developer`.
  final int value;
}

/// Receives formatted log lines. Replaceable in tests.
typedef LogSink = void Function(
  LogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// The single logger used by every SDK module.
///
/// Logs only when [enabled] is true, prefixes every line with `[FISHJAM]` and
/// writes through `dart:developer` (never `print`).
final class FishjamLogger {
  /// Creates a logger. [sink] defaults to `dart:developer`'s `log`.
  FishjamLogger({required this.enabled, LogSink? sink})
    : _sink = sink ?? _developerSink;

  /// A logger that never logs.
  FishjamLogger.disabled() : this(enabled: false);

  /// Prefix of every line.
  static const prefix = '[FISHJAM]';

  /// Whether lines are emitted (the client's `debug` flag).
  final bool enabled;

  final LogSink _sink;

  /// Logs a debug line.
  void debug(String message) => _log(LogLevel.debug, message);

  /// Logs a warning.
  void warn(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warn, message, error, stackTrace);

  /// Logs an error.
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!enabled) return;
    _sink(level, '$prefix $message', error: error, stackTrace: stackTrace);
  }

  static void _developerSink(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => developer.log(
    message,
    name: 'fishjam_client',
    level: level.value,
    error: error,
    stackTrace: stackTrace,
  );
}
