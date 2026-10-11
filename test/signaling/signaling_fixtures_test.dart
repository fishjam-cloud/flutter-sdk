/// Replays the golden fixtures that only involve the signaling layer
/// (socket, authentication, close reasons, reconnection) against a minimal
/// client built from [SignalingSession], [MessageQueue] and
/// [ReconnectManager]. Media is out of scope here: `connected` simply
/// produces `Joined` with the server's peer id.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/auth.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/reconnect.dart';
import 'package:fishjam_client/src/signaling/signaling_session.dart';
import 'package:fishjam_client/src/version.dart';
import 'package:fishjam_client/src/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';
import '../support/fixtures.dart';

/// The connection lifecycle of SPEC §3 and §6, without media.
class _SignalingClient implements ReconnectHost {
  _SignalingClient(this.transports, ReconnectConfig config) {
    reconnect = ReconnectManager(config: config, host: this);
  }

  final FakeTransportFactory transports;
  final events = <FishjamEvent>[];
  late final ReconnectManager reconnect;
  late final queue = MessageQueue(send: (frame) => _session?.sendNow(frame));
  final _logger = FishjamLogger.disabled();

  ConnectionStatus status = ConnectionStatus.idle;
  SignalingSession? _session;
  late String _url;
  late String _token;
  Object? _peerMetadata;
  Completer<void>? _joined;

  Future<void> connect(String url, String token, Object? peerMetadata) async {
    _url = url;
    _token = token;
    _peerMetadata = peerMetadata;
    reconnect.reset();
    status = ConnectionStatus.connecting;
    final joined = _joined = Completer<void>();
    final session = _newSession();
    try {
      await _open(session);
    } on SignalingClosedException catch (e) {
      _fail(e.reason);
    } on Object catch (e) {
      _fail(RetryableClose(error: e));
    }
    return await joined.future;
  }

  void _fail(CloseReason reason) {
    final joined = _joined;
    if (joined == null || joined.isCompleted) return;
    _end(reason);
    joined.completeError(connectExceptionFor(reason));
  }

  SignalingSession _newSession() {
    final session = _session = SignalingSession(
      transport: transports(),
      queue: queue,
      logger: _logger,
      sdkVersion: sdkVersion,
    );
    unawaited(session.closed.then((reason) => _onClosed(session, reason)));
    session.serverMediaEvents.listen((e) => _onEvent(session, e));
    return session;
  }

  Future<void> _open(SignalingSession session) async {
    final auth = await session.open(url: _url, token: _token);
    if (!reconnect.isReconnecting) {
      events.add(
        AuthSucceeded(
          roomType: auth.roomType == PeerMessage_RoomType.ROOM_TYPE_AUDIO_ONLY
              ? RoomType.audioOnly
              : RoomType.conference,
        ),
      );
      status = ConnectionStatus.authenticated;
    }
    session.sendMediaEvent(
      peer.MediaEvent(
        connect: peer.MediaEvent_Connect(
          metadataJson: encodeMetadataJson(_peerMetadata),
        ),
      ),
    );
  }

  void _onEvent(SignalingSession session, server.MediaEvent event) {
    if (session != _session || !event.hasConnected()) return;
    events.add(
      Joined(
        peerId: event.connected.endpointId,
        peers: const [],
        components: const [],
      ),
    );
    status = ConnectionStatus.joined;
    final joined = _joined!;
    if (!joined.isCompleted) joined.complete();
    unawaited(reconnect.onSessionJoined());
  }

  void _onClosed(SignalingSession session, CloseReason reason) {
    if (session != _session) return;
    if (status != ConnectionStatus.joined && !reconnect.isReconnecting) {
      _fail(reason);
      return;
    }
    if (reason is RetryableClose) {
      if (reconnect.onRetryableLoss(
        reason,
        ReconnectSnapshot(peerMetadata: _peerMetadata, tracks: const []),
      )) {
        status = ConnectionStatus.reconnecting;
        return;
      }
      if (reconnect.state == ReconnectState.failed) {
        status = ConnectionStatus.disconnected;
        events.add(const Disconnected(DisconnectReason.reconnectionFailed));
        return;
      }
    } else {
      reconnect.onTerminalClose(reason);
    }
    _end(reason);
  }

  void _end(CloseReason reason) {
    status = ConnectionStatus.disconnected;
    final error = errorEventFor(reason);
    if (error != null) events.add(error);
    events.add(disconnectedFor(reason));
  }

  @override
  Future<void> startSession(Object? peerMetadata) async {
    final old = _session;
    _session = null;
    await old?.close();
    _peerMetadata = peerMetadata;
    try {
      await _open(_newSession());
    } on Object {
      // Reported through `closed`.
    }
  }

  @override
  Future<void> restoreTrack(LocalTrackContext track) async {}

  @override
  void holdQueue() => queue.hold();

  @override
  void releaseQueue() => queue.release();

  @override
  void clearQueue() => queue.clear();

  @override
  void emit(FishjamEvent event) => events.add(event);
}

