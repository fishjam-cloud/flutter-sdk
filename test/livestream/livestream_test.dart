import 'dart:async';

import 'package:fishjam_client/src/livestream/livestream.dart';
import 'package:fishjam_client/src/livestream/whep.dart';
import 'package:fishjam_client/src/livestream/whip.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_rtc.dart';

const answerSdp = 'v=0\r\ns=answer\r\n';
final Uri whipUrl = Uri.parse('https://live.fishjam.test/api/whip');
final Uri whepUrl = Uri.parse('https://live.fishjam.test/api/whep/stream-1');

TypeMatcher<LivestreamException> livestreamError(
  LivestreamError error, {
  int? statusCode,
}) => isA<LivestreamException>()
    .having((e) => e.error, 'error', error)
    .having((e) => e.statusCode, 'statusCode', statusCode);

void main() {
  late FakeRtcAdapter adapter;
  late List<http.Request> requests;
  late http.Response Function(http.Request request) respond;
  late MockClient client;
  late List<String> logs;
  late FishjamLogger logger;

  setUp(() {
    adapter = FakeRtcAdapter();
    requests = [];
    respond = (request) => request.method == 'POST'
        ? http.Response(
            answerSdp,
            201,
            headers: {'location': '/api/resource/res-1'},
          )
        : http.Response('', 200);
    client = MockClient((request) async {
      requests.add(request);
      return respond(request);
    });
    logs = [];
    logger = FishjamLogger(
      enabled: true,
      sink: (level, message, {error, stackTrace}) => logs.add(message),
    );
  });

  /// Lets the SDK reach the "wait for ICE gathering" step, then completes it.
  Future<void> completeGathering() async {
    await pumpEventQueue();
    adapter.lastPeerConnection.setIceGatheringState(IceGatheringState.complete);
    await pumpEventQueue();
  }

  group('livestreamErrorForStatus (SPEC §19)', () {
    test('maps the documented statuses', () {
      expect(
        livestreamErrorForStatus(401, publishing: true),
        LivestreamError.unauthorized,
      );
      expect(
        livestreamErrorForStatus(404, publishing: false),
        LivestreamError.streamNotFound,
      );
      expect(
        livestreamErrorForStatus(409, publishing: true),
        LivestreamError.streamerAlreadyConnected,
      );
    });

    test('409 while receiving and anything else is unknown', () {
      expect(
        livestreamErrorForStatus(409, publishing: false),
        LivestreamError.unknownError,
      );
      expect(
        livestreamErrorForStatus(500, publishing: true),
        LivestreamError.unknownError,
      );
      expect(
        livestreamErrorForStatus(400, publishing: false),
        LivestreamError.unknownError,
      );
    });
  });

  group('publishWhip', () {
    late FakeMediaStream stream;
    late FakeMediaTrack video;
    late FakeMediaTrack audio;

    setUp(() async {
      stream = FakeMediaStream();
      video = FakeMediaTrack.video();
      audio = FakeMediaTrack.audio();
      await stream.addTrack(video);
      await stream.addTrack(FakeMediaTrack.video());
      await stream.addTrack(audio);
    });

    Future<WhipPublication> publish({MockClient? httpClient}) async {
      final future = publishWhip(
        adapter: adapter,
        stream: stream,
        url: whipUrl,
        token: 'streamer-token',
        httpClient: httpClient ?? client,
        logger: logger,
      )..ignore(); // failures are asserted by the caller
      await completeGathering();
      return await future;
    }

    test('throws ArgumentError for a stream without tracks', () async {
      await expectLater(
        publishWhip(
          adapter: adapter,
          stream: FakeMediaStream(),
          url: whipUrl,
          token: 't',
          httpClient: client,
        ),
        throwsArgumentError,
      );
      expect(adapter.peerConnections, isEmpty);
    });

    test('sends the first video and first audio track sendonly', () async {
      await publish();

      expect(
        adapter.lastPeerConnection.callsOf('addTransceiver').map((c) => c.args),
        [
          {'kind': 'video', 'trackId': video.id, 'direction': 'sendonly'},
          {'kind': 'audio', 'trackId': audio.id, 'direction': 'sendonly'},
        ],
      );
    });

    test('publishes an audio-only stream', () async {
      stream = FakeMediaStream();
      await stream.addTrack(audio);
      await publish();

      expect(adapter.lastPeerConnection.callsOf('addTransceiver').single.args, {
        'kind': 'audio',
        'trackId': audio.id,
        'direction': 'sendonly',
      });
    });

    test('POSTs the gathered offer after ICE gathering completes', () async {
      final future = publishWhip(
        adapter: adapter,
        stream: stream,
        url: whipUrl,
        token: 'streamer-token',
        httpClient: client,
      );
      await pumpEventQueue();
      expect(requests, isEmpty);

      final pc = adapter.lastPeerConnection
        ..setIceGatheringState(IceGatheringState.gathering);
      await pumpEventQueue();
      expect(requests, isEmpty);

      pc.setIceGatheringState(IceGatheringState.complete);
      await future;

      final post = requests.single;
      expect(post.method, 'POST');
      expect(post.url, whipUrl);
      expect(post.headers['Content-Type'], 'application/sdp');
      expect(post.headers['Authorization'], 'Bearer streamer-token');
      expect(post.body, pc.localDescription!.sdp);
      expect(
        pc.calls.map((c) => c.method),
        containsAllInOrder(['createOffer', 'setLocalDescription']),
      );
    });

    test('does not wait when gathering already completed', () async {
      final future = publishWhip(
        adapter: adapter,
        stream: stream,
        url: whipUrl,
        token: 't',
        httpClient: client,
      );
      // The connection exists after the first microtasks; mark gathering
      // complete before the offer is applied.
      while (adapter.peerConnections.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      adapter.lastPeerConnection.setIceGatheringState(
        IceGatheringState.complete,
      );
      await future;
      expect(requests, hasLength(1));
    });

    test('applies the answer', () async {
      await publish();
      expect(
        adapter.lastPeerConnection.remoteDescription,
        const SessionDescription(type: SdpType.answer, sdp: answerSdp),
      );
    });

    test('stopPublishing DELETEs the resolved Location and closes', () async {
      final publication = await publish();
      await publication.stopPublishing();

      final delete = requests.last;
      expect(delete.method, 'DELETE');
      expect(
        delete.url,
        Uri.parse('https://live.fishjam.test/api/resource/res-1'),
      );
      expect(delete.headers['Authorization'], 'Bearer streamer-token');
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });

    test('stopPublishing is idempotent', () async {
      final publication = await publish();
      await publication.stopPublishing();
      await publication.stopPublishing();
      expect(requests.where((r) => r.method == 'DELETE'), hasLength(1));
    });

    test('uses an absolute Location as is', () async {
      respond = (request) => request.method == 'POST'
          ? http.Response(
              answerSdp,
              201,
              headers: {'location': 'https://other.test/resource/x'},
            )
          : http.Response('', 200);
      final publication = await publish();
      await publication.stopPublishing();
      expect(requests.last.url, Uri.parse('https://other.test/resource/x'));
    });

    test('without a Location, stop only closes the connection', () async {
      respond = (request) => http.Response(answerSdp, 201);
      final publication = await publish();
      await publication.stopPublishing();
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });

    test('a failed DELETE is logged and the connection still closes', () async {
      respond = (request) => request.method == 'POST'
          ? http.Response(answerSdp, 201, headers: {'location': '/r'})
          : http.Response('nope', 500);
      final publication = await publish();
      await publication.stopPublishing();
      expect(adapter.lastPeerConnection.isClosed, isTrue);
      expect(logs.where((l) => l.contains('DELETE')), isNotEmpty);
    });

    test(
      'a DELETE network error is logged and the connection still closes',
      () async {
        final publication = await publish(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.method == 'DELETE') {
              throw http.ClientException('offline');
            }
            return http.Response(answerSdp, 201, headers: {'location': '/r'});
          }),
        );
        await publication.stopPublishing();
        expect(adapter.lastPeerConnection.isClosed, isTrue);
        expect(logs.where((l) => l.contains('DELETE')), isNotEmpty);
      },
    );

    for (final (status, error) in [
      (401, LivestreamError.unauthorized),
      (404, LivestreamError.streamNotFound),
      (409, LivestreamError.streamerAlreadyConnected),
      (500, LivestreamError.unknownError),
    ]) {
      test('status $status fails with $error and closes', () async {
        respond = (request) => http.Response('error', status);
        await expectLater(
          publish(),
          throwsA(livestreamError(error, statusCode: status)),
        );
        expect(adapter.lastPeerConnection.isClosed, isTrue);
      });
    }

    test('a network error is unknownError with the cause', () async {
      final failing = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      await expectLater(
        publish(httpClient: failing),
        throwsA(
          livestreamError(LivestreamError.unknownError)
              .having((e) => e.cause, 'cause', isA<http.ClientException>()),
        ),
      );
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });

    test('a WebRTC failure is unknownError and closes', () async {
      final future = publishWhip(
        adapter: adapter,
        stream: stream,
        url: whipUrl,
        token: 't',
        httpClient: client,
      )..ignore(); // asserted below
      // Fail the answer: the resource was created, so it is deleted again.
      while (adapter.peerConnections.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      adapter.lastPeerConnection.failNext(
        'setRemoteDescription',
        StateError('bad answer'),
      );
      await completeGathering();
      await expectLater(
        future,
        throwsA(livestreamError(LivestreamError.unknownError)),
      );
      expect(adapter.lastPeerConnection.isClosed, isTrue);
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
    });

    test('exposes statistics and connection state', () async {
      final publication = await publish();
      final pc = adapter.lastPeerConnection
        ..stats = const [
          RtcStats(id: 'o', type: 'outbound-rtp', timestampMs: 1, values: {}),
        ];
      expect(await publication.getStatistics(), pc.stats);

      final states = <PeerConnectionState>[];
      publication.connectionState.listen(states.add);
      pc.setConnectionState(PeerConnectionState.connected);
      await pumpEventQueue();
      expect(states, [PeerConnectionState.connected]);
    });
  });

  group('receiveWhep', () {
    Future<WhepPlayback> receive({String? token, bool emitTrack = true}) async {
      final future = receiveWhep(
        adapter: adapter,
        url: whepUrl,
        token: token,
        httpClient: client,
        logger: logger,
      )..ignore(); // failures are asserted by the caller
      await completeGathering();
      if (emitTrack) {
        adapter.lastPeerConnection.emitTrack(
          mid: '0',
          kind: MediaKind.video,
          streamId: 'live',
        );
      }
      return await future;
    }

    test('receives video and audio recvonly', () async {
      await receive();
      expect(
        adapter.lastPeerConnection.callsOf('addTransceiver').map((c) => c.args),
        [
          {'kind': 'video', 'direction': 'recvonly'},
          {'kind': 'audio', 'direction': 'recvonly'},
        ],
      );
    });

    test('POSTs the offer, without a bearer header when no token', () async {
      await receive();
      final post = requests.single;
      expect(post.url, whepUrl);
      expect(post.headers['Content-Type'], 'application/sdp');
      expect(post.headers.containsKey('Authorization'), isFalse);
    });

    test('sends the bearer header when a token is given', () async {
      final playback = await receive(token: 'viewer-token');
      await playback.stop();
      expect(requests.first.headers['Authorization'], 'Bearer viewer-token');
      expect(requests.last.headers['Authorization'], 'Bearer viewer-token');
    });

    test('completes with the first remote stream', () async {
      final playback = await receive();
      expect(playback.stream.id, 'live');
    });

    test('does not complete before a stream arrives', () async {
      var done = false;
      unawaited(
        receiveWhep(
          adapter: adapter,
          url: whepUrl,
          httpClient: client,
        ).then((_) => done = true),
      );
      await completeGathering();
      expect(requests, hasLength(1));
      expect(done, isFalse);

      adapter.lastPeerConnection.emitTrack(mid: '1', kind: MediaKind.audio);
      await pumpEventQueue();
      expect(done, isTrue);
    });

    test('stop DELETEs the resource and closes', () async {
      final playback = await receive();
      await playback.stop();
      expect(requests.last.method, 'DELETE');
      expect(
        requests.last.url,
        Uri.parse('https://live.fishjam.test/api/resource/res-1'),
      );
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });

    test('409 while receiving is unknownError', () async {
      respond = (request) => http.Response('busy', 409);
      await expectLater(
        receive(emitTrack: false),
        throwsA(livestreamError(LivestreamError.unknownError, statusCode: 409)),
      );
    });

    test('401 and 404 are mapped', () async {
      respond = (request) => http.Response('no', 401);
      await expectLater(
        receive(emitTrack: false),
        throwsA(livestreamError(LivestreamError.unauthorized, statusCode: 401)),
      );
      respond = (request) => http.Response('no', 404);
      await expectLater(
        receive(emitTrack: false),
        throwsA(
          livestreamError(LivestreamError.streamNotFound, statusCode: 404),
        ),
      );
      expect(adapter.peerConnections.every((pc) => pc.isClosed), isTrue);
    });

    test('a failed connection before any stream fails and cleans up', () async {
      final future = receiveWhep(
        adapter: adapter,
        url: whepUrl,
        httpClient: client,
      );
      final failed = expectLater(
        future,
        throwsA(livestreamError(LivestreamError.unknownError)),
      );
      await completeGathering();
      adapter.lastPeerConnection.setConnectionState(PeerConnectionState.failed);
      await failed;
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });

    test('exposes statistics and connection state', () async {
      final playback = await receive();
      final pc = adapter.lastPeerConnection;
      expect(await playback.getStatistics(), isEmpty);
      final states = <PeerConnectionState>[];
      playback.connectionState.listen(states.add);
      pc.setConnectionState(PeerConnectionState.connected);
      await pumpEventQueue();
      expect(states, [PeerConnectionState.connected]);
    });
  });

  group('timeouts (SPEC §19)', () {
    test('defaults', () {
      expect(defaultIceGatheringTimeout, const Duration(seconds: 3));
      expect(defaultFirstStreamTimeout, const Duration(seconds: 10));
    });

    test(
      'WHIP sends the offer gathered so far when gathering times out',
      () async {
        final stream = FakeMediaStream();
        await stream.addTrack(FakeMediaTrack.audio());
        await publishWhip(
          adapter: adapter,
          stream: stream,
          url: whipUrl,
          token: 't',
          httpClient: client,
          logger: logger,
          iceGatheringTimeout: const Duration(milliseconds: 20),
        );
        expect(
          requests.single.body,
          adapter.lastPeerConnection.localDescription!.sdp,
        );
        expect(logs.where((l) => l.contains('ICE gathering')), isNotEmpty);
      },
    );

    test('WHEP gathering timeout also proceeds', () async {
      final future = receiveWhep(
        adapter: adapter,
        url: whepUrl,
        httpClient: client,
        iceGatheringTimeout: const Duration(milliseconds: 20),
      );
      while (requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      adapter.lastPeerConnection.emitTrack(mid: '0', kind: MediaKind.video);
      await future;
    });

    test('WHEP fails when no stream arrives in time and cleans up', () async {
      final future = receiveWhep(
        adapter: adapter,
        url: whepUrl,
        httpClient: client,
        firstStreamTimeout: const Duration(milliseconds: 20),
      );
      final failed = expectLater(
        future,
        throwsA(
          livestreamError(LivestreamError.unknownError)
              .having((e) => e.cause, 'cause', isA<TimeoutException>()),
        ),
      );
      await completeGathering();
      await failed;
      expect(requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(adapter.lastPeerConnection.isClosed, isTrue);
    });
  });
}
