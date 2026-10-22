import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _methods = MethodChannel('test/audio_output');
const _events = EventChannel('test/audio_output_events');

const _speakerMap = {
  'type': 'speaker',
  'nativeType': 'builtInSpeaker',
  'name': 'Speaker',
  'id': 'speaker',
};
const _headsetMap = {
  'type': 'bluetooth',
  'nativeType': 'bluetoothHFP',
  'name': 'AirPods',
  'id': 'uid-1',
};
const _speaker = AudioDevice(
  type: AudioDeviceType.speaker,
  nativeType: 'builtInSpeaker',
  name: 'Speaker',
  id: 'speaker',
);
const _headset = AudioDevice(
  type: AudioDeviceType.bluetooth,
  nativeType: 'bluetoothHFP',
  name: 'AirPods',
  id: 'uid-1',
);

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

  AudioOutputManager manager(TargetPlatform platform) =>
      AudioOutputManager.internal(
        methodChannel: _methods,
        eventChannel: _events,
        platform: () => platform,
      );

  group('AudioDevice (SPEC §20b)', () {
    test('parses every type name', () {
      for (final type in AudioDeviceType.values) {
        final device = AudioDevice.fromMap({
          'type': type.name,
          'nativeType': 'x',
          'name': 'n',
          'id': 'i',
        });
        expect(device.type, type);
      }
    });

    test('an unknown type or missing fields fall back', () {
      final device = AudioDevice.fromMap(const {'type': 'streaming', 'id': 7});
      expect(device.type, AudioDeviceType.unknown);
      expect(device.nativeType, '');
      expect(device.name, '');
      expect(device.id, '7');
    });

    test('value equality and toString', () {
      expect(AudioDevice.fromMap(_speakerMap), _speaker);
      expect(AudioDevice.fromMap(_speakerMap).hashCode, _speaker.hashCode);
      expect(_speaker, isNot(_headset));
      expect(_speaker.toString(), contains('speaker'));
    });
  });

  group('reading the state', () {
    test('getAvailableAudioOutputs parses the list', () async {
      reply = (_) => [_speakerMap, _headsetMap];
      final devices = await manager(TargetPlatform.iOS)
          .getAvailableAudioOutputs();
      expect(devices, [_speaker, _headset]);
      expect(calls.single.method, 'getAvailableAudioOutputs');
    });

    test('getAvailableAudioOutputs treats null as empty', () async {
      final devices = await manager(TargetPlatform.android)
          .getAvailableAudioOutputs();
      expect(devices, isEmpty);
    });

    test('getCurrentAudioOutput parses the device or null', () async {
      reply = (_) => _headsetMap;
      expect(
        await manager(TargetPlatform.iOS).getCurrentAudioOutput(),
        _headset,
      );
      reply = (_) => null;
      expect(await manager(TargetPlatform.iOS).getCurrentAudioOutput(), isNull);
    });

    test('onAudioOutputChanged parses native events', () async {
      messenger.setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            sink
              ..success({
                'currentAudioOutput': _headsetMap,
                'availableAudioOutputs': [_speakerMap, _headsetMap],
              })
              ..success({
                'currentAudioOutput': null,
                'availableAudioOutputs': null,
              });
          },
        ),
      );
      final infos = await manager(TargetPlatform.android).onAudioOutputChanged
          .take(2)
          .toList();
      expect(infos[0].currentAudioOutput, _headset);
      expect(infos[0].availableAudioOutputs, [_speaker, _headset]);
      expect(infos[1].currentAudioOutput, isNull);
      expect(infos[1].availableAudioOutputs, isEmpty);
    });
  });

  group('iOS controls', () {
    test('overrideAudioOutput sends the override name', () async {
      final m = manager(TargetPlatform.iOS);
      await m.ios.overrideAudioOutput(IosAudioOutputOverride.speaker);
      await m.ios.overrideAudioOutput(IosAudioOutputOverride.none);
      expect(calls.map((c) => (c.method, c.arguments)), [
        ('overrideAudioOutput', 'speaker'),
        ('overrideAudioOutput', 'none'),
      ]);
    });

    test('showAudioRoutePicker calls native code', () async {
      await manager(TargetPlatform.iOS).ios.showAudioRoutePicker();
      expect(calls.single.method, 'showAudioRoutePicker');
    });

    test('throw UnsupportedError on Android without calling native code', () {
      final m = manager(TargetPlatform.android);
      expect(
        () => m.ios.overrideAudioOutput(IosAudioOutputOverride.speaker),
        throwsUnsupportedError,
      );
      expect(m.ios.showAudioRoutePicker, throwsUnsupportedError);
      expect(calls, isEmpty);
    });
  });

  group('Android controls', () {
    test('selectAudioOutput sends the device id', () async {
      await manager(TargetPlatform.android).android.selectAudioOutput('12');
      expect(calls.single.method, 'selectAudioOutput');
      expect(calls.single.arguments, '12');
    });

    test('throws UnsupportedError on iOS without calling native code', () {
      expect(
        () => manager(TargetPlatform.iOS).android.selectAudioOutput('12'),
        throwsUnsupportedError,
      );
      expect(calls, isEmpty);
    });

    test('native error codes become AudioOutputException', () async {
      const codes = {
        'E_AUDIO_OUTPUT_SELECT': AudioOutputErrorCode.select,
        'E_AUDIO_OUTPUT_SUPERSEDED': AudioOutputErrorCode.superseded,
        'E_AUDIO_OUTPUT_TIMEOUT': AudioOutputErrorCode.timeout,
        'E_AUDIO_OUTPUT_CANCELLED': AudioOutputErrorCode.cancelled,
        'E_AUDIO_OUTPUT_INVALID': AudioOutputErrorCode.invalid,
        'E_AUDIO_OUTPUT_OVERRIDE': AudioOutputErrorCode.override,
        'something else': AudioOutputErrorCode.unknown,
      };
      final m = manager(TargetPlatform.android);
      for (final MapEntry(key: native, value: code) in codes.entries) {
        reply = (_) => throw PlatformException(code: native, message: 'msg');
        await expectLater(
          m.android.selectAudioOutput('1'),
          throwsA(
            isA<AudioOutputException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', contains('msg')),
          ),
        );
      }
    });

    test('errors of the reading calls are mapped too', () async {
      reply = (_) => throw PlatformException(code: 'E_AUDIO_OUTPUT_SELECT');
      await expectLater(
        manager(TargetPlatform.iOS).getCurrentAudioOutput(),
        throwsA(isA<AudioOutputException>()),
      );
    });
  });

  group('communication mode (internal)', () {
    test('calls native code on Android', () async {
      final m = manager(TargetPlatform.android);
      await m.enterCommunicationMode();
      await m.exitCommunicationMode();
      expect(calls.map((c) => c.method), [
        'enterCommunicationMode',
        'exitCommunicationMode',
      ]);
    });

    test('calls native code on iOS', () async {
      final m = manager(TargetPlatform.iOS);
      await m.enterCommunicationMode();
      await m.exitCommunicationMode();
      expect(calls.map((c) => c.method), [
        'enterCommunicationMode',
        'exitCommunicationMode',
      ]);
    });
  });

  test('instance is a single shared manager', () {
    expect(AudioOutputManager.instance, same(AudioOutputManager.instance));
  });
}
