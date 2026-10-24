import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_network.dart';

void main() {
  late FakeNetworkMonitor monitor;
  late List<NetworkChange> changes;
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
      onChanged: changes.add,
    );
  });

  /// Starts the watcher inside [body]'s fake time.
  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
    unawaited(watcher.start());
    async.flushMicrotasks();
    body(async);
  });

  test('the networks in use at start are the baseline, not a change', () {
    run((async) {
      monitor.report({'wifi'});
      async.flushMicrotasks();

      expect(changes, isEmpty);
    });
  });

  test('a report is acted on at once', () {
    run((async) {
      monitor.report({'cellular'});
      async.flushMicrotasks();

      expect(changes, [NetworkChange.changed]);
    });
  });

  test('offline is lost; online after offline is available, even when it '
      'comes right after', () {
    run((async) {
      monitor
        ..report({})
        ..report({'wifi'});
      async.flushMicrotasks();

      expect(changes, [NetworkChange.lost, NetworkChange.available]);
    });
  });

  test('a repeated report is no change', () {
    run((async) {
      monitor
        ..report({})
        ..report({})
        ..report({'wifi'})
        ..report({'wifi'});
      async.flushMicrotasks();

      expect(changes, [NetworkChange.lost, NetworkChange.available]);
    });
  });

  test('only gaining a network is no change; losing one later is', () {
    run((async) {
      monitor.report({'wifi', 'cellular'});
      async.flushMicrotasks();
      expect(changes, isEmpty);

      monitor.report({'cellular'});
      async.flushMicrotasks();
      expect(changes, [NetworkChange.changed]);
    });
  });

  test('reports are listened to only once the start value was read, so an '
      'OS that cannot be asked is never subscribed to', () {
    fakeAsync((async) {
      final gate = monitor.currentGate = Completer<void>();
      unawaited(watcher.start());
      async.flushMicrotasks();
      expect(monitor.isWatched, isFalse);

      gate.complete();
      async.flushMicrotasks();
      expect(monitor.isWatched, isTrue);
      monitor.report({'wifi'});
      async.flushMicrotasks();
      expect(changes, isEmpty);
    });
  });

  test('stop while the start value is read: nothing is listened to', () {
    fakeAsync((async) {
      final gate = monitor.currentGate = Completer<void>();
      unawaited(watcher.start());
      async.flushMicrotasks();
      unawaited(watcher.stop());
      gate.complete();
      async.flushMicrotasks();

      expect(monitor.isWatched, isFalse);
    });
  });

  test(
    'a superseded start whose read fails leaves the newer watch running',
    () {
      fakeAsync((async) {
        final gate = monitor.currentGate = Completer<void>();
        unawaited(watcher.start());
        async.flushMicrotasks();
        monitor.currentGate = null;
        unawaited(watcher.start());
        async.flushMicrotasks();
        expect(monitor.isWatched, isTrue);

        monitor.currentError = StateError('no answer');
        gate.complete();
        async.flushMicrotasks();

        expect(monitor.isWatched, isTrue);
        expect(logs, isEmpty);
      });
    },
  );

  test('when the OS cannot be asked, it warns, reports nothing and does not '
      'listen', () {
    monitor.currentError = StateError('no plugin');
    run((async) {
      expect(monitor.isWatched, isFalse);
      monitor.report({'cellular'});
      async.flushMicrotasks();

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

  test('stop ends watching; start after stop takes a new baseline', () {
    run((async) {
      unawaited(watcher.stop());
      async.flushMicrotasks();
      expect(monitor.isWatched, isFalse);

      monitor.report({'cellular'});
      unawaited(watcher.start());
      async.flushMicrotasks();
      monitor.report({'cellular'});
      async.flushMicrotasks();
      expect(changes, isEmpty);
    });
  });
}
