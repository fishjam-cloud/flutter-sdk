import 'dart:async';

import 'package:fishjam_client/src/engine/command_queue.dart';
import 'package:fishjam_client/src/engine/negotiation_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a command did.
class _Harness {
  _Harness() {
    queue = CommandQueue(
      negotiation: negotiation,
      executor: SerialExecutor(),
      perform: (effects) {
        for (final e in effects) {
          switch (e) {
            case NegotiationEffect.none:
              break;
            case NegotiationEffect.sendRenegotiateTracks:
              renegotiations++;
            case NegotiationEffect.processNextCommand:
              queue.pump();
          }
        }
      },
    );
  }

  final negotiation = NegotiationStateMachine();
  late final CommandQueue queue;
  final List<String> log = [];
  int renegotiations = 0;

  Command command(
    String name, {
    bool batchable = true,
    CommandCompletion completion = CommandCompletion.afterNegotiation,
    Future<void> Function()? run,
  }) => Command(
    name: name,
    batchable: batchable,
    completion: completion,
    run: () async {
      log.add(name);
      await run?.call();
    },
  );

  /// Pushes [command] and returns a record of its outcome.
  _Outcome push(Command command) => _Outcome(queue.push(command));

  /// Simulates `offerData` handling and the answer of the current cycle.
  Future<void> completeCycle() async {
    await queue.executor.run(queue.drainBatch);
    negotiation.handle(NegotiationInput.offerSent);
    queue.completeCycle();
    queue.perform(negotiation.handle(NegotiationInput.answerApplied));
    await pumpEventQueue();
  }
}

class _Outcome {
  _Outcome(Future<void> future) {
    unawaited(
      future.then<void>(
        (_) => done = true,
        onError: (Object e) {
          error = e;
        },
      ),
    );
  }

  bool done = false;
  Object? error;
}

