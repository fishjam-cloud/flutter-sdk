import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_rtc.dart';

void main() {
  late FakePeerConnection pc;

  setUp(() async {
    pc = await FakeRtcAdapter().createPeerConnection(
      const RtcConfiguration(),
    ) as FakePeerConnection;
  });

  group('transceivers', () {
    test('model flutter_webrtc on Android: a lookup by mid disposes the '
        'handles of transceivers without a mid', () async {
      final pc = FakePeerConnection(const RtcConfiguration());
      await pc.addTransceiverOfKind(
        MediaKind.audio,
        const TransceiverInit(direction: TransceiverDirection.recvonly),
      );
      await pc.setLocalDescription(
        const SessionDescription(type: SdpType.offer, sdp: 'v=0'),
      );
      await pc.addTransceiverOfKind(
        MediaKind.video,
        const TransceiverInit(direction: TransceiverDirection.recvonly),
      );
      final [negotiated, fresh] = await pc.getTransceivers();
      expect(negotiated.mid, isNotNull);
      expect(fresh.mid, isNull);

      await fresh.getDirection();
      await negotiated.getDirection();
      await expectLater(fresh.getDirection(), throwsStateError);
      await expectLater(fresh.stop(), throwsStateError);
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
}
