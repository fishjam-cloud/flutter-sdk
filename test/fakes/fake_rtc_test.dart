import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_rtc.dart';

void main() {
  late FakeRtcAdapter adapter;
  late FakePeerConnection pc;

  setUp(() async {
    adapter = FakeRtcAdapter();
    pc = await adapter.createPeerConnection(
      const RtcConfiguration(
        iceServers: [
          IceServer(urls: ['turn:t'], username: 'u', credential: 'c'),
        ],
      ),
    ) as FakePeerConnection;
  });

  group('FakeRtcAdapter', () {
    test('records created peer connections and their configuration', () {
      expect(adapter.peerConnections, [pc]);
      expect(adapter.lastPeerConnection, same(pc));
      expect(pc.configuration.iceServers.single.urls, ['turn:t']);
    });

    test('creates local media streams', () async {
      final stream = await adapter.createLocalMediaStream('camera');
      final track = FakeMediaTrack.video();

      await stream.addTrack(track);

      expect(stream.tracks, [track]);
      await stream.removeTrack(track);
      expect(stream.tracks, isEmpty);
    });
  });

  group('FakeMediaTrack', () {
    test('has unique ids, a kind and can end', () {
      final a = FakeMediaTrack.audio();
      final b = FakeMediaTrack.video(id: 'cam');

      expect(a.id, isNot(b.id));
      expect(a.kind, MediaKind.audio);
      expect(b.id, 'cam');
      expect(b.isLive, isTrue);
      b.end();
      expect(b.isLive, isFalse);
    });
  });

  group('transceivers', () {
    test('send transceiver keeps track, encodings and streams', () async {
      final track = FakeMediaTrack.video();
      final stream = FakeMediaStream('s1');
      final t = await pc.addTransceiverWithTrack(
        track,
        TransceiverInit(
          direction: TransceiverDirection.sendonly,
          sendEncodings: const [
            RtpEncoding(rid: 'l', scaleResolutionDownBy: 4),
            RtpEncoding(rid: 'h'),
          ],
          streams: [stream],
        ),
      );

      expect(t.mid, isNull);
      expect(await t.getDirection(), TransceiverDirection.sendonly);
      expect(await t.getCurrentDirection(), isNull);
      expect(t.sender.track, same(track));
      expect(t.receiver.kind, MediaKind.video);
      expect(t.sender.getParameters().encodings.map((e) => e.rid), ['l', 'h']);
      expect(pc.calls.single.method, 'addTransceiver');
      expect(pc.calls.single.args, {
        'kind': 'video',
        'trackId': track.id,
        'direction': 'sendonly',
        'sendEncodings': [
          {'rid': 'l', 'active': true, 'scaleResolutionDownBy': 4.0},
          {'rid': 'h', 'active': true},
        ],
        'streams': ['s1'],
      });
    });

    test('a transceiver without encodings gets one default encoding', () async {
      final t = await pc.addTransceiverOfKind(
        MediaKind.audio,
        const TransceiverInit(direction: TransceiverDirection.recvonly),
      );

      expect(t.sender.track, isNull);
      expect(t.receiver.kind, MediaKind.audio);
      expect(t.receiver.track, isNotNull);
      expect(t.sender.getParameters().encodings, [const RtpEncoding()]);
    });

    test(
      'mids are assigned by setLocalDescription and views are snapshots',
      () async {
        final early = await pc.addTransceiverOfKind(
          MediaKind.video,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        await pc.addTransceiverWithTrack(
          FakeMediaTrack.audio(),
          const TransceiverInit(direction: TransceiverDirection.sendonly),
        );

        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        expect(early.mid, isNull, reason: 'objects keep the mid they had');
        final fresh = await pc.getTransceivers();
        expect(fresh.map((t) => t.mid), ['0', '1']);
        expect(pc.signalingState, SignalingState.haveLocalOffer);

        await pc.addTransceiverOfKind(
          MediaKind.audio,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        await pc.setLocalDescription(await pc.createOffer());
        expect((await pc.getTransceivers()).map((t) => t.mid), ['0', '1', '2']);
      },
    );

    test(
      'setRemoteDescription stabilizes and sets current directions',
      () async {
        final states = <SignalingState>[];
        pc.onSignalingState.listen(states.add);
        await pc.addTransceiverOfKind(
          MediaKind.video,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        await pc.setLocalDescription(await pc.createOffer());

        await pc.setRemoteDescription(
          const SessionDescription(type: SdpType.answer, sdp: 'answer'),
        );

        final t = (await pc.getTransceivers()).single;
        expect(await t.getCurrentDirection(), TransceiverDirection.recvonly);
        expect(pc.signalingState, SignalingState.stable);
        expect(pc.remoteDescription?.sdp, 'answer');
        await Future<void>.delayed(Duration.zero);
        expect(states, [SignalingState.haveLocalOffer, SignalingState.stable]);
      },
    );

    test('stop marks the transceiver stopped', () async {
      final t = await pc.addTransceiverOfKind(
        MediaKind.video,
        const TransceiverInit(direction: TransceiverDirection.recvonly),
      );

      await t.stop();

      final fresh = (await pc.getTransceivers()).single;
      expect(await fresh.getDirection(), TransceiverDirection.stopped);
      expect(await fresh.getCurrentDirection(), TransceiverDirection.stopped);
      expect(pc.calls.last.method, 'stopTransceiver');
    });

    test(
      'removeTrack clears the sender and drops the send direction',
      () async {
        final t = await pc.addTransceiverWithTrack(
          FakeMediaTrack.video(),
          const TransceiverInit(direction: TransceiverDirection.sendonly),
        );

        await pc.removeTrack(t.sender);

        final fresh = (await pc.getTransceivers()).single;
        expect(fresh.sender.track, isNull);
        expect(await fresh.getDirection(), TransceiverDirection.inactive);
        expect((await pc.getSenders()).single.track, isNull);
      },
    );
  });

  group('senders', () {
    late RtcRtpTransceiver t;

    setUp(() async {
      t = await pc.addTransceiverWithTrack(
        FakeMediaTrack.video(),
        const TransceiverInit(
          direction: TransceiverDirection.sendonly,
          sendEncodings: [
            RtpEncoding(rid: 'l'),
            RtpEncoding(rid: 'h'),
          ],
        ),
      );
    });

    test('setParameters stores and records parameters', () async {
      final params = t.sender.getParameters();
      await t.sender.setParameters(
        params.copyWith(
          encodings: [
            params.encodings[0].copyWith(active: false),
            params.encodings[1].copyWith(maxBitrateBps: 1000),
          ],
        ),
      );

      expect(t.sender.getParameters().encodings, const [
        RtpEncoding(rid: 'l', active: false),
        RtpEncoding(rid: 'h', maxBitrateBps: 1000),
      ]);
      final sender = t.sender as FakeRtpSender;
      expect(sender.parameterHistory, hasLength(1));
    });

    test('replaceTrack swaps the track and can be scripted to fail', () async {
      final next = FakeMediaTrack.video();
      await t.sender.replaceTrack(next);
      expect(t.sender.track, same(next));

      await t.sender.replaceTrack(null);
      expect(t.sender.track, isNull);

      (t.sender as FakeRtpSender).failNextReplaceTrack = StateError('boom');
      await expectLater(t.sender.replaceTrack(next), throwsStateError);
      expect(t.sender.track, isNull);
    });

    test('getStats returns the scripted sender stats', () async {
      const stats = RtcStats(
        id: 'ms',
        type: 'media-source',
        timestampMs: 1,
        values: {'kind': 'audio', 'audioLevel': 0.5},
      );
      (t.sender as FakeRtpSender).stats = [stats];

      expect(await t.sender.getStats(), [stats]);
    });
  });

  group('peer connection', () {
    test('offers are distinct and recorded', () async {
      final a = await pc.createOffer();
      final b = await pc.createOffer();

      expect(a.type, SdpType.offer);
      expect(a.sdp, isNot(b.sdp));
      expect(pc.calls.where((c) => c.method == 'createOffer'), hasLength(2));
    });

    test('scripted failures throw once', () async {
      pc.failNext('createOffer', StateError('nope'));

      await expectLater(pc.createOffer(), throwsStateError);
      await pc.createOffer();
    });

    test('remote candidates are recorded', () async {
      const c = IceCandidate(candidate: 'candidate:1', sdpMid: '0');
      await pc.addIceCandidate(c);

      expect(pc.remoteCandidates, [c]);
    });

    test('emits ICE candidates, tracks and state changes', () async {
      final candidates = <IceCandidate>[];
      final tracks = <RtcTrackEvent>[];
      final ice = <IceConnectionState>[];
      final conn = <PeerConnectionState>[];
      final gathering = <IceGatheringState>[];
      pc.onIceCandidate.listen(candidates.add);
      pc.onTrack.listen(tracks.add);
      pc.onIceConnectionState.listen(ice.add);
      pc.onConnectionState.listen(conn.add);
      pc.onIceGatheringState.listen(gathering.add);

      pc
        ..emitIceCandidate(const IceCandidate(candidate: 'c1'))
        ..emitTrack(mid: '0', kind: MediaKind.video, streamId: 'remote')
        ..setIceConnectionState(IceConnectionState.disconnected)
        ..setConnectionState(PeerConnectionState.failed)
        ..setIceGatheringState(IceGatheringState.complete);
      await Future<void>.delayed(Duration.zero);

      expect(candidates.single.candidate, 'c1');
      expect(tracks.single.mid, '0');
      expect(tracks.single.track.kind, MediaKind.video);
      expect(tracks.single.streams.single.id, 'remote');
      expect(ice, [IceConnectionState.disconnected]);
      expect(pc.iceConnectionState, IceConnectionState.disconnected);
      expect(conn, [PeerConnectionState.failed]);
      expect(pc.connectionState, PeerConnectionState.failed);
      expect(gathering, [IceGatheringState.complete]);
      expect(pc.iceGatheringState, IceGatheringState.complete);
    });

    test('getStats returns scripted stats', () async {
      const s = RtcStats(
        id: 'a',
        type: 'inbound-rtp',
        timestampMs: 0,
        values: {},
      );
      pc.stats = [s];

      expect(await pc.getStats(), [s]);
    });

    test('local description is available after setLocalDescription', () async {
      expect(await pc.getLocalDescription(), isNull);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      expect(await pc.getLocalDescription(), offer);
    });

    test('close completes every stream', () async {
      final done = Completer<void>();
      pc.onTrack.listen(null, onDone: done.complete);

      await pc.close();

      expect(pc.isClosed, isTrue);
      expect(pc.signalingState, SignalingState.closed);
      await done.future;
    });
  });

  group('data channels', () {
    test('created channels are recorded and scriptable', () async {
      final channel = await pc.createDataChannel(
        'lossy',
        const DataChannelInit(ordered: false, maxRetransmits: 0),
      ) as FakeDataChannel;
      final states = <DataChannelState>[];
      final messages = <Uint8List>[];
      channel.onStateChange.listen(states.add);
      channel.onMessage.listen(messages.add);

      expect(pc.dataChannels, [channel]);
      expect(channel.init.maxRetransmits, 0);
      expect(pc.calls.last.args, {
        'label': 'lossy',
        'ordered': false,
        'maxRetransmits': 0,
      });
      expect(channel.state, DataChannelState.connecting);

      channel
        ..open()
        ..receive(Uint8List.fromList([1, 2]));
      await channel.send(Uint8List.fromList([3]));
      await Future<void>.delayed(Duration.zero);

      expect(states, [DataChannelState.open]);
      expect(messages.single, [1, 2]);
      expect(channel.sent.single, [3]);
      expect(pc.calls.last.method, 'dataChannelSend');
    });

    test('sending on a channel that is not open throws', () async {
      final channel = await pc.createDataChannel(
        'reliable',
        const DataChannelInit(),
      );

      await expectLater(
        channel.send(Uint8List.fromList([1])),
        throwsStateError,
      );
    });

    test('remote close and local close end in closed state', () async {
      final a = await pc.createDataChannel(
        'reliable',
        const DataChannelInit(),
      ) as FakeDataChannel;
      final b = await pc.createDataChannel('lossy', const DataChannelInit());

      a.closeFromRemote();
      await b.close();

      expect(a.state, DataChannelState.closed);
      expect(b.state, DataChannelState.closed);
    });
  });
}
