// Imports every hand-written library so `flutter test --coverage` reports
// files that no test touches yet (the coverage gate must see them).
// ignore_for_file: unused_import, directives_ordering

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:fishjam_client/src/data/data_channels.dart';
import 'package:fishjam_client/src/engine/command_queue.dart';
import 'package:fishjam_client/src/engine/negotiation_state.dart';
import 'package:fishjam_client/src/engine/rtc_engine.dart';
import 'package:fishjam_client/src/fishjam_client.dart';
import 'package:fishjam_client/src/livestream/livestream.dart';
import 'package:fishjam_client/src/livestream/whep.dart';
import 'package:fishjam_client/src/livestream/whip.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/signaling/auth.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/reconnect.dart';
import 'package:fishjam_client/src/signaling/signaling_session.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:fishjam_client/src/stats/audio_level.dart';
import 'package:fishjam_client/src/stats/stats_reporter.dart';
import 'package:fishjam_client/src/tracks/bandwidth.dart';
import 'package:fishjam_client/src/tracks/encodings.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:fishjam_client/src/version.dart';
import 'package:fishjam_client/src/wire.dart';

const _imported = {
  'fishjam_client.dart',
  'src/data/data_channels.dart',
  'src/engine/command_queue.dart',
  'src/engine/negotiation_state.dart',
  'src/engine/rtc_engine.dart',
  'src/fishjam_client.dart',
  'src/livestream/livestream.dart',
  'src/livestream/whep.dart',
  'src/livestream/whip.dart',
  'src/logger.dart',
  'src/models/config.dart',
  'src/models/endpoint.dart',
  'src/models/errors.dart',
  'src/models/events.dart',
  'src/models/simulcast.dart',
  'src/models/track.dart',
  'src/rtc/flutter_webrtc_adapter.dart',
  'src/rtc/rtc_adapter.dart',
  'src/signaling/auth.dart',
  'src/signaling/message_queue.dart',
  'src/signaling/reconnect.dart',
  'src/signaling/signaling_session.dart',
  'src/signaling/transport.dart',
  'src/stats/audio_level.dart',
  'src/stats/stats_reporter.dart',
  'src/tracks/bandwidth.dart',
  'src/tracks/encodings.dart',
  'src/tracks/local_track.dart',
  'src/tracks/remote_track.dart',
  'src/version.dart',
  'src/wire.dart',
};

void main() {
  test('imports every library under lib/ (generated code excluded)', () {
    final actual = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.substring('lib/'.length))
        .where((p) => p.endsWith('.dart') && !p.startsWith('src/proto/'))
        .toSet();

    expect(
      actual,
      _imported,
      reason: 'add new library files to test/all_libraries_test.dart',
    );
  });
}
