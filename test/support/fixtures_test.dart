import 'dart:async';
import 'dart:convert';

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
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

  group('proto3 JSON', () {
    test('round-trips a PeerMessage including maps and enums', () {
      final json = {
        'peerMediaEvent': {
          'sdpOffer': {
            'sdp': 'v=0',
            'midToTrackId': {'0': 'p:1'},
            'trackIdToBitrates': {
              'p:1': {
                'trackId': 'p:1',
                'variantBitrates': [
                  {'variant': 'VARIANT_LOW', 'bitrate': 153600},
                ],
              },
            },
          },
        },
      };

      final message = peerMessageFromJson(json);

      expect(message.peerMediaEvent.sdpOffer.midToTrackId, {'0': 'p:1'});
      expect(peerMessageToJson(message), json);
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
    test('drives a scripted client through a fixture', () async {
      final transports = FakeTransportFactory();
      final rtc = FakeRtcAdapter();
      final events = <FishjamEvent>[];
      final client = _ToyClient(transports, rtc, events);

      final fixture = Fixture.parse(
        jsonEncode({
          'name': 'toy',
          'description': 'toy client',
          'steps': [
            {
              'direction': 'api',
              'call': 'connect',
              'args': {'token': 'T'},
            },
            {
              'direction': 'out',
              'message': {
                'authRequest': {'token': 'T', 'sdkVersion': '<any>'},
              },
            },
            {
              'direction': 'in',
              'message': {'authenticated': <String, Object?>{}},
            },
            {
              'direction': 'expect',
              'event': 'AuthSucceeded',
              'fields': {'roomType': 'unspecified'},
            },
            {
              'direction': 'out',
              'message': {
                'peerMediaEvent': {
                  'connect': {'metadataJson': r'${meta}'},
                },
              },
            },
            {'direction': 'api', 'call': 'openChannel', 'bind': 'label'},
            {
              'direction': 'expectRtc',
              'call': 'createDataChannel',
              'args': {'label': r'${label}'},
            },
            {
              'direction': 'rtc',
              'event': 'iceConnectionState',
              'args': {'state': 'disconnected'},
            },
            {
              'direction': 'out',
              'message': {
                'peerMediaEvent': {'renegotiateTracks': <String, Object?>{}},
              },
            },
            {'direction': 'api', 'call': 'fail', 'error': 'StateError'},
            {'direction': 'wait', 'ms': 1},
            {'direction': 'noOut', 'ms': 1},
            {'direction': 'close', 'code': 1000, 'reason': 'Room stopped'},
            {
              'direction': 'expect',
              'event': 'Disconnected',
              'fields': {'reason': 'sessionEnded'},
            },
          ],
        }),
      );

      await FixtureReplayer(
        fixture: fixture,
        transports: transports,
        rtc: rtc,
        events: events,
        onApi: client.call,
      ).run();

      expect(client.metadataSent, isTrue);
    });

    test('reports an unexpected outgoing message', () async {
      final transports = FakeTransportFactory();
      final rtc = FakeRtcAdapter();
      final events = <FishjamEvent>[];
      final client = _ToyClient(transports, rtc, events);
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
          rtc: rtc,
          events: events,
          onApi: client.call,
        ).run(),
        throwsA(isA<FixtureMismatch>()),
      );
    });
  });
}

/// A tiny hand-written client used only to exercise the replayer.
class _ToyClient {
  _ToyClient(this.transports, this.rtc, this.events);

  final FakeTransportFactory transports;
  final FakeRtcAdapter rtc;
  final List<FishjamEvent> events;
  bool metadataSent = false;

  Future<Object?> call(ApiStep step) async {
    switch (step.call) {
      case 'connect':
        final t = transports();
        await t.connect(Uri.parse('ws://toy'));
        t.incoming.listen((bytes) {
          final m = PeerMessage.fromBuffer(bytes);
          if (m.hasAuthenticated()) {
            events.add(const AuthSucceeded(roomType: RoomType.unspecified));
            metadataSent = true;
            t.send(
              PeerMessage(
                peerMediaEvent: peer.MediaEvent(
                  connect: peer.MediaEvent_Connect(metadataJson: 'null'),
                ),
              ).writeToBuffer(),
            );
          }
        });
        unawaited(
          t.onClose.then((_) {
            events.add(const Disconnected(DisconnectReason.sessionEnded));
          }),
        );
        t.send(
          PeerMessage(
            authRequest: PeerMessage_AuthRequest(
              token: step.args['token']! as String,
              sdkVersion: 'toy-1.0.0',
            ),
          ).writeToBuffer(),
        );
        return null;
      case 'openChannel':
        final pc = await rtc.createPeerConnection(const RtcConfiguration());
        pc.onIceConnectionState.listen((s) {
          if (s == IceConnectionState.disconnected) {
            transports.last.send(
              PeerMessage(
                peerMediaEvent: peer.MediaEvent(
                  renegotiateTracks: peer.MediaEvent_RenegotiateTracks(),
                ),
              ).writeToBuffer(),
            );
          }
        });
        await pc.createDataChannel('reliable', const DataChannelInit());
        return 'reliable';
      case 'fail':
        throw StateError('expected');
    }
    throw UnimplementedError(step.call);
  }
}
