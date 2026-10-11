import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'log_capture.dart';

const Map<Variant, int> _caps = {
  Variant.low: 150,
  Variant.medium: 500,
  Variant.high: 1500,
};

void main() {
  late LogCapture logs;
  late FishjamLogger logger;

  setUp(() {
    logs = LogCapture();
    logger = logs.logger;
  });

  group('unit conversion (1 kbps = 1024 bps)', () {
    test('kbpsToBps multiplies by 1024', () {
      expect(kbpsToBps(0), 0);
      expect(kbpsToBps(1), 1024);
      expect(kbpsToBps(1500), 1536000);
    });

    test('bpsToKbps divides by 1024 and rounds', () {
      expect(bpsToKbps(1024), 1);
      expect(bpsToKbps(1536000), 1500);
      expect(bpsToKbps(1535), 1);
      expect(bpsToKbps(1537), 2);
      expect(bpsToKbps(73142.857), 71);
    });
  });

  group('resolveVideoBandwidth, single stream (SPEC §13.2)', () {
    for (final (requested, expected, warns) in [
      (0, 1500, false),
      (-5, 1500, false),
      (800, 800, false),
      (1500, 1500, false),
      (1501, 1500, true),
      (8000, 1500, true),
    ]) {
      test('$requested kbps resolves to $expected', () {
        expect(
          resolveVideoBandwidth(
            BandwidthLimit.single(requested),
            simulcast: false,
            logger: logger,
          ),
          BandwidthLimit.single(expected),
        );
        expect(logs.warnings, hasLength(warns ? 1 : 0));
      });
    }

    test('a per-variant map is rejected', () {
      expect(
        () => resolveVideoBandwidth(
          const BandwidthLimit.simulcast({Variant.high: 100}),
          simulcast: false,
          logger: logger,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('non-simulcast track expects a single bandwidth limit'),
          ),
        ),
      );
    });
  });

  group('resolveVideoBandwidth, simulcast (SPEC §13.3)', () {
    for (final (name, requested, expected) in [
      ('0 uses every cap', BandwidthLimit.unlimited, _caps),
      ('negative uses every cap', const BandwidthLimit.single(-1), _caps),
      (
        '1500 is split 1:4:16',
        const BandwidthLimit.single(1500),
        {Variant.low: 71, Variant.medium: 286, Variant.high: 1143},
      ),
      (
        '2100 lets the high layer reach its cap',
        const BandwidthLimit.single(2100),
        {Variant.low: 100, Variant.medium: 400, Variant.high: 1500},
      ),
      (
        'a huge budget clamps every layer',
        const BandwidthLimit.single(100000),
        _caps,
      ),
      (
        'a map fills missing layers with caps',
        const BandwidthLimit.simulcast({Variant.high: 900}),
        {Variant.low: 150, Variant.medium: 500, Variant.high: 900},
      ),
      (
        'a map clamps layers above the cap',
        const BandwidthLimit.simulcast({
          Variant.medium: 300,
          Variant.high: 9000,
        }),
        {Variant.low: 150, Variant.medium: 300, Variant.high: 1500},
      ),
      (
        'a map with 0 or negative entries uses the caps',
        const BandwidthLimit.simulcast({
          Variant.low: 0,
          Variant.medium: -3,
          Variant.high: 1200,
        }),
        {Variant.low: 150, Variant.medium: 500, Variant.high: 1200},
      ),
      (
        'an empty map uses every cap',
        const BandwidthLimit.simulcast({}),
        _caps,
      ),
    ]) {
      test(name, () {
        final resolved = resolveVideoBandwidth(
          requested,
          simulcast: true,
          logger: logger,
        );

        expect(resolved, BandwidthLimit.simulcast(expected));
        expect(
          (resolved as SimulcastBandwidthLimit).kbpsPerVariant.keys,
          Variant.values,
          reason: 'resolved layers are ordered low, medium, high',
        );
      });
    }

    test('clamping a layer warns', () {
      resolveVideoBandwidth(
        const BandwidthLimit.simulcast({Variant.high: 9000}),
        simulcast: true,
        logger: logger,
      );

      expect(logs.warnings, hasLength(1));
    });
  });

  group('resolveTrackBandwidth', () {
    test('audio limits are applied as given', () {
      expect(
        resolveTrackBandwidth(
          const BandwidthLimit.single(5000),
          kind: MediaKind.audio,
          simulcast: false,
          logger: logger,
        ),
        const BandwidthLimit.single(5000),
      );
    });

    test('a map on an audio track is rejected', () {
      expect(
        () => resolveTrackBandwidth(
          const BandwidthLimit.simulcast({}),
          kind: MediaKind.audio,
          simulcast: false,
          logger: logger,
        ),
        throwsArgumentError,
      );
    });

    test('video limits are resolved against the caps', () {
      expect(
        resolveTrackBandwidth(
          const BandwidthLimit.single(5000),
          kind: MediaKind.video,
          simulcast: false,
          logger: logger,
        ),
        const BandwidthLimit.single(1500),
      );
      expect(
        resolveTrackBandwidth(
          BandwidthLimit.unlimited,
          kind: MediaKind.video,
          simulcast: true,
          logger: logger,
        ),
        const BandwidthLimit.simulcast(_caps),
      );
    });
  });

  group('resolveVariantBandwidth (SPEC §13.3)', () {
    for (final (variant, requested, expected) in [
      (Variant.low, 1000, 150),
      (Variant.low, 100, 100),
      (Variant.low, 0, 150),
      (Variant.medium, 9000, 500),
      (Variant.medium, -1, 500),
      (Variant.high, 1000, 1000),
      (Variant.high, 1600, 1500),
    ]) {
      test('${variant.name} $requested kbps resolves to $expected', () {
        expect(
          resolveVariantBandwidth(variant, requested, logger: logger),
          expected,
        );
      });
    }
  });

  group('splitSimulcastBudget', () {
    test('divides a budget by pixel count, ordered low, medium, high', () {
      final split = splitSimulcastBudget(1500, logger: logger);

      expect(split.keys, Variant.values);
      expect(split, {Variant.low: 71, Variant.medium: 286, Variant.high: 1143});
    });

    test('0 yields 0 for every layer', () {
      expect(splitSimulcastBudget(0, logger: logger), {
        Variant.low: 0,
        Variant.medium: 0,
        Variant.high: 0,
      });
    });
  });

  group('splitBandwidth (SPEC §13.6)', () {
    const simulcast = [
      RtpEncoding(rid: 'l', scaleResolutionDownBy: 4),
      RtpEncoding(rid: 'm', scaleResolutionDownBy: 2),
      RtpEncoding(rid: 'h'),
    ];

    test('one encoding gets the whole budget', () {
      expect(
        splitBandwidth(const [RtpEncoding()], 1500, logger: logger),
        const [RtpEncoding(maxBitrateBps: 1536000)],
      );
    });

    test('several encodings are split by (scale0 / scaleI)^2', () {
      // Relative to the first encoding (scale 4): 1 : 4 : 16.
      final split = splitBandwidth(simulcast, 2100, logger: logger);

      expect(split.map((e) => e.maxBitrateBps), [102400, 409600, 1638400]);
      expect(split.map((e) => e.rid), ['l', 'm', 'h']);
      expect(split.map((e) => e.scaleResolutionDownBy), [4, 2, null]);
    });

    test('a missing scale counts as 1', () {
      final split = splitBandwidth(
        const [RtpEncoding(), RtpEncoding(scaleResolutionDownBy: 2)],
        500,
        logger: logger,
      );

      // weights 1 : 1/4 → 400 / 100 kbps.
      expect(split.map((e) => e.maxBitrateBps), [409600, 102400]);
    });

    test('0 removes every cap', () {
      final split = splitBandwidth(
        const [
          RtpEncoding(rid: 'l', maxBitrateBps: 1),
          RtpEncoding(rid: 'h', maxBitrateBps: 2),
        ],
        0,
        logger: logger,
      );

      expect(split, const [RtpEncoding(rid: 'l'), RtpEncoding(rid: 'h')]);
    });

    test('no encodings logs an error and returns none', () {
      expect(splitBandwidth(const [], 100, logger: logger), isEmpty);
      expect(logs.errors, hasLength(1));
    });

    test('keeps the active flag', () {
      expect(
        splitBandwidth(const [RtpEncoding(active: false)], 1, logger: logger),
        const [RtpEncoding(active: false, maxBitrateBps: 1024)],
      );
    });
  });

  group('variantBitrates (SPEC §13.5)', () {
    List<(shared.Variant, int)> flat(BandwidthLimit limit, MediaKind kind) => [
      for (final v in variantBitrates(limit, kind)) (v.variant, v.bitrate),
    ];

    test('a single limit is reported in bps as VARIANT_UNSPECIFIED', () {
      expect(flat(const BandwidthLimit.single(900), MediaKind.video), [
        (shared.Variant.VARIANT_UNSPECIFIED, 921600),
      ]);
      expect(flat(const BandwidthLimit.single(64), MediaKind.audio), [
        (shared.Variant.VARIANT_UNSPECIFIED, 65536),
      ]);
    });

    test('0 reports the default per kind', () {
      expect(flat(BandwidthLimit.unlimited, MediaKind.audio), [
        (shared.Variant.VARIANT_UNSPECIFIED, 50000),
      ]);
      expect(flat(BandwidthLimit.unlimited, MediaKind.video), [
        (shared.Variant.VARIANT_UNSPECIFIED, 1536000),
      ]);
    });

    test('a map reports every variant in low, medium, high order', () {
      expect(
        flat(
          const BandwidthLimit.simulcast({
            Variant.high: 1200,
            Variant.low: 100,
            Variant.medium: 400,
          }),
          MediaKind.video,
        ),
        [
          (shared.Variant.VARIANT_LOW, 102400),
          (shared.Variant.VARIANT_MEDIUM, 409600),
          (shared.Variant.VARIANT_HIGH, 1228800),
        ],
      );
    });

    test('trackVariantBitrates uses the context limit and kind', () {
      final bitrates = trackVariantBitrates(
        const LocalTrackContext(
          trackId: 'p:t',
          kind: MediaKind.audio,
          rtcTrack: null,
          rtcStream: null,
          metadata: null,
          simulcastConfig: SimulcastConfig.disabled(),
          maxBandwidth: BandwidthLimit.unlimited,
        ),
      );

      expect(bitrates.single.bitrate, defaultAudioBitrateBps);
    });
  });
}
