// End-to-end test against a running Fishjam server. Run it with
// tool/run_integration.sh (see integration_test/README.md).
import 'dart:convert';
import 'dart:typed_data';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

/// Fishjam ID (resolved like the server SDKs do) or a full server URL,
/// e.g. `http://localhost:<port>`. `FISHJAM_URL` is accepted as an alias.
const _fishjamIdOrUrl = String.fromEnvironment(
  'FISHJAM_ID',
  defaultValue: String.fromEnvironment('FISHJAM_URL'),
);

/// Base URL serving both the REST API and the peer WebSocket.
final _fishjamUrl = fishjamUrlFromId(_fishjamIdOrUrl);

/// Management token of that server (used only by this test to create the
/// room and the peers, as an app backend would).
const _managementToken = String.fromEnvironment('FISHJAM_MANAGEMENT_TOKEN');

const _timeout = Duration(seconds: 20);

/// The parts of the server REST API a backend uses to set up a room.
class _Backend {
  final _http = http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_managementToken',
    'Content-Type': 'application/json',
  };

  Uri _url(String path) => Uri.parse(
    _fishjamUrl.endsWith('/') ? '$_fishjamUrl$path' : '$_fishjamUrl/$path',
  );

  Future<Map<String, Object?>> _post(String path, Object body) async {
    final response = await _http.post(
      _url(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode >= 300) {
      throw StateError('POST $path: ${response.statusCode} ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return json['data']! as Map<String, Object?>;
  }

  Future<String> createRoom() async {
    final data = await _post('room', <String, Object?>{});
    return (data['room']! as Map<String, Object?>)['id']! as String;
  }

  Future<String> createPeerToken(String roomId) async {
    final data = await _post('room/$roomId/peer', {
      'type': 'webrtc',
      'options': <String, Object?>{},
    });
    return data['token']! as String;
  }

  Future<void> deleteRoom(String roomId) async {
    await _http.delete(_url('room/$roomId'), headers: _headers);
    _http.close();
  }
}

/// The first event of type [T] matching [test], subscribed now.
Future<T> _next<T extends FishjamEvent>(
  FishjamClient client, [
  bool Function(T event)? test,
]) => client.events
    .where((e) => e is T && (test?.call(e) ?? true))
    .cast<T>()
    .first
    .timeout(_timeout);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two peers exchange data and audio, then leave', (_) async {
    expect(
      _fishjamIdOrUrl,
      isNotEmpty,
      reason: 'pass --dart-define=FISHJAM_ID (or FISHJAM_URL)',
    );
    expect(
      _managementToken,
      isNotEmpty,
      reason: 'pass --dart-define=FISHJAM_MANAGEMENT_TOKEN',
    );

    final backend = _Backend();
    final roomId = await backend.createRoom();
    final alice = FishjamClient(debug: true);
    final bob = FishjamClient(debug: true);
    MediaStream? microphone;
    try {
      // Join.
      await alice.connect(
        url: _fishjamUrl,
        token: await backend.createPeerToken(roomId),
        peerMetadata: {'name': 'alice'},
      );
      final aliceJoinedBob = _next<PeerJoined>(alice);
      await bob.connect(
        url: _fishjamUrl,
        token: await backend.createPeerToken(roomId),
        peerMetadata: {'name': 'bob'},
      );
      final alicePeerId = alice.localPeer!.id;
      final bobPeerId = bob.localPeer!.id;
      expect(bob.remotePeers.keys, contains(alicePeerId));
      expect((await aliceJoinedBob).peer.id, bobPeerId);

      // Data channels, both ways.
      await Future.wait([alice.createDataChannels(), bob.createDataChannels()]);
      expect(alice.dataChannelsReady && bob.dataChannelsReady, isTrue);
      final toBob = bob.dataStream(reliable: true).first.timeout(_timeout);
      final toAlice = alice.dataStream(reliable: false).first.timeout(_timeout);
      // A channel is open on the client before the server routes it to other
      // peers; messages sent in that gap are dropped by the server.
      await Future<void>.delayed(const Duration(seconds: 1));
      alice.publishData(utf8.encode('hello bob'), reliable: true);
      bob.publishData(Uint8List.fromList([1, 2, 3]), reliable: false);
      expect(utf8.decode(await toBob), 'hello bob');
      expect(await toAlice, [1, 2, 3]);

      // Alice publishes audio; Bob receives it.
      final bobReady = _next<TrackReady>(
        bob,
        (e) => e.track.endpointId == alicePeerId,
      );
      microphone = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      final trackId = await alice.addTrack(
        microphone.getAudioTracks().first,
        metadata: const TrackMetadata(type: TrackType.microphone),
      );
      final ready = (await bobReady).track;
      expect(ready.trackId, trackId);
      expect(ready.kind, MediaKind.audio);
      expect(ready.metadata?.type, TrackType.microphone);
      expect(ready.track, isNotNull);

      // Leave.
      final bobSawAliceLeave = _next<PeerLeft>(
        bob,
        (e) => e.peer.id == alicePeerId,
      );
      final aliceLeft = _next<Disconnected>(alice);
      await alice.leave();
      expect((await aliceLeft).reason, DisconnectReason.left);
      await bobSawAliceLeave;
      await bob.leave();
      expect(bob.status, ConnectionStatus.disconnected);
    } finally {
      await alice.dispose();
      await bob.dispose();
      for (final track in microphone?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await microphone?.dispose();
      await backend.deleteRoom(roomId);
    }
  });
}
