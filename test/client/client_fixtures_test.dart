import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';
import '../public/native_fakes.dart';
import '../support/fixtures.dart';

/// Replays every golden fixture, step by step, against the real
/// [FishjamClient] wired to the fakes (SPEC §23).
void main() {
  for (final name in Fixture.all()) {
    test(name, () async {
      final fixture = Fixture.load(name);
      final transports = FakeTransportFactory();
      final rtc = FakeRtcAdapter();
      final client = FishjamClient.internal(
        reconnect: _reconnectConfig(fixture.config),
        rtcAdapter: rtc,
        transportFactory: transports.call,
      );
      final events = <FishjamEvent>[];
      final subscription = client.events.listen(events.add);
      late final FixtureReplayer replayer;
      replayer = FixtureReplayer(
        fixture: fixture,
        transports: transports,
        rtc: rtc,
        events: events,
        onApi: (step) => _api(
          client,
          step.call,
          replayer.bindings.substitute(step.args)! as Map<String, Object?>,
        ),
      );
      await replayer.run();
      expect(events.whereType<Disconnected>().length, lessThanOrEqualTo(1));
      await client.dispose();
      await subscription.cancel();
    });
  }
}

var _trackCounter = 0;

FutureOr<Object?> _api(
  FishjamClient client,
  String call,
  Map<String, Object?> args,
) {
  String trackId() => args['trackId']! as String;
  Variant variant() => Variant.values.byName(args['variant']! as String);
  return switch (call) {
    'connect' => client.connect(
      url: args['url']! as String,
      token: args['token']! as String,
      peerMetadata: args['peerMetadata'],
    ),
    'leave' => client.leave(),
    'addTrack' => client.addTrack(
      NativeTrack('media-${_trackCounter++}', args['kind']! as String),
      metadata: TrackMetadata.tryParse(args['metadata']),
      simulcastConfig: _simulcast(args['simulcastConfig']),
      maxBandwidth: _bandwidth(args['maxBandwidth']),
    ),
    'removeTrack' => client.removeTrack(trackId()),
    'replaceTrack' => client.replaceTrack(trackId(), switch (args['kind']) {
      final String kind => NativeTrack('media-${_trackCounter++}', kind),
      _ => null,
    }),
    'setTrackBandwidth' => client.setTrackBandwidth(
      trackId(),
      _bandwidth(args['maxBandwidth']),
    ),
    'setEncodingBandwidth' => client.setEncodingBandwidth(
      trackId(),
      variant(),
      args['kbps']! as int,
    ),
    'enableTrackEncoding' => client.enableTrackEncoding(trackId(), variant()),
    'disableTrackEncoding' => client.disableTrackEncoding(trackId(), variant()),
    'setTargetTrackEncoding' => _sync(
      () => client.setTargetTrackEncoding(trackId(), variant()),
    ),
    'updatePeerMetadata' => _sync(
      () => client.updatePeerMetadata(args['metadata']),
    ),
    'updateTrackMetadata' => _sync(
      () => client.updateTrackMetadata(
        trackId(),
        TrackMetadata.tryParse(args['metadata']),
      ),
    ),
    'createDataChannels' => client.createDataChannels(),
    'publishData' => _sync(
      () => client.publishData(
        Uint8List.fromList((args['data']! as List<Object?>).cast<int>()),
        reliable: args['reliable']! as bool,
      ),
    ),
    _ => throw UnimplementedError('fixture api call $call'),
  };
}

/// Runs a synchronous API call; its errors are thrown to the replayer.
Object? _sync(void Function() call) {
  call();
  return null;
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

SimulcastConfig _simulcast(Object? json) {
  if (json is! Map<String, Object?>) return const SimulcastConfig.disabled();
  return SimulcastConfig(
    enabled: json['enabled']! as bool,
    enabledVariants: [
      for (final v in (json['enabledVariants'] as List<Object?>?) ?? const [])
        Variant.values.byName(v! as String),
    ],
  );
}

BandwidthLimit _bandwidth(Object? json) => switch (json) {
  null => BandwidthLimit.unlimited,
  final int kbps => BandwidthLimit.single(kbps),
  final Map<String, Object?> map => BandwidthLimit.simulcast({
    for (final e in map.entries) Variant.values.byName(e.key): e.value! as int,
  }),
  _ => throw ArgumentError(json),
};
