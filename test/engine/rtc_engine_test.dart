import 'dart:async';

import 'package:fishjam_client/src/engine/rtc_engine.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../support/fixtures.dart';
import 'engine_harness.dart';

typedef _C = peer.MediaEvent_Content;

const _camera = TrackMetadata(type: TrackType.camera);
const _microphone = TrackMetadata(type: TrackType.microphone);

server.MediaEvent _tracksAdded(String endpointId, List<String> ids) =>
    server.MediaEvent(
      tracksAdded: server.MediaEvent_TracksAdded(
        endpointId: endpointId,
        trackIdToTrack: {
          for (final id in ids)
            id: server.MediaEvent_Track(
              metadataJson: '{"type":"camera","paused":false}',
            ),
        }.entries,
      ),
    );

server.MediaEvent _candidate(String line) => server.MediaEvent(
  candidate: shared.Candidate(candidate: line, sdpMid: '0'),
);

/// Joined harness with log lines captured.
Future<(EngineHarness, List<String>)> _joined({
  Map<String, server.MediaEvent_Endpoint> endpoints = const {},
}) async {
  final logs = <String>[];
  final h = EngineHarness(
    logger: FishjamLogger(
      enabled: true,
      sink: (level, message, {error, stackTrace}) =>
          logs.add('${level.name} $message'),
    ),
  );
  await h.join(endpoints: endpoints);
  return (h, logs);
}

/// Adds a track and completes its negotiation.
Future<String> _publish(
  EngineHarness h, {
  MediaKind kind = MediaKind.video,
  TrackMetadata metadata = _camera,
}) async {
  final id = h.engine.addTrack(FakeMediaTrack(kind: kind), metadata: metadata);
  await settle();
  await h.offerData();
  await h.answer(h.lastOffer.midToTrackId);
  return await id;
}

/// Captures the outcome of a future without awaiting it.
class _Outcome<T> {
  _Outcome(Future<T> future) {
    unawaited(
      future.then<void>(
        (v) {
          value = v;
          done = true;
        },
        onError: (Object e) {
          error = e;
        },
      ),
    );
  }

  bool done = false;
  T? value;
  Object? error;
}

