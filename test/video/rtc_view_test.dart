import 'package:fishjam_client/src/video/rtc_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class _VideoTrack extends MediaStreamTrack {
  _VideoTrack(this._id, this._settings);

  final String _id;
  final Map<String, dynamic> _settings;

  @override
  String? get id => _id;

  @override
  String? get label => 'camera';

  @override
  String? get kind => 'video';

  @override
  bool get enabled => true;

  @override
  set enabled(bool b) {}

  @override
  bool? get muted => false;

  @override
  Map<String, dynamic> getSettings() => _settings;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _Stream extends MediaStream {
  _Stream(this.tracks) : super('stream', 'local');

  final List<MediaStreamTrack> tracks;

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(
    MediaStreamTrack track, {
    bool addToNative = true,
  }) async {}

  @override
  Future<void> removeTrack(
    MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async {}

  @override
  List<MediaStreamTrack> getTracks() => tracks;

  @override
  List<MediaStreamTrack> getAudioTracks() => const [];

  @override
  List<MediaStreamTrack> getVideoTracks() => tracks;

  @override
  Future<void> getMediaTracks() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const webrtc = MethodChannel('FlutterWebRTC.Method');

  setUp(() {
    resetVideoPreview();
    videoPreviewIsAndroid = () => true;
  });

  tearDown(resetVideoPreview);

  test(
    'selectCamera pauses, switches the open camera, then mirror resumes',
    () async {
      final events = <String>[];
      final current = _Stream([
        _VideoTrack('old', {'deviceId': 'front'}),
      ]);
      openCamera = (deviceId) async {
        events.add('open $deviceId');
        return _Stream(const []);
      };
      switchVideoCamera = (track) async {
        events.add('switch ${track.id}');
        return false;
      };
      sendVideoPaused = ({required textureId, required paused}) async {
        events.add('${paused ? 'pause' : 'resume'} $textureId');
      };
      sendVideoMirror = ({required textureId, required mirror}) async {
        events.add('mirror $textureId $mirror');
      };
      registerVideoPreview(textureId: 4, shows: (track) => track.id == 'old');

      final stream = await selectCamera('back', current: current);
      expect(stream, same(current));
      expect(events, ['pause 4', 'switch old']);

      await applyVideoMirror(4, mirror: false);
      expect(events, ['pause 4', 'switch old', 'mirror 4 false', 'resume 4']);
    },
  );

  test('selecting the camera already in use does nothing', () async {
    var opened = 0;
    openCamera = (deviceId) async {
      opened += 1;
      return _Stream(const []);
    };
    final current = _Stream([
      _VideoTrack('old', {'deviceId': 'front'}),
    ]);

    final stream = await selectCamera('front', current: current);
    expect(stream, same(current));
    expect(opened, 0);
  });

  test('a failed switch resumes drawing', () async {
    final events = <String>[];
    switchVideoCamera = (track) async => throw StateError('camera');
    sendVideoPaused = ({required textureId, required paused}) async {
      events.add(paused ? 'pause' : 'resume');
    };
    registerVideoPreview(textureId: 4, shows: (_) => true);
    final current = _Stream([
      _VideoTrack('old', {'deviceId': 'front'}),
    ]);

    await expectLater(
      selectCamera('back', current: current),
      throwsA(isA<StateError>()),
    );
    expect(events, ['pause', 'resume']);
  });

  test('selectCamera opens a camera when none is running', () async {
    final opened = _Stream([
      _VideoTrack('new', {'deviceId': 'back'}),
    ]);
    openCamera = (deviceId) async {
      expect(deviceId, 'back');
      return opened;
    };

    expect(await selectCamera('back'), same(opened));
  });

  test('an empty device id does not open a camera', () async {
    var opened = 0;
    openCamera = (deviceId) async {
      opened += 1;
      return _Stream(const []);
    };

    await expectLater(selectCamera(''), throwsArgumentError);
    expect(opened, 0);
  });

  test('cameraDevices keeps video inputs only', () async {
    enumerateCameras = () async => [
      MediaDeviceInfo(deviceId: 'mic', kind: 'audioinput', label: 'Mic'),
      MediaDeviceInfo(deviceId: 'back', kind: 'videoinput', label: 'Back'),
    ];

    final cameras = await cameraDevices();
    expect(cameras.map((device) => device.deviceId), ['back']);
    expect(cameras.single.label, 'Back');
  });

  testWidgets('Android does not mirror with a widget transform', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(webrtc, (
      call,
    ) async {
      if (call.method == 'createVideoRenderer') return {'textureId': 3};
      return null;
    });
    sendVideoMirror = ({required textureId, required mirror}) async {
      calls.add(
        MethodCall('setMirror', {'textureId': textureId, 'mirror': mirror}),
      );
    };
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        webrtc,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RTCView(mediaStream: null, mirror: true)),
    );
    await tester.pump();

    expect(find.byType(RTCVideoView), findsOneWidget);
    expect(
      tester.widget<RTCVideoView>(find.byType(RTCVideoView)).mirror,
      isFalse,
    );
    expect(calls.single.arguments, {'textureId': 3, 'mirror': true});
  });

  testWidgets('iOS mirrors with the view transform', (tester) async {
    videoPreviewIsAndroid = () => false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(webrtc, (
      call,
    ) async {
      if (call.method == 'createVideoRenderer') return {'textureId': 3};
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        webrtc,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RTCView(mediaStream: null, mirror: true)),
    );
    await tester.pump();

    expect(
      tester.widget<RTCVideoView>(find.byType(RTCVideoView)).mirror,
      isTrue,
    );
  });
}