ReconnectConfig _reconnectConfig(Map<String, Object?> config) {
  final json = config['reconnect'] as Map<String, Object?>?;
  if (json == null) return const ReconnectConfig();
  return ReconnectConfig(
    maxAttempts: (json['maxAttempts'] as int?) ?? 3,
    initialDelay: Duration(
      milliseconds: (json['initialDelayMs'] as int?) ?? 500,
    ),
    delay: Duration(milliseconds: (json['delayMs'] as int?) ?? 500),
    addTracksOnReconnect: (json['addTracksOnReconnect'] as bool?) ?? false,
  );
}

Future<_SignalingClient> _replay(
  Fixture fixture, {
  FakeTransportFactory? transports,
}) async {
  final factory = transports ?? FakeTransportFactory();
  final client = _SignalingClient(factory, _reconnectConfig(fixture.config));
  await FixtureReplayer(
    fixture: fixture,
    transports: factory,
    rtc: FakeRtcAdapter(),
    events: client.events,
    onApi: (step) => switch (step.call) {
      'connect' => client.connect(
        step.args['url']! as String,
        step.args['token']! as String,
        step.args['peerMetadata'],
      ),
      _ => throw UnimplementedError(step.call),
    },
  ).run();
  return client;
}

const _alice = {'name': 'alice'};

Map<String, Object?> _connectStep({String? error}) => {
  'direction': 'api',
  'call': 'connect',
  'args': {
    'url': 'ws://fishjam.test',
    'token': 'peer-token',
    'peerMetadata': _alice,
  },
  'error': ?error,
};

const Map<String, Object?> _authRequest = {
  'direction': 'out',
  'message': {
    'authRequest': {'token': 'peer-token', 'sdkVersion': '<sdkVersion>'},
  },
};

const Map<String, Object?> _authenticated = {
  'direction': 'in',
  'message': {
    'authenticated': {'roomType': 'ROOM_TYPE_CONFERENCE'},
  },
};

const Map<String, Object?> _connectOut = {
  'direction': 'out',
  'message': {
    'peerMediaEvent': {
      'connect': {'metadataJson': '{"name":"alice"}'},
    },
  },
};

const Map<String, Object?> _connectedIn = {
  'direction': 'in',
  'message': {
    'serverMediaEvent': {
      'connected': {'endpointId': 'local-peer'},
    },
  },
};

const Map<String, Object?> _joined = {
  'direction': 'expect',
  'event': 'Joined',
  'fields': {'peerId': 'local-peer'},
};

const List<Map<String, Object?>> _rejoin = [
  _authRequest,
  _authenticated,
  _connectOut,
  _connectedIn,
  _joined,
];

Map<String, Object?> _close(int code, String reason) => {
  'direction': 'close',
  'code': code,
  'reason': reason,
};

Map<String, Object?> _expect(String event, [Map<String, Object?>? fields]) => {
  'direction': 'expect',
  'event': event,
  'fields': fields ?? const <String, Object?>{},
};

Map<String, Object?> _timed(String direction, int ms) => {
  'direction': direction,
  'ms': ms,
};

Fixture _inline(
  String name,
  List<Map<String, Object?>> steps, {
  Map<String, Object?>? reconnect,
}) => Fixture.parse(
  jsonEncode({
    'name': name,
    'config': {'reconnect': ?reconnect},
    'steps': steps,
  }),
);

