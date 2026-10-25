import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_network.dart';

void main() {
  late FakeNetworkSource source;
  late List<NetworkChange> changes;
  late List<String> logs;
  late NetworkChangeDetector detector;

  setUp(() {
    source = FakeNetworkSource();
    changes = [];
    logs = [];
    detector = NetworkChangeDetector(
      source: source,
      logger: FishjamLogger(
        enabled: true,
        sink: (level, message, {error, stackTrace}) =>
            logs.add('${level.name}: $message'),
      ),
      onChanged: changes.add,
    );
  });

  /// Starts the detector inside [body]'s fake time.
  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
    unawaited(detector.start());
    async.flushMicrotasks();
    body(async);
  });

  test('the networks in use at start are the baseline, not a change', () {
    run((async) {
      source.report({'wifi'});
      async.flushMicrotasks();

      expect(changes, isEmpty);
    });
  });

  test('a report is acted on at once', () {
    run((async) {
      source.report({'mobile'});
      async.flushMicrotasks();

      expect(changes, [NetworkChange.changed]);
    });
  });

  test('offline is lost; online after offline is available, even when it '
      'comes right after', () {
    run((async) {
      source
        ..report({})
        ..report({'wifi'});
      async.flushMicrotasks();

      expect(changes, [NetworkChange.lost, NetworkChange.available]);
    });
  });

  test('a repeated report is no change', () {
    run((async) {
      source
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
      source.report({'wifi', 'mobile'});
      async.flushMicrotasks();
      expect(changes, isEmpty);

      source.report({'mobile'});
      async.flushMicrotasks();
      expect(changes, [NetworkChange.changed]);
    });
  });

  test('reports are listened to only once the start value was read, so an '
      'OS that cannot be asked is never subscribed to', () {
    fakeAsync((async) {
      final gate = source.getNetworkTypesGate = Completer<void>();
      unawaited(detector.start());
      async.flushMicrotasks();
      expect(source.isWatched, isFalse);

      gate.complete();
      async.flushMicrotasks();
      expect(source.isWatched, isTrue);
      source.report({'wifi'});
      async.flushMicrotasks();
      expect(changes, isEmpty);
    });
  });

  test('of two starts in a row only the newer one listens, so stop ends '
      'watching', () {
    fakeAsync((async) {
      unawaited(detector.start());
      unawaited(detector.start());
      async.flushMicrotasks();
      detector.stop();
      async.flushMicrotasks();

      expect(source.isWatched, isFalse);
    });
  });

  test('stop while the start value is read: nothing is listened to', () {
    fakeAsync((async) {
      final gate = source.getNetworkTypesGate = Completer<void>();
      unawaited(detector.start());
      async.flushMicrotasks();
      detector.stop();
      gate.complete();
      async.flushMicrotasks();

      expect(source.isWatched, isFalse);
    });
  });

  test(
    'a superseded start whose read fails leaves the newer watch running',
    () {
      fakeAsync((async) {
        final gate = source.getNetworkTypesGate = Completer<void>();
        unawaited(detector.start());
        async.flushMicrotasks();
        source.getNetworkTypesGate = null;
        unawaited(detector.start());
        async.flushMicrotasks();
        expect(source.isWatched, isTrue);

        source.getNetworkTypesError = StateError('no answer');
        gate.complete();
        async.flushMicrotasks();

        expect(source.isWatched, isTrue);
        expect(logs, isEmpty);
      });
    },
  );

  test('when the OS cannot be asked, it warns, reports nothing and does not '
      'listen', () {
    source.getNetworkTypesError = StateError('no plugin');
    run((async) {
      expect(source.isWatched, isFalse);
      source.report({'mobile'});
      async.flushMicrotasks();

      expect(changes, isEmpty);
      expect(logs, [startsWith('warn')]);
    });
  });

  test('when the report stream cannot be opened, it warns and reports '
      'nothing', () {
    source.networkTypesChangedError = StateError('no binding');
    run((async) {
      expect(logs, [startsWith('warn')]);
      expect(changes, isEmpty);
    });
  });

  test('a failing report stream warns and stops watching', () {
    run((async) {
      source.fail(StateError('channel gone'));
      async.flushMicrotasks();

      expect(logs, [startsWith('warn')]);
      expect(source.isWatched, isFalse);
    });
  });

  test('stop ends watching; start after stop takes a new baseline', () {
    run((async) {
      detector.stop();
      async.flushMicrotasks();
      expect(source.isWatched, isFalse);

      source.report({'mobile'});
      unawaited(detector.start());
      async.flushMicrotasks();
      source.report({'mobile'});
      async.flushMicrotasks();
      expect(changes, isEmpty);
    });
  });
}
