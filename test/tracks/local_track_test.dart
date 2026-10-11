import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import 'log_capture.dart';

const _camera = TrackMetadata(type: TrackType.camera);
const _allVariantCaps = BandwidthLimit.simulcast({
  Variant.low: 150,
  Variant.medium: 500,
  Variant.high: 1500,
});

LocalTrack _track({
  String trackId = 'me:t1',
  MediaKind kind = MediaKind.video,
  RtcMediaTrack? track,
  bool noTrack = false,
  RtcMediaStream? stream,
  TrackMetadata? metadata = _camera,
  SimulcastConfig simulcastConfig = const SimulcastConfig.disabled(),
  BandwidthLimit? maxBandwidth,
}) => LocalTrack(
  trackId: trackId,
  kind: kind,
  track: noTrack ? null : track ?? FakeMediaTrack(kind: kind),
  stream: stream,
  metadata: metadata,
  simulcastConfig: simulcastConfig,
  maxBandwidth:
      maxBandwidth ??
      (kind == MediaKind.audio
          ? BandwidthLimit.unlimited
          : simulcastConfig.enabled
          ? _allVariantCaps
          : const BandwidthLimit.single(1500)),
);

FakeRtpSender _sender(LocalTrack t) => t.transceiver!.sender as FakeRtpSender;

List<RtpEncoding> _encodings(LocalTrack t) =>
    t.transceiver!.sender.getParameters().encodings;