void main() {
  group('golden fixtures', () {
    for (final name in [
      'join_empty_room',
      'auth_failure_close',
      'join_failure_close',
      'session_ended_close',
    ]) {
      test(name, () async {
        final client = await _replay(Fixture.load(name));
        expect(
          client.events.whereType<Disconnected>().length,
          lessThanOrEqualTo(1),
        );
      });
    }
  });

  group('reconnection sequences (SPEC §6)', () {
    const fast = {'maxAttempts': 2, 'initialDelayMs': 100, 'delayMs': 100};

    test('a retryable close reconnects with the last metadata and emits '
        'Reconnected, never Disconnected (D9)', () async {
      final client = await _replay(
        _inline('reconnect', [
          _connectStep(),
          _authRequest,
          _authenticated,
          _expect('AuthSucceeded', {'roomType': 'conference'}),
          _connectOut,
          _connectedIn,
          _joined,
          _close(1011, 'Internal server error'),
          _expect('ReconnectionStarted'),
          _timed('noOut', 60),
          _timed('wait', 60),
          ..._rejoin,
          _expect('Reconnected'),
        ], reconnect: fast),
      );
      expect(client.events.whereType<Disconnected>(), isEmpty);
      expect(client.status, ConnectionStatus.joined);
    });

    test('a lost connection (no close frame) reconnects too', () async {
      final client = await _replay(
        _inline('lost', [
          _connectStep(),
          _authRequest,
          _authenticated,
          _connectOut,
          _connectedIn,
          _joined,
          {'direction': 'close'},
          _expect('ReconnectionStarted'),
          _timed('wait', 120),
          ..._rejoin,
          _expect('Reconnected'),
        ], reconnect: fast),
      );
      expect(client.events.whereType<Disconnected>(), isEmpty);
    });

    test('exhausted attempts emit ReconnectionFailed then '
        'Disconnected(reconnectionFailed)', () async {
      final transports = FakeTransportFactory();
      final client = await _replay(
        _inline('exhausted', [
          _connectStep(),
          _authRequest,
          _authenticated,
          _connectOut,
          _connectedIn,
          _joined,
          _close(1011, 'boom'),
          _expect('ReconnectionStarted'),
          _timed('wait', 120),
          _authRequest,
          _close(1006, ''),
          _timed('wait', 220),
          _authRequest,
          _close(1006, ''),
          _expect('ReconnectionFailed'),
          _expect('Disconnected', {'reason': 'reconnectionFailed'}),
          _timed('noOut', 400),
        ], reconnect: fast),
        transports: transports,
      );
      expect(client.events.whereType<Disconnected>(), hasLength(1));
      expect(transports.created, hasLength(3));
    });

    test('a terminal close while reconnecting ends without retrying', () async {
      final client = await _replay(
        _inline('terminal_while_reconnecting', [
          _connectStep(),
          _authRequest,
          _authenticated,
          _connectOut,
          _connectedIn,
          _joined,
          _close(1011, 'boom'),
          _expect('ReconnectionStarted'),
          _timed('wait', 120),
          _authRequest,
          _close(1000, 'Expired token'),
          _expect('AuthFailed', {'reason': 'expiredToken'}),
          _expect('Disconnected', {'reason': 'authError'}),
          _timed('noOut', 400),
        ], reconnect: fast),
      );
      expect(client.events.whereType<Disconnected>(), hasLength(1));
      expect(client.events.whereType<ReconnectionFailed>(), isEmpty);
    });

    test('with reconnection disabled a retryable close ends the session '
        'with connectionLost', () async {
      final client = await _replay(
        _inline(
          'disabled',
          [
            _connectStep(),
            _authRequest,
            _authenticated,
            _connectOut,
            _connectedIn,
            _joined,
            _close(1011, 'boom'),
            _expect('Disconnected', {
              'reason': 'connectionLost',
              'closeCode': 1011,
              'closeReason': 'boom',
            }),
            _timed('noOut', 300),
          ],
          reconnect: {'maxAttempts': 0},
        ),
      );
      expect(client.events.whereType<ReconnectionStarted>(), isEmpty);
    });

    test('a retryable close before Joined fails connect() and is not '
        'retried (SPEC §3.2, D6)', () async {
      final client = await _replay(
        _inline('close_before_joined', [
          _connectStep(error: 'ConnectionException'),
          _authRequest,
          _authenticated,
          _connectOut,
          _close(1011, 'boom'),
          _expect('Disconnected', {'reason': 'connectionLost'}),
          _timed('noOut', 300),
        ], reconnect: fast),
      );
      expect(client.events.whereType<ReconnectionStarted>(), isEmpty);
    });

    test('a socket that cannot be opened fails connect()', () async {
      final transports = FakeTransportFactory()..failNextConnects(1);
      await _replay(
        _inline('cannot_connect', [
          _connectStep(error: 'ConnectionException'),
          _expect('Disconnected', {'reason': 'connectionLost'}),
          _timed('noOut', 300),
        ], reconnect: fast),
        transports: transports,
      );
      expect(transports.created, hasLength(1));
    });

    test('queued messages are held while reconnecting and flushed on '
        'Reconnected', () async {
      final transports = FakeTransportFactory();
      late _SignalingClient client;
      final fixture = _inline('held_queue', [
        _connectStep(),
        _authRequest,
        _authenticated,
        _connectOut,
        _connectedIn,
        _joined,
        _close(1011, 'boom'),
        _expect('ReconnectionStarted'),
        {
          'direction': 'api',
          'call': 'updateMetadata',
          'args': <String, Object?>{},
        },
        _timed('noOut', 50),
        _timed('wait', 70),
        ..._rejoin,
        {
          'direction': 'out',
          'message': {
            'peerMediaEvent': {
              'updateEndpointMetadata': {'metadataJson': '{"name":"bob"}'},
            },
          },
        },
        _expect('Reconnected'),
      ], reconnect: fast);
      client = _SignalingClient(transports, _reconnectConfig(fixture.config));
      await FixtureReplayer(
        fixture: fixture,
        transports: transports,
        rtc: FakeRtcAdapter(),
        events: client.events,
        onApi: (step) => switch (step.call) {
          'connect' => client.connect(
            'ws://fishjam.test',
            'peer-token',
            _alice,
          ),
          'updateMetadata' => client._session!.sendMediaEvent(
            peer.MediaEvent(
              updateEndpointMetadata: peer.MediaEvent_UpdateEndpointMetadata(
                metadataJson: '{"name":"bob"}',
              ),
            ),
          ),
          _ => throw UnimplementedError(step.call),
        },
      ).run();
      expect(client.queue.isHeld, isFalse);
    });
  });
}
