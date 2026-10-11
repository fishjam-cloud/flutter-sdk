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
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../support/fixtures.dart';

typedef _C = peer.MediaEvent_Content;

/// RtcEngine with the real Tracks module (LocalTrackRegistry, RemoteStore
/// and the default LocalTrackFactory) on the WebRTC fake.
void main() {
  test('publish, receive, update, mute and remove with the real Tracks '
      'module', () async {
    final logger = FishjamLogger.disabled();
    final events = <FishjamEvent>[];
    final sent = <peer.MediaEvent>[];
    final rtc = FakeRtcAdapter();
    final engine = RtcEngine(
      adapter: rtc,
      logger: logger,
      sendMediaEvent: sent.add,
      emit: events.add,
      localTracks: LocalTrackRegistry(
        logger: logger,
        sendMediaEvent: sent.add,
        emit: events.add,
      ),
      remote: RemoteStore(
        logger: logger,
        emit: events.add,
        sendMediaEvent: sent.add,
      ),
    );
    List<peer.MediaEvent> sentOf(_C kind) =>
        sent.where((e) => e.whichContent() == kind).toList();
    peer.MediaEvent_SdpOffer lastOffer() => sentOf(_C.sdpOffer).last.sdpOffer;
    Future<void> receive(server.MediaEvent e) async {
      await engine.handleServerEvent(e);
      await settle();
    }

    Future<void> offerData({int audio = 0, int video = 0}) => receive(
      server.MediaEvent(
        offerData: server.MediaEvent_OfferData(
          tracksTypes: server.MediaEvent_OfferData_TrackTypes(
            audio: audio,
            video: video,
          ),
        ),
      ),
    );
    Future<void> answer(Map<String, String> mids) => receive(
      server.MediaEvent(
        sdpAnswer: server.MediaEvent_SdpAnswer(
          sdp: 'v=0\r\n',
          midToTrackId: mids.entries,
        ),
      ),
    );

    // Join: the local peer's metadata comes from connected.
    engine.connect({'name': 'alice'});
    await receive(
      server.MediaEvent(
        connected: server.MediaEvent_Connected(
          endpointId: 'me',
          endpointIdToEndpoint: {
            'me': server.MediaEvent_Endpoint(
              endpointType: 'exwebrtc',
              metadataJson: '{"peer":{"name":"alice"},"server":{"role":"x"}}',
            ),
            'bob': server.MediaEvent_Endpoint(
              endpointType: 'exwebrtc',
              metadataJson: '{"peer":{"name":"bob"},"server":null}',
            ),
          }.entries,
        ),
      ),
    );
    final joined = await engine.joined;
    expect(joined.peers.single.id, 'bob');
    expect(engine.localTracks.serverMetadata, {'role': 'x'});

    // Publish camera and microphone in one cycle.
    final camera = FakeMediaTrack.video();
    final cameraId = engine.addTrack(
      camera,
      metadata: const TrackMetadata(type: TrackType.camera),
    );
    final micId = engine.addTrack(
      FakeMediaTrack.audio(),
      metadata: const TrackMetadata(type: TrackType.microphone),
      maxBandwidth: const BandwidthLimit.single(64),
    );
    await settle();
    expect(sentOf(_C.renegotiateTracks), hasLength(1));
    await offerData();
    final offer = lastOffer();
    expect(offer.midToTrackId.values.toSet(), hasLength(2));
    final bitrates = {
      for (final e in offer.trackIdToBitrates.entries)
        e.key: e.value.variantBitrates.single.bitrate,
    };
    expect(bitrates.values.toSet(), {1536000, 50000});
    expect(
      rtc.lastPeerConnection.callsOf('addTransceiver').first.args,
      containsPair('sendEncodings', [
        {'active': true, 'maxBitrate': 1536000},
      ]),
    );
    await answer(Map.of(offer.midToTrackId));
    final cam = await cameraId;
    final mic = await micId;
    final added = events.whereType<LocalTrackAdded>().toList();
    expect(added.map((e) => e.track.trackId), [cam, mic]);
    expect(added[0].track.maxBandwidth, const BandwidthLimit.single(1500));
    expect(added[1].track.maxBandwidth, BandwidthLimit.unlimited);
    expect(added[0].track.rtcStream, same(added[1].track.rtcStream));

    // A remote track: TrackAdded, negotiation, TrackReady by mid.
    await receive(
      server.MediaEvent(
        tracksAdded: server.MediaEvent_TracksAdded(
          endpointId: 'bob',
          trackIdToTrack: {
            'bob:cam': server.MediaEvent_Track(
              metadataJson: '{"type":"camera","paused":false}',
            ),
          }.entries,
        ),
      ),
    );
    expect(events.whereType<TrackAdded>().single.track.trackId, 'bob:cam');
    await offerData(video: 1);
    final recv = rtc.lastPeerConnection.transceiverStates.last;
    expect(recv.direction, TransceiverDirection.recvonly);
    await answer({...lastOffer().midToTrackId, recv.mid!: 'bob:cam'});
    rtc.lastPeerConnection.emitTrack(mid: recv.mid!, kind: MediaKind.video);
    await settle();
    expect(events.whereType<TrackReady>().single.track.trackId, 'bob:cam');

    // Metadata of a negotiated track is sent at once.
    engine.updateTrackMetadata(
      cam,
      const TrackMetadata(type: TrackType.camera, paused: true),
    );
    expect(
      sentOf(_C.updateTrackMetadata).single.updateTrackMetadata.trackId,
      cam,
    );

    // Mute through the registry.
    await engine.replaceTrack(cam, null);
    expect(events.whereType<LocalTrackMuted>().single.trackId, cam);

    // Remove the microphone.
    final removed = engine.removeTrack(mic);
    await settle();
    await offerData(video: 1);
    expect(lastOffer().trackIdToMetadataJson.keys, [cam]);
    await answer(Map.of(lastOffer().midToTrackId));
    await removed;
    expect(events.whereType<LocalTrackRemoved>().single.trackId, mic);
    expect(engine.localTracks.tracks.map((t) => t.trackId), [cam]);

    unawaited(engine.close());
  });
}
