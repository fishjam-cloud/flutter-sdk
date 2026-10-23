import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// The receive-only transceivers of one peer connection (SPEC §9).
///
/// This client always makes the offer, so every transceiver in the peer
/// connection was created here: the receive ones are recorded by their
/// receiver's track id, which stays the same in every snapshot, instead of
/// asking each transceiver for its direction. Per-transceiver native calls
/// are unreliable in the WebRTC plugin: on Android a call on a negotiated
/// transceiver disposes the handles of the ones without a mid, and on iOS all
/// transceivers without a mid share one id.
class ReceiveTransceivers {
  final _live = <MediaKind, List<String>>{
    MediaKind.video: [],
    MediaKind.audio: [],
  };

  /// Makes the live receive transceivers per kind match the numbers the
  /// server asked for in `offerData`, before the offer is created.
  Future<void> sync(
    RtcPeerConnection pc,
    server.MediaEvent_OfferData_TrackTypes types,
  ) async {
    final wanted = {MediaKind.video: types.video, MediaKind.audio: types.audio};
    if (_live.entries.any((e) => e.value.length > wanted[e.key]!)) {
      await _stopExcess(pc, wanted);
    }
    for (final kind in [MediaKind.video, MediaKind.audio]) {
      for (var i = _live[kind]!.length; i < wanted[kind]!; i++) {
        final transceiver = await pc.addTransceiverOfKind(
          kind,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        final id = transceiver.receiver.track?.id;
        if (id != null) _live[kind]!.add(id);
      }
    }
  }

  /// Transceivers without a mid were never negotiated: they are stopped
  /// first. They are also stopped before any negotiated one, from one
  /// snapshot, because stopping a negotiated one invalidates their handles.
  Future<void> _stopExcess(
    RtcPeerConnection pc,
    Map<MediaKind, int> wanted,
  ) async {
    final snapshot = {
      for (final t in await pc.getTransceivers()) ?t.receiver.track?.id: t,
    };
    final victims = <(MediaKind, String, RtcRtpTransceiver)>[];
    for (final kind in [MediaKind.video, MediaKind.audio]) {
      // A recorded transceiver missing from the snapshot is gone already.
      final live = _live[kind]!..removeWhere((id) => !snapshot.containsKey(id));
      final excess = live.length - wanted[kind]!;
      if (excess <= 0) continue;
      final ordered = [
        ...live.where((id) => snapshot[id]!.mid == null),
        ...live.where((id) => snapshot[id]!.mid != null),
      ];
      victims.addAll([
        for (final id in ordered.take(excess)) (kind, id, snapshot[id]!),
      ]);
    }
    for (final (kind, id, transceiver) in [
      ...victims.where((v) => v.$3.mid == null),
      ...victims.where((v) => v.$3.mid != null),
    ]) {
      await transceiver.stop();
      _live[kind]!.remove(id);
    }
  }
}
