import 'package:fishjam_client/src/engine/receive_transceivers.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/rtc/rtc_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_rtc.dart';
import '../tracks/log_capture.dart';

void main() {
  test('a receive transceiver added without a receiver track is reported, '
      'since it cannot be recorded', () async {
    final logs = LogCapture();
    final receive = ReceiveTransceivers(logger: logs.logger);
    final pc = FakePeerConnection(const RtcConfiguration())
      ..receiversWithoutTrack = true;

    await receive.sync(pc, server.MediaEvent_OfferData_TrackTypes(video: 1));

    expect(logs.warnings, [contains('no receiver track')]);
  });
}