void main() {
  late FakePeerConnection pc;

  setUp(() {
    pc = FakePeerConnection(const RtcConfiguration());
  });

  group('LocalTrack', () {
    test('toContext is a snapshot of the current state', () {
      final media = FakeMediaTrack.video();
      final stream = FakeMediaStream('s');
      final t = _track(track: media, stream: stream);

      final context = t.toContext();

      expect(context.trackId, 'me:t1');
      expect(context.kind, MediaKind.video);
      expect(context.rtcTrack, same(media));
      expect(context.rtcStream, same(stream));
      expect(context.metadata, _camera);
      expect(context.simulcastConfig, const SimulcastConfig.disabled());
      expect(context.maxBandwidth, const BandwidthLimit.single(1500));
      expect(context.isMuted, isFalse);
      expect(t.track, same(media));
      expect(t.negotiationStatus, TrackNegotiationStatus.pending);
      expect(t.mid, isNull);
    });

    test('metadata can be replaced', () {
      final t = _track()..metadata = null;

      expect(t.metadata, isNull);
      expect(t.toContext().metadata, isNull);
    });

    group('addToConnection (SPEC §11.1)', () {
      test('adds a sendonly transceiver with the resolved encoding', () async {
        final media = FakeMediaTrack.video();
        final t = _track(track: media, stream: FakeMediaStream('cam'));

        await t.addToConnection(pc);

        expect(pc.callsOf('addTransceiver').single.args, {
          'kind': 'video',
          'trackId': media.id,
          'direction': 'sendonly',
          'sendEncodings': [
            {'active': true, 'maxBitrate': 1536000},
          ],
          'streams': ['cam'],
        });
        expect(t.transceiver, isNotNull);
        expect(t.transceiver!.sender.track, same(media));
      });

      test('a muted track gets a transceiver of its kind', () async {
        final t = _track(kind: MediaKind.audio, noTrack: true);

        await t.addToConnection(pc);

        expect(pc.callsOf('addTransceiver').single.args, {
          'kind': 'audio',
          'direction': 'sendonly',
        });
        expect(t.transceiver!.sender.track, isNull);
      });

      test('simulcast tracks get three layers', () async {
        final t = _track(simulcastConfig: const SimulcastConfig.allVariants());

        await t.addToConnection(pc);

        expect(_encodings(t).map((e) => e.rid), ['l', 'm', 'h']);
      });
    });

    group('replaceTrack (SPEC §11.3)', () {
      test('reports mute, unmute and replace', () async {
        final first = FakeMediaTrack.video();
        final second = FakeMediaTrack.video();
        final t = _track(track: first);
        await t.addToConnection(pc);

        expect(await t.replaceTrack(null), ReplaceAction.mute);
        expect(t.track, isNull);
        expect(t.toContext().isMuted, isTrue);
        expect(await t.replaceTrack(first), ReplaceAction.unmute);
        expect(await t.replaceTrack(second), ReplaceAction.replace);
        expect(t.track, same(second));
        expect(_sender(t).track, same(second));
        expect(pc.callsOf('replaceTrack').map((c) => c.args), [
          {'from': first.id, 'to': null},
          {'from': null, 'to': first.id},
          {'from': first.id, 'to': second.id},
        ]);
      });

      test('null to null is a replace', () async {
        final t = _track(noTrack: true);
        await t.addToConnection(pc);

        expect(await t.replaceTrack(null), ReplaceAction.replace);
      });

      test('keeps the associated stream in sync', () async {
        final first = FakeMediaTrack.video();
        final second = FakeMediaTrack.video();
        final stream = FakeMediaStream();
        await stream.addTrack(first);
        final t = _track(track: first, stream: stream);
        await t.addToConnection(pc);

        await t.replaceTrack(second);
        expect(stream.tracks, [second]);

        await t.replaceTrack(null);
        expect(stream.tracks, isEmpty);
      });

      test('restores the previous track when the sender fails', () async {
        final first = FakeMediaTrack.video();
        final stream = FakeMediaStream();
        await stream.addTrack(first);
        final t = _track(track: first, stream: stream);
        await t.addToConnection(pc);
        _sender(t).failNextReplaceTrack = StateError('boom');

        await expectLater(t.replaceTrack(null), throwsStateError);

        expect(t.track, same(first));
        expect(stream.tracks, [first]);
      });

      test('without a sender only the stored track changes', () async {
        final second = FakeMediaTrack.video();
        final t = _track();

        expect(await t.replaceTrack(second), ReplaceAction.replace);
        expect(t.track, same(second));
        expect(pc.calls, isEmpty);
      });
    });

    group('setBandwidth (SPEC §13.6)', () {
      test('fails without a sender', () async {
        final t = _track();

        await expectLater(
          t.setBandwidth(const BandwidthLimit.single(100)),
          throwsStateError,
        );
      });

      test('a single limit goes to the only encoding', () async {
        final t = _track();
        await t.addToConnection(pc);

        await t.setBandwidth(const BandwidthLimit.single(800));

        expect(_encodings(t).single.maxBitrateBps, 800 * 1024);
        expect(t.maxBandwidth, const BandwidthLimit.single(800));
        expect(t.toContext().maxBandwidth, const BandwidthLimit.single(800));
      });

      test('0 removes the limit', () async {
        final t = _track();
        await t.addToConnection(pc);

        await t.setBandwidth(BandwidthLimit.unlimited);

        expect(_encodings(t).single.maxBitrateBps, isNull);
      });

      test('a sender without encodings gets one unlimited encoding', () async {
        final t = _track(kind: MediaKind.audio);
        await t.addToConnection(pc);
        await _sender(t).setParameters(const RtpSendParameters(encodings: []));

        await t.setBandwidth(const BandwidthLimit.single(64));

        expect(_encodings(t), const [RtpEncoding()]);
        expect(t.maxBandwidth, const BandwidthLimit.single(64));
      });

      test('per-layer limits go to the matching rids', () async {
        final t = _track(simulcastConfig: const SimulcastConfig.allVariants());
        await t.addToConnection(pc);
        const limit = BandwidthLimit.simulcast({
          Variant.low: 100,
          Variant.medium: 0,
          Variant.high: 900,
        });

        await t.setBandwidth(limit);

        expect(_encodings(t).map((e) => e.maxBitrateBps), [
          102400,
          null,
          921600,
        ]);
        expect(_encodings(t).map((e) => e.scaleResolutionDownBy), [4, 2, null]);
        expect(t.maxBandwidth, limit);
      });

      test('keeps the stored limit when the sender fails', () async {
        final t = _track();
        await t.addToConnection(pc);
        _sender(t).failNextSetParameters = StateError('boom');

        await expectLater(
          t.setBandwidth(const BandwidthLimit.single(100)),
          throwsStateError,
        );

        expect(t.maxBandwidth, const BandwidthLimit.single(1500));
      });
    });

    group('setEncodingBandwidth (SPEC §13.6)', () {
      test('sets the matching layer and the stored limit', () async {
        final t = _track(simulcastConfig: const SimulcastConfig.allVariants());
        await t.addToConnection(pc);

        await t.setEncodingBandwidth(Variant.medium, 300);

        expect(_encodings(t).map((e) => e.maxBitrateBps), [
          153600,
          307200,
          1536000,
        ]);
        expect(
          t.maxBandwidth,
          const BandwidthLimit.simulcast({
            Variant.low: 150,
            Variant.medium: 300,
            Variant.high: 1500,
          }),
        );
      });

      test('0 removes the layer limit', () async {
        final t = _track(simulcastConfig: const SimulcastConfig.allVariants());
        await t.addToConnection(pc);

        await t.setEncodingBandwidth(Variant.high, 0);

        expect(_encodings(t).last.maxBitrateBps, isNull);
      });

      test('a missing layer is an ArgumentError', () async {
        final t = _track();
        await t.addToConnection(pc);

        await expectLater(
          t.setEncodingBandwidth(Variant.low, 100),
          throwsArgumentError,
        );
        expect(pc.callsOf('setParameters'), isEmpty);
      });

      test('fails without a sender', () async {
        await expectLater(
          _track().setEncodingBandwidth(Variant.low, 100),
          throwsStateError,
        );
      });
    });

    group('setEncodingActive (SPEC §11.4)', () {
      test('toggles the layer and the simulcast config', () async {
        final t = _track(simulcastConfig: const SimulcastConfig.allVariants());
        await t.addToConnection(pc);

        await t.setEncodingActive(Variant.low, active: false);

        expect(_encodings(t).map((e) => e.active), [false, true, true]);
        expect(
          t.simulcastConfig,
          const SimulcastConfig(
            enabled: true,
            enabledVariants: [Variant.medium, Variant.high],
            disabledVariants: [Variant.low],
          ),
        );

        await t.setEncodingActive(Variant.low, active: true);

        expect(_encodings(t).map((e) => e.active), [true, true, true]);
        expect(
          t.toContext().simulcastConfig,
          const SimulcastConfig.allVariants(),
        );
      });

      test('a missing layer is an ArgumentError', () async {
        final t = _track();
        await t.addToConnection(pc);

        await expectLater(
          t.setEncodingActive(Variant.high, active: false),
          throwsArgumentError,
        );
      });

      test('fails without a sender', () async {
        await expectLater(
          _track().setEncodingActive(Variant.high, active: false),
          throwsStateError,
        );
      });
    });

    group('audioLevel (SPEC §18)', () {
      RtcStats stats(String type, Map<String, Object?> values) =>
          RtcStats(id: '$type-1', type: type, timestampMs: 0, values: values);

      test('null without a sender', () async {
        expect(await _track(kind: MediaKind.audio).audioLevel(), isNull);
      });

      test('the first audio media-source level', () async {
        final t = _track(kind: MediaKind.audio);
        await t.addToConnection(pc);
        _sender(t).stats = [
          stats('outbound-rtp', {'kind': 'audio'}),
          stats('media-source', {'kind': 'video'}),
          stats('media-source', {'kind': 'audio', 'audioLevel': 0.25}),
          stats('media-source', {'kind': 'audio', 'audioLevel': 0.75}),
        ];

        expect(await t.audioLevel(), 0.25);
      });

      test('integer levels are converted', () async {
        final t = _track(kind: MediaKind.audio);
        await t.addToConnection(pc);
        _sender(t).stats = [
          stats('media-source', {'kind': 'audio', 'audioLevel': 1}),
        ];

        expect(await t.audioLevel(), 1.0);
      });

      test('null without a level', () async {
        final t = _track(kind: MediaKind.audio);
        await t.addToConnection(pc);

        expect(await t.audioLevel(), isNull);
      });

      test('null when stats fail', () async {
        final t = _track(kind: MediaKind.audio)
          ..transceiver = _BrokenTransceiver();

        expect(await t.audioLevel(), isNull);
      });
    });
  });

  group('LocalTrackRegistry', () {
    late LogCapture logs;
    late List<peer.MediaEvent> sent;
    late List<FishjamEvent> events;
    late LocalTrackRegistry registry;

    setUp(() {
      logs = LogCapture();
      sent = [];
      events = [];
      registry = LocalTrackRegistry(
        logger: logs.logger,
        sendMediaEvent: sent.add,
        emit: events.add,
      )..peerId = 'me';
    });

    Future<LocalTrack> connected(LocalTrack t) async {
      registry.register(t);
      await t.addToConnection(pc);
      return t;
    }

    test('newTrackId is <peerId>:<uuid v4>', () {
      final id = registry.newTrackId();

      expect(
        id,
        matches(
          RegExp(
            '^me:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
      expect(registry.newTrackId(), isNot(id));
    });

    test('register, byId and unregister', () {
      final a = _track(trackId: 'me:a');
      final b = _track(trackId: 'me:b');

      registry
        ..register(a)
        ..register(b);

      expect(registry.tracks, [a, b]);
      expect(registry.byId('me:b'), same(b));
      expect(registry.unregister('me:a'), same(a));
      expect(registry.tracks, [b]);
    });

    test('unknown ids and duplicates are ArgumentErrors', () {
      registry.register(_track(trackId: 'me:a'));

      expect(() => registry.byId('me:x'), throwsArgumentError);
      expect(() => registry.unregister('me:x'), throwsArgumentError);
      expect(
        () => registry.register(_track(trackId: 'me:a')),
        throwsArgumentError,
      );
    });

    test('tracks is a read-only view', () {
      expect(() => registry.tracks.add(_track()), throwsUnsupportedError);
    });

    test('isPublished matches the media track id', () {
      final media = FakeMediaTrack.video();
      registry.register(_track(track: media));

      expect(registry.isPublished(media), isTrue);
      expect(registry.isPublished(FakeMediaTrack.video()), isFalse);
      expect(
        registry.isPublished(
          FakeMediaTrack(kind: MediaKind.video, id: media.id),
        ),
        isTrue,
      );
    });

    test('trackIdToMetadataJson is valid JSON, null included (SPEC §2.3)', () {
      registry
        ..register(_track(trackId: 'me:a'))
        ..register(_track(trackId: 'me:b', metadata: null));

      expect(registry.trackIdToMetadataJson(), {
        'me:a': '{"type":"camera","paused":false}',
        'me:b': 'null',
      });
    });

    test('trackIdToBitrates reports every track (SPEC §13.5)', () {
      registry
        ..register(_track(trackId: 'me:v'))
        ..register(_track(trackId: 'me:a', kind: MediaKind.audio))
        ..register(
          _track(
            trackId: 'me:s',
            simulcastConfig: const SimulcastConfig.allVariants(),
          ),
        );

      final bitrates = registry.trackIdToBitrates();

      expect(bitrates.keys, ['me:v', 'me:a', 'me:s']);
      expect(bitrates['me:v']!.trackId, 'me:v');
      expect(
        [
          for (final v in bitrates['me:v']!.variantBitrates)
            (v.variant, v.bitrate),
        ],
        [(shared.Variant.VARIANT_UNSPECIFIED, 1536000)],
      );
      expect(bitrates['me:a']!.variantBitrates.single.bitrate, 50000);
      expect(bitrates['me:s']!.variantBitrates.map((v) => v.bitrate), [
        153600,
        512000,
        1536000,
      ]);
    });

    group('midToTrackId (SPEC §10.1)', () {
      test('maps transceivers with a mid to the owning local track', () async {
        await pc.addTransceiverOfKind(
          MediaKind.video,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        final cam = await connected(_track(trackId: 'me:cam'));
        final mic = await connected(
          _track(trackId: 'me:mic', kind: MediaKind.audio),
        );
        await pc.setLocalDescription(
          const SessionDescription(type: SdpType.offer, sdp: 'x'),
        );

        final mapping = await registry.midToTrackId(await pc.getTransceivers());

        expect(mapping, {'1': 'me:cam', '2': 'me:mic'});
        expect(cam.mid, isNull, reason: 'mids are stored from answers only');
        expect(mic.mid, isNull);
        expect(logs.warnings, isEmpty);
      });

      test('ignores transceivers without a mid yet', () async {
        await connected(_track(trackId: 'me:cam'));

        expect(
          await registry.midToTrackId(await pc.getTransceivers()),
          isEmpty,
        );
      });

      test('keeps muted tracks mapped by their previous mid', () async {
        final cam = await connected(_track(trackId: 'me:cam'));
        await pc.setLocalDescription(
          const SessionDescription(type: SdpType.offer, sdp: 'x'),
        );
        registry.applyAnswerMids({'0': 'me:cam'});
        await cam.replaceTrack(null);

        expect(await registry.midToTrackId(await pc.getTransceivers()), {
          '0': 'me:cam',
        });
      });

      test('maps a track muted before its first offer by its sender', () async {
        await connected(_track(trackId: 'me:cam', noTrack: true));
        await pc.setLocalDescription(
          const SessionDescription(type: SdpType.offer, sdp: 'x'),
        );

        expect(await registry.midToTrackId(await pc.getTransceivers()), {
          '0': 'me:cam',
        });
      });

      test('skips and logs a sender track owned by no local track', () async {
        await pc.addTransceiverWithTrack(
          FakeMediaTrack.video(),
          const TransceiverInit(direction: TransceiverDirection.sendonly),
        );
        await pc.setLocalDescription(
          const SessionDescription(type: SdpType.offer, sdp: 'x'),
        );

        expect(
          await registry.midToTrackId(await pc.getTransceivers()),
          isEmpty,
        );
        expect(logs.warnings, hasLength(1));
      });
    });

    test('applyAnswerMids stores mids of local tracks only', () {
      final cam = _track(trackId: 'me:cam');
      registry
        ..register(cam)
        ..applyAnswerMids({'0': 'me:cam', '1': 'bob:cam'});

      expect(cam.mid, '0');
      expect(logs.lines, isEmpty);
    });

    test('toLocalPeer snapshots id, metadata and tracks', () {
      final cam = _track(trackId: 'me:cam');
      registry
        ..peerMetadata = {'name': 'alice'}
        ..serverMetadata = {'role': 'host'}
        ..register(cam);

      final local = registry.toLocalPeer();

      expect(local.id, 'me');
      expect(
        local.metadata,
        const Metadata(peer: {'name': 'alice'}, server: {'role': 'host'}),
      );
      expect(local.tracks.keys, ['me:cam']);
      expect(local.tracks['me:cam']!.trackId, 'me:cam');
    });

    group('replaceTrack (SPEC §11.3)', () {
      test('mute emits LocalTrackMuted, then LocalTrackReplaced', () async {
        final cam = await connected(_track(trackId: 'me:cam'));

        await registry.replaceTrack('me:cam', null);

        expect(cam.track, isNull);
        expect(sent, isEmpty);
        expect(events, [
          isA<LocalTrackMuted>().having((e) => e.trackId, 'trackId', 'me:cam'),
          isA<LocalTrackReplaced>()
              .having((e) => e.trackId, 'trackId', 'me:cam')
              .having((e) => e.rtcTrack, 'rtcTrack', isNull),
        ]);
      });

      test('unmute sends unmuteTrack before replacing, then emits', () async {
        final media = FakeMediaTrack.audio();
        final mic = _track(
          trackId: 'me:mic',
          kind: MediaKind.audio,
          noTrack: true,
        );
        await mic.addToConnection(pc);
        final replacesWhenSent = <int>[];
        final registry = LocalTrackRegistry(
          logger: logs.logger,
          sendMediaEvent: (e) {
            sent.add(e);
            replacesWhenSent.add(pc.callsOf('replaceTrack').length);
          },
          emit: events.add,
        )..register(mic);

        await registry.replaceTrack('me:mic', media);

        expect(sent.single.unmuteTrack.trackId, 'me:mic');
        expect(replacesWhenSent, [0]);
        expect(events, [
          isA<LocalTrackUnmuted>().having((e) => e.trackId, 'id', 'me:mic'),
          isA<LocalTrackReplaced>().having(
            (e) => e.rtcTrack,
            'rtcTrack',
            same(media),
          ),
        ]);
      });

      test('replace emits only LocalTrackReplaced', () async {
        final media = FakeMediaTrack.video();
        await connected(_track(trackId: 'me:cam'));

        await registry.replaceTrack('me:cam', media);

        expect(sent, isEmpty);
        expect(events, [isA<LocalTrackReplaced>()]);
      });

      test('a failed mute rolls back with LocalTrackUnmuted', () async {
        final media = FakeMediaTrack.video();
        final cam = await connected(_track(trackId: 'me:cam', track: media));
        _sender(cam).failNextReplaceTrack = StateError('boom');

        await expectLater(
          registry.replaceTrack('me:cam', null),
          throwsStateError,
        );

        expect(cam.track, same(media));
        expect(events, [isA<LocalTrackMuted>(), isA<LocalTrackUnmuted>()]);
      });

      test('a failed unmute rolls back with LocalTrackMuted', () async {
        final cam = await connected(_track(trackId: 'me:cam', noTrack: true));
        _sender(cam).failNextReplaceTrack = StateError('boom');

        await expectLater(
          registry.replaceTrack('me:cam', FakeMediaTrack.video()),
          throwsStateError,
        );

        expect(cam.track, isNull);
        expect(sent.single.hasUnmuteTrack(), isTrue);
        expect(events, [isA<LocalTrackUnmuted>(), isA<LocalTrackMuted>()]);
      });

      test('a failed replace emits nothing', () async {
        final cam = await connected(_track(trackId: 'me:cam'));
        _sender(cam).failNextReplaceTrack = StateError('boom');

        await expectLater(
          registry.replaceTrack('me:cam', FakeMediaTrack.video()),
          throwsStateError,
        );

        expect(events, isEmpty);
      });

      test('unknown id is an ArgumentError', () async {
        await expectLater(
          registry.replaceTrack('me:x', null),
          throwsArgumentError,
        );
      });
    });

    group('setTrackBandwidth (SPEC §11.5)', () {
      test('resolves, applies, reports bitrates and emits once', () async {
        final cam = await connected(_track(trackId: 'me:cam'));

        await registry.setTrackBandwidth(
          'me:cam',
          const BandwidthLimit.single(5000),
        );

        expect(_encodings(cam).single.maxBitrateBps, 1536000);
        expect(cam.maxBandwidth, const BandwidthLimit.single(1500));
        expect(sent.single.trackBitrates.trackId, 'me:cam');
        expect(
          sent.single.trackBitrates.variantBitrates.single.bitrate,
          1536000,
        );
        expect(events, hasLength(1));
        expect(
          events.single,
          isA<LocalTrackBandwidthSet>()
              .having((e) => e.trackId, 'trackId', 'me:cam')
              .having(
                (e) => e.bandwidth,
                'bandwidth',
                const BandwidthLimit.single(1500),
              ),
        );
      });

      test('audio limits are applied as given', () async {
        final mic = await connected(
          _track(trackId: 'me:mic', kind: MediaKind.audio),
        );

        await registry.setTrackBandwidth(
          'me:mic',
          const BandwidthLimit.single(64),
        );

        expect(mic.maxBandwidth, const BandwidthLimit.single(64));
        expect(sent.single.trackBitrates.variantBitrates.single.bitrate, 65536);
      });

      test('a number on a simulcast track is split per layer', () async {
        final cam = await connected(
          _track(
            trackId: 'me:cam',
            simulcastConfig: const SimulcastConfig.allVariants(),
          ),
        );

        await registry.setTrackBandwidth(
          'me:cam',
          const BandwidthLimit.single(2100),
        );

        expect(
          cam.maxBandwidth,
          const BandwidthLimit.simulcast({
            Variant.low: 100,
            Variant.medium: 400,
            Variant.high: 1500,
          }),
        );
        expect(_encodings(cam).map((e) => e.maxBitrateBps), [
          102400,
          409600,
          1536000,
        ]);
        expect(
          sent.single.trackBitrates.variantBitrates.map((v) => v.variant),
          [
            shared.Variant.VARIANT_LOW,
            shared.Variant.VARIANT_MEDIUM,
            shared.Variant.VARIANT_HIGH,
          ],
        );
      });

      test('an invalid limit sends and emits nothing', () async {
        await connected(_track(trackId: 'me:cam'));

        await expectLater(
          registry.setTrackBandwidth(
            'me:cam',
            const BandwidthLimit.simulcast({}),
          ),
          throwsArgumentError,
        );

        expect(sent, isEmpty);
        expect(events, isEmpty);
      });

      test('no sender is a StateError and sends nothing', () async {
        registry.register(_track(trackId: 'me:cam'));

        await expectLater(
          registry.setTrackBandwidth(
            'me:cam',
            const BandwidthLimit.single(100),
          ),
          throwsStateError,
        );

        expect(sent, isEmpty);
        expect(events, isEmpty);
      });

      test('unknown id is an ArgumentError', () async {
        await expectLater(
          registry.setTrackBandwidth('me:x', BandwidthLimit.unlimited),
          throwsArgumentError,
        );
      });
    });

    group('setEncodingBandwidth (SPEC §11.5)', () {
      test('clamps, reports the whole track and emits once', () async {
        final cam = await connected(
          _track(
            trackId: 'me:cam',
            simulcastConfig: const SimulcastConfig.allVariants(),
          ),
        );

        await registry.setEncodingBandwidth('me:cam', Variant.medium, 9000);

        expect(_encodings(cam)[1].maxBitrateBps, 512000);
        expect(
          [
            for (final v in sent.single.trackBitrates.variantBitrates)
              (v.variant, v.bitrate),
          ],
          [
            (shared.Variant.VARIANT_LOW, 153600),
            (shared.Variant.VARIANT_MEDIUM, 512000),
            (shared.Variant.VARIANT_HIGH, 1536000),
          ],
        );
        expect(events, hasLength(1));
        expect(
          events.single,
          isA<LocalTrackEncodingBandwidthSet>()
              .having((e) => e.trackId, 'trackId', 'me:cam')
              .having((e) => e.variant, 'variant', Variant.medium)
              .having((e) => e.kbps, 'kbps', 500),
        );
      });

      test('a track without the layer is an ArgumentError', () async {
        await connected(_track(trackId: 'me:cam'));
        await connected(_track(trackId: 'me:mic', kind: MediaKind.audio));

        await expectLater(
          registry.setEncodingBandwidth('me:cam', Variant.low, 100),
          throwsArgumentError,
        );
        await expectLater(
          registry.setEncodingBandwidth('me:mic', Variant.low, 100),
          throwsArgumentError,
        );
        expect(sent, isEmpty);
        expect(events, isEmpty);
      });

      test('unknown id is an ArgumentError', () async {
        await expectLater(
          registry.setEncodingBandwidth('me:x', Variant.low, 1),
          throwsArgumentError,
        );
      });
    });

    group('enable/disableTrackEncoding (SPEC §11.4)', () {
      test('disable sends disableTrackVariant and emits the disabled '
          'event (D3)', () async {
        final cam = await connected(
          _track(
            trackId: 'me:cam',
            simulcastConfig: const SimulcastConfig.allVariants(),
          ),
        );

        await registry.disableTrackEncoding('me:cam', Variant.low);

        expect(_encodings(cam).first.active, isFalse);
        expect(sent.single.hasDisableTrackVariant(), isTrue);
        expect(sent.single.disableTrackVariant.trackId, 'me:cam');
        expect(
          sent.single.disableTrackVariant.variant,
          shared.Variant.VARIANT_LOW,
        );
        expect(events, [
          isA<LocalTrackEncodingDisabled>()
              .having((e) => e.trackId, 'trackId', 'me:cam')
              .having((e) => e.variant, 'variant', Variant.low),
        ]);
      });

      test('enable sends enableTrackVariant and emits the enabled '
          'event', () async {
        final cam = await connected(
          _track(
            trackId: 'me:cam',
            simulcastConfig: const SimulcastConfig(
              enabled: true,
              enabledVariants: [Variant.low],
            ),
          ),
        );

        await registry.enableTrackEncoding('me:cam', Variant.high);

        expect(_encodings(cam).last.active, isTrue);
        expect(sent.single.hasEnableTrackVariant(), isTrue);
        expect(
          sent.single.enableTrackVariant.variant,
          shared.Variant.VARIANT_HIGH,
        );
        expect(events, [
          isA<LocalTrackEncodingEnabled>()
              .having((e) => e.trackId, 'trackId', 'me:cam')
              .having((e) => e.variant, 'variant', Variant.high),
        ]);
      });

      test('a missing layer is an ArgumentError and nothing is sent', () async {
        await connected(_track(trackId: 'me:cam'));

        await expectLater(
          registry.enableTrackEncoding('me:cam', Variant.low),
          throwsArgumentError,
        );
        await expectLater(
          registry.disableTrackEncoding('me:cam', Variant.low),
          throwsArgumentError,
        );
        expect(sent, isEmpty);
        expect(events, isEmpty);
      });

      test('unknown id is an ArgumentError', () async {
        await expectLater(
          registry.disableTrackEncoding('me:x', Variant.low),
          throwsArgumentError,
        );
      });
    });

    test('audioLevel is null for unknown tracks (SPEC §18)', () async {
      expect(await registry.audioLevel('me:x'), isNull);

      final mic = await connected(
        _track(trackId: 'me:mic', kind: MediaKind.audio),
      );
      _sender(mic).stats = [
        const RtcStats(
          id: 'm',
          type: 'media-source',
          timestampMs: 0,
          values: {'kind': 'audio', 'audioLevel': 0.5},
        ),
      ];

      expect(await registry.audioLevel('me:mic'), 0.5);
    });
  });
}

class _BrokenTransceiver implements RtcRtpTransceiver {
  @override
  RtcRtpSender get sender => _BrokenSender();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenSender implements RtcRtpSender {
  @override
  Future<List<RtcStats>> getStats() async => throw StateError('stats');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
