import 'package:fishjam_client/src/livestream_api.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_rtc.dart';
import '../public/native_fakes.dart';

final Uri _whip = Uri.parse('https://live.fishjam.test/api/whip');
final Uri _whep = Uri.parse('https://live.fishjam.test/api/whep/s1');

void main() {
  late FakeRtcAdapter adapter;
  final httpClient = MockClient(
    (request) async => request.method == 'POST'
        ? http.Response('v=0\r\n', 201, headers: {'location': '/res/1'})
        : http.Response('', 200),
  );

  setUp(() => adapter = FakeRtcAdapter());

  Future<void> completeGathering() async {
    await pumpEventQueue();
    adapter.lastPeerConnection.setIceGatheringState(IceGatheringState.complete);
    await pumpEventQueue();
  }

  test('publishLivestream publishes the tracks of the native stream', () async {
    final stream = NativeStream('s');
    await stream.addTrack(NativeTrack('cam', 'video'));
    await stream.addTrack(NativeTrack('mic', 'audio'));

    final publishing = publishLivestreamWith(
      stream,
      url: _whip,
      token: 'streamer-token',
      rtcAdapter: adapter,
      httpClient: httpClient,
    );
    await completeGathering();
    final result = await publishing;

    final transceivers = adapter.lastPeerConnection.callsOf('addTransceiver');
    expect(transceivers.map((c) => c.args['trackId']), ['cam', 'mic']);
    await result.stopPublishing();
  });

  test('receiveLivestream: a stream without a native counterpart throws on '
      'access', () async {
    final receiving = receiveLivestreamWith(
      url: _whep,
      rtcAdapter: adapter,
      httpClient: httpClient,
    );
    await completeGathering();
    adapter.lastPeerConnection.emitTrack(mid: '0', kind: MediaKind.video);
    final result = await receiving;

    expect(() => result.stream, throwsStateError);
    await result.stop();
  });
}
