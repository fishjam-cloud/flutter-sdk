import 'dart:async';

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/track.dart';

enum ReconnectState {
  idle,

  /// Attempts are scheduled or running.
  reconnecting,

  /// Gave up; terminal until [ReconnectManager.reset].
  failed,
}

/// What the client looked like when the connection was lost.
final class ReconnectSnapshot {
  const ReconnectSnapshot({required this.peerMetadata, required this.tracks});

  /// The `peer` part of the local peer's metadata.
  final Object? peerMetadata;

  /// Local tracks to restore when `addTracksOnReconnect` is set.
  final List<LocalTrackContext> tracks;
}

/// Side effects of [ReconnectManager], implemented by the client facade.
abstract interface class ReconnectHost {
  /// Tears down the old session silently and starts a new one that sends
  /// [peerMetadata] in `connect`. Losses of the new session are reported
  /// back as usual; if this throws, the manager treats it as a retryable loss
  /// of the attempt.
  Future<void> startSession(Object? peerMetadata);

  /// Tears the session down and emits `Disconnected(reason)`. Called only
  /// where no caller waits for a result (`ReconnectionFailed` was emitted
  /// just before): [startSession] threw on the last attempt, the device was
  /// offline for `offlineTimeout`, or the network changed after the total
  /// attempt cap was reached. Later reports about the abandoned session must
  /// be ignored.
  void endSession(DisconnectReason reason);

  /// Publishes [track]'s media again; the new track gets a new id.
  Future<void> restoreTrack(LocalTrackContext track);

  void holdQueue();

  void releaseQueue();

  void clearQueue();

  void emit(FishjamEvent event);
}

/// Decides when to reconnect, schedules attempts and restores tracks. Uses
/// `dart:async` timers (tests drive it with fake time).
///
/// Division of work with the caller (the client facade):
/// - The caller reports every loss of the current session — including a new
///   session that fails to open — through [onRetryableLoss] or
///   [onTerminalClose], and every `connected` through [onSessionJoined].
/// - The caller reports every network change through [onNetworkLost] or
///   [onNetworkAvailable]. While joined it first reports a lost or changed
///   network as a retryable loss, so the change then acts on the
///   reconnection that loss started.
/// - The manager emits only `ReconnectionStarted`, `ReconnectionFailed` and
///   `Reconnected`. It never emits `Disconnected`: when
///   [onRetryableLoss] returns `false` the caller ends the session with
///   `Disconnected(reconnectionFailed)` if [state] is
///   [ReconnectState.failed], else `Disconnected(connectionLost)`; after a
///   terminal close the caller emits the error event and `Disconnected`.
///   Where no caller waits for a result (timers, network events), the
///   manager ends the session itself through [ReconnectHost.endSession] (the
///   cases are listed there).
/// - With `addTracksOnReconnect`, only tracks with a live media track are
///   re-added. Muted tracks (no media track) and ended tracks are
///   not; a failed re-add does not stop the others.
class ReconnectManager {
  ReconnectManager({required this._config, required this._host});

  final ReconnectConfig _config;
  final ReconnectHost _host;

  ReconnectState _state = ReconnectState.idle;
  ReconnectSnapshot? _snapshot;
  Timer? _nextAttemptTimer;

  /// Number of attempts started on the current network in the current
  /// reconnection (the budget of `maxAttempts`).
  int _attemptsOnThisNetwork = 0;

  /// Number of attempts started in the current reconnection on any network:
  /// a network that keeps changing restarts the budget, so this caps it.
  int _totalAttempts = 0;

  /// Whether the latest attempt is still open: started, and neither lost nor
  /// left waiting for the network (it stays set while a joined attempt
  /// restores its tracks).
  bool _attemptInProgress = false;

  /// While offline no attempt starts, and a loss waits for the network
  /// instead of using up the budget.
  bool _online = true;

  /// Runs while reconnecting offline; fires [_failAndEndSession] at
  /// `offlineTimeout`.
  Timer? _offlineTimer;

  /// Bumped whenever the current attempt is superseded, so a pending track
  /// restoration of an outdated session does not complete the reconnection.
  int _generation = 0;

