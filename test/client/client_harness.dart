/// A [FishjamClient] wired to [FakeTransportFactory] and [FakeRtcAdapter],
/// with helpers to script the server side.
library;

import 'dart:async';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';
import '../public/native_fakes.dart';
import '../support/fixtures.dart';

/// Id of the local peer in [ClientHarness.join].
const localPeerId = 'local-peer';

/// One client plus its fakes.
class ClientHarness {
  /// Creates the client; nothing is connected yet.
  ClientHarness({ReconnectConfig reconnect = const ReconnectConfig()})
    : rtc = FakeRtcAdapter() {
    client = FishjamClient.internal(
      reconnect: reconnect,
      rtcAdapter: rtc,
      transportFactory: transports.call,
    );
    _subscription = client.events.listen(events.add);
  }

  /// Transports created by the client.
  final transports = FakeTransportFactory();

  /// The WebRTC fake.
  final FakeRtcAdapter rtc;

  /// The client under test.
  late final FishjamClient client;

  /// Every event the client emitted.
  final List<FishjamEvent> events = [];

  late final StreamSubscription<FishjamEvent> _subscription;
  int _trackCounter = 0;

  /// The current transport.
  FakeTransport get transport => transports.last;

  /// The last peer connection.
  FakePeerConnection get pc => rtc.lastPeerConnection;

  /// Events of type [T].
  List<T> eventsOf<T extends FishjamEvent>() => events.whereType<T>().toList();

  /// Every peer media event sent on every transport, decoded.
  List<peer.MediaEvent> get sentMediaEvents => [
    for (final t in transports.created)
      for (final m in t.sentMessages)
        if (m.hasPeerMediaEvent()) m.peerMediaEvent,
  ];

  /// Sent peer media events of [kind].
  List<peer.MediaEvent> sentOf(peer.MediaEvent_Content kind) =>
      sentMediaEvents.where((e) => e.whichContent() == kind).toList();

  /// A new native track of [kind] (`audio` / `video`).
  NativeTrack track(String kind) =>
      NativeTrack('$kind-${_trackCounter++}', kind);

  /// Starts `connect()`, authenticates with [roomType] and joins with
  /// [endpoints] besides the local peer. Returns the `connect()` future.
  Future<void> join({
    PeerMessage_RoomType roomType = PeerMessage_RoomType.ROOM_TYPE_CONFERENCE,
    Map<String, server.MediaEvent_Endpoint> endpoints = const {},
    Object? peerMetadata = const {'name': 'alice'},
  }) async {
    final connected = client.connect(
      url: 'ws://fishjam.test',
      token: 'peer-token',
      peerMetadata: peerMetadata,
    );
    await settle();
    await authenticate(roomType: roomType);
    await connectedEvent(endpoints: endpoints);
    await connected;
  }

  /// The server accepts the `authRequest` on the current transport.
  Future<void> authenticate({
    PeerMessage_RoomType roomType = PeerMessage_RoomType.ROOM_TYPE_CONFERENCE,
  }) async {
    transport.receive(
      PeerMessage(authenticated: PeerMessage_Authenticated(roomType: roomType)),
    );
    await settle();
  }

  /// The server sends `connected` on the current transport.
  Future<void> connectedEvent({
    Map<String, server.MediaEvent_Endpoint> endpoints = const {},
  }) => receive(
    server.MediaEvent(
      connected: server.MediaEvent_Connected(
        endpointId: localPeerId,
        endpointIdToEndpoint: {
          localPeerId: server.MediaEvent_Endpoint(
            endpointType: 'exwebrtc',
            metadataJson: '{"peer":{"name":"alice"},"server":{}}',
          ),
          ...endpoints,
        }.entries,
      ),
    ),
  );

  /// The server sends [event]; waits until it was handled.
  Future<void> receive(server.MediaEvent event) async {
    transport.receive(PeerMessage(serverMediaEvent: event));
    await settle();
  }

  /// The server runs one negotiation cycle: `offerData`, then an answer
  /// that maps the mids of the client's offer.
  Future<void> negotiate({int audio = 0, int video = 0}) async {
    await receive(
      server.MediaEvent(
        offerData: server.MediaEvent_OfferData(
          tracksTypes: server.MediaEvent_OfferData_TrackTypes(
            audio: audio,
            video: video,
          ),
        ),
      ),
    );
    final offer = sentOf(peer.MediaEvent_Content.sdpOffer).last.sdpOffer;
    await receive(
      server.MediaEvent(
        sdpAnswer: server.MediaEvent_SdpAnswer(
          sdp: 'v=0\r\ns=fake-answer\r\n',
          midToTrackId: offer.midToTrackId.entries,
        ),
      ),
    );
  }

  /// Publishes a new track of [kind] and completes the negotiation.
  Future<String> publish(String kind, {TrackMetadata? metadata}) async {
    final id = client.addTrack(track(kind), metadata: metadata);
    await settle();
    await negotiate();
    return await id;
  }

  /// Stops listening to events.
  Future<void> dispose() => _subscription.cancel();
}
