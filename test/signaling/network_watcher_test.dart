import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_network.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeNetworkMonitor monitor;
  late List<bool> changes;
  late List<String> logs;
  late NetworkWatcher watcher;

  setUp(() {
    monitor = FakeNetworkMonitor();
    changes = [];
    logs = [];
    watcher = NetworkWatcher(
      monitor: monitor,
      logger: FishjamLogger(
        enabled: true,
        sink: (level, message, {error, stackTrace}) =>
            logs.add('${level.name}: $message'),
      ),
      onChanged: ({required online}) => changes.add(online),
    );
  });

  test('the networks in use at start are the baseline, not a change', () async {
    await watcher.start();
    monitor.report({'wifi'});
    await _settle();

    expect(changes, isEmpty);
  });

  test('a different set of networks is a change; none means offline', () async {
    await watcher.start();
    monitor
      ..report({'cellular'})
      ..report({'cellular'})
      ..report({})
      ..report({'wifi', 'vpn'});
    await _settle();

    expect(changes, [true, false, true]);
  });

  test(
    'a report that arrives before the start value is the baseline',
    () async {
      final gate = monitor.currentGate = Completer<void>();
      final started = watcher.start();
      monitor.report({'cellular'});
      await _settle();
      gate.complete();
      await started;
      monitor.report({'cellular'});
      await _settle();

      expect(changes, isEmpty);
    },
  );

  test('when the OS cannot be asked, it warns and reports nothing', () async {
    monitor.currentError = StateError('no plugin');
    await watcher.start();
    monitor.report({'cellular'});
    await _settle();

    expect(changes, isEmpty);
    expect(logs, [startsWith('warn')]);
  });

  test('when the report stream cannot be opened, it warns and reports '
      'nothing', () async {
    monitor.changesError = StateError('no binding');
    await watcher.start();

    expect(logs, [startsWith('warn')]);
    expect(changes, isEmpty);
  });

  test('a failing report stream warns and stops watching', () async {
    await watcher.start();
    monitor.fail(StateError('channel gone'));
    await _settle();

    expect(logs, [startsWith('warn')]);
    expect(monitor.isWatched, isFalse);
  });

  test('stop ends watching; start after stop takes a new baseline', () async {
    await watcher.start();
    await watcher.stop();
    expect(monitor.isWatched, isFalse);
    monitor.report({'cellular'});

    await watcher.start();
    monitor.report({'cellular'});
    await _settle();
    expect(changes, isEmpty);
  });
}