void main() {
  group('session setup', () {
    test('connect sends connect with the peer metadata as JSON', () async {
      final h = EngineHarness()..engine.connect({'name': 'alice'});
      final h2 = EngineHarness()..engine.connect(null);
      // No transport is needed to capture the event.
      expect(h.sent.single.connect.metadataJson, '{"name":"alice"}');
      expect(h2.sent.single.connect.metadataJson, 'null');
      expect(h.localTracks.peerMetadata, {'name': 'alice'});
    });

    test('connected completes joined with the remote snapshot and sets the '
        'local peer id', () async {
      final (h, _) = await _joined(
        endpoints: {
          'bob': server.MediaEvent_Endpoint(endpointType: 'exwebrtc'),
        },
      );
      final joined = h.events.whereType<Joined>().single;
      expect(joined.peerId, 'local-peer');
      expect(joined.peers.map((p) => p.id), ['bob']);
      expect(h.localTracks.peerId, 'local-peer');
      expect(h.localTracks.peerMetadata, {'name': 'alice'});
      expect(h.localTracks.serverMetadata, {'role': 'x'});
    });

    test('events before connected are dropped (SPEC §7)', () async {
      final h = EngineHarness();
      await h.engine.handleServerEvent(_tracksAdded('bob', ['bob:cam']));
      expect(h.events, isEmpty);
    });

    test('a second connected is ignored', () async {
      final (h, logs) = await _joined();
      await h.engine.handleServerEvent(
        server.MediaEvent(
          connected: server.MediaEvent_Connected(endpointId: 'other'),
        ),
      );
      expect(h.localTracks.peerId, 'local-peer');
      expect(logs, contains(contains('connected')));
    });

    test('the peer connection is created lazily with the ICE servers from '
        'connected', () async {
      final (h, _) = await _joined();
      expect(h.engine.peerConnection, isNull);
      expect(h.rtc.peerConnections, isEmpty);

      await h.offerData();
      expect(h.rtc.peerConnections, hasLength(1));
      expect(h.engine.peerConnection, same(h.pc));
      expect(h.pc.configuration.iceServers, const [
        IceServer(
          urls: ['turn:turn.test:3478'],
          username: 'user',
          credential: 'pass',
        ),
      ]);
      expect(await h.engine.ensurePeerConnection(), same(h.pc));
      expect(h.rtc.peerConnections, hasLength(1));
    });

    test('ensurePeerConnection creates the connection and adds registered '
        'tracks', () async {
      final (h, _) = await _joined();
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      await settle();
      final pc = await h.engine.ensurePeerConnection();
      expect(pc, same(h.pc));
      expect(h.pc.callsOf('addTransceiver'), hasLength(1));
    });
  });

  group('media event dispatch (SPEC §7)', () {
    test('events about the local endpoint are ignored (D11)', () async {
      final (h, _) = await _joined();
      h.events.clear();
      for (final e in [
        server.MediaEvent(
          endpointAdded: server.MediaEvent_EndpointAdded(
            endpointId: 'local-peer',
          ),
        ),
        server.MediaEvent(
          endpointUpdated: server.MediaEvent_EndpointUpdated(
            endpointId: 'local-peer',
          ),
        ),
        server.MediaEvent(
          trackUpdated: server.MediaEvent_TrackUpdated(
            endpointId: 'local-peer',
          ),
        ),
        server.MediaEvent(
          tracksRemoved: server.MediaEvent_TracksRemoved(
            endpointId: 'local-peer',
          ),
        ),
        _tracksAdded('local-peer', ['local-peer:x']),
      ]) {
        await h.engine.handleServerEvent(e);
      }
      expect(h.events, isEmpty);

      // The negotiation state did not move: addTrack still requests a cycle.
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      await settle();
      expect(h.sentOf(_C.renegotiateTracks), hasLength(1));
    });

    test('endpointRemoved for the local peer reports the removal', () async {
      final (h, _) = await _joined();
      await h.engine.handleServerEvent(
        server.MediaEvent(
          endpointRemoved: server.MediaEvent_EndpointRemoved(
            endpointId: 'local-peer',
          ),
        ),
      );
      await settle();
      expect(h.localPeerRemovals, 1);
    });

    test('error emits ServerError and reports it', () async {
      final (h, _) = await _joined();
      await h.engine.handleServerEvent(
        server.MediaEvent(error: server.MediaEvent_Error(message: 'boom')),
      );
      expect(h.events.whereType<ServerError>().single.message, 'boom');
      await settle();
      expect(h.serverErrors, ['boom']);
    });

    test(
      'a failing handler is logged and later events are still handled',
      () async {
        final logs = <String>[];
        final h = EngineHarness(
          logger: FishjamLogger(
            enabled: true,
            sink: (level, message, {error, stackTrace}) =>
                logs.add('${level.name} $message'),
          ),
          remoteStore: _FailingEndpointAdded.new,
        );
        await h.join(
          endpoints: {
            'bob': server.MediaEvent_Endpoint(endpointType: 'exwebrtc'),
          },
        );
        await h.engine.handleServerEvent(
          server.MediaEvent(
            endpointAdded: server.MediaEvent_EndpointAdded(endpointId: 'carol'),
          ),
        );
        await h.engine.handleServerEvent(
          server.MediaEvent(
            endpointUpdated: server.MediaEvent_EndpointUpdated(
              endpointId: 'bob',
            ),
          ),
        );
        expect(h.events.whereType<PeerUpdated>(), hasLength(1));
        expect(logs, contains(startsWith('error')));
      },
    );

    test('an empty media event is ignored', () async {
      final (h, logs) = await _joined();
      await h.engine.handleServerEvent(server.MediaEvent());
      expect(logs, contains(contains('notSet')));
    });

    test('events are handled strictly in order, one at a time', () async {
      final rtc = _GatedRtcAdapter();
      final h = EngineHarness(rtc: rtc);
      await h.join(
        endpoints: {
          'bob': server.MediaEvent_Endpoint(endpointType: 'exwebrtc'),
        },
      );
      final gate = rtc.offerGate = Completer<void>();

      unawaited(h.engine.handleServerEvent(_offerData()));
      final updated = h.engine.handleServerEvent(
        server.MediaEvent(
          endpointUpdated: server.MediaEvent_EndpointUpdated(endpointId: 'bob'),
        ),
      );
      await settle();
      expect(h.events.whereType<PeerUpdated>(), isEmpty);
      expect(h.sentOf(_C.sdpOffer), isEmpty);

      gate.complete();
      await updated;
      expect(h.sentOf(_C.sdpOffer), hasLength(1));
      expect(h.events.whereType<PeerUpdated>(), hasLength(1));
    });

    test('nothing is handled after close', () async {
      final (h, _) = await _joined();
      await h.engine.close();
      h.events.clear();
      await h.engine.handleServerEvent(_tracksAdded('bob', ['bob:cam']));
      expect(h.events, isEmpty);
    });
  });

  group('negotiation (SPEC §8)', () {
    test('a remote tracksAdded starts a server-initiated cycle: addTrack '
        'rides it without renegotiateTracks', () async {
      final (h, _) = await _joined();
      await h.receive(_tracksAdded('bob', ['bob:cam']));
      final id = _Outcome(
        h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
      );
      await settle();
      expect(h.sentOf(_C.renegotiateTracks), isEmpty);

      await h.offerData(video: 1);
      expect(h.lastOffer.trackIdToMetadataJson.keys, [id.value ?? isNotNull]);
      await h.answer(h.lastOffer.midToTrackId);
      expect(id.done, isTrue);
    });

    test('offerData while an offer is in flight is handled again', () async {
      final (h, logs) = await _joined();
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      await settle();
      await h.offerData();
      await h.offerData();
      expect(h.sentOf(_C.sdpOffer), hasLength(2));
      expect(logs, contains(startsWith('warn')));
    });

    test('sdpAnswer outside offerSent is ignored', () async {
      final (h, logs) = await _joined();
      await h.answer();
      expect(h.rtc.peerConnections, isEmpty);
      await h.offerData();
      await h.answer();
      await h.answer();
      expect(h.pc.callsOf('setRemoteDescription'), hasLength(1));
      expect(logs.where((l) => l.contains('sdpAnswer')), hasLength(2));
    });

    test('tracks are offered, then negotiated after the answer', () async {
      final (h, _) = await _joined();
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      await settle();
      final track = h.localTracks.tracks.single;
      expect(track.negotiationStatus, TrackNegotiationStatus.pending);
      await h.offerData();
      expect(track.negotiationStatus, TrackNegotiationStatus.offered);
      await h.answer(h.lastOffer.midToTrackId);
      expect(track.negotiationStatus, TrackNegotiationStatus.negotiated);
      expect(track.mid, '0');
    });

    test('a failing createOffer fails the cycle as a connection failure and '
        'drops the tracks it carried (SPEC §8.2)', () async {
      final (h, logs) = await _joined();
      final first = _Outcome(
        h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
      );
      await settle();
      await h.engine.ensurePeerConnection();
      h.pc.failNext('createOffer', StateError('no offer'));
      await h.offerData();
      expect(first.error, isA<StateError>());
      expect(logs, contains(startsWith('error')));
      expect(h.events.whereType<ConnectionError>(), hasLength(1));
      expect(h.connectionFailures, hasLength(1));
      expect(h.localTracks.tracks, isEmpty);
      expect(h.pc.callsOf('removeTrack'), hasLength(1));
    });

    test('a failing setRemoteDescription fails the cycle as a connection '
        'failure and drops the tracks it carried', () async {
      final (h, _) = await _joined();
      final added = _Outcome(
        h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
      );
      await settle();
      await h.offerData();
      h.pc.failNext('setRemoteDescription', StateError('bad answer'));
      await h.answer(h.lastOffer.midToTrackId);
      expect(added.error, isA<StateError>());
      expect(h.events.whereType<ConnectionError>(), hasLength(1));
      expect(h.connectionFailures, hasLength(1));
      expect(h.localTracks.tracks, isEmpty);
      expect(h.pc.callsOf('removeTrack'), hasLength(1));
    });

    test(
      'a native call that never completes times out and fails the cycle',
      () async {
        final rtc = _GatedRtcAdapter();
        final h = EngineHarness(
          rtc: rtc,
          nativeCallTimeout: const Duration(milliseconds: 20),
        );
        await h.join();
        final added = _Outcome(
          h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
        );
        await settle();
        rtc.offerGate = Completer<void>();
        await h.offerData();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await settle();
        expect(added.error, isA<TimeoutException>());
        expect(h.events.whereType<ConnectionError>(), hasLength(1));
        expect(h.sentOf(_C.sdpOffer), isEmpty);
      },
    );

    test('ICE disconnected while idle requests a renegotiation', () async {
      final (h, logs) = await _joined();
      await h.offerData();
      await h.answer();
      h.pc.setIceConnectionState(IceConnectionState.disconnected);
      await settle();
      expect(h.sentOf(_C.renegotiateTracks), hasLength(1));
      expect(logs, contains(startsWith('warn')));
    });

    test('ICE or peer connection failure emits one ConnectionError and '
        'reports it', () async {
      final (h, _) = await _joined();
      await h.offerData();
      h.pc
        ..setIceConnectionState(IceConnectionState.failed)
        ..setConnectionState(PeerConnectionState.failed);
      await settle();
      expect(h.events.whereType<ConnectionError>(), hasLength(1));
      expect(h.connectionFailures, hasLength(1));
    });

    test('peer connection failure emits ConnectionError', () async {
      final (h, _) = await _joined();
      await h.offerData();
      h.pc.setConnectionState(PeerConnectionState.failed);
      await settle();
      expect(h.events.whereType<ConnectionError>(), hasLength(1));
    });
  });

  group('receive transceiver sync (SPEC §9)', () {
    Future<List<FakeTransceiverState>> liveRecv(EngineHarness h) async => [
      for (final t in h.pc.transceiverStates)
        if (t.direction == TransceiverDirection.recvonly) t,
    ];

    test('adds missing video first, then audio', () async {
      final (h, _) = await _joined();
      await h.offerData(audio: 1, video: 2);
      expect(h.pc.callsOf('addTransceiver').map((c) => c.args['kind']), [
        'video',
        'video',
        'audio',
      ]);
      expect(
        h.pc.callsOf('addTransceiver').map((c) => c.args['direction']),
        everyElement('recvonly'),
      );
    });

    test('keeps matching counts and stops the excess, orphans first', () async {
      final (h, _) = await _joined();
      await h.offerData(video: 1);
      await h.answer();
      await h.offerData(video: 1);
      await h.answer();
      expect(h.pc.callsOf('addTransceiver'), hasLength(1));

      // An orphan: added for a cycle that failed before mids were assigned.
      h.pc.failNext('setLocalDescription', StateError('failed'));
      await h.offerData(video: 2);
      final states = h.pc.transceiverStates;
      expect(states.map((t) => t.mid), ['0', null]);

      await h.offerData(video: 1);
      expect(h.pc.callsOf('stopTransceiver').single.args['mid'], isNull);
      expect(states[0].isStopped, isFalse);
      expect(states[1].isStopped, isTrue);
      expect(await liveRecv(h), hasLength(1));

      await h.answer();
      await h.offerData();
      expect(states[0].isStopped, isTrue);
      expect(await liveRecv(h), isEmpty);
    });

    test('stopped transceivers are not counted', () async {
      final (h, _) = await _joined();
      await h.offerData(audio: 1);
      await h.answer();
      await h.offerData();
      await h.answer();
      await h.offerData(audio: 1);
      expect(h.pc.callsOf('addTransceiver').map((c) => c.args['kind']), [
        'audio',
        'audio',
      ]);
    });
  });

  group('ICE candidates (SPEC §8.4)', () {
    test('candidates gathered before the offer is sent follow it', () async {
      // The server rejects a candidate that arrives before the offer it
      // belongs to; native stacks emit candidates during setLocalDescription.
      final (h, _) = await _joined();
      await h.engine.ensurePeerConnection();
      h.pc.onLocalDescriptionSet = () => h.pc.emitIceCandidate(
        const IceCandidate(candidate: 'early', sdpMLineIndex: 0, sdpMid: '0'),
      );
      await h.offerData();
      await settle();

      final kinds = h.sent.map((e) => e.whichContent()).toList();
      expect(
        kinds.indexOf(_C.candidate),
        greaterThan(kinds.indexOf(_C.sdpOffer)),
      );
      expect(h.sentOf(_C.candidate).single.candidate.candidate, 'early');
    });

    test('local candidates are sent; remote ones are added', () async {
      final (h, _) = await _joined();
      await h.offerData();
      await h.answer();
      h.pc.emitIceCandidate(
        const IceCandidate(
          candidate: 'candidate:1',
          sdpMLineIndex: 0,
          sdpMid: '0',
          usernameFragment: 'u',
        ),
      );
      await settle();
      final sent = h.sentOf(_C.candidate).single.candidate;
      expect(sent.candidate, 'candidate:1');
      expect(sent.sdpMLineIndex, 0);
      expect(sent.sdpMid, '0');
      expect(sent.usernameFragment, 'u');

      await h.receive(_candidate('candidate:2'));
      expect(h.pc.remoteCandidates.single.candidate, 'candidate:2');
      expect(h.pc.remoteCandidates.single.sdpMid, '0');
    });

    test(
      'remote candidates are buffered until a remote description exists',
      () async {
        final (h, _) = await _joined();
        await h.receive(_candidate('before-pc'));
        await h.offerData();
        await h.receive(_candidate('before-answer'));
        expect(h.pc.remoteCandidates, isEmpty);

        await h.answer();
        expect(h.pc.remoteCandidates.map((c) => c.candidate), [
          'before-pc',
          'before-answer',
        ]);
        final calls = h.pc.calls.map((c) => c.method).toList();
        expect(
          calls.indexOf('setRemoteDescription'),
          lessThan(calls.indexOf('addIceCandidate')),
        );
      },
    );

    test('a failing addIceCandidate is logged', () async {
      final (h, logs) = await _joined();
      await h.offerData();
      await h.answer();
      h.pc.failNext('addIceCandidate', StateError('bad candidate'));
      await h.receive(_candidate('bad'));
      await h.receive(_candidate('good'));
      expect(h.pc.remoteCandidates.single.candidate, 'good');
      expect(logs, contains(startsWith('warn')));
    });
  });

  group('addTrack (SPEC §11.1)', () {
    test('fails before Joined', () async {
      final h = EngineHarness();
      await expectLater(
        h.engine.addTrack(FakeMediaTrack.video()),
        throwsStateError,
      );
    });

    test('fails for a media track that is already published', () async {
      final (h, _) = await _joined();
      final media = FakeMediaTrack.video();
      unawaited(h.engine.addTrack(media, metadata: _camera));
      await settle();
      await expectLater(h.engine.addTrack(media), throwsArgumentError);
      expect(h.localTracks.tracks, hasLength(1));
    });

    test('an invalid limit fails without registering anything', () async {
      final (h, _) = await _joined();
      await expectLater(
        h.engine.addTrack(
          FakeMediaTrack.video(),
          maxBandwidth: const BandwidthLimit.simulcast({Variant.low: 100}),
        ),
        throwsArgumentError,
      );
      expect(h.localTracks.tracks, isEmpty);
      expect(h.sentOf(_C.renegotiateTracks), isEmpty);
    });

    test(
      'adds a send transceiver at once when the connection exists',
      () async {
        final (h, _) = await _joined();
        await h.offerData();
        await h.answer();
        unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
        await settle();
        expect(
          h.pc.callsOf('addTransceiver').single.args['direction'],
          'sendonly',
        );
      },
    );

    test('camera and microphone share a stream; screen share and other '
        'tracks get their own', () async {
      final (h, _) = await _joined();
      for (final m in [
        _camera,
        _microphone,
        const TrackMetadata(type: TrackType.screenShareVideo),
        const TrackMetadata(type: TrackType.screenShareAudio),
        const TrackMetadata(type: TrackType.customVideo),
        null,
      ]) {
        unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: m));
      }
      await settle();
      final streams = h.localTracks.tracks.map((t) => t.stream).toList();
      expect(streams[0], same(streams[1]));
      expect(streams[2], same(streams[3]));
      expect(streams[0], isNot(same(streams[2])));
      expect(streams.toSet(), hasLength(4));
      expect(streams[0]!.tracks, hasLength(2));
      expect(h.rtc.localStreams, hasLength(4));
    });

    test('uses the stream given by the caller', () async {
      final (h, _) = await _joined();
      final stream = FakeMediaStream('mine');
      unawaited(
        h.engine.addTrack(
          FakeMediaTrack.video(),
          metadata: _camera,
          stream: stream,
        ),
      );
      await settle();
      expect(h.localTracks.tracks.single.stream, same(stream));
      expect(h.rtc.localStreams, isEmpty);
    });

    test('completes with the track id after the answer and emits '
        'LocalTrackAdded', () async {
      final (h, _) = await _joined();
      final id = await _publish(h);
      expect(id, startsWith('local-peer:'));
      final added = h.events.whereType<LocalTrackAdded>().single.track;
      expect(added.trackId, id);
      // Video limits resolve against the caps; audio is never limited.
      expect(added.maxBandwidth, const BandwidthLimit.single(1500));

      final mic = await _publish(h, kind: MediaKind.audio);
      expect(
        h.events.whereType<LocalTrackAdded>().last.track,
        isA<LocalTrackContext>()
            .having((t) => t.trackId, 'trackId', mic)
            .having(
              (t) => t.maxBandwidth,
              'maxBandwidth',
              BandwidthLimit.unlimited,
            ),
      );
    });
  });

  group('removeTrack (SPEC §11.2)', () {
    test(
      'removes the sender, renegotiates, completes after the answer',
      () async {
        final (h, _) = await _joined();
        final id = await _publish(h);
        final removed = _Outcome(h.engine.removeTrack(id));
        await settle();
        expect(h.pc.callsOf('removeTrack'), hasLength(1));
        expect(h.localTracks.tracks, isEmpty);
        expect(h.sentOf(_C.renegotiateTracks), hasLength(2));
        expect(removed.done, isFalse);

        await h.offerData();
        expect(h.lastOffer.trackIdToMetadataJson, isEmpty);
        await h.answer();
        expect(removed.done, isTrue);
        expect(h.events.whereType<LocalTrackRemoved>().single.trackId, id);
      },
    );

    test(
      'removing a track that was never negotiated needs no sender',
      () async {
        final (h, _) = await _joined();
        final add = _Outcome(
          h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
        );
        await settle();
        final id = h.localTracks.tracks.single.trackId;
        final removed = _Outcome(h.engine.removeTrack(id));
        await settle();
        expect(removed.done, isFalse);
        await h.offerData();
        await h.answer();
        expect(add.done, isTrue);
        await h.offerData();
        await h.answer();
        expect(removed.done, isTrue);
      },
    );

    test('unknown id is an ArgumentError', () async {
      final (h, _) = await _joined();
      await expectLater(h.engine.removeTrack('nope'), throwsArgumentError);
    });
  });

  group('replaceTrack (SPEC §11.3)', () {
    test('delegates to the registry without negotiating', () async {
      final (h, _) = await _joined();
      final id = await _publish(h);
      final camera = FakeMediaTrack.video();

      await h.engine.replaceTrack(id, null);
      await h.engine.replaceTrack(id, camera);
      expect(h.events.whereType<LocalTrackMuted>().single.trackId, id);
      expect(h.events.whereType<LocalTrackUnmuted>().single.trackId, id);
      expect(h.pc.callsOf('replaceTrack'), hasLength(2));
      expect(h.sentOf(_C.renegotiateTracks), hasLength(1));
    });

    test('waits for the commands queued before it', () async {
      final (h, _) = await _joined();
      final id = await _publish(h);
      unawaited(h.engine.addTrack(FakeMediaTrack.audio()));
      final replaced = _Outcome(h.engine.replaceTrack(id, null));
      await settle();
      expect(replaced.done, isFalse);
      await h.offerData();
      await h.answer(h.lastOffer.midToTrackId);
      expect(replaced.done, isTrue);
    });

    test('fails with the error of the registry', () async {
      final (h, _) = await _joined();
      final id = await _publish(h);
      (h.localTracks.byId(id).transceiver!.sender as FakeRtpSender)
          .failNextReplaceTrack = StateError(
        'x',
      );
      await expectLater(h.engine.replaceTrack(id, null), throwsStateError);
      expect(h.events.whereType<LocalTrackReplaced>(), isEmpty);
    });

    test('unknown id is an ArgumentError', () async {
      final (h, _) = await _joined();
      await expectLater(
        h.engine.replaceTrack('nope', null),
        throwsArgumentError,
      );
    });
  });

  group('negotiate (data channels, SPEC §16)', () {
    test('fails before connected without creating a connection', () async {
      final h = EngineHarness();
      await expectLater(
        h.engine.negotiate((pc) async {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'not connected',
          ),
        ),
      );
      expect(h.rtc.peerConnections, isEmpty);
    });

    test('creates the connection, applies, renegotiates and completes after '
        'the answer', () async {
      final (h, _) = await _joined();
      final applied = <RtcPeerConnection>[];
      final done = _Outcome(
        h.engine.negotiate((pc) async {
          applied.add(pc);
          await pc.createDataChannel('reliable', const DataChannelInit());
        }),
      );
      await settle();
      expect(applied.single, same(h.pc));
      expect(h.sentOf(_C.renegotiateTracks), hasLength(1));
      expect(done.done, isFalse);

      await h.offerData();
      await h.answer();
      expect(done.done, isTrue);
    });

    test('is batched with tracks into one offer', () async {
      final (h, _) = await _joined();
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      unawaited(h.engine.negotiate((pc) async {}));
      await settle();
      expect(h.sentOf(_C.renegotiateTracks), hasLength(1));
    });
  });

  group('metadata (SPEC §11.6)', () {
    test('updatePeerMetadata stores, sends and emits', () async {
      final (h, _) = await _joined();
      h.engine.updatePeerMetadata(null);
      expect(h.localTracks.peerMetadata, isNull);
      expect(
        h
            .sentOf(_C.updateEndpointMetadata)
            .single
            .updateEndpointMetadata
            .metadataJson,
        'null',
      );
      expect(h.events.whereType<LocalPeerMetadataChanged>(), hasLength(1));
    });

    test('updateTrackMetadata on a pending track only stores it; the offer '
        'carries it and no event is emitted', () async {
      final (h, _) = await _joined();
      unawaited(h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera));
      await settle();
      final id = h.localTracks.tracks.single.trackId;
      h.engine.updateTrackMetadata(id, _microphone);
      expect(h.sentOf(_C.updateTrackMetadata), isEmpty);
      expect(h.localTracks.tracks.single.metadata, _microphone);
      expect(h.events.whereType<LocalTrackMetadataChanged>(), isEmpty);

      await h.offerData();
      expect(
        h.lastOffer.trackIdToMetadataJson[id],
        '{"type":"microphone","paused":false}',
      );
      await h.answer(h.lastOffer.midToTrackId);
      expect(h.sentOf(_C.updateTrackMetadata), isEmpty);
    });

    test(
      'updateTrackMetadata on an unknown track is an ArgumentError',
      () async {
        final (h, _) = await _joined();
        expect(
          () => h.engine.updateTrackMetadata('nope', null),
          throwsArgumentError,
        );
      },
    );
  });

  group('owner callbacks', () {
    test(
      'the terminal outcome is recorded when the event was handled',
      () async {
        final (h, _) = await _joined();
        h.onServerErrorHook = (_) {};
        expect(h.engine.endedBy, isNull);
        await h.engine.handleServerEvent(
          server.MediaEvent(error: server.MediaEvent_Error(message: 'boom')),
        );
        expect(h.engine.endedBy, EngineEnd.serverError);
        // The first outcome wins.
        await h.engine.handleServerEvent(
          server.MediaEvent(
            endpointRemoved: server.MediaEvent_EndpointRemoved(
              endpointId: 'local-peer',
            ),
          ),
        );
        expect(h.engine.endedBy, EngineEnd.serverError);
      },
    );

    test('removal of the local peer is recorded too', () async {
      final (h, _) = await _joined();
      await h.engine.handleServerEvent(
        server.MediaEvent(
          endpointRemoved: server.MediaEvent_EndpointRemoved(
            endpointId: 'local-peer',
          ),
        ),
      );
      expect(h.engine.endedBy, EngineEnd.localPeerRemoved);
    });

    test('onServerError runs outside the event task and may await '
        'engine work', () async {
      final (h, _) = await _joined();
      final order = <String>[];
      h.onServerErrorHook = (_) async {
        order.add('callback');
        await h.engine.ensurePeerConnection();
        order.add('awaited');
      };
      await h.engine.handleServerEvent(
        server.MediaEvent(error: server.MediaEvent_Error(message: 'boom')),
      );
      order.add('handled');
      await settle();
      // Outside the event task: awaiting engine work does not deadlock.
      expect(order, containsAll(['handled', 'callback', 'awaited']));
      expect(order.indexOf('callback'), lessThan(order.indexOf('awaited')));
    });

    test('onLocalPeerRemoved runs after the event was handled', () async {
      final (h, _) = await _joined();
      final order = <String>[];
      h.onLocalPeerRemovedHook = () => order.add('callback');
      await h.engine.handleServerEvent(
        server.MediaEvent(
          endpointRemoved: server.MediaEvent_EndpointRemoved(
            endpointId: 'local-peer',
          ),
        ),
      );
      order.add('handled');
      await settle();
      expect(order, unorderedEquals(['handled', 'callback']));
    });
  });

  group('teardown (SPEC §3.3)', () {
    test(
      "close disposes the streams the engine created, not the caller's",
      () async {
        final (h, _) = await _joined();
        final own = FakeMediaStream('own');
        h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera).ignore();
        h.engine
            .addTrack(FakeMediaTrack.video(), metadata: _camera, stream: own)
            .ignore();
        await settle();
        final created = h.rtc.localStreams.single;
        await h.engine.close();
        expect(created.disposed, isTrue);
        expect(created.tracks, isEmpty);
        expect(own.disposed, isFalse);
        expect(own.tracks, isEmpty);
      },
    );

    test('close during an in-flight createOffer is quiet', () async {
      final rtc = _GatedRtcAdapter();
      final logs = <String>[];
      final h = EngineHarness(
        rtc: rtc,
        logger: FishjamLogger(
          enabled: true,
          sink: (level, message, {error, stackTrace}) =>
              logs.add('${level.name} $message'),
        ),
      );
      await h.join();
      final gate = rtc.offerGate = Completer<void>();
      unawaited(h.offerData());
      await settle();
      await h.engine.close();
      gate.completeError(StateError('peer connection closed'));
      await settle();
      expect(logs.where((l) => l.startsWith('error')), isEmpty);
      expect(h.events.whereType<ConnectionError>(), isEmpty);
      expect(h.connectionFailures, isEmpty);
    });

    test('sendDisconnect sends disconnect', () async {
      final (h, _) = await _joined();
      h.engine.sendDisconnect();
      expect(h.sent.last.whichContent(), _C.disconnect);
    });

    test('close fails pending commands, closes the connection and sends '
        'nothing afterwards', () async {
      final (h, _) = await _joined();
      await h.offerData();
      await h.answer();
      final added = _Outcome(
        h.engine.addTrack(FakeMediaTrack.video(), metadata: _camera),
      );
      await settle();

      await h.engine.close();
      await settle();
      expect(added.error, isA<StateError>());
      expect('${added.error}', contains('disconnected'));
      expect(h.pc.isClosed, isTrue);

      final sentBefore = h.sent.length;
      h.engine
        ..updatePeerMetadata({'late': true})
        ..sendDisconnect();
      expect(h.sent, hasLength(sentBefore));
      await expectLater(
        h.engine.addTrack(FakeMediaTrack.audio()),
        throwsStateError,
      );
    });

    test('close before connected fails joined', () async {
      final h = EngineHarness();
      final joined = h.engine.joined;
      await h.engine.close();
      await expectLater(joined, throwsStateError);
    });

    test('a connection created while closing is closed', () async {
      final (h, _) = await _joined();
      final pc = h.engine.ensurePeerConnection();
      await h.engine.close();
      await expectLater(pc, throwsStateError);
      expect(h.rtc.peerConnections.every((p) => p.isClosed), isTrue);
    });
  });
}

server.MediaEvent _offerData() => server.MediaEvent(
  offerData: server.MediaEvent_OfferData(
    tracksTypes: server.MediaEvent_OfferData_TrackTypes(),
  ),
);

/// Holds `createOffer` on [offerGate] when it is set.
class _GatedRtcAdapter extends FakeRtcAdapter {
  Completer<void>? offerGate;

  @override
  Future<RtcPeerConnection> createPeerConnection(
    RtcConfiguration config,
  ) async {
    final pc = _GatedPeerConnection(config, this);
    peerConnections.add(pc);
    return pc;
  }
}

class _GatedPeerConnection extends FakePeerConnection {
  _GatedPeerConnection(super.configuration, this._adapter);

  final _GatedRtcAdapter _adapter;

  @override
  Future<SessionDescription> createOffer() async {
    await _adapter.offerGate?.future;
    return await super.createOffer();
  }
}

/// Fails every `endpointAdded`.
class _FailingEndpointAdded extends RemoteStore {
  _FailingEndpointAdded({
    required super.logger,
    required super.emit,
    required super.sendMediaEvent,
  });

  @override
  void endpointAdded(server.MediaEvent_EndpointAdded event) =>
      throw StateError('endpointAdded failed');
}
