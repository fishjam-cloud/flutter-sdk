/// Wires an [RtcEngine] to [FakeTransport], [FakeRtcAdapter] and the Tracks
/// fakes, with just enough signaling (auth, media event routing) and session
/// handling (server error, leave) to replay the golden fixtures at the
/// engine level.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fishjam_client/src/engine/rtc_engine.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/version.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';
import '../support/fixtures.dart';
import 'fake_tracks.dart';

/// One engine plus its fakes.
class EngineHarness {
  /// Creates the harness; nothing is connected yet.
  EngineHarness({FishjamLogger? logger})
    : logger = logger ?? FishjamLogger.disabled() {
    remote = FakeRemoteStore(emit: events.add);
    engine = RtcEngine(
      adapter: rtc,
      logger: this.logger,
      sendMediaEvent: _send,
      emit: events.add,
      localTracks: localTracks,
      remote: remote,
      createLocalTrack: fakeLocalTrackFactory,
      onServerError: (message) {
        serverErrors.add(message);
        unawaited(leave(DisconnectReason.serverError));
      },
      onLocalPeerRemoved: () => localPeerRemovals++,
      onConnectionFailed: connectionFailures.add,
    );
  }

  /// Logger passed to the engine.
  final FishjamLogger logger;

  /// Transports created by [connect].
  final transports = FakeTransportFactory();

  /// The WebRTC fake.
  final rtc = FakeRtcAdapter();

  /// Every event the engine (or this harness) emitted.
  final List<FishjamEvent> events = [];

  /// Every peer media event the engine sent, decoded.
  final List<peer.MediaEvent> sent = [];

  /// The local track registry fake.
  final localTracks = FakeLocalTrackRegistry();

  /// The remote store fake.
  late final FakeRemoteStore remote;

  /// The engine under test.
  late final RtcEngine engine;

  /// Messages passed to `onServerError`.
  final List<String> serverErrors = [];

  /// Messages passed to `onConnectionFailed`.
  final List<String> connectionFailures = [];

  /// Number of `onLocalPeerRemoved` calls.
  int localPeerRemovals = 0;

  Object? _peerMetadata;

  /// The current transport.
  FakeTransport get transport => transports.last;

  /// The peer connection created by the engine.
  FakePeerConnection get pc => rtc.lastPeerConnection;

  void _send(peer.MediaEvent event) {
    sent.add(event);
    if (transports.created.isEmpty) return;
    transport.send(PeerMessage(peerMediaEvent: event).writeToBuffer());
  }

  /// Opens a transport, authenticates and completes on `connected`.
  Future<void> connect({
    String url = 'ws://fishjam.test',
    String token = 'peer-token',
    Object? peerMetadata,
  }) async {
    final transport = transports();
    await transport.connect(Uri.parse(url));
    transport.incoming.listen(_onFrame);
    _peerMetadata = peerMetadata;
    transport.send(
      PeerMessage(
        authRequest: PeerMessage_AuthRequest(
          token: token,
          sdkVersion: sdkVersion,
        ),
      ).writeToBuffer(),
    );
    events.add(await engine.joined);
  }

  void _onFrame(List<int> frame) {
    final message = PeerMessage.fromBuffer(frame);
    switch (message.whichContent()) {
      case PeerMessage_Content.authenticated:
        events.add(const AuthSucceeded(roomType: RoomType.conference));
        engine.connect(_peerMetadata);
      case PeerMessage_Content.serverMediaEvent:
        unawaited(engine.handleServerEvent(message.serverMediaEvent));
      case _:
        break;
    }
  }

  /// Joins a room whose `connected` lists [endpoints] besides the local
  /// peer `local-peer`.
  Future<void> join({
    Map<String, server.MediaEvent_Endpoint> endpoints = const {},
  }) async {
    final joined = connect(peerMetadata: {'name': 'alice'});
    await settle();
    transport.receive(PeerMessage(authenticated: PeerMessage_Authenticated()));
    await settle();
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
    await joined;
  }

  /// The server sends [event]; waits until it was handled.
  Future<void> receive(server.MediaEvent event) async {
    transport.receive(PeerMessage(serverMediaEvent: event));
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

  /// Leaves: sends `disconnect` first, then tears down (SPEC §3.3).
  Future<void> leave([DisconnectReason reason = DisconnectReason.left]) async {
    engine.sendDisconnect();
    await engine.close();
    await transport.close();
    events.add(Disconnected(reason));
  }

  /// Performs a fixture `api` step.
  Future<Object?> api(ApiStep step, Bindings bindings) {
    final args = bindings.substitute(step.args)! as Map<String, Object?>;
    switch (step.call) {
      case 'connect':
        return connect(
          url: args['url']! as String,
          token: args['token']! as String,
          peerMetadata: args['peerMetadata'],
        );
      case 'leave':
        return leave();
      case 'addTrack':
        final kind = MediaKind.values.byName(args['kind']! as String);
        return engine.addTrack(
          FakeMediaTrack(kind: kind),
          metadata: TrackMetadata.tryParse(args['metadata']),
          simulcastConfig: _simulcast(args['simulcastConfig']),
          maxBandwidth: _bandwidth(args['maxBandwidth']),
        );
      case 'removeTrack':
        return engine.removeTrack(args['trackId']! as String);
      case 'updatePeerMetadata':
        engine.updatePeerMetadata(args['metadata']);
        return Future.value();
      case 'updateTrackMetadata':
        engine.updateTrackMetadata(
          args['trackId']! as String,
          TrackMetadata.tryParse(args['metadata']),
        );
        return Future.value();
      default:
        throw UnimplementedError('engine harness: ${step.call}');
    }
  }

  /// Replays fixture [name] without the steps at [skip] (steps covered by
  /// other modules).
  Future<void> replay(String name, {Set<int> skip = const {}}) async {
    final json = jsonDecode(
      File('$fixturesDirectory/$name.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final steps = json['steps']! as List<Object?>;
    json['steps'] = [
      for (var i = 0; i < steps.length; i++)
        if (!skip.contains(i)) steps[i],
    ];
    late final FixtureReplayer replayer;
    replayer = FixtureReplayer(
      fixture: Fixture.parse(jsonEncode(json)),
      transports: transports,
      rtc: rtc,
      events: events,
      onApi: (step) => api(step, replayer.bindings),
    );
    await replayer.run();
  }
}

SimulcastConfig _simulcast(Object? json) {
  if (json is! Map<String, Object?>) return const SimulcastConfig.disabled();
  return SimulcastConfig(
    enabled: json['enabled']! as bool,
    enabledVariants: [
      for (final v in (json['enabledVariants'] as List<Object?>?) ?? const [])
        Variant.values.byName(v! as String),
    ],
  );
}

BandwidthLimit _bandwidth(Object? json) => switch (json) {
  null => BandwidthLimit.unlimited,
  final int kbps => BandwidthLimit.single(kbps),
  final Map<String, Object?> map => BandwidthLimit.simulcast({
    for (final e in map.entries) Variant.values.byName(e.key): e.value! as int,
  }),
  _ => throw ArgumentError(json),
};
