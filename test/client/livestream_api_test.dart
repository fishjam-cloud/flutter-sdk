import 'package:fishjam_client/fishjam_client.dart';
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
  late List<http.Request> requests;
  late MockClient httpClient;

  setUp(() {
    adapter = FakeRtcAdapter();
    requests = [];
    httpClient = MockClient((request) async {
      requests.add(request);
      return request.method == 'POST'
          ? http.Response('v=0\r\n', 201, headers: {'location': '/res/1'})
          : http.Response('', 200);
    });
  });

  Future<void> completeGathering() async {
    await pumpEventQueue();
    adapter.lastPeerConnection.setIceGatheringState(IceGatheringState.complete);
    await pumpEventQueue();
  }

  test('publishLivestream publishes the native stream over WHIP', () async {
    final stream = NativeStream('s');
    await stream.addTrack(NativeTrack('cam', 'video'));
    await stream.addTrack(NativeTrack('mic', 'audio'));

    final publishing = publishLivestream(
      stream,
      url: _whip,
      token: 'streamer-token',
      rtcAdapter: adapter,
      httpClient: httpClient,
    );
    await completeGathering();
    final result = await publishing;

    final post = requests.single;
    expect(post.method, 'POST');
    expect(post.headers['Authorization'], 'Bearer streamer-token');
    final transceivers = adapter.lastPeerConnection.callsOf('addTransceiver');
    expect(transceivers.map((c) => c.args['trackId']), ['cam', 'mic']);
    expect(await result.getStatistics(), isEmpty);
    expect(result.connectionState, isA<Stream<PeerConnectionState>>());

    await result.stopPublishing();
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url, Uri.parse('https://live.fishjam.test/res/1'));
  });

  test('publishLivestream rejects a stream without tracks', () async {
    await expectLater(
      publishLivestream(
        NativeStream('empty'),
        url: _whip,
        token: 't',
        rtcAdapter: adapter,
        httpClient: httpClient,
      ),
      throwsArgumentError,
    );
  });

  test('receiveLivestream plays the WHEP stream and stops', () async {
    final receiving = receiveLivestream(
      url: _whep,
      rtcAdapter: adapter,
      httpClient: httpClient,
    );
    await completeGathering();
    adapter.lastPeerConnection.emitTrack(mid: '0', kind: MediaKind.video);
    final result = await receiving;

    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(await result.getStatistics(), isEmpty);
    expect(result.connectionState, isA<Stream<PeerConnectionState>>());
    // A fake stream has no flutter_webrtc counterpart.
    expect(() => result.stream, throwsStateError);

    await result.stop();
    expect(requests.last.method, 'DELETE');
  });

  test('receiveLivestream maps HTTP errors', () async {
    httpClient = MockClient((request) async => http.Response('', 404));
    final receiving = receiveLivestream(
      url: _whep,
      token: 'viewer-token',
      rtcAdapter: adapter,
      httpClient: httpClient,
    );
    final result = expectLater(
      receiving,
      throwsA(
        isA<LivestreamException>().having(
          (e) => e.error,
          'error',
          LivestreamError.streamNotFound,
        ),
      ),
    );
    await completeGathering();
    await result;
  });
}
