import 'dart:async';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import 'client_harness.dart';

const _methods = MethodChannel('test/client_audio_output');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late bool failNative;
  late ClientHarness h;

  setUp(() {
    calls = [];
    failNative = false;
    messenger.setMockMethodCallHandler(_methods, (call) async {
      calls.add(call.method);
      if (failNative) throw PlatformException(code: 'boom');
      return null;
    });
    h = ClientHarness(
      audioOutput: AudioOutputManager.internal(
        methodChannel: _methods,
        eventChannel: const EventChannel('test/client_audio_output_events'),
        platform: () => TargetPlatform.android,
      ),
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_methods, null);
    await h.dispose();
  });

  group('communication mode (SPEC §20b)', () {
    test('entered on Joined, exited on leave()', () async {
      await h.join();
      expect(calls, ['enterCommunicationMode']);
      await h.client.leave();
      await settle();
      expect(calls, ['enterCommunicationMode', 'exitCommunicationMode']);
    });

    test('exited when the server removes the local peer', () async {
      await h.join();
      await h.receive(
        server.MediaEvent(
          endpointRemoved: server.MediaEvent_EndpointRemoved(
            endpointId: localPeerId,
          ),
        ),
      );
      await settle();
      expect(calls, ['enterCommunicationMode', 'exitCommunicationMode']);
    });

    test('a connect() made while the previous session is torn down opens '
        'after it, so the mode is exited and entered again', () async {
      await h.join();
      final gate = h.transport.closeGate = Completer<void>();
      final leaving = h.client.leave();
      await settle();
      final connecting = h.client.connect(url: 'ws://f', token: 't');
      await settle();
      expect(h.transport.isOpen, isFalse);

      gate.complete();
      await leaving;
      await settle();
      await h.rejoin();
      await connecting;

      expect(calls, [
        'enterCommunicationMode',
        'exitCommunicationMode',
        'enterCommunicationMode',
      ]);
      expect(h.events.whereType<Disconnected>(), hasLength(1));
      expect(h.events.last, isA<Joined>());
    });

    test('never entered when connect() fails before Joined', () async {
      final connecting = h.client.connect(url: 'ws://f', token: 't');
      final failed = expectLater(
        connecting,
        throwsA(isA<ConnectionException>()),
      );
      await settle();
      h.transport.serverClose(code: 1011, reason: 'boom');
      await failed;
      expect(calls, isEmpty);
    });

    test('exited once even if leave() is called twice', () async {
      await h.join();
      await h.client.leave();
      await h.client.leave();
      await settle();
      expect(calls, ['enterCommunicationMode', 'exitCommunicationMode']);
    });

    test('native failures never escape', () async {
      failNative = true;
      await h.join();
      await h.client.leave();
      await settle();
      expect(calls, ['enterCommunicationMode', 'exitCommunicationMode']);
      expect(h.client.status, ConnectionStatus.disconnected);
    });
  });
}
