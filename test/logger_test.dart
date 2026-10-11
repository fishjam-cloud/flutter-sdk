import 'package:fishjam_client/src/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(LogLevel, String, Object?)> lines;

  void sink(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => lines.add((level, message, error));

  setUp(() => lines = []);

  test('prefixes every line with [FISHJAM]', () {
    final error = StateError('x');
    FishjamLogger(enabled: true, sink: sink)
      ..debug('d')
      ..warn('w')
      ..error('e', error);

    expect(lines, [
      (LogLevel.debug, '[FISHJAM] d', null),
      (LogLevel.warn, '[FISHJAM] w', null),
      (LogLevel.error, '[FISHJAM] e', error),
    ]);
  });

  test('logs nothing when disabled', () {
    FishjamLogger(enabled: false, sink: sink)
      ..debug('d')
      ..warn('w')
      ..error('e');
    FishjamLogger.disabled().warn('w');

    expect(lines, isEmpty);
  });

  test('the default sink does not throw', () {
    FishjamLogger(enabled: true)
      ..debug('d')
      ..warn('w', StateError('x'), StackTrace.current)
      ..error('e');
  });

  test('levels map to dart:developer values', () {
    expect(LogLevel.values.map((l) => l.value), [500, 900, 1000]);
  });
}
