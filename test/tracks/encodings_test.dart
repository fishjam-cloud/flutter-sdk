import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/encodings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';

void main() {
  group('sendTransceiverInit (SPEC §11.1, §12)', () {
    test('audio: sendonly, the stream, no encodings', () {
      final stream = FakeMediaStream('s');

      final init = sendTransceiverInit(
        kind: MediaKind.audio,
        simulcastConfig: const SimulcastConfig.disabled(),
        maxBandwidth: BandwidthLimit.unlimited,
        stream: stream,
      );

      expect(init.direction, TransceiverDirection.sendonly);
      expect(init.sendEncodings, isEmpty);
      expect(init.streams, [stream]);
    });

    test('audio ignores a simulcast config', () {
      final init = sendTransceiverInit(
        kind: MediaKind.audio,
        simulcastConfig: const SimulcastConfig.allVariants(),
        maxBandwidth: const BandwidthLimit.single(64),
      );

      expect(init.sendEncodings, isEmpty);
      expect(init.streams, isEmpty);
    });

    test('video: one active encoding with maxBitrate in bps', () {
      final init = sendTransceiverInit(
        kind: MediaKind.video,
        simulcastConfig: const SimulcastConfig.disabled(),
        maxBandwidth: const BandwidthLimit.single(1500),
      );

      expect(init.direction, TransceiverDirection.sendonly);
      expect(init.sendEncodings, const [RtpEncoding(maxBitrateBps: 1536000)]);
    });

    test('video with limit 0: one active encoding without maxBitrate', () {
      final init = sendTransceiverInit(
        kind: MediaKind.video,
        simulcastConfig: const SimulcastConfig.disabled(),
        maxBandwidth: BandwidthLimit.unlimited,
      );

      expect(init.sendEncodings, const [RtpEncoding()]);
    });

    test('simulcast video: l/m/h, scales 4/2/1, active per enabled '
        'variants, limits per layer', () {
      final stream = FakeMediaStream('cam');

      final init = sendTransceiverInit(
        kind: MediaKind.video,
        simulcastConfig: const SimulcastConfig(
          enabled: true,
          enabledVariants: [Variant.low, Variant.high],
        ),
        maxBandwidth: const BandwidthLimit.simulcast({
          Variant.low: 150,
          Variant.medium: 500,
          Variant.high: 1200,
        }),
        stream: stream,
      );

      expect(init.direction, TransceiverDirection.sendonly);
      expect(init.streams, [stream]);
      expect(init.sendEncodings, const [
        RtpEncoding(rid: 'l', maxBitrateBps: 153600, scaleResolutionDownBy: 4),
        RtpEncoding(
          rid: 'm',
          active: false,
          maxBitrateBps: 512000,
          scaleResolutionDownBy: 2,
        ),
        RtpEncoding(rid: 'h', maxBitrateBps: 1228800),
      ]);
    });

    test('simulcast layer limit 0 leaves maxBitrate unset', () {
      final init = sendTransceiverInit(
        kind: MediaKind.video,
        simulcastConfig: const SimulcastConfig.allVariants(),
        maxBandwidth: const BandwidthLimit.simulcast({Variant.high: 0}),
      );

      expect(init.sendEncodings.map((e) => e.maxBitrateBps), [
        null,
        null,
        null,
      ]);
    });

    test('an unresolved limit of the wrong shape is rejected', () {
      expect(
        () => sendTransceiverInit(
          kind: MediaKind.video,
          simulcastConfig: const SimulcastConfig.allVariants(),
          maxBandwidth: const BandwidthLimit.single(100),
        ),
        throwsArgumentError,
      );
      expect(
        () => sendTransceiverInit(
          kind: MediaKind.video,
          simulcastConfig: const SimulcastConfig.disabled(),
          maxBandwidth: const BandwidthLimit.simulcast({}),
        ),
        throwsArgumentError,
      );
    });
  });

  group('applySimulcastLimits (SPEC §13.6)', () {
    test('sets maxBitrate per rid and clears it for 0 or missing', () {
      final applied = applySimulcastLimits(
        const [
          RtpEncoding(rid: 'l', maxBitrateBps: 1, scaleResolutionDownBy: 4),
          RtpEncoding(rid: 'm', active: false, maxBitrateBps: 1),
          RtpEncoding(rid: 'h', maxBitrateBps: 1),
        ],
        const {Variant.low: 100, Variant.medium: 0},
      );

      expect(applied, const [
        RtpEncoding(rid: 'l', maxBitrateBps: 102400, scaleResolutionDownBy: 4),
        RtpEncoding(rid: 'm', active: false),
        RtpEncoding(rid: 'h'),
      ]);
    });

    test('leaves encodings without a rid untouched', () {
      expect(
        applySimulcastLimits(
          const [RtpEncoding(maxBitrateBps: 7)],
          const {Variant.high: 100},
        ),
        const [RtpEncoding(maxBitrateBps: 7)],
      );
    });
  });
}
