import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('metadata JSON (SPEC §2.3)', () {
    test('null is encoded as the JSON literal, never an empty string', () {
      expect(encodeMetadataJson(null), 'null');
      expect(encodeMetadataJson({'a': 1}), '{"a":1}');
    });

    test('empty string decodes to null', () {
      expect(decodeMetadataJson(''), isNull);
    });

    test('valid JSON decodes', () {
      expect(decodeMetadataJson('{"peer":{"name":"a"}}'), {
        'peer': {'name': 'a'},
      });
    });

    test('invalid JSON reports the error and decodes to null', () {
      FormatException? reported;

      expect(decodeMetadataJson('{', onError: (e) => reported = e), isNull);
      expect(reported, isNotNull);
      expect(decodeMetadataJson('{'), isNull);
    });
  });

  group('variants', () {
    test('round-trip through protobuf', () {
      for (final v in Variant.values) {
        expect(variantFromProto(variantToProto(v)), v);
      }
    });

    test('unspecified has no public variant', () {
      expect(variantFromProto(shared.Variant.VARIANT_UNSPECIFIED), isNull);
    });
  });

  group('simulcastConfigFromProto', () {
    test('missing config is disabled', () {
      expect(simulcastConfigFromProto(null), const SimulcastConfig.disabled());
    });

    test('maps variants and drops unspecified ones', () {
      final config = server.MediaEvent_Track_SimulcastConfig(
        enabled: true,
        enabledVariants: [
          shared.Variant.VARIANT_LOW,
          shared.Variant.VARIANT_UNSPECIFIED,
          shared.Variant.VARIANT_HIGH,
        ],
        disabledVariants: [shared.Variant.VARIANT_MEDIUM],
      );

      expect(
        simulcastConfigFromProto(config),
        const SimulcastConfig(
          enabled: true,
          enabledVariants: [Variant.low, Variant.high],
          disabledVariants: [Variant.medium],
        ),
      );
    });
  });
}
