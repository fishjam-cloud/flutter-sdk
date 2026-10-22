import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_network.dart';

const _settle = Duration(milliseconds: 500);

void main() {
  late FakeNetworkMonitor monitor;
  late List<(NetworkChange, DateTime)> changes;
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
      onChanged: (change, began) => changes.add((change, began)),
    );
  });

  /// Starts the watcher inside [body]'s fake time.
  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
    unawaited(watcher.start());
    async.flushMicrotasks();
    body(async);
  });

  List<NetworkChange> kinds() => [for (final (c, _) in changes) c];

  test('the networks in use at start are the baseline, not a change', () {
    run((async) {
      monitor.report({'wifi'});
      async.elapse(_settle * 2);

      expect(changes, isEmpty);
    });
  });

  test('a change is reported once the reports have been stable for 500 ms, '
      'with the time its first report arrived', () {
    run((async) {
      final began = clock.now();
      monitor.report({'cellular'});
      async.elapse(_settle - const Duration(milliseconds: 1));
      expect(changes, isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(changes, [(NetworkChange.changed, began)]);
    });
  });

  test('offline is lost; online after offline is available', () {
    run((async) {
      monitor.report({});
      async.elapse(_settle);
      monitor.report({'cellular'});
      async.elapse(_settle);

      expect(kinds(), [NetworkChange.lost, NetworkChange.available]);
    });
  });

  test('reports within the settle time are one change that began with the '
      'first of them', () {
    run((async) {
      final began = clock.now();
      monitor.report({});
      async.elapse(const Duration(milliseconds: 200));
      monitor.report({'cellular'});
      async.elapse(_settle);

      expect(changes, [(NetworkChange.changed, began)]);
    });
  });

  test('back to the same networks through offline is a change: another '
      'Wi-Fi network looks the same', () {
    run((async) {
      monitor
        ..report({})
        ..report({'wifi'});
      async.elapse(_settle);

      expect(kinds(), [NetworkChange.changed]);
    });
  });

  test('a network appearing after a settled offline is available at once', () {
    run((async) {
      monitor.report({});
      async.elapse(_settle);
      final began = clock.now();
      monitor.report({'cellular'});
      async.flushMicrotasks();

      expect(changes.last, (NetworkChange.available, began));
    });
  });

  test('a network appearing while offline is still settling is a change at '
      'once, that began with the offline report', () {
    run((async) {
      final began = clock.now();
      monitor.report({});
      async.elapse(const Duration(milliseconds: 200));
      monitor.report({'wifi'});
      async.flushMicrotasks();

      expect(changes, [(NetworkChange.changed, began)]);
    });
  });

  test('reports right after a network appeared settle against it', () {
    run((async) {
      monitor
        ..report({})
        ..report({'wifi'})
        ..report({'wifi', 'cellular'});
      async.elapse(_settle);

      expect(kinds(), [NetworkChange.changed]);
    });
  });

  test('only gaining a network is no change; losing one later is', () {
    run((async) {
      monitor.report({'wifi', 'cellular'});
      async.elapse(_settle);
      monitor.report({'wifi', 'cellular'});
      async.elapse(_settle);
      expect(changes, isEmpty);

      monitor.report({'cellular'});
      async.elapse(_settle);
      expect(kinds(), [NetworkChange.changed]);
    });
  });

  test('a report that arrives before the start value is the baseline', () {
    fakeAsync((async) {
      final gate = monitor.currentGate = Completer<void>();
      unawaited(watcher.start());
      async.flushMicrotasks();
      monitor.report({'cellular'});
      async.flushMicrotasks();
      gate.complete();
      async.flushMicrotasks();
      monitor.report({'cellular'});
      async.elapse(_settle);

      expect(changes, isEmpty);
    });
  });

  test('when the OS cannot be asked, it warns and reports nothing', () {
    monitor.currentError = StateError('no plugin');
    run((async) {
      monitor.report({'cellular'});
      async.elapse(_settle);

      expect(changes, isEmpty);
      expect(logs, [startsWith('warn')]);
    });
  });

  test('when the report stream cannot be opened, it warns and reports '
      'nothing', () {
    monitor.changesError = StateError('no binding');
    run((async) {
      expect(logs, [startsWith('warn')]);
      expect(changes, isEmpty);
    });
  });

  test('a failing report stream warns and stops watching', () {
    run((async) {
      monitor.fail(StateError('channel gone'));
      async.flushMicrotasks();

      expect(logs, [startsWith('warn')]);
      expect(monitor.isWatched, isFalse);
    });
  });

  test('stop ends watching and drops a change still settling; start after '
      'stop takes a new baseline', () {
    run((async) {
      monitor.report({'cellular'});
      unawaited(watcher.stop());
      async.elapse(_settle);
      expect(monitor.isWatched, isFalse);
      expect(changes, isEmpty);

      unawaited(watcher.start());
      async.flushMicrotasks();
      monitor.report({'cellular'});
      async.elapse(_settle);
      expect(changes, isEmpty);
    });
  });
}
