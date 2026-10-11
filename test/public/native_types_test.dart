// Values are built with `new` on purpose so constructors run at test time.
// ignore_for_file: prefer_const_constructors

import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

import '../fakes/fake_rtc.dart';
import 'native_fakes.dart';

void main() {
  final nativeTrack = NativeTrack('cam', 'video');
  final nativeStream = NativeStream('s');

  group('adapter boundary helpers', () {
    test('wrap and unwrap native tracks and streams', () {
      final wrapped = wrapNativeTrack(nativeTrack);

      expect(wrapped.id, 'cam');
      expect(wrapped.kind, MediaKind.video);
      expect(nativeTrackOf(wrapped), same(nativeTrack));
      expect(
        nativeStreamOf(wrapNativeStream(nativeStream)),
        same(nativeStream),
      );
    });

    test('non-native values unwrap to null', () {
      expect(nativeTrackOf(FakeMediaTrack.video()), isNull);
      expect(nativeTrackOf(null), isNull);
      expect(nativeStreamOf(FakeMediaStream()), isNull);
      expect(nativeStreamOf(null), isNull);
    });
  });

  group('public contexts expose flutter_webrtc types', () {
    test('local track context', () {
      final context = LocalTrackContext(
        trackId: 'me:1',
        kind: MediaKind.video,
        rtcTrack: wrapNativeTrack(nativeTrack),
        rtcStream: wrapNativeStream(nativeStream),
        metadata: null,
        simulcastConfig: SimulcastConfig.disabled(),
        maxBandwidth: BandwidthLimit.unlimited,
      );

      expect(context.track, isA<webrtc.MediaStreamTrack>());
      expect(context.track, same(nativeTrack));
      expect(context.stream, same(nativeStream));
      expect(context.isMuted, isFalse);
    });

    test('remote track context', () {
      final context = RemoteTrackContext(
        trackId: 'bob:1',
        endpointId: 'bob',
        rawMetadata: null,
        simulcastConfig: SimulcastConfig.disabled(),
        rtcTrack: wrapNativeTrack(nativeTrack),
        rtcStream: wrapNativeStream(nativeStream),
      );

      expect(context.track, same(nativeTrack));
      expect(context.stream, same(nativeStream));
      expect(context.isReady, isTrue);
    });

    test('contexts built from fakes have no native objects but keep state', () {
      final context = RemoteTrackContext(
        trackId: 'bob:1',
        endpointId: 'bob',
        rawMetadata: null,
        simulcastConfig: SimulcastConfig.disabled(),
        rtcTrack: FakeMediaTrack.audio(),
      );

      expect(context.track, isNull);
      expect(context.isReady, isTrue);
      expect(context.copyWith(vadStatus: VadStatus.speech).rtcTrack, isNotNull);
    });

    test('LocalTrackReplaced exposes the native track', () {
      final event = LocalTrackReplaced('me:1', wrapNativeTrack(nativeTrack));

      expect(event.track, same(nativeTrack));
      expect(LocalTrackReplaced('me:1', null).track, isNull);
    });
  });
}
