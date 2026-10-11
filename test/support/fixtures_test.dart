import 'dart:convert';

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';
import 'fixtures.dart';

void main() {
  group('Bindings.match', () {
    test('literals, lists and subset objects', () {
      final b = Bindings();

      expect(b.match(1, 1), isTrue);
      expect(b.match('a', 'b'), isFalse);
      expect(b.match([1, 2], [1, 2]), isTrue);
      expect(b.match([1], [1, 2]), isFalse);
      expect(b.match({'a': 1}, {'a': 1, 'extra': true}), isTrue);
      expect(b.match({'a': 1, 'b': 2}, {'a': 1}), isFalse);
    });

    test('expected proto3 defaults match missing keys', () {
      final b = Bindings();

      expect(
        b.match({
          'variant': 'VARIANT_UNSPECIFIED',
          'bitrate': 0,
          'flag': false,
          'text': '',
          'list': <Object?>[],
          'map': <String, Object?>{},
        }, <String, Object?>{}),
        isTrue,
      );
      expect(b.match({'metadataJson': 'null'}, <String, Object?>{}), isFalse);
    });

    test('<any> and <sdp> wildcards', () {
      final b = Bindings();

      expect(b.match('<any>', {'x': 1}), isTrue);
      expect(b.match('<any>', null), isTrue);
      expect(b.match('<sdp>', 'v=0'), isTrue);
      expect(b.match('<sdp>', ''), isFalse);
      expect(b.match('<sdp>', 3), isFalse);
      expect(b.match('<sdkVersion>', 'flutter-$packageVersion'), isTrue);
      expect(b.match('<sdkVersion>', 'web-0.31.0'), isFalse);
    });

    test(r'${name} binds once', () {
      final b = Bindings();

      expect(b.match(r'${cam}', 'peer:1'), isTrue);
      expect(b['cam'], 'peer:1');
      expect(b.match(r'${cam}', 'peer:1'), isTrue);
      expect(b.match(r'${cam}', 'peer:2'), isFalse);
    });

    test('placeholders in map keys bind to the remaining key', () {
      final b = Bindings();

      expect(
        b.match(
          {r'${a}': '{"type":"camera"}', r'${b}': '{"type":"microphone"}'},
          {'p:2': '{"type":"microphone"}', 'p:1': '{"type":"camera"}'},
        ),
        isTrue,
      );
      expect(b['a'], 'p:1');
      expect(b['b'], 'p:2');
      expect(b.match({r'${a}': 1}, {'p:1': 1}), isTrue);
      expect(b.match({r'${a}': 1}, {'p:9': 1}), isFalse);
    });

    test('a failed match does not leave partial bindings', () {
      final b = Bindings();

      expect(b.match({'x': r'${a}', 'y': 'no'}, {'x': 1, 'y': 'yes'}), isFalse);
      expect(b.has('a'), isFalse);
    });

    test('describeMismatch explains the first difference', () {
      final b = Bindings();

      expect(
        b.describeMismatch(
          {
            'a': {'b': 1},
          },
          {
            'a': {'b': 2},
          },
        ),
        contains(r'$.a.b'),
      );
      expect(b.describeMismatch({'a': 1}, {'a': 1}), isNull);
    });
  });

  group('Bindings.substitute', () {
    test('replaces bound placeholders in values and keys', () {
      final b = Bindings()..bind('cam', 'p:1');

      expect(
        b.substitute({
          'midToTrackId': {'0': r'${cam}'},
          r'${cam}': [r'${cam}', 'x'],
        }),
        {
          'midToTrackId': {'0': 'p:1'},
          'p:1': ['p:1', 'x'],
        },
      );
    });

    test('fails on unbound placeholders', () {
      expect(() => Bindings().substitute(r'${nope}'), throwsStateError);
    });
  });

  group('Fixture.parse', () {
    test('parses every step kind', () {
      final fixture = Fixture.parse('''
{
  "name": "all",
  "description": "d",
  "steps": [
    {"direction": "api", "call": "addTrack", "args": {"kind": "video"}, "bind": "cam"},
    {"direction": "api", "call": "connect", "error": "AuthException"},
    {"direction": "out", "message": {"peerMediaEvent": {"renegotiateTracks": {}}}},
    {"direction": "in", "message": {"serverMediaEvent": {"offerData": {"tracksTypes": {"video": 1}}}}},
    {"direction": "close", "code": 1000, "reason": "Invalid token"},
    {"direction": "close"},
    {"direction": "rtc", "event": "iceConnectionState", "args": {"state": "disconnected"}},
    {"direction": "expectRtc", "call": "createDataChannel", "args": {"label": "reliable"}},
    {"direction": "expect", "event": "Joined", "fields": {"peerId": "p"}},
    {"direction": "wait", "ms": 600},
    {"direction": "noOut", "ms": 10}
  ]
}
''');

      expect(fixture.name, 'all');
      expect(fixture.steps.map((s) => s.runtimeType.toString()), [
        'ApiStep',
        'ApiStep',
        'OutStep',
        'InStep',
        'CloseStep',
        'CloseStep',
        'RtcStep',
        'ExpectRtcStep',
        'ExpectEventStep',
        'WaitStep',
        'NoOutStep',
      ]);
      final api = fixture.steps[0] as ApiStep;
      expect(api.call, 'addTrack');
      expect(api.args, {'kind': 'video'});
      expect(api.bind, 'cam');
      expect((fixture.steps[1] as ApiStep).error, 'AuthException');
      final close = fixture.steps[4] as CloseStep;
      expect(close.code, 1000);
      expect(close.reason, 'Invalid token');
      expect((fixture.steps[5] as CloseStep).code, isNull);
      expect(
        (fixture.steps[9] as WaitStep).duration,
        const Duration(milliseconds: 600),
      );
    });

    test('rejects unknown step kinds', () {
      expect(
        () => Fixture.parse(
          '{"name": "x", "description": "", "steps": [{"direction": "up"}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('describeEvent', () {
    test('names every event and exposes its fields', () {
      expect(describeEvent(const ReconnectionStarted()), {
        'event': 'ReconnectionStarted',
      });
      expect(
        describeEvent(
          const Joined(
            peerId: 'me',
            peers: [Peer(id: 'bob', type: 'exwebrtc', metadata: Metadata())],
            components: [],
          ),
        ),
        {
          'event': 'Joined',
          'peerId': 'me',
          'peers': [
            {
              'id': 'bob',
              'type': 'exwebrtc',
              'metadata': {'peer': null, 'server': null},
              'tracks': <String>[],
            },
          ],
          'components': <Object?>[],
        },
      );
      expect(describeEvent(const Disconnected(DisconnectReason.left)), {
        'event': 'Disconnected',
        'reason': 'left',
        'closeCode': null,
        'closeReason': null,
      });
    });
  });

  group('FixtureReplayer', () {
    test('reports an unexpected outgoing message', () async {
      final transports = FakeTransportFactory();
      final fixture = Fixture.parse(
        jsonEncode({
          'name': 'bad',
          'description': '',
          'steps': [
            {
              'direction': 'api',
              'call': 'connect',
              'args': {'token': 'T'},
            },
            {
              'direction': 'out',
              'message': {
                'authRequest': {'token': 'other'},
              },
            },
          ],
        }),
      );

      await expectLater(
        FixtureReplayer(
          fixture: fixture,
          transports: transports,
          rtc: FakeRtcAdapter(),
          events: <FishjamEvent>[],
          onApi: (step) => _connect(transports, step),
        ).run(),
        throwsA(isA<FixtureMismatch>()),
      );
    });
  });
}

/// Opens a transport and sends an auth request with the step's token.
Future<Object?> _connect(FakeTransportFactory transports, ApiStep step) async {
  final t = transports();
  await t.connect(Uri.parse('ws://toy'));
  t.send(
    PeerMessage(
      authRequest: PeerMessage_AuthRequest(
        token: step.args['token']! as String,
      ),
    ).writeToBuffer(),
  );
  return null;
}
