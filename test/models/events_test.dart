// Events are built with `new` on purpose: const instances are created at
// compile time and would not exercise the constructors.
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../support/fixtures.dart';

void main() {
  final peer = Peer(id: 'bob', type: 'exwebrtc', metadata: Metadata());
  final component = Component(id: 'c', type: 'hls', metadata: Metadata());
  final remote = RemoteTrackContext(
    trackId: 'bob:1',
    endpointId: 'bob',
    rawMetadata: null,
    simulcastConfig: SimulcastConfig.disabled(),
  );
  final local = LocalTrackContext(
    trackId: 'me:1',
    kind: MediaKind.video,
    track: FakeMediaTrack.video(),
    stream: null,
    metadata: TrackMetadata(type: TrackType.camera),
    simulcastConfig: SimulcastConfig.disabled(),
    maxBandwidth: BandwidthLimit.simulcast({Variant.low: 1}),
  );

  final events = <FishjamEvent>[
    AuthSucceeded(roomType: RoomType.audioOnly),
    AuthFailed(AuthErrorReason.expiredToken),
    JoinFailed(JoinErrorReason.nodeNotFound),
    Joined(peerId: 'me', peers: [peer], components: [component]),
    Disconnected(DisconnectReason.connectionLost, closeCode: 1006),
    ReconnectionStarted(),
    Reconnected(),
    ReconnectionFailed(),
    ConnectionError('ice'),
    ServerError('boom'),
    PeerJoined(peer),
    PeerLeft(peer),
    PeerUpdated(peer),
    ComponentAdded(component),
    ComponentRemoved(component),
    ComponentUpdated(component),
    TrackAdded(remote),
    TrackReady(remote),
    TrackRemoved(remote),
    TrackUpdated(remote),
    TrackEncodingChanged(remote),
    TrackVariantsChanged(remote),
    VoiceActivityChanged(remote),
    TargetTrackEncodingRequested('bob:1', Variant.low),
    LocalTrackAdded(local),
    LocalTrackRemoved('me:1'),
    LocalTrackReplaced('me:1', null),
    LocalTrackMuted('me:1'),
    LocalTrackUnmuted('me:1'),
    LocalTrackBandwidthSet('me:1', BandwidthLimit.single(100)),
    LocalTrackEncodingBandwidthSet('me:1', Variant.high, 900),
    LocalTrackEncodingEnabled('me:1', Variant.medium),
    LocalTrackEncodingDisabled('me:1', Variant.medium),
    LocalPeerMetadataChanged({'name': 'a'}),
    LocalTrackMetadataChanged('me:1', null),
    DataChannelsReady(),
    DataChannelsError(StateError('dc')),
  ];

  test('every event has a distinct, known name', () {
    final names = events.map((e) => describeEvent(e)['event']).toSet();

    expect(names, hasLength(events.length));
    expect(names, knownEventNames);
  });

  test('descriptions carry the event fields', () {
    expect(describeEvent(events[0]), {
      'event': 'AuthSucceeded',
      'roomType': 'audioOnly',
    });
    expect(describeEvent(events[4])['closeCode'], 1006);
    expect(describeEvent(events[24]), {
      'event': 'LocalTrackAdded',
      'track': {
        'trackId': 'me:1',
        'kind': 'video',
        'metadata': {'type': 'camera', 'paused': false},
        'simulcastConfig': {
          'enabled': false,
          'enabledVariants': <String>[],
          'disabledVariants': <String>[],
        },
        'maxBandwidth': {'low': 1},
        'muted': false,
      },
    });
    expect(describeEvent(events[29])['bandwidth'], 100);
    expect(describeEvent(events[36])['error'], contains('dc'));
  });
}
