/// The reconnection state machine (SPEC §6).
///
/// Owner: **Signaling** agent.
library;

import 'dart:async';

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
/// Division of work with the caller (the client facade):
/// - The caller reports every loss of the current session — including a new
///   session that fails to open — through [onRetryableLoss] or
///   [onTerminalClose], and every `connected` through [onSessionJoined].
/// - The manager emits only `ReconnectionStarted`, `ReconnectionFailed` and
///   `Reconnected`. It never emits `Disconnected` (D9): when
///   [onRetryableLoss] returns `false` the caller ends the session with
///   `Disconnected(reconnectionFailed)` if [state] is
///   [ReconnectState.failed], else `Disconnected(connectionLost)`; after a
///   terminal close the caller emits the error event and `Disconnected`.
class ReconnectManager {
  /// Creates a manager.
  ReconnectManager({required this._config, required this._host});

  final ReconnectConfig _config;
  final ReconnectHost _host;

  ReconnectState _state = ReconnectState.idle;
  ReconnectSnapshot? _snapshot;
  Timer? _timer;

  /// Number of attempts started in the current reconnection.
  int _attempt = 0;

  /// Bumped whenever the current attempt is superseded, so a pending track
  /// restoration of an outdated session does not complete the reconnection.
  int _generation = 0;

  /// Current state.
  ReconnectState get state => _state;

  /// Whether attempts are scheduled or running.
  bool get isReconnecting => _state == ReconnectState.reconnecting;

  /// A retryable loss happened while joined or reconnecting. Returns `false`
  /// when the caller must end the session instead (reconnection disabled or
  /// attempts exhausted — in the latter case `ReconnectionFailed` was
  /// already emitted).
  bool onRetryableLoss(RetryableClose reason, ReconnectSnapshot snapshot) {
    switch (_state) {
      case ReconnectState.failed:
        return false;
      case ReconnectState.idle:
        if (!_config.isEnabled) return false;
        _state = ReconnectState.reconnecting;
        _snapshot = snapshot;
        _attempt = 0;
        _host
          ..holdQueue()
          ..emit(const ReconnectionStarted());
        _scheduleNextAttempt();
        return true;
      case ReconnectState.reconnecting:
        if (_timer != null) return true;
        _generation++;
        if (_attempt < _config.maxAttempts) {
          _scheduleNextAttempt();
          return true;
        }
        _finish(ReconnectState.failed);
        _host.emit(const ReconnectionFailed());
        return false;
    }
  }

  /// A terminal close happened; cancels any pending attempt. While
  /// reconnecting it also clears the queue and moves to
  /// [ReconnectState.failed]. Emits nothing.
  void onTerminalClose(CloseReason reason) {
    if (_state == ReconnectState.reconnecting) {
      _finish(ReconnectState.failed);
    } else {
      _cancelTimer();
    }
  }

  /// A session reached `connected`. In [ReconnectState.reconnecting]:
  /// restores tracks, releases the queue and emits `Reconnected`.
  ///
  /// Only live tracks are restored; ended or muted ones are skipped and a
  /// failed restore does not stop the others (D2). If the session is lost
  /// while restoring, `Reconnected` is not emitted for it.
  Future<void> onSessionJoined() async {
    if (_state != ReconnectState.reconnecting) return;
    final generation = _generation;
    if (_config.addTracksOnReconnect) {
      for (final track in _snapshot!.tracks) {
        if (track.rtcTrack?.isLive != true) continue;
        try {
          await _host.restoreTrack(track);
        } on Object {
          // The host reports the failure; the other tracks still go.
        }
        if (generation != _generation) return;
      }
    }
    _finish(ReconnectState.idle, release: true);
    _host.emit(const Reconnected());
  }

  /// Cancels everything and returns to [ReconnectState.idle] (on `leave()`
  /// and on a new `connect()`); clears the queue.
  void reset() => _finish(ReconnectState.idle);

  void _scheduleNextAttempt() {
    final attempt = _attempt + 1;
    _timer = Timer(_config.delayBeforeAttempt(attempt), () {
      _timer = null;
      _attempt = attempt;
      _generation++;
      unawaited(_host.startSession(_snapshot!.peerMetadata));
    });
  }

  /// Leaves the current reconnection: cancels the timer, invalidates pending
  /// restores, and releases (success) or clears (otherwise) the queue.
  void _finish(ReconnectState state, {bool release = false}) {
    _cancelTimer();
    _generation++;
    _state = state;
    _snapshot = null;
    _attempt = 0;
    if (release) {
      _host.releaseQueue();
    } else {
      _host.clearQueue();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
