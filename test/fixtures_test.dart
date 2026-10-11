import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

/// Every scenario the spec requires a golden sequence for.
const _required = {
  'join_empty_room',
  'join_room_with_peers',
  'publish_one_track',
  'publish_three_tracks_batched',
  'simulcast_publish',
  'remote_track_lifecycle',
  'peer_joined_updated_left',
  'metadata_updates',
  'renegotiate_on_ice_disconnected',
  'server_error_event',
  'auth_failure_close',
  'join_failure_close',
  'reconnect_with_track_restore',
  'data_channels',
  'session_ended_close',
};

void main() {
  test('every required fixture exists', () {
    expect(Fixture.all().toSet(), containsAll(_required));
  });
}
