/// Wires an [RtcEngine] to [FakeRtcAdapter] and the real Tracks module
/// ([LocalTrackRegistry], [RemoteStore]), recording what the engine sends
/// and emits.
library;

import 'package:fishjam_client/src/engine/rtc_engine.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/tracks/local_track_registry.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';

import '../fakes/fake_rtc.dart';
import '../support/fixtures.dart';

/// Creates the [RemoteStore] of a harness.
typedef RemoteStoreFactory = RemoteStore Function({
  required FishjamLogger logger,
  required void Function(FishjamEvent event) emit,
  required void Function(peer.MediaEvent event) sendMediaEvent,
});

/// One engine plus its fakes.
class EngineHarness {
  /// Creates the harness; nothing is connected yet.
  EngineHarness({
    FishjamLogger? logger,
    FakeRtcAdapter? rtc,
    RemoteStoreFactory remoteStore = RemoteStore.new,
    Duration nativeCallTimeout = const Duration(seconds: 10),
    Duration iceDisconnectedTimeout = const Duration(seconds: 3),
  }) : logger = logger ?? FishjamLogger.disabled(),
       rtc = rtc ?? FakeRtcAdapter() {
    localTracks = LocalTrackRegistry(
      logger: this.logger,
      sendMediaEvent: sent.add,
      emit: events.add,
    );
    remote = remoteStore(
      logger: this.logger,
      emit: events.add,
      sendMediaEvent: sent.add,
    );
    engine = RtcEngine(
      adapter: this.rtc,
      nativeCallTimeout: nativeCallTimeout,
      iceDisconnectedTimeout: iceDisconnectedTimeout,
      logger: this.logger,
      sendMediaEvent: sent.add,
      emit: events.add,
      localTracks: localTracks,
      remote: remote,
      onServerError: (message) {
        serverErrors.add(message);
        onServerErrorHook?.call(message);
      },
      onLocalPeerRemoved: () {
        localPeerRemovals++;
        onLocalPeerRemovedHook?.call();
      },
      onConnectionFailed: connectionFailures.add,
    );
  }

  /// Logger passed to the engine.
  final FishjamLogger logger;

  /// The WebRTC fake.
  final FakeRtcAdapter rtc;

  /// Runs after a server error was recorded.
  void Function(String message)? onServerErrorHook;

  /// Runs when the local peer was removed.
  void Function()? onLocalPeerRemovedHook;

  /// Every event the engine emitted (plus `Joined`, added by [join]).
  final List<FishjamEvent> events = [];

  /// Every peer media event the engine sent.
  final List<peer.MediaEvent> sent = [];

  /// The local track registry.
  late final LocalTrackRegistry localTracks;

  /// The remote store.
  late final RemoteStore remote;

  /// The engine under test.
  late final RtcEngine engine;

  /// Messages passed to `onServerError`.
  final List<String> serverErrors = [];

  /// Messages passed to `onConnectionFailed`.
  final List<String> connectionFailures = [];

  /// Number of `onLocalPeerRemoved` calls.
  int localPeerRemovals = 0;

  /// The peer connection created by the engine.
  FakePeerConnection get pc => rtc.lastPeerConnection;

  /// Joins a room whose `connected` lists [endpoints] besides the local
  /// peer `local-peer`.
  Future<void> join({
    Map<String, server.MediaEvent_Endpoint> endpoints = const {},
  }) async {
    engine.connect({'name': 'alice'});
    await receive(
      server.MediaEvent(
        connected: server.MediaEvent_Connected(
          endpointId: 'local-peer',
          endpointIdToEndpoint: {
            'local-peer': server.MediaEvent_Endpoint(
              endpointType: 'exwebrtc',
              metadataJson: '{"peer":{"name":"alice"},"server":{"role":"x"}}',
            ),
            ...endpoints,
          }.entries,
          iceServers: [
            server.MediaEvent_IceServer(
              urls: ['turn:turn.test:3478'],
              username: 'user',
              credential: 'pass',
            ),
          ],
        ),
      ),
    );
    events.add(await engine.joined);
  }

  /// The server sends [event]; waits until it was handled.
  Future<void> receive(server.MediaEvent event) async {
    await engine.handleServerEvent(event);
    await settle();
  }

  /// `offerData` with the given receive counts.
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

  /// `sdpAnswer` mapping [mids].
  Future<void> answer([Map<String, String> mids = const {}]) => receive(
    server.MediaEvent(
      sdpAnswer: server.MediaEvent_SdpAnswer(
        sdp: 'v=0\r\ns=fake-answer\r\n',
        midToTrackId: mids.entries,
      ),
    ),
  );

  /// Sent events of [kind].
  List<peer.MediaEvent> sentOf(peer.MediaEvent_Content kind) =>
      sent.where((e) => e.whichContent() == kind).toList();

  /// The last `sdpOffer` sent.
  peer.MediaEvent_SdpOffer get lastOffer =>
      sentOf(peer.MediaEvent_Content.sdpOffer).last.sdpOffer;
}
