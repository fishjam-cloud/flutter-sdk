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

  @override
  Future<void> startSession(Object? peerMetadata) async {
    calls.add('startSession');
    startedWith.add(peerMetadata);
  }

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

// maxAttempts 3, initialDelay 500 ms (the defaults), delay 300 ms.
const _config = ReconnectConfig(delay: Duration(milliseconds: 300));

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
        expect(host.count('emit:Reconnected'), 1);
      });
    });

    test('restores live tracks in order, skips ended and muted ones, '
        'survives failures, then releases the queue and emits '
        'Reconnected', () {
      fakeAsync((async) {
        final ended = FakeMediaTrack.video()..end();
        final m = manager(const ReconnectConfig(addTracksOnReconnect: true))
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

        // The queue stays held until every restore settled.
        expect(host.calls.last, 'restoreTrack:cam');
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
        expect(host.restored, ['cam', 'mic']);
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
        final m = manager(const ReconnectConfig(addTracksOnReconnect: true))
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

        expect(host.count('restoreTrack:mic'), 0);
        expect(host.count('emit:Reconnected'), 0);
        expect(host.count('releaseQueue'), 0);
        expect(m.isReconnecting, isTrue);

        async.elapse(const Duration(milliseconds: 1000));
        expect(host.count('startSession'), 2);
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
        final m = manager(const ReconnectConfig(addTracksOnReconnect: true))
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
}
