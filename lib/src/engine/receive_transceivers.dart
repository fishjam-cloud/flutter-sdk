import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Makes the live receive transceivers per kind match the numbers the
/// server asked for in `offerData`, before the offer is created.
Future<void> syncReceiveTransceivers(
  RtcPeerConnection pc,
  server.MediaEvent_OfferData_TrackTypes types,
) async {
  final live = <MediaKind, List<RtcRtpTransceiver>>{
    MediaKind.video: [],
    MediaKind.audio: [],
  };
  for (final t in await pc.getTransceivers()) {
    if (await t.getDirection() == TransceiverDirection.recvonly &&
        await t.getCurrentDirection() != TransceiverDirection.stopped) {
      live[t.receiver.kind]!.add(t);
    }
  }
  final wanted = {MediaKind.video: types.video, MediaKind.audio: types.audio};
  for (final kind in [MediaKind.video, MediaKind.audio]) {
    final have = live[kind]!;
    final excess = have.length - wanted[kind]!;
    if (excess <= 0) continue;
    // Transceivers without a mid were never negotiated: stop them first.
    final candidates = [
      ...have.where((t) => t.mid == null),
      ...have.where((t) => t.mid != null),
    ];
    for (final t in candidates.take(excess)) {
      await t.stop();
    }
  }
  for (final kind in [MediaKind.video, MediaKind.audio]) {
    for (var i = live[kind]!.length; i < wanted[kind]!; i++) {
      await pc.addTransceiverOfKind(
        kind,
        const TransceiverInit(direction: TransceiverDirection.recvonly),
      );
    }
  }
}
