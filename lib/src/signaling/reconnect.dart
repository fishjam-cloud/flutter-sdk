/// The reconnection state machine (SPEC §6).
///
/// Owner: **Signaling** agent.
library;

// Constructor fields are kept for the Signaling implementation.
// ignore_for_file: unused_field

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/track.dart';

/// States of [ReconnectManager].
enum ReconnectState {
  /// Not reconnecting.
  idle,

  /// Attempts are scheduled or running.
  reconnecting,

  /// Gave up; terminal until [ReconnectManager.reset].
  failed,
}

/// What the client looked like when the connection was lost.
final class ReconnectSnapshot {
  /// Creates a snapshot.
  const ReconnectSnapshot({required this.peerMetadata, required this.tracks});

  /// The `peer` part of the local peer's metadata.
  final Object? peerMetadata;

  /// Local tracks to restore when `addTracksOnReconnect` is set.
  final List<LocalTrackContext> tracks;
}

/// Side effects of [ReconnectManager], implemented by the client facade.
abstract interface class ReconnectHost {
  /// Tears down the old session silently and starts a new one that sends
  /// [peerMetadata] in `connect`.
  Future<void> startSession(Object? peerMetadata);

  /// Publishes [track]'s media again; the new track gets a new id.
  Future<void> restoreTrack(LocalTrackContext track);

  /// Holds outgoing queued messages.
  void holdQueue();

  /// Flushes outgoing queued messages.
  void releaseQueue();

  /// Drops outgoing queued messages.
  void clearQueue();

  /// Emits a client event.
  void emit(FishjamEvent event);
}

/// Decides when to reconnect, schedules attempts and restores tracks
/// (SPEC §6). Uses `dart:async` timers (tests drive it with fake time).
///
/// Owner: Signaling.
class ReconnectManager {
  /// Creates a manager.
  ReconnectManager({required this._config, required this._host});

  final ReconnectConfig _config;
  final ReconnectHost _host;

  /// Current state.
  ReconnectState get state => throw UnimplementedError('Signaling');

  /// Whether attempts are scheduled or running.
  bool get isReconnecting => throw UnimplementedError('Signaling');

  /// A retryable loss happened while joined or reconnecting. Returns `false`
  /// when the caller must end the session instead (reconnection disabled or
  /// attempts exhausted — in the latter case `ReconnectionFailed` was
  /// already emitted).
  bool onRetryableLoss(RetryableClose reason, ReconnectSnapshot snapshot) =>
      throw UnimplementedError('Signaling');

  /// A terminal close happened; cancels any pending attempt.
  void onTerminalClose(CloseReason reason) =>
      throw UnimplementedError('Signaling');

  /// A session reached `connected`. In [ReconnectState.reconnecting]:
  /// restores tracks, releases the queue and emits `Reconnected`.
  Future<void> onSessionJoined() => throw UnimplementedError('Signaling');

  /// Cancels everything and returns to [ReconnectState.idle] (on `leave()`
  /// and on a new `connect()`).
  void reset() => throw UnimplementedError('Signaling');
}
