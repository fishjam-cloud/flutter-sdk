/// The command queue (SPEC §8.3).
///
/// Owner: **Engine** agent.
library;

import 'dart:async';

import 'package:fishjam_client/src/engine/negotiation_state.dart';

/// Runs asynchronous tasks strictly one after another.
///
/// Media event handling and command execution share one executor, so a
/// command never interleaves with an offer being built (SPEC §7, §8).
/// A task must not wait for another task scheduled on the same executor.
class SerialExecutor {
  Future<void> _tail = Future.value();

  /// Runs [task] after every previously scheduled task completed. The
  /// returned future completes with the task's result or error; a failing
  /// task does not stop the following ones.
  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// When a command is complete.
enum CommandCompletion {
  /// When the answer of the negotiation that carried it was applied.
  afterNegotiation,

  /// When its handler finished (no negotiation needed).
  onHandlerDone,
}

/// A user operation that touches the sender set (SPEC §8.3).
///
/// Owner: Engine.
class Command {
  /// Creates a command.
  Command({
    required this.name,
    required this.run,
    required this.completion,
    required this.batchable,
  });

  /// For logs.
  final String name;

  /// Validates and applies the command. Throwing fails only this command.
  final Future<void> Function() run;

  /// When the command is complete.
  final CommandCompletion completion;

  /// Whether it may join a pending negotiation.
  final bool batchable;

  /// Whether the command is carried by a negotiation.
  bool get needsNegotiation => completion == CommandCompletion.afterNegotiation;

  final Completer<void> _done = Completer<void>();

  /// Completes when the command is complete or failed.
  Future<void> get done => _done.future;

  void _complete() {
    if (!_done.isCompleted) _done.complete();
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (!_done.isCompleted) _done.completeError(error, stackTrace);
  }

  @override
  String toString() => 'Command($name)';
}

/// FIFO of [Command]s driven by the negotiation state machine.
///
/// Owner: Engine.
class CommandQueue {
  /// Creates a queue.
  CommandQueue({
    required this.negotiation,
    required this.executor,
    required this.perform,
  });

  /// The state machine deciding when commands may start.
  final NegotiationStateMachine negotiation;

  /// The serial lane commands run on.
  final SerialExecutor executor;

  /// Performs the effects of a state machine transition.
  final void Function(List<NegotiationEffect> effects) perform;

  final _pending = <Command>[];
  final _inFlight = <Command>[];
  Command? _running;
  bool _closed = false;

  /// Adds [command]; returns [Command.done].
  Future<void> push(Command command) {
    if (_closed) {
      command._fail(_disconnected());
    } else {
      _pending.add(command);
      pump();
    }
    return command.done;
  }

  /// Schedules starting every command that may start now (SPEC §8.3 rules
  /// 1, 2).
  void pump() => unawaited(executor.run(_pumpNow));

  Future<void> _pumpNow() async {
    while (!_closed &&
        _pending.isNotEmpty &&
        negotiation.canStart(batchable: _pending.first.batchable)) {
      final command = _pending.removeAt(0);
      if (await _start(command) && command.needsNegotiation) {
        perform(negotiation.handle(NegotiationInput.commandStarted));
      }
    }
  }

  /// Runs the batchable commands at the head of the queue into the offer
  /// being built, stopping at the first non-batchable one (SPEC §8.3 rule
  /// 2). Call it on [executor].
  Future<void> drainBatch() async {
    while (!_closed && _pending.isNotEmpty && _pending.first.batchable) {
      await _start(_pending.removeAt(0));
    }
  }

  /// Runs [command]; returns whether it started successfully.
  Future<bool> _start(Command command) async {
    _running = command;
    try {
      await command.run();
    } on Object catch (e, st) {
      command._fail(e, st);
      return false;
    } finally {
      _running = null;
    }
    if (_closed) return false;
    if (command.needsNegotiation) {
      _inFlight.add(command);
    } else {
      command._complete();
    }
    return true;
  }

  /// Completes the commands carried by the cycle whose answer was applied.
  void completeCycle() {
    final done = List.of(_inFlight);
    _inFlight.clear();
    for (final c in done) {
      c._complete();
    }
  }

  /// Fails the commands carried by the current cycle with [error].
  void failCycle(Object error) {
    final failed = List.of(_inFlight);
    _inFlight.clear();
    for (final c in failed) {
      c._fail(error);
    }
  }

  /// Fails every pending, running and in-flight command with
  /// `StateError('disconnected')`; later pushes fail the same way
  /// (SPEC §8.3 rule 6).
  void failAll() {
    _closed = true;
    final all = [?_running, ..._inFlight, ..._pending];
    _inFlight.clear();
    _pending.clear();
    for (final c in all) {
      c._fail(_disconnected());
    }
  }

  static StateError _disconnected() => StateError('disconnected');
}
