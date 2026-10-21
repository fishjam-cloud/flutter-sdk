import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _methods = MethodChannel('test/background');
const _events = EventChannel('test/callkit_events');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function(MethodCall call) reply;

  setUp(() {
    calls = [];
    reply = (_) => null;
    messenger.setMockMethodCallHandler(_methods, (call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(_methods, null)
      ..setMockStreamHandler(_events, null);
  });

  CallKit callKit(TargetPlatform platform) => CallKit.internal(
    methodChannel: _methods,
    eventChannel: _events,
    platform: () => platform,
  );

  group('CallKit sessions (SPEC §20c)', () {
    test('startSession defaults handle to displayName', () async {
      await callKit(TargetPlatform.iOS)
          .startSession(const CallKitConfig(displayName: 'Ann', isVideo: true));
      expect(calls.single.method, 'startCallKitSession');
      expect(calls.single.arguments, {
        'displayName': 'Ann',
        'handle': 'Ann',
        'isVideo': true,
        'isDialing': false,
      });
    });

    test('startSession sends handle and isDialing', () async {
      await callKit(TargetPlatform.iOS).startSession(
        const CallKitConfig(
          displayName: 'Ann',
          handle: 'user-1',
          isVideo: false,
          isDialing: true,
        ),
      );
      expect(calls.single.arguments, {
        'displayName': 'Ann',
        'handle': 'user-1',
        'isVideo': false,
        'isDialing': true,
      });
    });

    test('an empty displayName throws without calling native code', () {
      expect(
        () => callKit(TargetPlatform.iOS)
            .startSession(const CallKitConfig(displayName: '', isVideo: false)),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });

    test('endSession sends the reason name, local by default', () async {
      final c = callKit(TargetPlatform.iOS);
      await c.endSession();
      await c.endSession(CallEndedReason.answeredElsewhere);
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('endCallKitSession', 'local'),
        ('endCallKitSession', 'answeredElsewhere'),
      ]);
    });

    test('setHeld, setMuted and reportOutgoingCallConnected', () async {
      final c = callKit(TargetPlatform.iOS);
      await c.setHeld(onHold: true);
      await c.setMuted(muted: false);
      await c.reportOutgoingCallConnected();
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('setCallKitCallHeld', true),
        ('setCallKitMuted', false),
        ('reportOutgoingCallConnected', null),
      ]);
    });

    test('hasActiveSession and isHeld read native state', () async {
      reply = (call) => call.method == 'hasActiveCallKitSession';
      final c = callKit(TargetPlatform.iOS);
      expect(await c.hasActiveSession(), isTrue);
      expect(await c.isHeld(), isFalse);
      reply = (_) => null;
      expect(await c.hasActiveSession(), isFalse);
    });
  });

  group('CallKit actions', () {
    test('native events become typed actions', () async {
      messenger.setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            sink
              ..success({'started': null})
              ..success({'unknown': 1})
              ..success({'muted': true})
              ..success({'held': false})
              ..success({'failed': 'boom'})
              ..success({'ended': 'remote'})
              ..success({'ended': 'whatever'});
          },
        ),
      );
      final actions = await callKit(TargetPlatform.iOS).actions
          .take(6)
          .toList();
      expect(actions, [
        const CallKitStarted(),
        const CallKitMuted(isMuted: true),
        const CallKitHeld(isHeld: false),
        const CallKitFailed('boom'),
        const CallKitEnded(CallEndedReason.remote),
        const CallKitEnded(CallEndedReason.local),
      ]);
    });

    test('actions value equality and toString', () {
      expect(const CallKitStarted().hashCode, const CallKitStarted().hashCode);
      expect(
        const CallKitMuted(isMuted: true),
        isNot(const CallKitMuted(isMuted: false)),
      );
      expect(
        const CallKitHeld(isHeld: true).hashCode,
        const CallKitHeld(isHeld: true).hashCode,
      );
      expect(
        const CallKitFailed('a').hashCode,
        const CallKitFailed('a').hashCode,
      );
      expect(
        const CallKitEnded(CallEndedReason.failed).hashCode,
        const CallKitEnded(CallEndedReason.failed).hashCode,
      );
      for (final action in const <CallKitAction>[
        CallKitStarted(),
        CallKitEnded(CallEndedReason.missed),
        CallKitFailed('x'),
        CallKitMuted(isMuted: true),
        CallKitHeld(isHeld: true),
      ]) {
        expect(action.toString(), startsWith('CallKit'));
      }
    });
  });

  group('on Android', () {
    test('every call is a no-op and getters return false', () async {
      final c = callKit(TargetPlatform.android);
      await c.startSession(
        const CallKitConfig(displayName: 'A', isVideo: true),
      );
      await c.endSession();
      await c.setHeld(onHold: true);
      await c.setMuted(muted: true);
      await c.reportOutgoingCallConnected();
      expect(await c.hasActiveSession(), isFalse);
      expect(await c.isHeld(), isFalse);
      expect(await c.actions.isEmpty, isTrue);
      expect(calls, isEmpty);
    });
  });

  test('instance is a single shared CallKit', () {
    expect(CallKit.instance, same(CallKit.instance));
  });
}