  ReconnectState get state => _state;

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
        _host
          ..holdQueue()
          ..emit(const ReconnectionStarted());
        if (_online) {
          _scheduleNextAttempt();
        } else {
          _startOfflineTimeout();
        }
        return true;
      case ReconnectState.reconnecting:
        if (_nextAttemptTimer != null) return true;
        _generation++;
        _attemptInProgress = false;
        // Offline: wait for the network; do not count an attempt.
        if (!_online) return true;
        if (_attemptsOnThisNetwork < _config.maxAttempts &&
            _totalAttempts < _maxTotalAttempts) {
          _scheduleNextAttempt();
          return true;
        }
        _markFailed();
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
      _cancelNextAttemptTimer();
    }
  }

  /// A session reached `connected`. In [ReconnectState.reconnecting]:
  /// restores tracks, releases the queue and emits `Reconnected`.
  ///
  /// Only live tracks are restored, all at once; ended or muted ones are
  /// skipped and a failed restore does not stop the others. If the session
  /// is lost or the device goes offline before it is restored, `Reconnected`
  /// is not emitted for it.
  Future<void> onSessionJoined() async {
    if (_state != ReconnectState.reconnecting) return;
    if (_online && _config.addTracksOnReconnect) {
      final generation = _generation;
      // Start all restores at once so they usually share one renegotiation.
      // A failed restore is ignored, so the others still run; that track is
      // not published again and the app gets no `LocalTrackAdded` for it.
      await Future.wait([
        for (final track in _snapshot!.tracks)
          if (track.rtcTrack?.isLive ?? false)
            _host.restoreTrack(track).then<void>((_) {}, onError: (_) {}),
      ]);
      if (generation != _generation) return;
    }
    if (!_online) {
      // The device went offline before or during the restore. This session
      // will not survive, so do not emit `Reconnected`; wait for the network
      // instead (the offline timeout is already running).
      _attemptInProgress = false;
      return;
    }
    _finish(ReconnectState.idle, release: true);
    _host.emit(const Reconnected());
  }

  /// The device has no network. While reconnecting, a scheduled attempt is
  /// cancelled and the reconnection waits, at most `offlineTimeout`, for
  /// [onNetworkAvailable]. Outside a reconnection it is only remembered.
  void onNetworkLost() {
    _online = false;
    if (_state != ReconnectState.reconnecting) return;
    _cancelNextAttemptTimer();
    _startOfflineTimeout();
  }

  /// The device is online again or switched networks. While reconnecting:
  /// reset the attempt budget and start a new attempt now.
  void onNetworkAvailable() {
    _online = true;
    _cancelOfflineTimer();
    if (_state != ReconnectState.reconnecting) return;
    if (_totalAttempts >= _maxTotalAttempts) {
      // If an attempt is still running, its result decides; otherwise fail
      // now.
      if (!_attemptInProgress) _failAndEndSession();
      return;
    }
    _cancelNextAttemptTimer();
    _startAttempt(1);
  }

  /// Cancels everything and returns to [ReconnectState.idle] (on `leave()`
  /// and on a new `connect()`); clears the queue and forgets that the device
  /// was offline.
  void reset() {
    _finish(ReconnectState.idle);
    _online = true;
  }

  int get _maxTotalAttempts => 3 * _config.maxAttempts;

  /// Calls [_failAndEndSession] after `offlineTimeout` unless
  /// [onNetworkAvailable] comes first.
  void _startOfflineTimeout() {
    _offlineTimer ??= Timer(_config.offlineTimeout, () {
      _offlineTimer = null;
      _failAndEndSession();
    });
  }

  /// Emits `ReconnectionFailed`. The caller ends the session (used when
  /// [onRetryableLoss] returns `false`).
  void _markFailed() {
    _finish(ReconnectState.failed);
    _host.emit(const ReconnectionFailed());
  }

  /// Emits `ReconnectionFailed` and ends the session. Used where no caller is
  /// waiting for a result (timers, network events).
  void _failAndEndSession() {
    _markFailed();
    _host.endSession(DisconnectReason.reconnectionFailed);
  }

  void _scheduleNextAttempt() {
    final attempt = _attemptsOnThisNetwork + 1;
    _nextAttemptTimer = Timer(_config.delayBeforeAttempt(attempt), () {
      _nextAttemptTimer = null;
      _startAttempt(attempt);
    });
  }

  /// Starts [attempt], superseding any attempt still in progress.
  void _startAttempt(int attempt) {
    _attemptsOnThisNetwork = attempt;
    _totalAttempts++;
    _attemptInProgress = true;
    final generation = ++_generation;
    unawaited(
      _host
          .startSession(_snapshot!.peerMetadata)
          .then<void>(
            (_) {},
            onError: (Object error) =>
                _onStartFailed(generation, RetryableClose(error: error)),
          ),
    );
  }

  /// [ReconnectHost.startSession] threw. Unless the attempt was already
  /// superseded (its loss reported, a terminal close, `reset`), this is the
  /// attempt's retryable loss.
  void _onStartFailed(int generation, RetryableClose loss) {
    if (generation != _generation || !isReconnecting) return;
    if (!onRetryableLoss(loss, _snapshot!)) {
      _host.endSession(DisconnectReason.reconnectionFailed);
    }
  }

  /// Leaves the current reconnection: cancels the timer, invalidates pending
  /// restores, and releases (success) or clears (otherwise) the queue.
  void _finish(ReconnectState state, {bool release = false}) {
    _cancelNextAttemptTimer();
    _cancelOfflineTimer();
    _generation++;
    _state = state;
    _snapshot = null;
    _attemptsOnThisNetwork = 0;
    _totalAttempts = 0;
    _attemptInProgress = false;
    if (release) {
      _host.releaseQueue();
    } else {
      _host.clearQueue();
    }
  }

  void _cancelNextAttemptTimer() {
    _nextAttemptTimer?.cancel();
    _nextAttemptTimer = null;
  }

  void _cancelOfflineTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }
}
