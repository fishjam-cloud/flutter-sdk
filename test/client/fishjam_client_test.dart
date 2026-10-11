import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/fishjam_client.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../support/fixtures.dart';
import 'client_harness.dart';

typedef _C = peer.MediaEvent_Content;

const _fast = ReconnectConfig(
  maxAttempts: 2,
  initialDelay: Duration(milliseconds: 20),
  delay: Duration(milliseconds: 20),
);

const _fastRestore = ReconnectConfig(
  maxAttempts: 2,
  initialDelay: Duration(milliseconds: 20),
  delay: Duration(milliseconds: 20),
  addTracksOnReconnect: true,
);

Future<void> _wait(int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await settle();
}

void main() {
  late ClientHarness h;

  tearDown(() => h.dispose());

  group('connect (SPEC §3.2)', () {
    test('joins: AuthSucceeded, Joined, status and room state', () async {
      h = ClientHarness();
      expect(h.client.status, ConnectionStatus.idle);
      expect(h.client.localPeer, isNull);
      final connecting = h.client.connect(
        url: 'ws://fishjam.test/',
        token: 'peer-token',
        peerMetadata: {'name': 'alice'},
      );
      await settle();
      expect(h.client.status, ConnectionStatus.connecting);
      expect(
        h.transport.connectedUrl,
        Uri.parse('ws://fishjam.test/socket/peer/websocket'),
      );
      await h.authenticate();
      expect(h.client.status, ConnectionStatus.authenticated);
      expect(
        h.sentOf(_C.connect).single.connect.metadataJson,
        '{"name":"alice"}',
      );
      await h.connectedEvent(
        endpoints: {
          'bob': server.MediaEvent_Endpoint(
            endpointType: 'exwebrtc',
            metadataJson: '{"peer":{"name":"bob"},"server":{}}',
          ),
        },
      );
      await connecting;

      expect(h.client.status, ConnectionStatus.joined);
      expect(h.eventsOf<AuthSucceeded>().single.roomType, RoomType.conference);
      final joined = h.eventsOf<Joined>().single;
      expect(joined.peerId, localPeerId);
      expect(joined.peers.single.id, 'bob');
      expect(h.client.localPeer!.id, localPeerId);
      expect(h.client.localPeer!.metadata.peer, {'name': 'alice'});
      expect(h.client.remotePeers.keys, ['bob']);
      expect(h.client.remoteComponents, isEmpty);
      expect(h.client.remoteTracks, isEmpty);
      expect(h.client.isReconnecting, isFalse);
    });

    test('an auth close fails connect() once with AuthException', () async {
      h = ClientHarness();
      final connecting = h.client.connect(url: 'ws://f', token: 't');
      final result = expectLater(connecting, throwsA(isA<AuthException>()));
      await settle();
      h.transport.serverClose(reason: 'Invalid token');
      await settle();
      await result;
      expect(
        h.eventsOf<AuthFailed>().single.reason,
        AuthErrorReason.invalidToken,
      );
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.authError,
      );
      expect(h.client.status, ConnectionStatus.disconnected);
    });

    test('a retryable close before Joined fails connect() and does not '
        'reconnect (D6)', () async {
      h = ClientHarness(reconnect: _fast);
      final connecting = h.client.connect(url: 'ws://f', token: 't');
      final result = expectLater(
        connecting,
        throwsA(isA<ConnectionException>()),
      );
      await settle();
      await h.authenticate();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await result;
      await _wait(100);
      expect(h.transports.created, hasLength(1));
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.connectionLost,
      );
    });

    test('a socket that cannot be opened fails connect()', () async {
      h = ClientHarness();
      h.transports.failNextConnects(1);
      await expectLater(
        h.client.connect(url: 'ws://f', token: 't'),
        throwsA(isA<ConnectionException>()),
      );
      expect(h.client.status, ConnectionStatus.disconnected);
    });

    test(
      'connect() rejects a URL that is not ws, wss, http or https',
      () async {
        h = ClientHarness();
        await expectLater(
          h.client.connect(url: 'ftp://fishjam.test', token: 't'),
          throwsArgumentError,
        );
        expect(h.client.status, ConnectionStatus.idle);
        expect(h.transports.created, isEmpty);
      },
    );

    test('connect() while connecting throws StateError', () async {
      h = ClientHarness();
      unawaited(h.client.connect(url: 'ws://f', token: 't'));
      await settle();
      expect(
        () => h.client.connect(url: 'ws://f', token: 't'),
        throwsStateError,
      );
    });

    test('can connect again after leaving', () async {
      h = ClientHarness();
      await h.join();
      await h.client.leave();
      await settle();
      await h.join();
      expect(h.client.status, ConnectionStatus.joined);
      expect(h.eventsOf<Joined>(), hasLength(2));
    });

    test('leave() before Joined settles connect()', () async {
      h = ClientHarness();
      final connecting = h.client.connect(url: 'ws://f', token: 't');
      final result = expectLater(
        connecting,
        throwsA(isA<ConnectionException>()),
      );
      await settle();
      await h.client.leave();
      await settle();
      await result;
      expect(h.eventsOf<Disconnected>().single.reason, DisconnectReason.left);
    });

    test('audio-only room: AuthSucceeded reports it and video tracks are '
        'rejected synchronously (SPEC §20)', () async {
      h = ClientHarness();
      await h.join(roomType: PeerMessage_RoomType.ROOM_TYPE_AUDIO_ONLY);
      expect(h.eventsOf<AuthSucceeded>().single.roomType, RoomType.audioOnly);
      expect(
        () => h.client.addTrack(h.track('video')),
        throwsA(isA<TrackTypeError>()),
      );
      await settle();
      expect(h.sentOf(_C.renegotiateTracks), isEmpty);
      final audio = h.client.addTrack(h.track('audio'));
      await settle();
      await h.negotiate();
      expect(await audio, startsWith('$localPeerId:'));
    });

    test('livestream room type is reported', () async {
      h = ClientHarness();
      await h.join(roomType: PeerMessage_RoomType.ROOM_TYPE_LIVESTREAM);
      expect(h.eventsOf<AuthSucceeded>().single.roomType, RoomType.livestream);
    });
  });

  group('leave (SPEC §3.3)', () {
    test('sends disconnect before closing the socket with 1000, emits '
        'Disconnected(left) once', () async {
      h = ClientHarness();
      await h.join();
      await h.publish('audio');
      await h.client.leave();
      await settle();

      expect(
        h.transport.sentMessages.last.peerMediaEvent.hasDisconnect(),
        isTrue,
      );
      expect(h.transport.closedByClient, isTrue);
      expect(h.transport.clientCloseCode, 1000);
      expect(h.pc.isClosed, isTrue);
      expect(h.client.status, ConnectionStatus.disconnected);
      expect(h.eventsOf<Disconnected>().single.reason, DisconnectReason.left);
      expect(h.client.localPeer, isNull);

      await h.client.leave();

      await settle();
      expect(h.eventsOf<Disconnected>(), hasLength(1));
    });

    test('closes the data channels before the disconnect and the peer '
        'connection', () async {
      h = ClientHarness();
      await h.join();
      final ready = h.client.createDataChannels();
      await settle();
      await h.negotiate();
      for (final c in h.pc.dataChannels) {
        c.open();
      }
      await ready;
      final states = <DataChannelState>[];
      h.pc.dataChannels.first.onStateChange.listen(states.add);
      var disconnectSentWhenClosed = true;
      h.pc.dataChannels.first.onStateChange.listen((_) {
        disconnectSentWhenClosed = h.sentOf(_C.disconnect).isNotEmpty;
      });
      await h.client.leave();
      await settle();
      expect(states, [DataChannelState.closed]);
      expect(disconnectSentWhenClosed, isFalse);
      expect(h.client.dataChannelsReady, isFalse);
    });

    test('pending track operations fail with StateError', () async {
      h = ClientHarness();
      await h.join();
      final adding = h.client.addTrack(h.track('video'));
      final result = expectLater(adding, throwsStateError);
      await settle();
      await h.client.leave();
      await settle();
      await result;
    });

    test('while reconnecting cancels the attempts', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await settle();
      expect(h.client.status, ConnectionStatus.reconnecting);
      await h.client.leave();
      await settle();
      await _wait(100);
      expect(h.transports.created, hasLength(1));
      expect(h.eventsOf<Disconnected>().single.reason, DisconnectReason.left);
      expect(h.client.isReconnecting, isFalse);
    });
  });

  group('server-initiated end (SPEC §3.4)', () {
    test('offerData, error and close back to back end with a server error, '
        'not a reconnection', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport
        ..receive(
          PeerMessage(
            serverMediaEvent: server.MediaEvent(
              offerData: server.MediaEvent_OfferData(
                tracksTypes: server.MediaEvent_OfferData_TrackTypes(audio: 1),
              ),
            ),
          ),
        )
        ..receive(
          PeerMessage(
            serverMediaEvent: server.MediaEvent(
              error: server.MediaEvent_Error(message: 'bad'),
            ),
          ),
        )
        ..serverClose(code: 1011, reason: 'Internal server error');
      await _wait(100);
      final names = h.events
          .where((e) => e is! AuthSucceeded && e is! Joined)
          .map((e) => e.runtimeType.toString())
          .toList();
      expect(names, ['ServerError', 'Disconnected']);
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.serverError,
      );
      expect(h.transports.created, hasLength(1));
    });

    test(
      'removal of the local peer followed by a close is peerRemoved',
      () async {
        h = ClientHarness(reconnect: _fast);
        await h.join();
        h.transport
          ..receive(
            PeerMessage(
              serverMediaEvent: server.MediaEvent(
                endpointRemoved: server.MediaEvent_EndpointRemoved(
                  endpointId: localPeerId,
                ),
              ),
            ),
          )
          ..serverClose(code: 1011, reason: 'boom');
        await _wait(100);
        expect(
          h.eventsOf<Disconnected>().single.reason,
          DisconnectReason.peerRemoved,
        );
        expect(h.eventsOf<ReconnectionStarted>(), isEmpty);
      },
    );

    test('a server error followed by a close is a serverError leave, not a '
        'lost connection', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport
        ..receive(
          PeerMessage(
            serverMediaEvent: server.MediaEvent(
              error: server.MediaEvent_Error(message: 'bad'),
            ),
          ),
        )
        ..serverClose(code: 1011, reason: 'Internal server error');
      await _wait(100);
      expect(h.eventsOf<ServerError>().single.message, 'bad');
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.serverError,
      );
      expect(h.eventsOf<ReconnectionStarted>(), isEmpty);
      expect(h.transports.created, hasLength(1));
    });

    test(
      'removal of the local peer tears down without sending disconnect',
      () async {
        h = ClientHarness();
        await h.join();
        await h.receive(
          server.MediaEvent(
            endpointRemoved: server.MediaEvent_EndpointRemoved(
              endpointId: localPeerId,
            ),
          ),
        );
        await settle();
        expect(
          h.eventsOf<Disconnected>().single.reason,
          DisconnectReason.peerRemoved,
        );
        expect(h.sentOf(_C.disconnect), isEmpty);
        expect(h.transport.closedByClient, isTrue);
        expect(h.client.status, ConnectionStatus.disconnected);
      },
    );

    test('a session-ended close is terminal', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport.serverClose(reason: 'Room stopped');
      await _wait(100);
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.roomStopped,
      );
      expect(h.transports.created, hasLength(1));
    });

    test(
      'with reconnection disabled a lost connection ends the session',
      () async {
        h = ClientHarness(reconnect: ReconnectConfig.disabled);
        await h.join();
        h.transport.serverClose(code: 1011, reason: 'boom');
        await settle();
        final disconnected = h.eventsOf<Disconnected>().single;
        expect(disconnected.reason, DisconnectReason.connectionLost);
        expect(disconnected.closeCode, 1011);
        expect(h.transports.created, hasLength(1));
      },
    );
  });

  group('reconnection (SPEC §6)', () {
    test('a peer connection failure replaces the session', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      await h.publish('audio');
      final firstPc = h.pc;
      final firstTransport = h.transport;
      firstPc.setConnectionState(PeerConnectionState.failed);
      await settle();
      expect(h.eventsOf<ConnectionError>(), hasLength(1));
      expect(h.eventsOf<ReconnectionStarted>(), hasLength(1));
      expect(h.client.isReconnecting, isTrue);
      await _wait(40);
      expect(h.transports.created, hasLength(2));
      expect(firstTransport.closedByClient, isTrue);
      expect(firstPc.isClosed, isTrue);
      await h.authenticate();
      await h.connectedEvent();
      await settle();
      expect(h.eventsOf<Reconnected>(), hasLength(1));
      expect(h.client.status, ConnectionStatus.joined);
      expect(h.eventsOf<Disconnected>(), isEmpty);
      expect(h.eventsOf<AuthSucceeded>(), hasLength(1));
    });

    test('a failed negotiation cycle replaces the session', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      final adding = h.client.addTrack(h.track('audio'));
      final result = expectLater(adding, throwsA(anything));
      await settle();
      await h.receive(
        server.MediaEvent(
          offerData: server.MediaEvent_OfferData(
            tracksTypes: server.MediaEvent_OfferData_TrackTypes(),
          ),
        ),
      );
      final offer = h.sentOf(_C.sdpOffer).last.sdpOffer;
      h.pc.failNext('setRemoteDescription', StateError('bad answer'));
      await h.receive(
        server.MediaEvent(
          sdpAnswer: server.MediaEvent_SdpAnswer(
            sdp: 'v=0',
            midToTrackId: offer.midToTrackId.entries,
          ),
        ),
      );
      await result;
      await settle();
      expect(h.eventsOf<ConnectionError>(), hasLength(1));
      expect(h.eventsOf<ReconnectionStarted>(), hasLength(1));
    });

    test('every old local track is reported removed; live ones are restored '
        'with new ids', () async {
      h = ClientHarness(reconnect: _fastRestore);
      await h.join();
      final cam = await h.publish(
        'video',
        metadata: const TrackMetadata(type: TrackType.camera),
      );
      final mic = await h.publish('audio');
      await h.client.replaceTrack(mic, null);
      await settle();
      h.events.clear();

      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(40);
      await h.authenticate();
      await h.connectedEvent();
      // The restored camera is being negotiated.
      expect(h.sentOf(_C.renegotiateTracks), isNotEmpty);
      await h.negotiate();
      await settle();

      final names = h.events.map((e) => e.runtimeType.toString()).toList();
      expect(names, [
        'ReconnectionStarted',
        'Joined',
        'LocalTrackRemoved',
        'LocalTrackRemoved',
        'LocalTrackAdded',
        'Reconnected',
      ]);
      expect(h.eventsOf<LocalTrackRemoved>().map((e) => e.trackId), [cam, mic]);
      final restored = h.eventsOf<LocalTrackAdded>().single.track;
      expect(restored.trackId, isNot(cam));
      expect(restored.metadata?.type, TrackType.camera);
      expect(h.client.localPeer!.tracks.keys, [restored.trackId]);
    });

    test('tracks restored by an attempt that is then lost are reported '
        'removed too', () async {
      h = ClientHarness(reconnect: _fastRestore);
      await h.join();
      final cam = await h.publish('video');
      final mic = await h.publish('audio');
      h.events.clear();

      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(40);
      await h.authenticate();
      await h.connectedEvent();
      await h.negotiate(); // the camera is restored
      final cam2 = h.eventsOf<LocalTrackAdded>().single.track.trackId;
      h.transport.serverClose(code: 1011, reason: 'boom'); // mic pending
      await _wait(60);
      await h.authenticate();
      await h.connectedEvent();
      await h.negotiate();
      await h.negotiate();
      await settle();

      expect(h.eventsOf<LocalTrackRemoved>().map((e) => e.trackId), [
        cam,
        mic,
        cam2,
      ]);
      final added = h.eventsOf<LocalTrackAdded>().map((e) => e.track.trackId);
      expect(added, hasLength(3));
      expect(h.client.localPeer!.tracks.keys, added.skip(1));
      expect(h.eventsOf<Reconnected>(), hasLength(1));
    });

    test(
      'without addTracksOnReconnect every old track is reported removed',
      () async {
        h = ClientHarness(reconnect: _fast);
        await h.join();
        final cam = await h.publish('video');
        h.events.clear();
        h.transport.loseConnection();
        await _wait(40);
        await h.authenticate();
        await h.connectedEvent();
        await settle();
        expect(h.eventsOf<LocalTrackRemoved>().single.trackId, cam);
        expect(h.eventsOf<LocalTrackAdded>(), isEmpty);
        expect(h.eventsOf<Reconnected>(), hasLength(1));
        expect(h.client.localPeer!.tracks, isEmpty);
      },
    );

    test('exhausted attempts emit ReconnectionFailed and '
        'Disconnected(reconnectionFailed)', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(30);
      h.transport.serverClose(code: 1006);
      await _wait(50);
      h.transport.serverClose(code: 1006);
      await _wait(50);
      expect(h.eventsOf<ReconnectionFailed>(), hasLength(1));
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.reconnectionFailed,
      );
      expect(h.client.status, ConnectionStatus.disconnected);
      expect(h.client.isReconnecting, isFalse);
    });

    test('a terminal close while reconnecting ends without retrying', () async {
      h = ClientHarness(reconnect: _fast);
      await h.join();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(30);
      expect(h.eventsOf<ReconnectionStarted>(), hasLength(1));
      expect(h.transports.created, hasLength(2));
      h.transport.serverClose(reason: 'Expired token');
      await _wait(100);
      expect(
        h.eventsOf<AuthFailed>().single.reason,
        AuthErrorReason.expiredToken,
      );
      expect(
        h.eventsOf<Disconnected>().single.reason,
        DisconnectReason.authError,
      );
      expect(h.eventsOf<ReconnectionFailed>(), isEmpty);
      expect(h.transports.created, hasLength(2));
      expect(h.client.isReconnecting, isFalse);
    });

    test('a session that cannot be created on the last attempt ends with '
        'reconnectionFailed (ReconnectHost.endSession)', () async {
      var failing = false;
      final rtc = FakeRtcAdapter();
      h = ClientHarness(reconnect: _fast);
      final client = FishjamClient.internal(
        reconnect: _fast,
        rtcAdapter: rtc,
        transportFactory: () {
          if (failing) throw StateError('no network');
          return h.transports();
        },
      );
      final events = <FishjamEvent>[];
      client.events.listen(events.add);
      final connecting = client.connect(url: 'ws://f', token: 't');
      await settle();
      await h.authenticate();
      await h.connectedEvent();
      await connecting;
      failing = true;
      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(150);
      expect(events.whereType<ReconnectionFailed>(), hasLength(1));
      expect(
        events.whereType<Disconnected>().single.reason,
        DisconnectReason.reconnectionFailed,
      );
      expect(client.status, ConnectionStatus.disconnected);
      await client.dispose();
    });

    test('operations fail fast from the accepted loss until Reconnected, and '
        'the lost session reports nothing more', () async {
      h = ClientHarness(reconnect: _fastRestore);
      await h.join();
      await h.publish('audio');
      final firstTransport = h.transport;
      h.pc.setConnectionState(PeerConnectionState.failed);
      await settle();
      expect(h.client.status, ConnectionStatus.reconnecting);

      final reconnecting = throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('reconnecting'),
        ),
      );
      await expectLater(h.client.addTrack(h.track('audio')), reconnecting);
      await expectLater(h.client.removeTrack('x'), reconnecting);
      await expectLater(h.client.replaceTrack('x', null), reconnecting);
      await expectLater(h.client.createDataChannels(), reconnecting);
      expect(() => h.client.updatePeerMetadata(null), reconnecting);
      expect(() => h.client.updateTrackMetadata('x', null), reconnecting);
      expect(
        () => h.client.setTargetTrackEncoding('x', Variant.low),
        reconnecting,
      );
      await settle();
      expect(h.eventsOf<DataChannelsError>(), isEmpty);

      // The old socket is still open, but its events are not forwarded.
      firstTransport.receive(
        PeerMessage(
          serverMediaEvent: server.MediaEvent(
            endpointAdded: server.MediaEvent_EndpointAdded(endpointId: 'carol'),
          ),
        ),
      );
      await settle();
      expect(h.eventsOf<PeerJoined>(), isEmpty);

      await _wait(40);
      await h.authenticate();
      await h.connectedEvent();
      // Joined, but the track is still being restored.
      expect(h.eventsOf<Joined>(), hasLength(2));
      expect(h.client.status, ConnectionStatus.reconnecting);
      expect(() => h.client.updatePeerMetadata(null), reconnecting);
      await h.negotiate();
      await settle();
      expect(h.eventsOf<Reconnected>(), hasLength(1));
      expect(h.client.status, ConnectionStatus.joined);
      h.client.updatePeerMetadata({'name': 'bob'});
      expect(h.sentOf(_C.updateEndpointMetadata), hasLength(1));
    });

    test('remote endpoints of the lost session are reported gone before the '
        'new Joined (D22)', () async {
      h = ClientHarness(reconnect: _fast);
      final endpoints = {
        'bob': server.MediaEvent_Endpoint(
          endpointType: 'exwebrtc',
          metadataJson: '{"peer":{"name":"bob"},"server":{}}',
          trackIdToTrack: {
            'bob:cam': server.MediaEvent_Track(
              metadataJson: '{"type":"camera","paused":false}',
            ),
          }.entries,
        ),
        'rec': server.MediaEvent_Endpoint(
          endpointType: 'recording',
          trackIdToTrack: {
            'rec:a': server.MediaEvent_Track(metadataJson: 'null'),
          }.entries,
        ),
      };
      await h.join(endpoints: endpoints);
      h.events.clear();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await _wait(40);
      await h.authenticate();
      await h.connectedEvent(endpoints: {'bob': endpoints['bob']!});
      await settle();

      final described = [
        for (final e in h.events)
          switch (e) {
            TrackRemoved(:final track) => 'TrackRemoved ${track.trackId}',
            PeerLeft(:final peer) => 'PeerLeft ${peer.id}',
            ComponentRemoved(:final component) =>
              'ComponentRemoved ${component.id}',
            _ => e.runtimeType.toString(),
          },
      ];
      expect(described, [
        'ReconnectionStarted',
        'TrackRemoved bob:cam',
        'TrackRemoved rec:a',
        'PeerLeft bob',
        'ComponentRemoved rec',
        'Joined',
        'Reconnected',
      ]);
      expect(h.client.remotePeers.keys, ['bob']);
      expect(h.client.remoteComponents, isEmpty);
    });
  });

  group('statistics (SPEC §17)', () {
    test('reports every 10 s while joined and stops on teardown', () {
      fakeAsync((async) {
        h = ClientHarness();
        unawaited(h.client.connect(url: 'ws://f', token: 't'));
        async.flushMicrotasks();
        h.transport.receive(
          PeerMessage(authenticated: PeerMessage_Authenticated()),
        );
        async.flushMicrotasks();
        h.transport.receive(
          PeerMessage(
            serverMediaEvent: server.MediaEvent(
              connected: server.MediaEvent_Connected(endpointId: localPeerId),
            ),
          ),
        );
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 10));
        expect(h.client.status, ConnectionStatus.joined);
        int reports() =>
            h.transport.sentMessages.where((m) => m.hasRtcStatsReport()).length;
        async.elapse(const Duration(seconds: 10));
        expect(reports(), 1);
        async.elapse(const Duration(seconds: 10));
        expect(reports(), 2);
        unawaited(h.client.leave());
        async.elapse(const Duration(seconds: 30));
        expect(reports(), 2);
      });
    });
  });

  group('routing to the modules', () {
    test('local track operations', () async {
      h = ClientHarness();
      await h.join();
      final mic = await h.publish('audio');
      final cam = await h.publish('video');
      final pcCalls = h.pc.calls.length;

      await h.client.setTrackBandwidth(cam, const BandwidthLimit.single(800));

      await settle();
      expect(h.eventsOf<LocalTrackBandwidthSet>().single.trackId, cam);
      expect(h.pc.calls.length, greaterThan(pcCalls));

      await expectLater(
        h.client.setEncodingBandwidth(cam, Variant.low, 100),
        throwsArgumentError,
      );
      await expectLater(
        h.client.enableTrackEncoding(cam, Variant.low),
        throwsArgumentError,
      );
      await expectLater(
        h.client.disableTrackEncoding(cam, Variant.low),
        throwsArgumentError,
      );

      final newMic = h.track('audio');
      await h.client.replaceTrack(mic, newMic);
      await settle();
      final replaced = h.eventsOf<LocalTrackReplaced>().single;
      expect(replaced.trackId, mic);
      expect(replaced.track, same(newMic));
      await h.client.replaceTrack(mic, null);
      await settle();
      expect(h.eventsOf<LocalTrackMuted>().single.trackId, mic);
      expect(h.client.localPeer!.tracks[mic]!.isMuted, isTrue);

      h.client.updateTrackMetadata(
        cam,
        const TrackMetadata(type: TrackType.camera, paused: true),
      );
      expect(h.sentOf(_C.updateTrackMetadata), hasLength(1));
      h.client.updatePeerMetadata({'name': 'carol'});
      await settle();
      expect(h.eventsOf<LocalPeerMetadataChanged>().single.metadata, {
        'name': 'carol',
      });

      expect(await h.client.getLocalTrackAudioLevel('unknown'), isNull);
      expect(await h.client.getLocalTrackAudioLevel(mic), isNull);

      final removing = h.client.removeTrack(cam);
      await settle();
      await h.negotiate();
      await removing;
      await settle();
      expect(h.eventsOf<LocalTrackRemoved>().single.trackId, cam);
    });

    test('a local track exposes the app media track', () async {
      h = ClientHarness();
      await h.join();
      final native = h.track('video');
      final adding = h.client.addTrack(native);
      await settle();
      await h.negotiate();
      final id = await adding;
      expect(h.client.localPeer!.tracks[id]!.track, same(native));
      expect(h.eventsOf<LocalTrackAdded>().single.track.track, same(native));
    });

    test('remote target variant validation (D7)', () async {
      h = ClientHarness();
      await h.join(
        endpoints: {
          'bob': server.MediaEvent_Endpoint(endpointType: 'exwebrtc'),
        },
      );
      expect(
        () => h.client.setTargetTrackEncoding('bob:cam', Variant.low),
        throwsArgumentError,
      );
      expect(h.sentOf(_C.setTargetTrackVariant), isEmpty);
    });

    test('statistics come from the peer connection', () async {
      h = ClientHarness();
      await h.join();
      expect(await h.client.getStatistics(), isEmpty);
      await h.publish('audio');
      h.pc.stats = [
        const RtcStats(
          id: 'o',
          type: 'outbound-rtp',
          timestampMs: 1,
          values: {},
        ),
      ];
      expect((await h.client.getStatistics()).single.id, 'o');
      expect((await h.client.getStatistics(h.track('audio'))).single.id, 'o');
    });

    test('data channels: create, publish, receive', () async {
      h = ClientHarness();
      final received = <Uint8List>[];
      h.client.dataStream(reliable: true).listen(received.add);
      await h.join();
      expect(h.client.dataChannelsReady, isFalse);
      expect(
        () => h.client.publishData(Uint8List(1), reliable: true),
        throwsStateError,
      );
      final ready = h.client.createDataChannels();
      await settle();
      await h.negotiate();
      for (final c in h.pc.dataChannels) {
        c.open();
      }
      await ready;
      await settle();
      expect(h.client.dataChannelsReady, isTrue);
      expect(h.eventsOf<DataChannelsReady>(), hasLength(1));
      h.client.publishData(Uint8List.fromList([1, 2]), reliable: false);
      await settle();
      expect(h.pc.callsOf('dataChannelSend'), hasLength(1));
    });

    test('calls that need a session fail before connect', () async {
      h = ClientHarness();
      await expectLater(h.client.addTrack(h.track('audio')), throwsStateError);
      await expectLater(h.client.removeTrack('x'), throwsStateError);
      await expectLater(h.client.replaceTrack('x', null), throwsStateError);
      await expectLater(
        h.client.setTrackBandwidth('x', BandwidthLimit.unlimited),
        throwsStateError,
      );
      await expectLater(
        h.client.setEncodingBandwidth('x', Variant.low, 1),
        throwsStateError,
      );
      await expectLater(
        h.client.enableTrackEncoding('x', Variant.low),
        throwsStateError,
      );
      await expectLater(
        h.client.disableTrackEncoding('x', Variant.low),
        throwsStateError,
      );
      expect(
        () => h.client.setTargetTrackEncoding('x', Variant.low),
        throwsStateError,
      );
      expect(() => h.client.updatePeerMetadata(null), throwsStateError);
      expect(() => h.client.updateTrackMetadata('x', null), throwsStateError);
      expect(await h.client.getLocalTrackAudioLevel('x'), isNull);
      expect(await h.client.getStatistics(), isEmpty);
      await expectLater(h.client.createDataChannels(), throwsStateError);
      await settle();
      expect(h.events, isEmpty);
    });
  });

  group('dispose', () {
    test('leaves, ends data streams and the event stream', () async {
      h = ClientHarness();
      await h.join();
      final dataDone = Completer<void>();
      h.client
          .dataStream(reliable: true)
          .listen(null, onDone: dataDone.complete);
      final eventsDone = Completer<void>();
      h.client.events.listen(null, onDone: eventsDone.complete);
      await h.client.dispose();
      await settle();
      await dataDone.future;
      await eventsDone.future;
      expect(h.eventsOf<Disconnected>().single.reason, DisconnectReason.left);
      expect(
        () => h.client.connect(url: 'ws://f', token: 't'),
        throwsStateError,
      );
      await h.client.dispose();
      await settle();
    });
  });
}
