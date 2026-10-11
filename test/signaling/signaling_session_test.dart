import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart'
    as shared;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/signaling_session.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:fishjam_client/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_transport.dart';
import '../support/fixtures.dart' show settle;

typedef _Line = (LogLevel, String);

PeerMessage _authenticated([
  PeerMessage_SdkDeprecation_Status status =
      PeerMessage_SdkDeprecation_Status.STATUS_UP_TO_DATE,
  String message = '',
]) => PeerMessage(
  authenticated: PeerMessage_Authenticated(
    roomType: PeerMessage_RoomType.ROOM_TYPE_CONFERENCE,
    sdkDeprecation: PeerMessage_SdkDeprecation(
      status: status,
      message: message,
    ),
  ),
);

PeerMessage _serverEvent(server.MediaEvent event) =>
    PeerMessage(serverMediaEvent: event);

server.MediaEvent _connected(String id) =>
    server.MediaEvent(connected: server.MediaEvent_Connected(endpointId: id));

peer.MediaEvent _updateMetadata(String json) => peer.MediaEvent(
  updateEndpointMetadata: peer.MediaEvent_UpdateEndpointMetadata(
    metadataJson: json,
  ),
);

void main() {
  late FakeTransport transport;
  late MessageQueue queue;
  late SignalingSession session;
  late List<_Line> logs;

  SignalingSession newSession(FakeTransport t) => SignalingSession(
    transport: t,
    queue: queue,
    logger: FishjamLogger(
      enabled: true,
      sink: (level, message, {error, stackTrace}) => logs.add((level, message)),
    ),
    sdkVersion: sdkVersion,
  );

  setUp(() {
    logs = [];
    transport = FakeTransport();
    // The queue owner routes queued writes to the current session.
    queue = MessageQueue(send: (frame) => session.sendNow(frame));
    session = newSession(transport);
  });

  Future<PeerMessage_Authenticated> openAndAuthenticate({
    PeerMessage? authenticated,
  }) async {
    final opened = session.open(url: 'ws://fishjam.test/', token: 'peer-token');
    await settle();
    transport.receive(authenticated ?? _authenticated());
    return await opened;
  }

  group('open (SPEC §2, §3.2)', () {
    test('connects to the peer socket and sends authRequest first', () async {
      final opened = session.open(url: 'ws://fishjam.test/', token: 'T');
      final first = await transport.nextSent();

      expect(
        transport.connectedUrl,
        Uri.parse('ws://fishjam.test/socket/peer/websocket'),
      );
      expect(first.whichContent(), PeerMessage_Content.authRequest);
      expect(first.authRequest.token, 'T');
      expect(first.authRequest.sdkVersion, 'flutter-$packageVersion');

      transport.receive(_authenticated());
      final authenticated = await opened;
      expect(authenticated.roomType, PeerMessage_RoomType.ROOM_TYPE_CONFERENCE);
    });

    test('authRequest bypasses a held queue', () async {
      queue.hold();
      unawaited(session.open(url: 'ws://fishjam.test', token: 'T'));
      final first = await transport.nextSent();
      expect(first.whichContent(), PeerMessage_Content.authRequest);
    });

    test('logs a deprecated SDK version as a warning', () async {
      await openAndAuthenticate(
        authenticated: _authenticated(
          PeerMessage_SdkDeprecation_Status.STATUS_DEPRECATED,
          'SDK version is deprecated',
        ),
      );
      expect(
        logs,
        contains(
          isA<_Line>()
              .having((l) => l.$1, 'level', LogLevel.warn)
              .having(
                (l) => l.$2,
                'message',
                contains('SDK version is deprecated'),
              ),
        ),
      );
    });

    test('logs an unsupported SDK version as an error', () async {
      await openAndAuthenticate(
        authenticated: _authenticated(
          PeerMessage_SdkDeprecation_Status.STATUS_UNSUPPORTED,
          'no longer supported',
        ),
      );
      expect(
        logs,
        contains(
          isA<_Line>()
              .having((l) => l.$1, 'level', LogLevel.error)
              .having((l) => l.$2, 'message', contains('no longer supported')),
        ),
      );
    });

    test('an up-to-date SDK version logs no warning or error', () async {
      await openAndAuthenticate();
      expect(logs.where((l) => l.$1 != LogLevel.debug), isEmpty);
    });

    test('fails with SignalingClosedException when the server closes '
        'before authenticating (auth_failure_close)', () async {
      final opened = session.open(url: 'ws://fishjam.test', token: 'T');
      await transport.nextSent();
      transport.serverClose(reason: 'Invalid token');

      await expectLater(
        opened,
        throwsA(
          isA<SignalingClosedException>().having(
            (e) => e.reason,
            'reason',
            isA<AuthClose>().having(
              (r) => r.authError,
              'authError',
              AuthErrorReason.invalidToken,
            ),
          ),
        ),
      );
      expect(await session.closed, isA<AuthClose>());
    });

    test('fails with SignalingClosedException on a join error close '
        '(join_failure_close)', () async {
      final opened = session.open(url: 'ws://fishjam.test', token: 'T');
      await transport.nextSent();
      transport.serverClose(reason: 'reached peers limit');

      await expectLater(
        opened,
        throwsA(
          isA<SignalingClosedException>().having(
            (e) => e.reason,
            'reason',
            isA<JoinClose>(),
          ),
        ),
      );
    });

    test('fails when the connection is lost before authenticating', () async {
      final opened = session.open(url: 'ws://fishjam.test', token: 'T');
      await transport.nextSent();
      transport.loseConnection();

      await expectLater(
        opened,
        throwsA(
          isA<SignalingClosedException>().having(
            (e) => e.reason,
            'reason',
            isA<RetryableClose>(),
          ),
        ),
      );
      expect(await session.closed, isA<RetryableClose>());
    });

    test('throws TransportException when the socket cannot be opened; '
        'closed still completes', () async {
      session = newSession(FakeTransport(failConnect: true));

      await expectLater(
        session.open(url: 'ws://fishjam.test', token: 'T'),
        throwsA(isA<TransportException>()),
      );
      expect(await session.closed, isA<RetryableClose>());
    });

    test('closed completes even if a failed transport never reports '
        'its close', () async {
      session = newSession(_SilentFailingTransport());

      await expectLater(
        session.open(url: 'ws://fishjam.test', token: 'T'),
        throwsA(isA<TransportException>()),
      );
      expect(
        await session.closed,
        isA<RetryableClose>().having((r) => r.error, 'error', isNotNull),
      );
    });

    test('a session is single use', () async {
      await openAndAuthenticate();
      expect(
        () => session.open(url: 'ws://fishjam.test', token: 'T'),
        throwsStateError,
      );
    });

    test('messages before authenticated are dropped', () async {
      final events = <server.MediaEvent>[];
      session.serverMediaEvents.listen(events.add);
      final opened = session.open(url: 'ws://fishjam.test', token: 'T');
      await settle();
      transport
        ..receive(_serverEvent(_connected('early')))
        ..receive(_authenticated());
      await opened;
      transport.receive(_serverEvent(_connected('late')));
      await settle();

      expect(events.map((e) => e.connected.endpointId), ['late']);
    });
  });

  group('after authentication', () {
    setUp(openAndAuthenticate);

    test('delivers server media events in arrival order', () async {
      final events = <server.MediaEvent>[];
      final done = Completer<void>();
      session.serverMediaEvents.listen(events.add, onDone: done.complete);

      transport
        ..receive(_serverEvent(_connected('a')))
        ..receive(PeerMessage(mediaEvent: PeerMessage_MediaEvent(data: '{}')))
        ..receive(_authenticated())
        ..receiveBytes([0xff, 0xff, 0xff])
        ..receive(_serverEvent(_connected('b')))
        ..serverClose(reason: 'Room stopped');
      await done.future;

      expect(events.map((e) => e.connected.endpointId), ['a', 'b']);
    });

    test('events arriving before a listener are buffered', () async {
      transport.receive(_serverEvent(_connected('a')));
      await settle();
      expect((await session.serverMediaEvents.first).connected.endpointId, 'a');
    });

    test('closed reports the classified server close', () async {
      transport.serverClose(reason: 'Room stopped');
      expect(
        await session.closed,
        isA<SessionEndedClose>()
            .having((r) => r.sessionEnd, 'end', SessionEndReason.roomStopped)
            .having((r) => r.code, 'code', 1000)
            .having((r) => r.reason, 'reason', 'Room stopped'),
      );
    });

    test('closed completes only after every received event was delivered '
        '(error then close)', () async {
      // A consumer that handles each event asynchronously, one at a time
      // (like the engine): the subscription is paused while it works.
      final events = <server.MediaEvent>[];
      var streamDone = false;
      unawaited(() async {
        await for (final event in session.serverMediaEvents) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          events.add(event);
        }
        streamDone = true;
      }());
      final seenAtClose = Completer<(List<server.MediaEvent>, bool)>();
      unawaited(
        session.closed.then(
          (_) => seenAtClose.complete((List.of(events), streamDone)),
        ),
      );

      transport
        ..receive(
          _serverEvent(
            server.MediaEvent(error: server.MediaEvent_Error(message: 'fatal')),
          ),
        )
        ..receive(_serverEvent(_connected('after')))
        ..serverClose(reason: 'Internal server error');

      final (seen, done) = await seenAtClose.future;
      expect(seen.map((e) => e.whichContent().name), ['error', 'connected']);
      expect(done, isTrue);
    });

    test('closed reports a lost connection as retryable', () async {
      transport.loseConnection();
      expect(await session.closed, isA<RetryableClose>());
    });

    test('bypassing media events are sent at once, even when held', () async {
      await transport.nextSent(); // authRequest
      queue.hold();
      session
        ..sendMediaEvent(
          peer.MediaEvent(
            connect: peer.MediaEvent_Connect(metadataJson: 'null'),
          ),
        )
        ..sendMediaEvent(
          peer.MediaEvent(
            renegotiateTracks: peer.MediaEvent_RenegotiateTracks(),
          ),
        )
        ..sendMediaEvent(
          peer.MediaEvent(sdpOffer: peer.MediaEvent_SdpOffer(sdp: 'v=0')),
        )
        ..sendMediaEvent(
          peer.MediaEvent(candidate: shared.Candidate(candidate: 'c')),
        );

      final kinds = [
        for (var i = 0; i < 4; i++)
          (await transport.nextSent()).peerMediaEvent.whichContent(),
      ];
      expect(kinds, [
        peer.MediaEvent_Content.connect,
        peer.MediaEvent_Content.renegotiateTracks,
        peer.MediaEvent_Content.sdpOffer,
        peer.MediaEvent_Content.candidate,
      ]);
      expect(queue.length, 0);
    });

    test('other media events and stats go through the queue', () async {
      await transport.nextSent(); // authRequest
      queue.hold();
      session
        ..sendMediaEvent(_updateMetadata('{"a":1}'))
        ..sendStatsReport('{"x":{}}');

      expect(transport.sent, hasLength(1));
      expect(queue.length, 2);

      queue.release();
      final update = await transport.nextSent();
      final stats = await transport.nextSent();
      expect(
        update.peerMediaEvent.updateEndpointMetadata.metadataJson,
        '{"a":1}',
      );
      expect(stats.rtcStatsReport.data, '{"x":{}}');
    });

    test('unheld queued messages are written immediately', () async {
      await transport.nextSent(); // authRequest
      session.sendMediaEvent(_updateMetadata('null'));
      final sent = await transport.nextSent();
      expect(
        sent.peerMediaEvent.whichContent(),
        peer.MediaEvent_Content.updateEndpointMetadata,
      );
    });

    test('writing to a closed socket is a no-op', () async {
      transport.loseConnection();
      await settle();
      final before = transport.sent.length;
      session
        ..sendNow([1, 2, 3])
        ..sendMediaEvent(
          peer.MediaEvent(
            renegotiateTracks: peer.MediaEvent_RenegotiateTracks(),
          ),
        );
      expect(transport.sent, hasLength(before));
      expect(logs.any((l) => l.$1 == LogLevel.debug), isTrue);
    });

    test('close() closes with 1000 and does not report closed', () async {
      var reported = false;
      unawaited(session.closed.then((_) => reported = true));
      final done = Completer<void>();
      session.serverMediaEvents.listen(null, onDone: done.complete);

      await session.close();
      await done.future;
      await settle();

      expect(transport.closedByClient, isTrue);
      expect(transport.clientCloseCode, 1000);
      expect(reported, isFalse);
    });
  });

  test('close() while opening makes open() fail', () async {
    final opened = session.open(url: 'ws://fishjam.test', token: 'T');
    await transport.nextSent();
    await session.close();

    await expectLater(opened, throwsA(isA<SignalingClosedException>()));
  });

  test('close() during the socket handshake makes open() fail', () async {
    final slow = _SlowTransport();
    session = newSession(slow);
    final opened = session.open(url: 'ws://fishjam.test', token: 'T');
    await session.close();
    slow.finishConnect();

    await expectLater(opened, throwsA(isA<SignalingClosedException>()));
    expect(slow.sent, isEmpty);
  });

  test('close() before open() ends the event stream', () async {
    final done = Completer<void>();
    session.serverMediaEvents.listen(null, onDone: done.complete);
    await session.close();
    await done.future;
  });

  test('SignalingClosedException describes its reason', () {
    expect(
      const SignalingClosedException(RetryableClose(code: 1006)).toString(),
      contains('SignalingClosedException'),
    );
  });
}

/// Fails to connect without ever completing [onClose].
class _SilentFailingTransport extends FakeTransport {
  final _never = Completer<TransportClosed>();

  @override
  Future<TransportClosed> get onClose => _never.future;

  @override
  Future<void> connect(Uri url) async =>
      throw TransportException('Cannot connect to $url');
}

/// Connects only when [finishConnect] is called.
class _SlowTransport extends FakeTransport {
  final _connected = Completer<void>();

  void finishConnect() => _connected.complete();

  @override
  Future<void> connect(Uri url) async {
    await _connected.future;
    await super.connect(url);
  }
}
