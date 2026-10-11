/// The command queue (SPEC §8.3).
///
/// Owner: **Engine** agent.
library;

import 'dart:async';

/// When a command is complete.
enum CommandCompletion {
  /// When the answer of the negotiation that carried it was applied.
  afterNegotiation,

  /// When its handler finished (no negotiation needed).
  onHandlerDone,

  /// When the command itself completes its [Command.done] (e.g. data
  /// channels open).
  custom,
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

  /// Completes when the command is complete or failed.
  Future<void> get done => throw UnimplementedError('Engine');
}

/// FIFO of [Command]s driven by the negotiation state machine.
///
/// Owner: Engine.
class CommandQueue {
  /// Adds [command]; returns [Command.done].
  Future<void> push(Command command) => throw UnimplementedError('Engine');

  /// Fails every pending and in-flight command with
  /// `StateError('disconnected')`.
  void failAll() => throw UnimplementedError('Engine');
}
