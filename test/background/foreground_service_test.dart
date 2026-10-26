import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _methods = MethodChannel('test/background');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(_methods, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_methods, null));

  ForegroundService service(TargetPlatform platform) =>
      ForegroundService.internal(
        methodChannel: _methods,
        platform: () => platform,
      );

  group('ForegroundService (SPEC §20c)', () {
    test('start sends the defaults and omits unset strings', () async {
      await service(TargetPlatform.android)
          .start(const ForegroundServiceConfig());
      expect(calls.single.method, 'startForegroundService');
      expect(calls.single.arguments, {
        'enableCamera': false,
        'enableMicrophone': false,
        'enableScreenSharing': false,
        'importance': 'high',
        'onlyAlertOnce': false,
      });
    });

    test('start sends every field that is set', () async {
      await service(TargetPlatform.android).start(
        const ForegroundServiceConfig(
          enableCamera: true,
          enableMicrophone: true,
          enableScreenSharing: true,
          channelId: 'id',
          channelName: 'name',
          notificationTitle: 'title',
          notificationContent: 'content',
          importance: ForegroundServiceImportance.low,
          onlyAlertOnce: true,
        ),
      );
      expect(calls.single.arguments, {
        'enableCamera': true,
        'enableMicrophone': true,
        'enableScreenSharing': true,
        'channelId': 'id',
        'channelName': 'name',
        'notificationTitle': 'title',
        'notificationContent': 'content',
        'importance': 'low',
        'onlyAlertOnce': true,
      });
    });

    test('stop sends stopForegroundService', () async {
      await service(TargetPlatform.android).stop();
      expect(calls.single.method, 'stopForegroundService');
    });

    test('is a no-op on iOS', () async {
      final s = service(TargetPlatform.iOS);
      await s.start(const ForegroundServiceConfig(enableMicrophone: true));
      await s.stop();
      expect(calls, isEmpty);
    });

    test('instance is a single shared service', () {
      expect(ForegroundService.instance, same(ForegroundService.instance));
    });
  });
}
