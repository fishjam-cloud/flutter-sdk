import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/signaling/reconnect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';

/// Records every host call in order.
class _Host implements ReconnectHost {
  final calls = <String>[];
  final events = <FishjamEvent>[];
  final startedWith = <Object?>[];
  final restored = <String>[];

  /// Restores complete when the test completes these (by track id); tracks
  /// not listed complete immediately.
  final pendingRestores = <String, Completer<void>>{};

  /// Track ids whose restore fails.
  final failingRestores = <String>{};

  /// Number of upcoming `startSession` calls that throw.
  int failingStarts = 0;

  /// When set, `startSession` waits for it before throwing.
  Completer<void>? startGate;

  @override
  Future<void> startSession(Object? peerMetadata) async {
    calls.add('startSession');
    startedWith.add(peerMetadata);
    final gate = startGate;
    if (gate != null) await gate.future;
    if (failingStarts > 0) {
      failingStarts--;
      throw StateError('cannot start');
    }
  }

  @override
  void endSession(DisconnectReason reason) => calls.add('endSession:$reason');

  @override
  Future<void> restoreTrack(LocalTrackContext track) async {
    calls.add('restoreTrack:${track.trackId}');
    final pending = pendingRestores[track.trackId];
    if (pending != null) await pending.future;
    if (failingRestores.contains(track.trackId)) {
      throw StateError('restore failed');
    }
    restored.add(track.trackId);
  }

  @override
  void holdQueue() => calls.add('holdQueue');

  @override
  void releaseQueue() => calls.add('releaseQueue');

  @override
  void clearQueue() => calls.add('clearQueue');

  @override
  void emit(FishjamEvent event) {
    calls.add('emit:${event.runtimeType}');
    events.add(event);
  }

  int count(String call) => calls.where((c) => c == call).length;
}

LocalTrackContext _track(String id, {RtcMediaTrack? media}) =>
    LocalTrackContext(
      trackId: id,
      kind: MediaKind.video,
      rtcTrack: media,
      rtcStream: null,
      metadata: null,
      simulcastConfig: const SimulcastConfig.disabled(),
      maxBandwidth: const SingleBandwidthLimit(0),
    );

const _loss = RetryableClose(code: 1011, reason: 'Internal server error');

// maxAttempts 3, initialDelay 500 ms (the defaults), delay 300 ms, tracks
// not restored.
const _config = ReconnectConfig(
  delay: Duration(milliseconds: 300),
  addTracksOnReconnect: false,
);

