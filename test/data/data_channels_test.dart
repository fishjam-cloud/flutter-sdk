import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/data/data_channels.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';

Uint8List bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('ChannelMessage framing (SPEC §16)', () {
    test('encodes source, destinations ["*"] and the binary payload', () {
      // Golden bytes from test/fixtures/data_channels.json.
      expect(encodeChannelMessage(bytes([104, 105]), source: 'local-peer'), [
        10, 10, 108, 111, 99, 97, 108, 45, 112, 101, 101, 114, //
        18, 1, 42, 26, 4, 10, 2, 104, 105,
      ]);
    });

    test('decodes the binary payload', () {
      final message = ChannelMessage(
        source: 'other',
        destinations: ['*'],
        binary: ChannelMessageBinaryPayload(data: [1, 2, 3]),
      ).writeToBuffer();
      expect(decodeChannelMessage(message), [1, 2, 3]);
    });

    test('round-trips an empty payload', () {
      expect(
        decodeChannelMessage(encodeChannelMessage(bytes([]), source: 'p')),
        isEmpty,
      );
    });

    test('returns null for a message without a binary payload', () {
      final message = ChannelMessage(source: 'other').writeToBuffer();
      expect(decodeChannelMessage(message), isNull);
    });

    test('returns null for undecodable bytes', () {
      expect(decodeChannelMessage(bytes([0xff, 0xff, 0xff])), isNull);
    });
  });

  group('DataChannelManager', () {
    late FakePeerConnection pc;
    late List<FishjamEvent> events;
    late List<String> logs;
    late int negotiations;
    late Completer<void>? negotiationGate;
    late DataChannelManager manager;

    setUp(() {
      pc = FakePeerConnection(const RtcConfiguration());
      events = [];
      logs = [];
      negotiations = 0;
      negotiationGate = null;
      manager = DataChannelManager(
        logger: FishjamLogger(
          enabled: true,
          sink: (level, message, {error, stackTrace}) => logs.add(message),
        ),
        negotiate: (apply) async {
          negotiations++;
          await apply(pc);
          await negotiationGate?.future;
        },
        emit: events.add,
        localPeerId: () => 'local-peer',
      );
    });

    FakeDataChannel channel(String label) =>
        pc.dataChannels.lastWhere((c) => c.label == label);

    Future<void> openBoth() async {
      channel(reliableLabel).open();
      channel(lossyLabel).open();
      await pumpEventQueue();
    }

    test('creates exactly the reliable and lossy channels', () async {
      unawaited(manager.createChannels());
      await pumpEventQueue();

      expect(pc.callsOf('createDataChannel').map((c) => c.args), [
        {'label': 'reliable', 'ordered': true},
        {'label': 'lossy', 'ordered': false, 'maxRetransmits': 0},
      ]);
      expect(negotiations, 1);
    });

    test('completes and emits DataChannelsReady once both are open', () async {
      var done = false;
      unawaited(manager.createChannels().then((_) => done = true));
      await pumpEventQueue();

      channel(reliableLabel).open();
      await pumpEventQueue();
      expect(done, isFalse);
      expect(manager.isReady, isFalse);
      expect(events, isEmpty);

      channel(lossyLabel).open();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(manager.isReady, isTrue);
      expect(events.whereType<DataChannelsReady>(), hasLength(1));
    });

    test('waits for the negotiation as well as for the channels', () async {
      negotiationGate = Completer<void>();
      var done = false;
      unawaited(manager.createChannels().then((_) => done = true));
      await pumpEventQueue();
      await openBoth();
      expect(done, isFalse);

      negotiationGate!.complete();
      await pumpEventQueue();
      expect(done, isTrue);
    });

    test('concurrent calls share one negotiation', () async {
      final first = manager.createChannels();
      final second = manager.createChannels();
      await pumpEventQueue();
      await openBoth();

      await Future.wait([first, second]);
      expect(negotiations, 1);
      expect(pc.dataChannels, hasLength(2));
      expect(events.whereType<DataChannelsReady>(), hasLength(1));
    });

    test('is a no-op when both channels are already open', () async {
      final first = manager.createChannels();
      await pumpEventQueue();
      await openBoth();
      await first;

      await manager.createChannels();
      expect(negotiations, 1);
      expect(events.whereType<DataChannelsReady>(), hasLength(1));
    });

    test(
      'fails and emits DataChannelsError when a channel closes before opening',
      () async {
        final future = manager.createChannels();
        await pumpEventQueue();
        channel(reliableLabel).open();
        channel(lossyLabel).closeFromRemote();

        await expectLater(future, throwsA(isA<StateError>()));
        expect(events.whereType<DataChannelsError>(), hasLength(1));
        expect(events.whereType<DataChannelsReady>(), isEmpty);
        expect(manager.isReady, isFalse);
      },
    );

    test(
      'fails and emits DataChannelsError when the negotiation fails',
      () async {
        pc.failNext('createDataChannel', StateError('boom'));

        await expectLater(
          manager.createChannels(),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'boom'),
          ),
        );
        final error = events.whereType<DataChannelsError>().single;
        expect(error.error, isA<StateError>());
      },
    );

    test('can be retried after a failure', () async {
      final failed = manager.createChannels();
      await pumpEventQueue();
      channel(lossyLabel).closeFromRemote();
      await expectLater(failed, throwsStateError);

      final retry = manager.createChannels();
      await pumpEventQueue();
      expect(negotiations, 2);
      await openBoth();
      await retry;
      expect(manager.isReady, isTrue);
    });

    test('a channel closing after readiness clears isReady', () async {
      final future = manager.createChannels();
      await pumpEventQueue();
      await openBoth();
      await future;

      channel(lossyLabel).closeFromRemote();
      await pumpEventQueue();
      expect(manager.isReady, isFalse);
      expect(events.whereType<DataChannelsError>(), isEmpty);
    });

    group('publish', () {
      test('throws StateError before the channels exist', () {
        expect(
          () => manager.publish(bytes([1]), reliable: true),
          throwsStateError,
        );
      });

      test('throws StateError while the channel is not open', () async {
        unawaited(manager.createChannels());
        await pumpEventQueue();
        channel(reliableLabel).open();
        expect(
          () => manager.publish(bytes([1]), reliable: false),
          throwsStateError,
        );
      });

      test('frames the payload on the chosen channel', () async {
        final future = manager.createChannels();
        await pumpEventQueue();
        await openBoth();
        await future;

        manager
          ..publish(bytes([104, 105]), reliable: true)
          ..publish(bytes([1]), reliable: false);
        await pumpEventQueue();

        expect(channel(reliableLabel).sent, [
          encodeChannelMessage(bytes([104, 105]), source: 'local-peer'),
        ]);
        expect(channel(lossyLabel).sent, [
          encodeChannelMessage(bytes([1]), source: 'local-peer'),
        ]);
      });
    });

    group('dataStream', () {
      test(
        'delivers payloads per channel, subscribed before creation',
        () async {
          final reliable = <Uint8List>[];
          final lossy = <Uint8List>[];
          manager.dataStream(reliable: true).listen(reliable.add);
          manager.dataStream(reliable: false).listen(lossy.add);

          unawaited(manager.createChannels());
          await pumpEventQueue();
          await openBoth();

          channel(reliableLabel)
              .receive(encodeChannelMessage(bytes([1, 2]), source: 'other'));
          channel(lossyLabel)
              .receive(encodeChannelMessage(bytes([3]), source: 'other'));
          await pumpEventQueue();

          expect(reliable, [
            [1, 2],
          ]);
          expect(lossy, [
            [3],
          ]);
        },
      );

      test('cancelling the subscription stops delivery', () async {
        final received = <Uint8List>[];
        final subscription = manager
            .dataStream(reliable: true)
            .listen(received.add);

        unawaited(manager.createChannels());
        await pumpEventQueue();
        await openBoth();
        await subscription.cancel();

        channel(reliableLabel)
            .receive(encodeChannelMessage(bytes([1]), source: 'other'));
        await pumpEventQueue();
        expect(received, isEmpty);
      });

      test('ignores messages without a binary payload and logs them', () async {
        final received = <Uint8List>[];
        manager.dataStream(reliable: true).listen(received.add);
        unawaited(manager.createChannels());
        await pumpEventQueue();
        await openBoth();

        channel(reliableLabel)
          ..receive(ChannelMessage(source: 'other').writeToBuffer())
          ..receive(bytes([0xff, 0xff]));
        await pumpEventQueue();

        expect(received, isEmpty);
        expect(
          logs.where((l) => l.contains('Dropped data channel message')),
          hasLength(2),
        );
      });
    });

    group('close', () {
      test('closes both channels', () async {
        final future = manager.createChannels();
        await pumpEventQueue();
        await openBoth();
        await future;

        await manager.close();
        expect(channel(reliableLabel).state, DataChannelState.closed);
        expect(channel(lossyLabel).state, DataChannelState.closed);
        expect(manager.isReady, isFalse);
        expect(
          () => manager.publish(bytes([1]), reliable: true),
          throwsStateError,
        );
      });

      test('fails a pending createChannels without emitting', () async {
        final future = manager.createChannels();
        await pumpEventQueue();
        final failed = expectLater(
          future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'disconnected',
            ),
          ),
        );

        await manager.close();
        await failed;
        expect(events, isEmpty);
      });

      test('keeps data stream subscriptions for the next session', () async {
        final received = <Uint8List>[];
        manager.dataStream(reliable: true).listen(received.add);
        await manager.close();

        unawaited(manager.createChannels());
        await pumpEventQueue();
        await openBoth();
        channel(reliableLabel)
            .receive(encodeChannelMessage(bytes([7]), source: 'other'));
        await pumpEventQueue();
        expect(received, [
          [7],
        ]);
      });

      test('stops delivering messages from closed channels', () async {
        final received = <Uint8List>[];
        manager.dataStream(reliable: true).listen(received.add);
        unawaited(manager.createChannels());
        await pumpEventQueue();
        await openBoth();
        final old = channel(reliableLabel);

        await manager.close();
        old.receive(encodeChannelMessage(bytes([1]), source: 'other'));
        await pumpEventQueue();
        expect(received, isEmpty);
      });
    });

    group('review fixes', () {
      DataChannelManager build(
        Future<void> Function(Future<void> Function(RtcPeerConnection pc) apply)
        negotiate,
      ) => DataChannelManager(
        logger: FishjamLogger(
          enabled: true,
          sink: (level, message, {error, stackTrace}) => logs.add(message),
        ),
        negotiate: negotiate,
        emit: events.add,
        localPeerId: () => 'local-peer',
      );

      test('a synchronously throwing negotiate can be retried', () async {
        var attempts = 0;
        final manager = build((apply) {
          attempts++;
          if (attempts == 1) throw StateError('not connected');
          return apply(pc);
        });

        await expectLater(manager.createChannels(), throwsStateError);
        expect(events.whereType<DataChannelsError>(), hasLength(1));

        final retry = manager.createChannels();
        await pumpEventQueue();
        expect(attempts, 2);
        await openBoth();
        await retry;
        expect(manager.isReady, isTrue);
      });

      test('negotiate failing before the room is joined is a normal '
          'failure', () async {
        final manager = build(
          (apply) async => throw StateError('not connected'),
        );
        await expectLater(
          manager.createChannels(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'not connected',
            ),
          ),
        );
        expect(events.whereType<DataChannelsError>(), hasLength(1));
      });

      test('a command failed by teardown is a silent cancel', () async {
        final gate = Completer<void>();
        final manager = build((apply) async {
          await apply(pc);
          await gate.future;
          throw StateError('disconnected');
        });
        final future = manager.createChannels();
        final failed = expectLater(
          future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'disconnected',
            ),
          ),
        );
        await pumpEventQueue();

        gate.complete();
        await failed;
        expect(events, isEmpty);
        expect(manager.isReady, isFalse);
        expect(channel(reliableLabel).state, DataChannelState.closed);
      });

      test('a channel created after teardown is closed', () async {
        late DataChannelManager manager;
        manager = build((apply) async {
          final applying = apply(pc);
          // Teardown while createDataChannel is in flight.
          unawaited(manager.close());
          await applying;
        });
        await expectLater(
          manager.createChannels(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'disconnected',
            ),
          ),
        );
        await pumpEventQueue();
        expect(pc.dataChannels, hasLength(1));
        expect(pc.dataChannels.single.state, DataChannelState.closed);
        expect(events, isEmpty);
      });

      test('a failing send is logged, not thrown', () async {
        final failing = _FailingPeerConnection();
        final manager = build((apply) => apply(failing));
        final future = manager.createChannels();
        await pumpEventQueue();
        for (final c in failing.dataChannels) {
          c.open();
        }
        await future;

        manager.publish(bytes([1]), reliable: true);
        await pumpEventQueue();
        expect(
          logs.where((l) => l.contains('Sending on data channel reliable')),
          hasLength(1),
        );
      });

      test('a failing channel close is logged, not thrown', () async {
        final failing = _FailingPeerConnection();
        final manager = build((apply) => apply(failing));
        manager.createChannels().ignore(); // fails with 'disconnected'
        await pumpEventQueue();

        await manager.close();
        expect(
          logs.where((l) => l.contains('Closing data channel')),
          hasLength(2),
        );
      });

      test('dispose ends data streams', () async {
        final reliableDone = manager.dataStream(reliable: true).toList();
        final lossyDone = manager.dataStream(reliable: false).toList();
        unawaited(manager.createChannels().catchError((Object _) {}));
        await pumpEventQueue();

        await manager.dispose();
        expect(await reliableDone, isEmpty);
        expect(await lossyDone, isEmpty);
        expect(channel(reliableLabel).state, DataChannelState.closed);
      });
    });
  });
}

/// Hands out channels whose `send` and `close` fail.
class _FailingPeerConnection extends FakePeerConnection {
  _FailingPeerConnection() : super(const RtcConfiguration());

  final List<FakeDataChannel> _inner = [];

  @override
  List<FakeDataChannel> get dataChannels => _inner;

  @override
  Future<RtcDataChannel> createDataChannel(
    String label,
    DataChannelInit init,
  ) async {
    final inner = await super.createDataChannel(label, init) as FakeDataChannel;
    _inner.add(inner);
    return _FailingChannel(inner);
  }
}

class _FailingChannel implements RtcDataChannel {
  _FailingChannel(this._inner);

  final FakeDataChannel _inner;

  @override
  String get label => _inner.label;

  @override
  DataChannelState get state => _inner.state;

  @override
  Stream<DataChannelState> get onStateChange => _inner.onStateChange;

  @override
  Stream<Uint8List> get onMessage => _inner.onMessage;

  @override
  Future<void> send(Uint8List data) async => throw StateError('send failed');

  @override
  Future<void> close() async => throw StateError('close failed');
}
