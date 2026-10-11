import 'package:flutter_test/flutter_test.dart';

import 'engine_harness.dart';

/// Replays the negotiation fixtures against the engine with fake Tracks.
/// Steps that only exercise other modules (sender encodings, remote
/// variants and voice activity) are skipped; the full fixtures run against
/// the client once every module is in place.
void main() {
  group('engine-level fixture replay', () {
    test('publish_one_track', () async {
      await EngineHarness().replay('publish_one_track');
    });

    test('publish_three_tracks_batched', () async {
      await EngineHarness().replay('publish_three_tracks_batched');
    });

    test('simulcast_publish (negotiation part)', () async {
      // 14–20: enable/disable encodings and encoding bandwidth (Tracks).
      await EngineHarness().replay(
        'simulcast_publish',
        skip: {for (var i = 14; i <= 20; i++) i},
      );
    });

    test('remote_track_lifecycle (negotiation part)', () async {
      // 19–30: voice activity, target variant, variant events, metadata
      // update (Tracks).
      await EngineHarness().replay(
        'remote_track_lifecycle',
        skip: {for (var i = 19; i <= 30; i++) i},
      );
    });

    test('metadata_updates', () async {
      await EngineHarness().replay('metadata_updates');
    });

    test('renegotiate_on_ice_disconnected', () async {
      await EngineHarness().replay('renegotiate_on_ice_disconnected');
    });

    test('server_error_event', () async {
      await EngineHarness().replay('server_error_event');
    });
  });
}
