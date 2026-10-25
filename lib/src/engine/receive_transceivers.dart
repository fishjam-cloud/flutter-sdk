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
  /// Missing transceivers are added video first (SPEC §9).
  static const List<MediaKind> _kinds = [MediaKind.video, MediaKind.audio];

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
    // Without an excess there is nothing to stop, and no native
    // `getTransceivers()` is made.
    if (_live.entries.any((e) => e.value.length > wanted[e.key]!)) {
      await _stopExcess(pc, wanted);
    }
    for (final kind in _kinds) {
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

  /// Stops the excess, all from one snapshot: first the transceivers
  /// without a mid (never negotiated) of every kind, then negotiated ones,
  /// because stopping a negotiated one invalidates the handles of those
  /// without a mid.
  Future<void> _stopExcess(
    RtcPeerConnection pc,
    Map<MediaKind, int> wanted,
  ) async {
    final snapshot = {
      for (final t in await pc.getTransceivers()) ?t.receiver.track?.id: t,
    };
    for (final ids in _live.values) {
      // A recorded transceiver missing from the snapshot is gone already.
      ids.removeWhere((id) => !snapshot.containsKey(id));
    }
    for (final negotiated in [false, true]) {
      for (final kind in _kinds) {
        final ids = _live[kind]!;
        final excess = ids.length - wanted[kind]!;
        if (excess <= 0) continue;
        final victims = ids
            .where((id) => (snapshot[id]!.mid != null) == negotiated)
            .take(excess)
            .toList();
        for (final id in victims) {
          await snapshot[id]!.stop();
          ids.remove(id);
        }
      }
    }
  }
}
