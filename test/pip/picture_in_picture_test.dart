import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _pip = MethodChannel('io.fishjam.client/pip');
const _pipEvents = EventChannel('io.fishjam.client/pip_events');
const _webrtc = MethodChannel('FlutterWebRTC.Method');
const _texture = EventChannel('FlutterWebRTC/Texture1');

class _FakeTrack extends Fake implements MediaStreamTrack {
  _FakeTrack(this.id);

  @override
  final String id;
}

class _FakeStream extends Fake implements MediaStream {
  _FakeStream(this.id, [this._videoTracks = const []]);

  @override
  final String id;
  final List<MediaStreamTrack> _videoTracks;

  @override
  String get ownerTag => 'owner';

  @override
  List<MediaStreamTrack> getVideoTracks() => _videoTracks;
}

final _camera = _FakeStream('s1', [_FakeTrack('video-1')]);

// Each wrapper carries its view's key, so removing one view (e.g. the first
// of two) does not misidentify a sibling at the same position as changed.
Widget _host(List<Widget> views) => Directionality(
  textDirection: TextDirection.ltr,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final v in views)
        SizedBox(key: v.key, width: 200, height: 100, child: v),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late List<MethodCall> webrtcCalls;
  MockStreamHandlerEventSink? events;

  Future<void> emit(WidgetTester tester, Map<String, Object> event) async {
    events!.success(event);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  List<MethodCall> callsOf(String method) =>
      calls.where((c) => c.method == method).toList();
  Map<Object?, Object?> argsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  setUp(() {
    calls = [];
    webrtcCalls = [];
    events = null;
    messenger
      ..setMockMethodCallHandler(_pip, (call) async {
        calls.add(call);
        return null;
      })
      ..setMockMethodCallHandler(_webrtc, (call) async {
        webrtcCalls.add(call);
        return call.method == 'createVideoRenderer' ? {'textureId': 1} : null;
      })
      ..setMockStreamHandler(
        _pipEvents,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            events = sink;
          },
        ),
      )
      ..setMockStreamHandler(
        _texture,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger
      ..setMockMethodCallHandler(_pip, null)
      ..setMockMethodCallHandler(_webrtc, null)
      ..setMockStreamHandler(_pipEvents, null)
      ..setMockStreamHandler(_texture, null);
  });

  group('PictureInPictureView (SPEC §20d)', () {
    testWidgets('an offered view sends update with the defaults and its rect', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            pipOptions: const PictureInPictureOptions(),
          ),
        ]),
      );
      await tester.pump();

      final update = argsOf(callsOf('update').last);
      expect(update['viewId'], isA<int>());
      expect(Map.of(update)..remove('viewId'), {
        'trackId': 'video-1',
        'rect': {'x': 0.0, 'y': 0.0, 'width': 200.0, 'height': 100.0},
        'mirror': false,
        'objectFit': 'cover',
        'startAutomatically': true,
        'stopAutomatically': true,
        'allowsCameraInBackground': false,
        'preferredSize': {'width': 1920.0, 'height': 1080.0},
        'fallbackLabel': 'No video',
        'fallbackBackgroundColor': 0xFF1C2945,
        'fallbackTextColor': 0xFFFFFFFF,
      });
    });

    testWidgets('sends every option that is set', (tester) async {
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            pipOptions: const PictureInPictureOptions(
              preferredSize: Size(16, 9),
              startAutomatically: false,
              stopAutomatically: false,
              allowsCameraInBackground: true,
            ),
          ),
        ]),
      );
      await tester.pump();

      final update = argsOf(callsOf('update').last);
      expect(update['mirror'], true);
      expect(update['objectFit'], 'contain');
      expect(update['preferredSize'], {'width': 16.0, 'height': 9.0});
      expect(update['startAutomatically'], false);
      expect(update['stopAutomatically'], false);
      expect(update['allowsCameraInBackground'], true);
    });

    testWidgets('a view without pip or with enabled: false is not offered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PictureInPictureView(mediaStream: _camera),
          PictureInPictureView(
            mediaStream: _camera,
            pipOptions: const PictureInPictureOptions(enabled: false),
          ),
        ]),
      );
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('rebuilding with the same values sends nothing new', (
      tester,
    ) async {
      Widget view() => _host([
        PictureInPictureView(
          mediaStream: _camera,
          pipOptions: const PictureInPictureOptions(),
        ),
      ]);
      await tester.pumpWidget(view());
      await tester.pump();
      final sent = calls.length;
      await tester.pumpWidget(view());
      await tester.pump();
      expect(calls.length, sent);
    });

    testWidgets('the window label and colors are sent with the update', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            pipOptions: const PictureInPictureOptions(
              fallbackLabel: 'Left',
              fallbackBackgroundColor: Color(0xFF112233),
              fallbackTextColor: Color(0xFFABCDEF),
            ),
          ),
        ]),
      );
      await tester.pump();
      final update = argsOf(callsOf('update').last);
      expect(update['fallbackLabel'], 'Left');
      expect(update['fallbackBackgroundColor'], 0xFF112233);
      expect(update['fallbackTextColor'], 0xFFABCDEF);
    });

    testWidgets('a changed value sends a new update', (tester) async {
      Widget view({required bool mirror}) => _host([
        PictureInPictureView(
          mediaStream: _camera,
          mirror: mirror,
          pipOptions: const PictureInPictureOptions(),
        ),
      ]);
      await tester.pumpWidget(view(mirror: false));
      await tester.pump();
      await tester.pumpWidget(view(mirror: true));
      await tester.pump();
      expect(argsOf(callsOf('update').last)['mirror'], true);
    });

    testWidgets('a stream without video sends a null trackId and shows the '
        'label', (tester) async {
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _FakeStream('audio-only'),
            pipOptions: const PictureInPictureOptions(fallbackLabel: 'Left'),
          ),
        ]),
      );
      await tester.pump();
      expect(argsOf(callsOf('update').last)['trackId'], isNull);
      expect(find.text('Left'), findsOneWidget);
    });

    testWidgets('two offered views each get their own id and both stay '
        'registered, like separate native controllers', (tester) async {
      final first = PictureInPictureView(
        key: const ValueKey('first'),
        mediaStream: _camera,
        pipOptions: const PictureInPictureOptions(),
      );
      final second = PictureInPictureView(
        key: const ValueKey('second'),
        mediaStream: _FakeStream('s2', [_FakeTrack('video-2')]),
        pipOptions: const PictureInPictureOptions(),
      );
      await tester.pumpWidget(_host([first]));
      await tester.pump();
      final firstId = argsOf(callsOf('update').last)['viewId'];

      await tester.pumpWidget(_host([first, second]));
      await tester.pump();
      final updates = callsOf('update').map(argsOf).toList();
      final secondUpdate = updates.lastWhere((u) => u['viewId'] != firstId);
      expect(secondUpdate['viewId'], isNot(firstId));
      expect(secondUpdate['trackId'], 'video-2');
      // The first view was not re-sent just because another one was added.
      expect(callsOf('unregister'), isEmpty);

      await tester.pumpWidget(_host([second]));
      await tester.pump();
      expect(argsOf(callsOf('unregister').single), {'viewId': firstId});

      await tester.pumpWidget(_host([]));
      await tester.pump();
    });

    testWidgets('disabling the only offered view sends unregister', (
      tester,
    ) async {
      Widget view(PictureInPictureOptions? pip) =>
          _host([PictureInPictureView(mediaStream: _camera, pipOptions: pip)]);
      await tester.pumpWidget(view(const PictureInPictureOptions()));
      await tester.pump();
      await tester.pumpWidget(
        view(const PictureInPictureOptions(enabled: false)),
      );
      await tester.pump();
      expect(callsOf('unregister'), hasLength(1));
    });
  });

  group('PictureInPictureController (SPEC §20d)', () {
    testWidgets('start and stop are sent for the offered view', (tester) async {
      final controller = PictureInPictureController();
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            controller: controller,
            pipOptions: const PictureInPictureOptions(),
          ),
        ]),
      );
      await tester.pump();
      final id = argsOf(callsOf('update').last)['viewId'];

      await controller.start();
      await controller.stop();
      expect(argsOf(callsOf('start').single), {'viewId': id});
      expect(argsOf(callsOf('stop').single), {'viewId': id});
    });

    testWidgets('start does nothing for a view that is not offered', (
      tester,
    ) async {
      final hidden = PictureInPictureController();
      final detached = PictureInPictureController();
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            pipOptions: const PictureInPictureOptions(),
          ),
          PictureInPictureView(
            mediaStream: _camera,
            controller: hidden,
            pipOptions: const PictureInPictureOptions(enabled: false),
          ),
        ]),
      );
      await tester.pump();
      await hidden.start();
      await detached.start();
      expect(callsOf('start'), isEmpty);
    });

    testWidgets('events update isActive and call onPictureInPictureChange', (
      tester,
    ) async {
      final controller = PictureInPictureController();
      final changes = <bool>[];
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            controller: controller,
            onPictureInPictureChange: changes.add,
            pipOptions: const PictureInPictureOptions(),
          ),
        ]),
      );
      await tester.pump();
      final id = argsOf(callsOf('update').last)['viewId']! as int;

      await emit(tester, {'viewId': id + 1000, 'isActive': true});
      expect(controller.isActive, isFalse);

      await emit(tester, {'viewId': id, 'isActive': true});
      expect(controller.isActive, isTrue);

      await emit(tester, {'viewId': id, 'isActive': false});
      expect(controller.isActive, isFalse);
      expect(changes, [true, false]);
    });

    testWidgets('a view that stops being offered while active becomes '
        'inactive without a callback', (tester) async {
      final controller = PictureInPictureController();
      final changes = <bool>[];
      Widget view(PictureInPictureOptions pip) => _host([
        PictureInPictureView(
          mediaStream: _camera,
          controller: controller,
          onPictureInPictureChange: changes.add,
          pipOptions: pip,
        ),
      ]);
      await tester.pumpWidget(view(const PictureInPictureOptions()));
      await tester.pump();
      final id = argsOf(callsOf('update').last)['viewId']! as int;
      await emit(tester, {'viewId': id, 'isActive': true});

      await tester.pumpWidget(
        view(const PictureInPictureOptions(enabled: false)),
      );
      await tester.pump();
      expect(controller.isActive, isFalse);
      expect(changes, [true]);
    });

    testWidgets('nothing is sent on other platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = PictureInPictureController();
      await tester.pumpWidget(
        _host([
          PictureInPictureView(
            mediaStream: _camera,
            controller: controller,
            pipOptions: const PictureInPictureOptions(),
          ),
        ]),
      );
      await tester.pump();
      await controller.start();
      await tester.pumpWidget(_host([]));
      await tester.pump();
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('PictureInPictureOptions value equality', () {
    expect(
      const PictureInPictureOptions(preferredSize: Size(1, 2)),
      const PictureInPictureOptions(preferredSize: Size(1, 2)),
    );
    expect(
      const PictureInPictureOptions().hashCode,
      const PictureInPictureOptions().hashCode,
    );
    expect(
      const PictureInPictureOptions(),
      isNot(const PictureInPictureOptions(enabled: false)),
    );
    expect(
      const PictureInPictureOptions(),
      isNot(const PictureInPictureOptions(fallbackLabel: 'Left')),
    );
  });
}
