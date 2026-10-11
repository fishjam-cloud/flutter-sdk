import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import 'log_capture.dart';

const _cameraJson = '{"type":"camera","paused":false}';
const _micJson = '{"type":"microphone","paused":false}';

server.MediaEvent_Track _simulcastTrack([String metadata = _cameraJson]) =>
    server.MediaEvent_Track(
      metadataJson: metadata,
      simulcastConfig: server.MediaEvent_Track_SimulcastConfig(
        enabled: true,
        enabledVariants: [
          shared.Variant.VARIANT_LOW,
          shared.Variant.VARIANT_MEDIUM,
          shared.Variant.VARIANT_HIGH,
        ],
      ),
    );

server.MediaEvent_Track _plainTrack([String metadata = _micJson]) =>
    server.MediaEvent_Track(metadataJson: metadata);

server.MediaEvent_Endpoint _endpoint(
  String type, {
  String metadata = '{"peer":{"name":"x"},"server":{}}',
  Map<String, server.MediaEvent_Track> tracks = const {},
}) => server.MediaEvent_Endpoint(
  endpointType: type,
  metadataJson: metadata,
  trackIdToTrack: tracks.entries,
);

void main() {
  late LogCapture logs;
  late List<FishjamEvent> events;
  late List<peer.MediaEvent> sent;
  late RemoteStore store;

  setUp(() {
    logs = LogCapture();
    events = [];
    sent = [];
    store = RemoteStore(
      logger: logs.logger,
      emit: events.add,
      sendMediaEvent: sent.add,
    );
  });

  void connect([Map<String, server.MediaEvent_Endpoint> others = const {}]) {
    store.loadConnected(
      server.MediaEvent_Connected(
        endpointId: 'me',
        endpointIdToEndpoint: {
          'me': _endpoint('exwebrtc', tracks: {'me:cam': _plainTrack()}),
          ...others,
        }.entries,
      ),
      'me',
    );
  }

  void addBob() {
    connect({'bob': _endpoint('exwebrtc')});
  }

  void addBobTracks() {
    addBob();
    store.tracksAdded(
      server.MediaEvent_TracksAdded(
        endpointId: 'bob',
        trackIdToTrack: {
          'bob:cam': _simulcastTrack(),
          'bob:mic': _plainTrack(),
        }.entries,
      ),
    );
    events.clear();
  }

  group('loadConnected (SPEC §14.1)', () {
    test('loads peers and components with tracks, skipping the local '
        'peer, and emits nothing', () {
      connect({
        'bob': _endpoint(
          'webrtc',
          metadata: '{"peer":{"name":"bob"},"server":{"id":1}}',
          tracks: {'bob:cam': _simulcastTrack()},
        ),
        'rec': _endpoint('recording', metadata: ''),
        'carol': _endpoint('exwebrtc'),
        'hls': _endpoint('hls'),
      });

      expect(events, isEmpty);
      expect(store.peers.map((p) => p.id), ['bob', 'carol']);
      expect(store.components.map((c) => c.id), ['rec', 'hls']);
      final bob = store.peers.first;
      expect(bob.type, 'webrtc');
      expect(
        bob.metadata,
        const Metadata(peer: {'name': 'bob'}, server: {'id': 1}),
      );
      expect(bob.tracks.keys, ['bob:cam']);
      final rec = store.components.first;
      expect(rec.type, 'recording');
      expect(rec.metadata, const Metadata());
      expect(store.tracks.keys, ['bob:cam']);
      final cam = store.tracks['bob:cam']!;
      expect(cam.endpointId, 'bob');
      expect(cam.metadata, const TrackMetadata(type: TrackType.camera));
      expect(cam.simulcastConfig, const SimulcastConfig.allVariants());
      expect(cam.isReady, isFalse);
      expect(cam.vadStatus, VadStatus.silence);
    });

    test('ignores endpoints of unknown types, including their tracks', () {
      connect({
        'odd': _endpoint('teapot', tracks: {'odd:t': _plainTrack()}),
      });

      expect(store.peers, isEmpty);
      expect(store.components, isEmpty);
      expect(store.tracks, isEmpty);
      expect(logs.debugs, isNotEmpty);
    });

    test('undecodable metadata is logged and treated as null', () {
      connect({'bob': _endpoint('exwebrtc', metadata: '{')});

      expect(store.peers.single.metadata, const Metadata());
      expect(logs.warnings, isNotEmpty);
    });

    test('a second snapshot replaces the first', () {
      addBob();
      connect({'carol': _endpoint('exwebrtc')});

      expect(store.peers.map((p) => p.id), ['carol']);
    });
  });

  group('endpoints (SPEC §14.1)', () {
    test('endpointAdded emits PeerJoined with an exwebrtc peer', () {
      connect();

      store.endpointAdded(
        server.MediaEvent_EndpointAdded(
          endpointId: 'bob',
          metadataJson: '{"peer":{"name":"bob"},"server":null}',
        ),
      );

      final joined = events.single as PeerJoined;
      expect(joined.peer.id, 'bob');
      expect(joined.peer.type, 'exwebrtc');
      expect(joined.peer.metadata, const Metadata(peer: {'name': 'bob'}));
      expect(joined.peer.tracks, isEmpty);
      expect(store.peers.single.id, 'bob');
    });

    test('endpointAdded for the local peer or a known endpoint is '
        'ignored', () {
      addBob();

      store
        ..endpointAdded(server.MediaEvent_EndpointAdded(endpointId: 'me'))
        ..endpointAdded(server.MediaEvent_EndpointAdded(endpointId: 'bob'));

      expect(events, isEmpty);
      expect(store.peers.map((p) => p.id), ['bob']);
    });

    test('endpointUpdated stores metadata and emits PeerUpdated', () {
      addBob();

      store.endpointUpdated(
        server.MediaEvent_EndpointUpdated(
          endpointId: 'bob',
          metadataJson: '{"peer":{"name":"robert"},"server":{}}',
        ),
      );

      final updated = events.single as PeerUpdated;
      expect(updated.peer.metadata.peer, {'name': 'robert'});
      expect(store.peers.single.metadata.peer, {'name': 'robert'});
    });

    test('endpointUpdated of a component emits ComponentUpdated', () {
      connect({'rec': _endpoint('recording')});

      store.endpointUpdated(
        server.MediaEvent_EndpointUpdated(
          endpointId: 'rec',
          metadataJson: '{"peer":1,"server":2}',
        ),
      );

      final updated = events.single as ComponentUpdated;
      expect(updated.component.metadata, const Metadata(peer: 1, server: 2));
    });

    test('endpointUpdated for unknown or local endpoints is ignored', () {
      connect();

      store
        ..endpointUpdated(server.MediaEvent_EndpointUpdated(endpointId: 'x'))
        ..endpointUpdated(server.MediaEvent_EndpointUpdated(endpointId: 'me'));

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(1));
    });

    test('endpointRemoved emits TrackRemoved per track, then PeerLeft', () {
      addBobTracks();

      store.endpointRemoved(
        server.MediaEvent_EndpointRemoved(endpointId: 'bob'),
      );

      expect(events.map((e) => e.runtimeType), [
        TrackRemoved,
        TrackRemoved,
        PeerLeft,
      ]);
      expect((events[0] as TrackRemoved).track.trackId, 'bob:cam');
      expect((events[1] as TrackRemoved).track.trackId, 'bob:mic');
      expect((events[2] as PeerLeft).peer.tracks.keys, ['bob:cam', 'bob:mic']);
      expect(store.peers, isEmpty);
      expect(store.tracks, isEmpty);
    });

    test('endpointRemoved of a component emits ComponentRemoved', () {
      connect({
        'rec': _endpoint('recording', tracks: {'rec:t': _plainTrack()}),
      });

      store.endpointRemoved(
        server.MediaEvent_EndpointRemoved(endpointId: 'rec'),
      );

      expect(events.map((e) => e.runtimeType), [
        TrackRemoved,
        ComponentRemoved,
      ]);
      expect(store.components, isEmpty);
    });

    test('endpointRemoved of an unknown or local endpoint is ignored', () {
      connect();

      store
        ..endpointRemoved(server.MediaEvent_EndpointRemoved(endpointId: 'x'))
        ..endpointRemoved(server.MediaEvent_EndpointRemoved(endpointId: 'me'));

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(1));
    });
  });

  group('tracks (SPEC §14.2)', () {
    test('tracksAdded emits TrackAdded per new track', () {
      addBob();

      store.tracksAdded(
        server.MediaEvent_TracksAdded(
          endpointId: 'bob',
          trackIdToTrack: {
            'bob:cam': _simulcastTrack(),
            'bob:mic': _plainTrack(),
          }.entries,
        ),
      );

      expect(events, hasLength(2));
      final cam = (events[0] as TrackAdded).track;
      final mic = (events[1] as TrackAdded).track;
      expect(cam.trackId, 'bob:cam');
      expect(cam.endpointId, 'bob');
      expect(cam.isReady, isFalse);
      expect(cam.simulcastConfig, const SimulcastConfig.allVariants());
      expect(mic.metadata, const TrackMetadata(type: TrackType.microphone));
      expect(mic.simulcastConfig, const SimulcastConfig.disabled());
      expect(store.peers.single.tracks.keys, ['bob:cam', 'bob:mic']);
    });

    test('a known track id is updated in place without a second '
        'TrackAdded', () {
      addBobTracks();

      store.tracksAdded(
        server.MediaEvent_TracksAdded(
          endpointId: 'bob',
          trackIdToTrack: {
            'bob:mic': _plainTrack('{"type":"microphone","paused":true}'),
          }.entries,
        ),
      );

      expect(events, isEmpty);
      expect(store.tracks['bob:mic']!.metadata!.paused, isTrue);
      expect(store.tracks, hasLength(2));
    });

    test('tracksAdded from the local peer or an unknown endpoint is '
        'ignored', () {
      connect();

      store
        ..tracksAdded(
          server.MediaEvent_TracksAdded(
            endpointId: 'me',
            trackIdToTrack: {'me:x': _plainTrack()}.entries,
          ),
        )
        ..tracksAdded(
          server.MediaEvent_TracksAdded(
            endpointId: 'ghost',
            trackIdToTrack: {'ghost:x': _plainTrack()}.entries,
          ),
        );

      expect(events, isEmpty);
      expect(store.tracks, isEmpty);
      expect(logs.warnings, hasLength(1));
    });

    test('a track id owned by another endpoint is not taken over', () {
      addBobTracks();
      store
        ..endpointAdded(server.MediaEvent_EndpointAdded(endpointId: 'eve'))
        ..tracksAdded(
          server.MediaEvent_TracksAdded(
            endpointId: 'eve',
            trackIdToTrack: {'bob:cam': _plainTrack()}.entries,
          ),
        );

      expect(store.tracks['bob:cam']!.endpointId, 'bob');
      expect(events.whereType<TrackAdded>(), isEmpty);
      expect(logs.warnings, hasLength(1));
    });

    test('tracksRemoved emits TrackRemoved for known ids only', () {
      addBobTracks();

      store.tracksRemoved(
        server.MediaEvent_TracksRemoved(
          endpointId: 'bob',
          trackIds: ['bob:cam', 'bob:nope'],
        ),
      );

      expect((events.single as TrackRemoved).track.trackId, 'bob:cam');
      expect(store.tracks.keys, ['bob:mic']);
      expect(store.peers.single.tracks.keys, ['bob:mic']);
      expect(logs.warnings, hasLength(1));
    });

    test('tracksRemoved from the local peer is ignored', () {
      addBobTracks();

      store.tracksRemoved(
        server.MediaEvent_TracksRemoved(endpointId: 'me', trackIds: ['me:cam']),
      );

      expect(events, isEmpty);
    });

    test('trackUpdated stores metadata and emits TrackUpdated', () {
      addBobTracks();

      store.trackUpdated(
        server.MediaEvent_TrackUpdated(
          endpointId: 'bob',
          trackId: 'bob:cam',
          metadataJson: '{"type":"camera","paused":true}',
        ),
      );

      final updated = (events.single as TrackUpdated).track;
      expect(updated.metadata!.paused, isTrue);
      expect(store.tracks['bob:cam']!.metadata!.paused, isTrue);
    });

    test('trackUpdated with empty metadata clears it', () {
      addBobTracks();

      store.trackUpdated(
        server.MediaEvent_TrackUpdated(
          endpointId: 'bob',
          trackId: 'bob:cam',
          metadataJson: '',
        ),
      );

      expect(store.tracks['bob:cam']!.rawMetadata, isNull);
      expect(store.tracks['bob:cam']!.metadata, isNull);
    });

    test('trackUpdated for unknown or local tracks is ignored', () {
      addBobTracks();

      store
        ..trackUpdated(
          server.MediaEvent_TrackUpdated(endpointId: 'bob', trackId: 'bob:x'),
        )
        ..trackUpdated(
          server.MediaEvent_TrackUpdated(endpointId: 'me', trackId: 'me:cam'),
        );

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(1));
    });

    test('non-standard metadata stays available raw', () {
      addBob();

      store.tracksAdded(
        server.MediaEvent_TracksAdded(
          endpointId: 'bob',
          trackIdToTrack: {'bob:x': _plainTrack('{"kind":"weird"}')}.entries,
        ),
      );

      final track = store.tracks['bob:x']!;
      expect(track.rawMetadata, {'kind': 'weird'});
      expect(track.metadata, isNull);
    });
  });

  group('track ready (SPEC §14.3)', () {
    test('onTrack attaches media by mid and emits TrackReady', () {
      addBobTracks();
      store.applyAnswerMids({'0': 'bob:cam', '1': 'bob:mic', '2': 'me:cam'});
      final media = FakeMediaTrack.video();
      final stream = FakeMediaStream('bob-stream');

      store.trackReady(
        RtcTrackEvent(track: media, streams: [stream], mid: '0'),
      );

      final ready = (events.single as TrackReady).track;
      expect(ready.trackId, 'bob:cam');
      expect(ready.kind, MediaKind.video);
      expect(ready.isReady, isTrue);
      expect(ready.rtcTrack, same(media));
      expect(ready.rtcStream, same(stream));
      expect(store.peers.single.tracks['bob:cam']!.isReady, isTrue);
    });

    test('works without streams', () {
      addBobTracks();
      store
        ..applyAnswerMids({'1': 'bob:mic'})
        ..trackReady(
          RtcTrackEvent(
            track: FakeMediaTrack.audio(),
            streams: const [],
            mid: '1',
          ),
        );

      final ready = (events.single as TrackReady).track;
      expect(ready.kind, MediaKind.audio);
      expect(ready.rtcStream, isNull);
    });

    test('unknown or missing mid is logged and ignored', () {
      addBobTracks();
      store
        ..applyAnswerMids({'0': 'bob:cam'})
        ..trackReady(
          RtcTrackEvent(
            track: FakeMediaTrack.video(),
            streams: const [],
            mid: '9',
          ),
        )
        ..trackReady(
          RtcTrackEvent(
            track: FakeMediaTrack.video(),
            streams: const [],
            mid: null,
          ),
        );

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(2));
    });

    test('a mid reassigned to another track resolves to the new one', () {
      addBobTracks();
      store
        ..applyAnswerMids({'0': 'bob:cam'})
        ..applyAnswerMids({'0': 'bob:mic'})
        ..trackReady(
          RtcTrackEvent(
            track: FakeMediaTrack.audio(),
            streams: const [],
            mid: '0',
          ),
        );

      expect((events.single as TrackReady).track.trackId, 'bob:mic');
    });

    test('a removed track no longer resolves its mid', () {
      addBobTracks();
      store
        ..applyAnswerMids({'0': 'bob:cam'})
        ..tracksRemoved(
          server.MediaEvent_TracksRemoved(
            endpointId: 'bob',
            trackIds: ['bob:cam'],
          ),
        );
      events.clear();

      store.trackReady(
        RtcTrackEvent(
          track: FakeMediaTrack.video(),
          streams: const [],
          mid: '0',
        ),
      );

      expect(events, isEmpty);
    });
  });

  group('variants (SPEC §14.4)', () {
    test('setTargetEncoding sends setTargetTrackVariant and emits', () {
      addBobTracks();

      store.setTargetEncoding('bob:cam', Variant.low);

      expect(sent.single.setTargetTrackVariant.trackId, 'bob:cam');
      expect(
        sent.single.setTargetTrackVariant.variant,
        shared.Variant.VARIANT_LOW,
      );
      expect(
        events.single,
        isA<TargetTrackEncodingRequested>()
            .having((e) => e.trackId, 'trackId', 'bob:cam')
            .having((e) => e.variant, 'variant', Variant.low),
      );
    });

    test('setTargetEncoding validates before sending (D7)', () {
      addBobTracks();
      store.variantDisabled(
        server.MediaEvent_TrackVariantDisabled(
          endpointId: 'bob',
          trackId: 'bob:cam',
          variant: shared.Variant.VARIANT_HIGH,
        ),
      );
      events.clear();

      expect(
        () => store.setTargetEncoding('bob:mic', Variant.low),
        throwsArgumentError,
        reason: 'not simulcast',
      );
      expect(
        () => store.setTargetEncoding('bob:cam', Variant.high),
        throwsArgumentError,
        reason: 'variant not enabled',
      );
      expect(
        () => store.setTargetEncoding('bob:nope', Variant.low),
        throwsArgumentError,
        reason: 'unknown track',
      );
      expect(sent, isEmpty);
      expect(events, isEmpty);
    });

    test('trackVariantSwitched sets the encoding', () {
      addBobTracks();

      store.variantSwitched(
        server.MediaEvent_TrackVariantSwitched(
          endpointId: 'bob',
          trackId: 'bob:cam',
          variant: shared.Variant.VARIANT_MEDIUM,
        ),
      );

      final changed = (events.single as TrackEncodingChanged).track;
      expect(changed.encoding, Variant.medium);
      expect(changed.encodingReason, isNull);
      expect(store.tracks['bob:cam']!.encoding, Variant.medium);
    });

    test('trackVariantSwitched with an unknown track or variant is '
        'ignored', () {
      addBobTracks();

      store
        ..variantSwitched(
          server.MediaEvent_TrackVariantSwitched(
            trackId: 'bob:nope',
            variant: shared.Variant.VARIANT_LOW,
          ),
        )
        ..variantSwitched(
          server.MediaEvent_TrackVariantSwitched(trackId: 'bob:cam'),
        );

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(2));
    });

    test('trackVariantDisabled and Enabled move the variant', () {
      addBobTracks();

      store.variantDisabled(
        server.MediaEvent_TrackVariantDisabled(
          endpointId: 'bob',
          trackId: 'bob:cam',
          variant: shared.Variant.VARIANT_HIGH,
        ),
      );

      expect(
        (events.single as TrackVariantsChanged).track.simulcastConfig,
        const SimulcastConfig(
          enabled: true,
          enabledVariants: [Variant.low, Variant.medium],
          disabledVariants: [Variant.high],
        ),
      );

      store.variantEnabled(
        server.MediaEvent_TrackVariantEnabled(
          endpointId: 'bob',
          trackId: 'bob:cam',
          variant: shared.Variant.VARIANT_HIGH,
        ),
      );

      expect(
        (events.last as TrackVariantsChanged).track.simulcastConfig,
        const SimulcastConfig.allVariants(),
      );
    });

    test('variant changes with an unknown track or variant are ignored', () {
      addBobTracks();

      store
        ..variantEnabled(
          server.MediaEvent_TrackVariantEnabled(
            trackId: 'x',
            variant: shared.Variant.VARIANT_LOW,
          ),
        )
        ..variantDisabled(
          server.MediaEvent_TrackVariantDisabled(trackId: 'bob:cam'),
        );

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(2));
    });
  });

  group('voice activity (SPEC §14.5)', () {
    test('speech and silence', () {
      addBobTracks();

      store.vadNotification(
        server.MediaEvent_VadNotification(
          trackId: 'bob:mic',
          status: server.MediaEvent_VadNotification_Status.STATUS_SPEECH,
        ),
      );
      expect(
        (events.single as VoiceActivityChanged).track.vadStatus,
        VadStatus.speech,
      );

      store.vadNotification(
        server.MediaEvent_VadNotification(
          trackId: 'bob:mic',
          status: server.MediaEvent_VadNotification_Status.STATUS_SILENCE,
        ),
      );
      expect(
        (events.last as VoiceActivityChanged).track.vadStatus,
        VadStatus.silence,
      );
      expect(store.tracks['bob:mic']!.vadStatus, VadStatus.silence);
    });

    test('unspecified status or unknown track is ignored', () {
      addBobTracks();

      store
        ..vadNotification(server.MediaEvent_VadNotification(trackId: 'bob:mic'))
        ..vadNotification(
          server.MediaEvent_VadNotification(
            trackId: 'x',
            status: server.MediaEvent_VadNotification_Status.STATUS_SPEECH,
          ),
        );

      expect(events, isEmpty);
      expect(logs.warnings, hasLength(2));
    });
  });

  test('events carry snapshots that later changes do not alter', () {
    addBobTracks();
    store.vadNotification(
      server.MediaEvent_VadNotification(
        trackId: 'bob:mic',
        status: server.MediaEvent_VadNotification_Status.STATUS_SPEECH,
      ),
    );
    final peers = store.peers;
    final tracks = store.tracks;

    store.vadNotification(
      server.MediaEvent_VadNotification(
        trackId: 'bob:mic',
        status: server.MediaEvent_VadNotification_Status.STATUS_SILENCE,
      ),
    );

    expect(
      (events.first as VoiceActivityChanged).track.vadStatus,
      VadStatus.speech,
    );
    expect(peers.single.tracks['bob:mic']!.vadStatus, VadStatus.speech);
    expect(tracks['bob:mic']!.vadStatus, VadStatus.speech);
    expect(() => tracks.remove('bob:mic'), throwsUnsupportedError);
  });
}