void main() {
  late _Host host;

  ReconnectManager manager([ReconnectConfig config = _config]) =>
      ReconnectManager(config: config, host: host);

  ReconnectSnapshot snapshot({
    Object? metadata = const {'name': 'alice'},
    List<LocalTrackContext> tracks = const [],
  }) => ReconnectSnapshot(peerMetadata: metadata, tracks: tracks);

  setUp(() => host = _Host());

  test('starts idle', () {
    final m = manager();
    expect(m.state, ReconnectState.idle);
    expect(m.isReconnecting, isFalse);
  });

  test('disabled reconnection: the caller ends the session', () {
    final m = manager(ReconnectConfig.disabled);
    expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
    expect(m.state, ReconnectState.idle);
    expect(host.calls, isEmpty);
  });

  test('a loss holds the queue, emits ReconnectionStarted and starts a '
      'session after initialDelay with the snapshot metadata', () {
    fakeAsync((async) {
      final m = manager();
      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);

      expect(m.state, ReconnectState.reconnecting);
      expect(m.isReconnecting, isTrue);
      expect(host.calls, ['holdQueue', 'emit:ReconnectionStarted']);

      async.elapse(const Duration(milliseconds: 499));
      expect(host.count('startSession'), 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(host.count('startSession'), 1);
      expect(host.startedWith, [
        {'name': 'alice'},
      ]);
    });
  });

  test('losses while an attempt is scheduled are ignored', () {
    fakeAsync((async) {
      final m = manager()..onRetryableLoss(_loss, snapshot());
      expect(m.onRetryableLoss(_loss, snapshot(metadata: 'other')), isTrue);
      async.elapse(const Duration(seconds: 5));

      expect(host.count('startSession'), 1);
      expect(host.startedWith, [
        {'name': 'alice'},
      ]);
      expect(host.count('emit:ReconnectionStarted'), 1);
    });
  });

  test('attempt n waits initialDelay + (n - 1) * delay; then gives up', () {
    fakeAsync((async) {
      final m = manager()..onRetryableLoss(_loss, snapshot());
      async.elapse(const Duration(milliseconds: 500));
      expect(host.count('startSession'), 1);

      // Attempt 1 fails before `connected`.
      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
      async.elapse(const Duration(milliseconds: 799));
      expect(host.count('startSession'), 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(host.count('startSession'), 2);

      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
      async.elapse(const Duration(milliseconds: 1099));
      expect(host.count('startSession'), 2);
      async.elapse(const Duration(milliseconds: 1));
      expect(host.count('startSession'), 3);
      expect(host.startedWith.toSet(), {
        {'name': 'alice'},
      });

      // No attempts left.
      expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      expect(m.state, ReconnectState.failed);
      expect(m.isReconnecting, isFalse);
      expect(host.calls.sublist(host.calls.length - 2), [
        'clearQueue',
        'emit:ReconnectionFailed',
      ]);
      // The caller emits Disconnected, never the manager (D9).
      expect(host.events.whereType<Disconnected>(), isEmpty);

      async.elapse(const Duration(seconds: 10));
      expect(host.count('startSession'), 3);

      // Still failed: later losses are the caller's to end.
      final before = host.calls.length;
      expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      expect(host.calls, hasLength(before));
    });
  });

  test('joining again releases the queue, emits Reconnected and resets the '
      'attempt counter', () {
    fakeAsync((async) {
      final m = manager()..onRetryableLoss(_loss, snapshot());
      async.elapse(const Duration(milliseconds: 500));
      m.onRetryableLoss(_loss, snapshot());
      async.elapse(const Duration(milliseconds: 800));
      expect(host.count('startSession'), 2);

      unawaited(m.onSessionJoined());
      async.flushMicrotasks();

      expect(m.state, ReconnectState.idle);
      expect(host.calls.sublist(host.calls.length - 2), [
        'releaseQueue',
        'emit:Reconnected',
      ]);
      expect(host.count('clearQueue'), 0);

      // A later loss starts over at attempt 1 with every attempt available.
      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
      expect(host.count('emit:ReconnectionStarted'), 2);
      async.elapse(const Duration(milliseconds: 500));
      expect(host.count('startSession'), 3);
      for (var i = 0; i < 2; i++) {
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(seconds: 2));
      }
      expect(host.count('startSession'), 5);
      expect(host.events.whereType<Disconnected>(), isEmpty);
    });
  });

  test('onSessionJoined outside reconnection does nothing', () async {
    final m = manager();
    await m.onSessionJoined();
    expect(host.calls, isEmpty);
    expect(m.state, ReconnectState.idle);
  });

  group('track restoration (SPEC §6, D2)', () {
    test('without addTracksOnReconnect no track is restored', () {
      fakeAsync((async) {
        final m = manager()
          ..onRetryableLoss(
            _loss,
            snapshot(tracks: [_track('t1', media: FakeMediaTrack.video())]),
          );
        async.elapse(const Duration(milliseconds: 500));
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();

        expect(host.restored, isEmpty);
        // Every old track id is reported removed, before Reconnected.
        expect(
          host.events.whereType<LocalTrackRemoved>().map((e) => e.trackId),
          ['t1'],
        );
        expect(host.calls.sublist(host.calls.length - 3), [
          'emit:LocalTrackRemoved',
          'releaseQueue',
          'emit:Reconnected',
        ]);
      });
    });

    test('restores live tracks together and in order, skips ended and muted '
        'ones, survives failures, then releases the queue and emits '
        'Reconnected', () {
      fakeAsync((async) {
        final ended = FakeMediaTrack.video()..end();
        final m = manager(const ReconnectConfig())
          ..onRetryableLoss(
            _loss,
            snapshot(
              tracks: [
                _track('cam', media: FakeMediaTrack.video()),
                _track('ended', media: ended),
                _track('muted'),
                _track('broken', media: FakeMediaTrack.audio()),
                _track('mic', media: FakeMediaTrack.audio()),
              ],
            ),
          );
        host
          ..failingRestores.add('broken')
          ..pendingRestores['cam'] = Completer<void>();
        async.elapse(const Duration(milliseconds: 500));

        var done = false;
        unawaited(m.onSessionJoined().then((_) => done = true));
        async.flushMicrotasks();

        // Every restore starts before the first one completes, so they ride
        // one negotiation cycle; the queue stays held until all settled.
        expect(host.calls.where((c) => c.startsWith('restoreTrack')), [
          'restoreTrack:cam',
          'restoreTrack:broken',
          'restoreTrack:mic',
        ]);
        expect(host.count('releaseQueue'), 0);
        expect(m.isReconnecting, isTrue);
        expect(done, isFalse);

        host.pendingRestores['cam']!.complete();
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(host.calls.where((c) => c.startsWith('restoreTrack')), [
          'restoreTrack:cam',
          'restoreTrack:broken',
          'restoreTrack:mic',
        ]);
        expect(host.restored, unorderedEquals(['cam', 'mic']));
        // Every old track id is reported removed, in order, before the
        // first restore (restored tracks get new ids).
        expect(
          host.events.whereType<LocalTrackRemoved>().map((e) => e.trackId),
          ['cam', 'ended', 'muted', 'broken', 'mic'],
        );
        final firstRestore = host.calls.indexOf('restoreTrack:cam');
        expect(
          host.calls
              .sublist(0, firstRestore)
              .where((c) => c == 'emit:LocalTrackRemoved'),
          hasLength(5),
        );
        expect(host.calls.sublist(host.calls.length - 2), [
          'releaseQueue',
          'emit:Reconnected',
        ]);
        expect(m.state, ReconnectState.idle);
      });
    });

    test('a loss during restoration cancels Reconnected and schedules the '
        'next attempt', () {
      fakeAsync((async) {
        final m = manager(const ReconnectConfig())
          ..onRetryableLoss(
            _loss,
            snapshot(
              tracks: [
                _track('cam', media: FakeMediaTrack.video()),
                _track('mic', media: FakeMediaTrack.audio()),
              ],
            ),
          );
        host.pendingRestores['cam'] = Completer<void>();
        async.elapse(const Duration(milliseconds: 500));
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();

        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        host.pendingRestores['cam']!.complete();
        async.flushMicrotasks();

        expect(host.count('restoreTrack:mic'), 1);
        expect(host.count('emit:Reconnected'), 0);
        expect(host.count('releaseQueue'), 0);
        expect(m.isReconnecting, isTrue);

        async.elapse(const Duration(milliseconds: 1000));
        expect(host.count('startSession'), 2);

        // The next attempt restores the snapshot again, but the old ids
        // were already reported removed.
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();
        expect(
          host.events.whereType<LocalTrackRemoved>().map((e) => e.trackId),
          ['cam', 'mic'],
        );
        expect(host.count('restoreTrack:cam'), 2);
        expect(host.count('emit:Reconnected'), 1);
      });
    });
  });

  group('terminal close (SPEC §4, §6, D14)', () {
    test('while reconnecting: cancels the attempt, clears the queue, '
        'fails without emitting', () {
      fakeAsync((async) {
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        m
          ..onRetryableLoss(_loss, snapshot())
          ..onTerminalClose(
            const SessionEndedClose(SessionEndReason.roomStopped),
          );
        async.elapse(const Duration(seconds: 10));

        expect(host.count('startSession'), 1);
        expect(host.calls.last, 'clearQueue');
        expect(m.state, ReconnectState.failed);
        expect(host.count('emit:ReconnectionFailed'), 0);
        expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      });
    });

    test('a terminal close during restoration prevents Reconnected', () {
      fakeAsync((async) {
        final m = manager(const ReconnectConfig())
          ..onRetryableLoss(
            _loss,
            snapshot(tracks: [_track('cam', media: FakeMediaTrack.video())]),
          );
        host.pendingRestores['cam'] = Completer<void>();
        async.elapse(const Duration(milliseconds: 500));
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();

        m.onTerminalClose(const AuthClose(AuthErrorReason.expiredToken));
        host.pendingRestores['cam']!.complete();
        async.flushMicrotasks();

        expect(host.count('emit:Reconnected'), 0);
        expect(host.count('releaseQueue'), 0);
        expect(m.state, ReconnectState.failed);
      });
    });

    test('while idle: nothing to do', () {
      final m = manager()
        ..onTerminalClose(const JoinClose(JoinErrorReason.nodeNotFound));
      expect(m.state, ReconnectState.idle);
      expect(host.calls, isEmpty);
    });
  });

  group('a new session that cannot be started', () {
    test('counts as a retryable loss of that attempt', () {
      fakeAsync((async) {
        host.failingStarts = 1;
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        expect(host.count('startSession'), 1);

        async.elapse(const Duration(milliseconds: 799));
        expect(host.count('startSession'), 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(host.count('startSession'), 2);
        expect(m.isReconnecting, isTrue);
      });
    });

    test('a loss reported after the start error is ignored', () {
      fakeAsync((async) {
        host.failingStarts = 1;
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        // The failed start already scheduled attempt 2.
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(milliseconds: 800));
        expect(host.count('startSession'), 2);
        async.elapse(const Duration(seconds: 5));
        expect(host.count('startSession'), 2);
      });
    });

    test('a start error after the loss was reported is ignored', () {
      fakeAsync((async) {
        host
          ..failingStarts = 1
          ..startGate = Completer<void>();
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        host.startGate!.complete();
        host.startGate = null;
        async.elapse(const Duration(milliseconds: 800));
        expect(host.count('startSession'), 2);
        // Attempt 3 was not scheduled by the late start error.
        async.elapse(const Duration(seconds: 5));
        expect(host.count('startSession'), 2);
        expect(m.isReconnecting, isTrue);
      });
    });

    test('on the last attempt fails the reconnection and ends the '
        'session through the host', () {
      fakeAsync((async) {
        host.failingStarts = 1;
        final m = manager(const ReconnectConfig(maxAttempts: 1))
          ..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));

        expect(m.state, ReconnectState.failed);
        expect(host.calls.sublist(host.calls.length - 3), [
          'clearQueue',
          'emit:ReconnectionFailed',
          'endSession:${DisconnectReason.reconnectionFailed}',
        ]);
        expect(host.events.whereType<Disconnected>(), isEmpty);
      });
    });

    test('a start error after reset() does nothing', () {
      fakeAsync((async) {
        host
          ..failingStarts = 1
          ..startGate = Completer<void>();
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        m.reset();
        host.startGate!.complete();
        async.elapse(const Duration(seconds: 5));

        expect(m.state, ReconnectState.idle);
        expect(host.count('startSession'), 1);
        expect(host.calls.where((c) => c.startsWith('endSession')), isEmpty);
      });
    });
  });

  test('reset cancels the attempt, clears the queue and returns to idle', () {
    fakeAsync((async) {
      final m = manager()
        ..onRetryableLoss(_loss, snapshot())
        ..reset();
      async.elapse(const Duration(seconds: 10));

      expect(host.count('startSession'), 0);
      expect(host.calls.last, 'clearQueue');
      expect(m.state, ReconnectState.idle);

      // Usable again, from attempt 1.
      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
      async.elapse(const Duration(milliseconds: 500));
      expect(host.count('startSession'), 1);
    });
  });

  test('reset after a failure makes reconnection available again', () {
    fakeAsync((async) {
      final m = manager(const ReconnectConfig(maxAttempts: 1))
        ..onRetryableLoss(_loss, snapshot());
      async.elapse(const Duration(milliseconds: 500));
      expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      expect(m.state, ReconnectState.failed);

      m.reset();
      expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
    });
  });

  group('network changes (SPEC §6.1)', () {
    const offline10s = ReconnectConfig(offlineTimeout: Duration(seconds: 10));

    test('losing the network cancels the scheduled attempt; while offline '
        'nothing starts and a loss waits instead of using an attempt', () {
      fakeAsync((async) {
        final m = manager()
          ..onRetryableLoss(_loss, snapshot())
          ..onNetworkLost();
        async.elapse(const Duration(seconds: 30));
        expect(host.count('startSession'), 0);
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(seconds: 20));
        expect(host.count('startSession'), 0);
        expect(m.isReconnecting, isTrue);
      });
    });

    test('a loss while already offline waits for the network', () {
      fakeAsync((async) {
        final m = manager()..onNetworkLost();
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(seconds: 30));
        expect(host.count('startSession'), 0);
        expect(host.count('emit:ReconnectionStarted'), 1);
      });
    });

    test('the network back starts an attempt at once with a fresh budget', () {
      fakeAsync((async) {
        final m = manager()
          ..onRetryableLoss(_loss, snapshot())
          ..onNetworkLost()
          ..onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 1);

        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(milliseconds: 800));
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(milliseconds: 1100));
        expect(host.count('startSession'), 3);
        expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      });
    });

    test('a new network abandons the scheduled attempt and starts one at '
        'once, with a fresh budget', () {
      fakeAsync((async) {
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        m.onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 800));
        m.onRetryableLoss(_loss, snapshot());
        expect(host.count('startSession'), 2);

        m.onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 3);
        async.elapse(const Duration(seconds: 5));
        expect(host.count('startSession'), 3);

        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(milliseconds: 800));
        expect(m.onRetryableLoss(_loss, snapshot()), isTrue);
        async.elapse(const Duration(milliseconds: 1100));
        expect(host.count('startSession'), 5);
        expect(m.onRetryableLoss(_loss, snapshot()), isFalse);
      });
    });

    test('an attempt in progress is abandoned; its '
        'late start error is ignored', () {
      fakeAsync((async) {
        final gate = host.startGate = Completer<void>();
        host.failingStarts = 1;
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        expect(host.count('startSession'), 1);

        async.elapse(const Duration(milliseconds: 100));
        m.onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 2);

        gate.complete();
        async.elapse(const Duration(seconds: 5));
        expect(host.count('startSession'), 2);
        expect(m.isReconnecting, isTrue);
      });
    });

    test('a network change during track restoration starts a new attempt '
        'and cancels Reconnected', () {
      fakeAsync((async) {
        final pending = host.pendingRestores['t1'] = Completer<void>();
        final m = manager(const ReconnectConfig())
          ..onRetryableLoss(
            _loss,
            snapshot(tracks: [_track('t1', media: FakeMediaTrack.video())]),
          );
        async.elapse(const Duration(milliseconds: 500));
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();

        m.onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 2);

        pending.complete();
        async.flushMicrotasks();
        expect(host.events.whereType<Reconnected>(), isEmpty);
      });
    });

    test('a session that joins while offline does not complete the '
        'reconnection; the network back starts a new attempt', () {
      fakeAsync((async) {
        final m = manager()..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        m.onNetworkLost();
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();
        expect(host.events.whereType<Reconnected>(), isEmpty);
        expect(m.isReconnecting, isTrue);

        m.onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 2);
      });
    });

    test('a session that goes offline while its tracks are restored does not '
        'complete the reconnection; the network back starts a new attempt', () {
      fakeAsync((async) {
        final pending = host.pendingRestores['t1'] = Completer<void>();
        final m = manager(const ReconnectConfig())
          ..onRetryableLoss(
            _loss,
            snapshot(tracks: [_track('t1', media: FakeMediaTrack.video())]),
          );
        async.elapse(const Duration(milliseconds: 500));
        unawaited(m.onSessionJoined());
        async.flushMicrotasks();

        m.onNetworkLost();
        pending.complete();
        async.flushMicrotasks();
        expect(host.events.whereType<Reconnected>(), isEmpty);
        expect(host.count('releaseQueue'), 0);
        expect(m.isReconnecting, isTrue);

        m.onNetworkAvailable();
        async.flushMicrotasks();
        expect(host.count('startSession'), 2);
      });
    });

    test('offline for offlineTimeout fails the reconnection', () {
      fakeAsync((async) {
        final m = manager(offline10s)
          ..onRetryableLoss(_loss, snapshot())
          ..onNetworkLost();
        async.elapse(const Duration(milliseconds: 9999));
        expect(m.isReconnecting, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(m.state, ReconnectState.failed);
        expect(host.calls.sublist(host.calls.length - 3), [
          'clearQueue',
          'emit:ReconnectionFailed',
          'endSession:${DisconnectReason.reconnectionFailed}',
        ]);
      });
    });

    test('the network back stops the offline timeout', () {
      fakeAsync((async) {
        final m = manager(offline10s)
          ..onRetryableLoss(_loss, snapshot())
          ..onNetworkLost();
        async.elapse(const Duration(seconds: 5));
        m.onNetworkAvailable();
        async.elapse(const Duration(seconds: 30));
        expect(host.events.whereType<ReconnectionFailed>(), isEmpty);
      });
    });

    test('one reconnection makes at most 3 × maxAttempts attempts', () {
      fakeAsync((async) {
        final m = manager(const ReconnectConfig(maxAttempts: 2))
          ..onRetryableLoss(_loss, snapshot());
        // A network that keeps changing restarts the budget every time.
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(seconds: 1));
          m.onNetworkAvailable();
          async.flushMicrotasks();
          m.onRetryableLoss(_loss, snapshot());
        }
        expect(host.count('startSession'), 6);
        expect(m.state, ReconnectState.failed);
        expect(host.events.whereType<ReconnectionFailed>(), hasLength(1));
      });
    });

    test('changes outside a reconnection start nothing', () {
      fakeAsync((async) {
        final m = manager()
          ..onNetworkLost()
          ..onNetworkAvailable();
        async.elapse(const Duration(seconds: 5));
        expect(host.calls, isEmpty);

        m
          ..onRetryableLoss(_loss, snapshot())
          ..reset()
          ..onNetworkAvailable();
        async.elapse(const Duration(seconds: 5));
        expect(host.count('startSession'), 0);
      });
    });

    test('reset forgets that the device was offline', () {
      fakeAsync((async) {
        manager()
          ..onNetworkLost()
          ..reset()
          ..onRetryableLoss(_loss, snapshot());
        async.elapse(const Duration(milliseconds: 500));
        expect(host.count('startSession'), 1);
      });
    });
  });
}