void main() {
  group('CommandQueue (SPEC §8.3)', () {
    test('a negotiating command in idle runs, requests a negotiation and '
        'completes after the answer', () async {
      final h = _Harness();
      final a = h.push(h.command('a'));
      await pumpEventQueue();

      expect(h.log, ['a']);
      expect(h.renegotiations, 1);
      expect(h.negotiation.state, NegotiationState.requested);
      expect(a.done, isFalse);

      await h.completeCycle();
      expect(a.done, isTrue);
      expect(h.negotiation.state, NegotiationState.idle);
    });

    test('batchable commands pushed back to back share one renegotiation '
        '(rule 4)', () async {
      final h = _Harness();
      final outcomes = [
        h.push(h.command('a')),
        h.push(h.command('b')),
        h.push(h.command('c')),
      ];
      await pumpEventQueue();

      expect(h.log, ['a', 'b', 'c']);
      expect(h.renegotiations, 1);

      await h.completeCycle();
      expect(outcomes.map((o) => o.done), everyElement(isTrue));
      expect(h.renegotiations, 1);
    });

    test('a non-batchable command waits for idle and blocks the commands '
        'behind it (rules 1, 2)', () async {
      final h = _Harness();
      final a = h.push(h.command('a'));
      final r = h.push(h.command('remove', batchable: false));
      final c = h.push(h.command('c'));
      await pumpEventQueue();
      expect(h.log, ['a']);

      await h.completeCycle();
      expect(a.done, isTrue);
      expect(r.done, isFalse);
      // remove started in idle and requested its own cycle; c rode it.
      expect(h.log, ['a', 'remove', 'c']);
      expect(h.renegotiations, 2);

      await h.completeCycle();
      expect(r.done, isTrue);
      expect(c.done, isTrue);
    });

    test('a command pushed after the offer was sent waits for the next '
        'cycle and requests it (rule 5)', () async {
      final h = _Harness();
      h.push(h.command('a'));
      await pumpEventQueue();
      h.negotiation.handle(NegotiationInput.offerSent);

      final b = h.push(h.command('b'));
      await pumpEventQueue();
      expect(h.log, ['a']);

      h.queue
        ..completeCycle()
        ..perform(h.negotiation.handle(NegotiationInput.answerApplied));
      await pumpEventQueue();
      expect(h.log, ['a', 'b']);
      expect(h.renegotiations, 2);
      expect(b.done, isFalse);
    });

    test('drainBatch runs batchable commands at the head without '
        'requesting a negotiation and stops at a non-batchable one', () async {
      final h = _Harness();
      h.negotiation
        ..handle(NegotiationInput.commandStarted)
        ..handle(NegotiationInput.offerSent);
      final a = h.push(h.command('a'));
      final b = h.push(h.command('b'));
      final r = h.push(h.command('remove', batchable: false));
      await pumpEventQueue();
      expect(h.log, isEmpty);

      await h.queue.executor.run(h.queue.drainBatch);
      expect(h.log, ['a', 'b']);
      expect(h.renegotiations, 0);

      h.queue.completeCycle();
      await pumpEventQueue();
      expect(a.done, isTrue);
      expect(b.done, isTrue);
      expect(r.done, isFalse);
    });

    test('a failing command completes with its error, requests nothing and '
        'does not affect the others (rule 3)', () async {
      final h = _Harness();
      final bad = h.push(
        h.command('bad', run: () async => throw ArgumentError('invalid')),
      );
      final good = h.push(h.command('good'));
      await pumpEventQueue();

      expect(bad.error, isA<ArgumentError>());
      expect(h.log, ['bad', 'good']);
      expect(h.renegotiations, 1);

      await h.completeCycle();
      expect(good.done, isTrue);
    });

    test('a non-negotiating command completes when its handler is done and '
        'does not change the state', () async {
      final h = _Harness();
      final replace = h.push(
        h.command(
          'replace',
          batchable: false,
          completion: CommandCompletion.onHandlerDone,
        ),
      );
      final next = h.push(
        h.command(
          'replace2',
          batchable: false,
          completion: CommandCompletion.onHandlerDone,
        ),
      );
      await pumpEventQueue();

      expect(replace.done, isTrue);
      expect(next.done, isTrue);
      expect(h.renegotiations, 0);
      expect(h.negotiation.state, NegotiationState.idle);
    });

    test('commands run one at a time', () async {
      final h = _Harness();
      final gate = Completer<void>();
      h
        ..push(h.command('slow', run: () => gate.future))
        ..push(h.command('next'));
      await pumpEventQueue();
      expect(h.log, ['slow']);

      gate.complete();
      await pumpEventQueue();
      expect(h.log, ['slow', 'next']);
    });

    test('failCycle fails the commands of the current cycle only', () async {
      final h = _Harness();
      final a = h.push(h.command('a'));
      await pumpEventQueue();
      h.negotiation.handle(NegotiationInput.offerSent);
      final b = h.push(h.command('b'));
      await pumpEventQueue();

      h.queue.failCycle(StateError('offer failed'));
      await pumpEventQueue();
      expect(a.error, isA<StateError>());
      expect(b.error, isNull);
      expect(b.done, isFalse);
    });

    test(
      'failAll fails pending, running and in-flight commands with '
      "StateError('disconnected') and rejects later pushes (rule 6)",
      () async {
        final h = _Harness();
        final gate = Completer<void>();
        final inFlight = h.push(h.command('inFlight'));
        await pumpEventQueue();
        h.negotiation.handle(NegotiationInput.offerSent);
        h.negotiation.reset();
        final running = h.push(h.command('running', run: () => gate.future));
        final pending = h.push(h.command('pending', batchable: false));
        await pumpEventQueue();
        expect(h.log, ['inFlight', 'running']);

        h.queue.failAll();
        gate.complete();
        final later = h.push(h.command('later'));
        await pumpEventQueue();

        for (final o in [inFlight, running, pending, later]) {
          expect(o.error, isA<StateError>());
          expect('${o.error}', contains('disconnected'));
        }
        expect(h.log, ['inFlight', 'running']);
      },
    );
  });

  group('SerialExecutor', () {
    test('runs tasks one after another and keeps going after errors', () async {
      final executor = SerialExecutor();
      final log = <String>[];
      final gate = Completer<void>();
      final first = executor.run(() async {
        await gate.future;
        log.add('first');
        throw StateError('boom');
      });
      final second = executor.run(() async {
        log.add('second');
        return 2;
      });
      await pumpEventQueue();
      expect(log, isEmpty);

      gate.complete();
      await expectLater(first, throwsStateError);
      expect(await second, 2);
      expect(log, ['first', 'second']);
    });
  });
}
