import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Variant', () {
    test('rids are l, m, h', () {
      expect(Variant.values.map((v) => v.rid), ['l', 'm', 'h']);
      expect(Variant.fromRid('m'), Variant.medium);
      expect(Variant.fromRid('x'), isNull);
    });
  });

  group('SimulcastConfig', () {
    test('value equality', () {
      const all = SimulcastConfig.allVariants();
      expect(all.enabledVariants, Variant.values);
      expect(
        all.copyWith(enabledVariants: [Variant.low]),
        const SimulcastConfig(enabled: true, enabledVariants: [Variant.low]),
      );
      expect(all, isNot(const SimulcastConfig.disabled()));
      expect(
        all.copyWith(enabledVariants: [Variant.low, Variant.medium]),
        isNot(all),
      );
    });
  });

  group('BandwidthLimit', () {
    test('single and simulcast value equality', () {
      expect(const BandwidthLimit.single(10), const SingleBandwidthLimit(10));
      expect(
        BandwidthLimit.unlimited,
        isA<SingleBandwidthLimit>().having((l) => l.kbps, 'kbps', 0),
      );
      expect(
        const BandwidthLimit.simulcast({Variant.low: 1, Variant.high: 2}),
        const BandwidthLimit.simulcast({Variant.high: 2, Variant.low: 1}),
      );
      expect(
        const BandwidthLimit.simulcast({Variant.low: 1}),
        isNot(const BandwidthLimit.simulcast({Variant.low: 2})),
      );
      expect(
        const BandwidthLimit.simulcast({Variant.low: 1}),
        isNot(
          const BandwidthLimit.simulcast({Variant.low: 1, Variant.medium: 1}),
        ),
      );
      expect(
        const BandwidthLimit.simulcast({Variant.low: 1}),
        isNot(const BandwidthLimit.single(1)),
      );
    });
  });

  group('TrackMetadata', () {
    test('parses the web SDK shape', () {
      expect(
        TrackMetadata.tryParse({
          'type': 'camera',
          'paused': true,
          'displayName': 'Alice',
        }),
        const TrackMetadata(
          type: TrackType.camera,
          paused: true,
          displayName: 'Alice',
        ),
      );
      expect(
        TrackMetadata.tryParse({'type': 'microphone'}),
        const TrackMetadata(type: TrackType.microphone),
      );
    });

    test('rejects anything else', () {
      expect(TrackMetadata.tryParse(null), isNull);
      expect(TrackMetadata.tryParse('camera'), isNull);
      expect(TrackMetadata.tryParse({'type': 1}), isNull);
      expect(TrackMetadata.tryParse({'type': 'unknown'}), isNull);
      expect(TrackMetadata.tryParse({'type': 'camera', 'paused': 1}), isNull);
      expect(
        TrackMetadata.tryParse({'type': 'camera', 'displayName': 1}),
        isNull,
      );
    });

    test('serializes with wire names', () {
      const m = TrackMetadata(type: TrackType.screenShareVideo);
      expect(m.toJson(), {'type': 'screenShareVideo', 'paused': false});
      expect(m.copyWith(paused: true, displayName: 'B').toJson(), {
        'type': 'screenShareVideo',
        'paused': true,
        'displayName': 'B',
      });
      expect(
        m.copyWith(type: TrackType.customAudio).type,
        TrackType.customAudio,
      );
      expect(TrackType.fromWireName('customVideo'), TrackType.customVideo);
    });
  });

  group('track contexts', () {
    test('remote track exposes parsed metadata and readiness', () {
      const remote = RemoteTrackContext(
        trackId: 'bob:1',
        endpointId: 'bob',
        rawMetadata: {'type': 'camera', 'paused': false},
        simulcastConfig: SimulcastConfig.disabled(),
      );

      expect(remote.metadata?.type, TrackType.camera);
      expect(remote.isReady, isFalse);
      expect(remote.vadStatus, VadStatus.silence);
      final updated = remote.copyWith(
        vadStatus: VadStatus.speech,
        encoding: Variant.high,
        kind: MediaKind.video,
      );
      expect(updated.vadStatus, VadStatus.speech);
      expect(updated.encoding, Variant.high);
      expect(updated.trackId, 'bob:1');
      expect(updated.rawMetadata, remote.rawMetadata);
    });

    test('local track is muted without a media track', () {
      const local = LocalTrackContext(
        trackId: 'me:1',
        kind: MediaKind.audio,
        rtcTrack: null,
        rtcStream: null,
        metadata: null,
        simulcastConfig: SimulcastConfig.disabled(),
        maxBandwidth: BandwidthLimit.unlimited,
      );

      expect(local.isMuted, isTrue);
    });
  });

  group('Metadata.fromServerJson (SPEC §2.3)', () {
    test('splits peer and server parts', () {
      expect(
        Metadata.fromServerJson(const {
          'peer': {'name': 'a'},
          'server': {'role': 'x'},
        }),
        const Metadata(peer: {'name': 'a'}, server: {'role': 'x'}),
      );
    });

    test('anything else is peer metadata', () {
      expect(
        Metadata.fromServerJson(const {'name': 'a'}),
        const Metadata(peer: {'name': 'a'}),
      );
      expect(Metadata.fromServerJson(null), const Metadata());
    });

    test('known endpoint types', () {
      expect(peerEndpointTypes, containsAll(['webrtc', 'exwebrtc']));
      expect(componentEndpointTypes, contains('recording'));
    });
  });

  group('ReconnectConfig (SPEC §6)', () {
    test('defaults enable three attempts', () {
      const config = ReconnectConfig();
      expect(config.isEnabled, isTrue);
      expect(config.maxAttempts, 3);
      expect(config.addTracksOnReconnect, isFalse);
      expect(ReconnectConfig.disabled.isEnabled, isFalse);
    });

    test('delay of attempt n is initialDelay + (n - 1) * delay', () {
      const config = ReconnectConfig(
        initialDelay: Duration(milliseconds: 100),
        delay: Duration(milliseconds: 50),
      );
      expect(config.delayBeforeAttempt(1), const Duration(milliseconds: 100));
      expect(config.delayBeforeAttempt(3), const Duration(milliseconds: 200));
    });
  });

  group('errors', () {
    test('close reasons carry their wire strings', () {
      expect(AuthErrorReason.invalidToken.wireReason, 'invalid token');
      expect(
        JoinErrorReason.reachedPeersLimit.wireReason,
        'reached peers limit',
      );
      expect(
        SessionEndReason.replacedByNewClient.wireReason,
        'new client connected as this peer',
      );
    });

    test('only retryable closes are retryable', () {
      expect(const RetryableClose(code: 1006).isRetryable, isTrue);
      expect(
        const AuthClose(AuthErrorReason.expiredToken).isRetryable,
        isFalse,
      );
      expect(
        const JoinClose(JoinErrorReason.nodeNotFound).isRetryable,
        isFalse,
      );
      expect(
        const SessionEndedClose(SessionEndReason.roomStopped).isRetryable,
        isFalse,
      );
      expect(const ProtocolErrorClose().isRetryable, isFalse);
    });

    test('exceptions describe themselves', () {
      expect(
        AuthException(AuthErrorReason.invalidToken).toString(),
        contains('invalidToken'),
      );
      expect(
        JoinException(JoinErrorReason.nodeNotFound).message,
        contains('nodeNotFound'),
      );
      expect(
        ConnectionException(code: 1011, reason: 'x').message,
        contains('1011'),
      );
      expect(
        LivestreamException(
          LivestreamError.unauthorized,
          statusCode: 401,
        ).message,
        contains('401'),
      );
      expect(TrackTypeError().toString(), contains('audio-only'));
    });
  });
}
