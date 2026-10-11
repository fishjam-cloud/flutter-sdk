import 'package:fishjam_client/src/logger.dart';

/// Records log lines of a [FishjamLogger] for assertions.
class LogCapture {
  /// Every line, in order.
  final List<(LogLevel, String)> lines = [];

  /// An enabled logger writing into [lines].
  late final FishjamLogger logger = FishjamLogger(
    enabled: true,
    sink: (level, message, {error, stackTrace}) => lines.add((level, message)),
  );

  /// Warning messages.
  List<String> get warnings => _of(LogLevel.warn);

  /// Error messages.
  List<String> get errors => _of(LogLevel.error);

  /// Debug messages.
  List<String> get debugs => _of(LogLevel.debug);

  List<String> _of(LogLevel level) => [
    for (final (l, m) in lines)
      if (l == level) m,
  ];
}
