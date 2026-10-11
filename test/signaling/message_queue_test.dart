import 'dart:typed_data';

import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart'
    as shared;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:flutter_test/flutter_test.dart';

PeerMessage _media(peer.MediaEvent event) => PeerMessage(peerMediaEvent: event);

Uint8List _frame(int n) => Uint8List.fromList([n]);

void main() {
  group('bypassesQueue (SPEC §5)', () {
    test('authRequest and session set-up media events bypass', () {
      for (final message in [
        PeerMessage(authRequest: PeerMessage_AuthRequest(token: 't')),
        _media(peer.MediaEvent(connect: peer.MediaEvent_Connect())),
        _media(
          peer.MediaEvent(
            renegotiateTracks: peer.MediaEvent_RenegotiateTracks(),
          ),
        ),
        _media(peer.MediaEvent(sdpOffer: peer.MediaEvent_SdpOffer())),
        _media(peer.MediaEvent(candidate: shared.Candidate())),
      ]) {
        expect(bypassesQueue(message), isTrue, reason: '$message');
      }
    });

    test('every other message is queued', () {
      for (final message in [
        PeerMessage(rtcStatsReport: PeerMessage_RTCStatsReport(data: '{}')),
        _media(peer.MediaEvent(disconnect: peer.MediaEvent_Disconnect())),
        _media(
          peer.MediaEvent(
            updateEndpointMetadata: peer.MediaEvent_UpdateEndpointMetadata(),
          ),
        ),
        _media(
          peer.MediaEvent(
            updateTrackMetadata: peer.MediaEvent_UpdateTrackMetadata(),
          ),
        ),
        _media(peer.MediaEvent(trackBitrates: peer.MediaEvent_TrackBitrates())),
        _media(
          peer.MediaEvent(
            enableTrackVariant: peer.MediaEvent_EnableTrackVariant(),
          ),
        ),
        _media(
          peer.MediaEvent(
            disableTrackVariant: peer.MediaEvent_DisableTrackVariant(),
          ),
        ),
        _media(
          peer.MediaEvent(
            setTargetTrackVariant: peer.MediaEvent_SetTargetTrackVariant(),
          ),
        ),
        _media(peer.MediaEvent(unmuteTrack: peer.MediaEvent_UnmuteTrack())),
        _media(peer.MediaEvent()),
        PeerMessage(),
      ]) {
        expect(bypassesQueue(message), isFalse, reason: '$message');
      }
    });
  });

  group('MessageQueue (SPEC §5)', () {
    late List<Uint8List> written;
    late MessageQueue queue;

    setUp(() {
      written = [];
      queue = MessageQueue(send: written.add);
    });

    test('writes immediately when not held', () {
      queue
        ..enqueue(_frame(1))
        ..enqueue(_frame(2));

      expect(written, [_frame(1), _frame(2)]);
      expect(queue.length, 0);
      expect(queue.isHeld, isFalse);
    });

    test('holds frames and flushes them in FIFO order on release', () {
      queue
        ..hold()
        ..enqueue(_frame(1))
        ..enqueue(_frame(2));

      expect(queue.isHeld, isTrue);
      expect(written, isEmpty);
      expect(queue.length, 2);

      queue.release();
      expect(written, [_frame(1), _frame(2)]);
      expect(queue.length, 0);
      expect(queue.isHeld, isFalse);

      queue.enqueue(_frame(3));
      expect(written.last, _frame(3));
    });

    test('clear drops waiting frames and stops holding', () {
      queue
        ..hold()
        ..enqueue(_frame(1))
        ..clear();

      expect(queue.length, 0);
      expect(queue.isHeld, isFalse);
      queue
        ..release()
        ..enqueue(_frame(2));
      expect(written, [_frame(2)]);
    });

    test('a frame enqueued while flushing is written after older frames', () {
      final frames = <Uint8List>[];
      late MessageQueue reentrant;
      reentrant = MessageQueue(
        send: (frame) {
          frames.add(frame);
          if (frame[0] == 1) reentrant.enqueue(_frame(3));
        },
      );
      reentrant
        ..hold()
        ..enqueue(_frame(1))
        ..enqueue(_frame(2))
        ..release();

      expect(frames, [_frame(1), _frame(2), _frame(3)]);
    });
  });
}
