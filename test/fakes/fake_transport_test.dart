import 'dart:async';

import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

PeerMessage _auth(String token) => PeerMessage(
  authRequest: PeerMessage_AuthRequest(token: token, sdkVersion: 'x-1.0.0'),
);

void main() {
  group('FakeTransport', () {
    test('records the url and opens on connect', () async {
      final transport = FakeTransport();
      expect(transport.isOpen, isFalse);

      await transport.connect(Uri.parse('ws://fishjam.test/socket'));

      expect(transport.isOpen, isTrue);
      expect(transport.connectedUrl, Uri.parse('ws://fishjam.test/socket'));
    });

    test('connect can be scripted to fail', () async {
      final transport = FakeTransport(failConnect: true);

      await expectLater(
        transport.connect(Uri.parse('ws://x')),
        throwsA(isA<TransportException>()),
      );
      expect(transport.isOpen, isFalse);
      expect(await transport.onClose, isA<TransportClosed>());
    });

    test('records sent frames and decodes them', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));

      transport.send(_auth('a').writeToBuffer());

      expect(transport.sent, hasLength(1));
      expect(transport.sentMessages.single.authRequest.token, 'a');
    });

    test('send before connect is dropped like a closed socket', () {
      FakeTransport().send(_auth('a').writeToBuffer());
    });

    test(
      'nextSent returns already sent and future messages in order',
      () async {
        final transport = FakeTransport();
        await transport.connect(Uri.parse('ws://x'));
        transport.send(_auth('1').writeToBuffer());

        expect((await transport.nextSent()).authRequest.token, '1');

        final pending = transport.nextSent();
        transport.send(_auth('2').writeToBuffer());
        expect((await pending).authRequest.token, '2');
      },
    );

    test('nextSent times out when nothing is sent', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));

      await expectLater(
        transport.nextSent(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('receive delivers encoded server messages', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));
      final received = <PeerMessage>[];
      transport.incoming.listen((b) => received.add(PeerMessage.fromBuffer(b)));

      transport.receive(
        PeerMessage(authenticated: PeerMessage_Authenticated()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.single.hasAuthenticated(), isTrue);
    });

    test('serverClose completes onClose once and ends incoming', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));
      final done = Completer<void>();
      transport.incoming.listen(null, onDone: done.complete);

      transport
        ..serverClose(reason: 'Invalid token')
        ..serverClose(code: 1011, reason: 'ignored');

      expect(
        await transport.onClose,
        const TransportClosed(code: 1000, reason: 'Invalid token'),
      );
      await done.future;
      expect(transport.isOpen, isFalse);
    });

    test('connection loss closes without a code', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));
      final error = Exception('network');

      transport.loseConnection(error);

      expect(await transport.onClose, TransportClosed(error: error));
    });

    test('client close records code and reason', () async {
      final transport = FakeTransport();
      await transport.connect(Uri.parse('ws://x'));

      await transport.close(1000, 'bye');

      expect(transport.closedByClient, isTrue);
      expect(transport.clientCloseCode, 1000);
      expect(
        await transport.onClose,
        const TransportClosed(code: 1000, reason: 'bye'),
      );
    });
  });

  group('FakeTransportFactory', () {
    test('creates a new transport per call and tracks the latest', () {
      final factory = FakeTransportFactory();

      final a = factory();
      final b = factory();

      expect(factory.created, [a, b]);
      expect(factory.last, same(b));
    });

    test('fails the configured number of connects', () async {
      final factory = FakeTransportFactory()..failNextConnects(1);

      await expectLater(
        factory().connect(Uri.parse('ws://x')),
        throwsA(isA<TransportException>()),
      );
      await factory().connect(Uri.parse('ws://x'));
    });

    test('nextSent spans every transport in creation order', () async {
      final factory = FakeTransportFactory();
      final a = factory();
      await a.connect(Uri.parse('ws://x'));
      a.send(_auth('a').writeToBuffer());
      final b = factory();
      await b.connect(Uri.parse('ws://x'));
      b.send(_auth('b').writeToBuffer());

      expect(factory.unreadSent, hasLength(2));
      expect((await factory.nextSent()).authRequest.token, 'a');
      expect((await factory.nextSent()).authRequest.token, 'b');
      expect(factory.unreadSent, isEmpty);
    });
  });
}
