import 'package:fishjam_client/src/logger.dart';
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
  ReceiveTransceivers({required this._logger});

  final FishjamLogger _logger;

  /// Missing transceivers are added video first (SPEC §9).
  static const List<MediaKind> _kinds = [MediaKind.video, MediaKind.audio];

  /// Receiver track ids of our receive-only transceivers, per kind. A
  /// transceiver is identified by its receiver's track id (see the class doc).
  final _receiverTrackIds = <MediaKind, List<String>>{
    MediaKind.video: [],
    MediaKind.audio: [],
  };

  /// Makes the live receive transceivers per kind match the numbers the
  /// server asked for in `offerData`, before the offer is created.
  Future<void> sync(
    RtcPeerConnection pc,
    server.MediaEvent_OfferData_TrackTypes types,
  ) async {
    final wantedCount = {
      MediaKind.video: types.video,
      MediaKind.audio: types.audio,
    };
    // Skip the native `getTransceivers()` call when nothing needs stopping.
    if (_receiverTrackIds.entries.any(
      (e) => e.value.length > wantedCount[e.key]!,
    )) {
      await _stopExcess(pc, wantedCount);
    }
    for (final kind in _kinds) {
      for (
        var i = _receiverTrackIds[kind]!.length;
        i < wantedCount[kind]!;
        i++
      ) {
        final transceiver = await pc.addTransceiverOfKind(
          kind,
          const TransceiverInit(direction: TransceiverDirection.recvonly),
        );
        final id = transceiver.receiver.track?.id;
        if (id == null) {
          // Unrecorded, it is added again on the next offerData.
          _logger.warn(
            'A ${kind.name} receive transceiver has no receiver '
            'track; it is not counted',
          );
        } else {
          _receiverTrackIds[kind]!.add(id);
        }
      }
    }
  }

  /// Stops the excess, all from one snapshot: first the transceivers
  /// without a mid (never negotiated) of every kind, then negotiated ones,
  /// because stopping a negotiated one invalidates the handles of those
  /// without a mid.
  Future<void> _stopExcess(
    RtcPeerConnection pc,
    Map<MediaKind, int> wantedCount,
  ) async {
    // One native call. Transceivers without a receiver track are skipped (the
    // `?` key).
    final transceiverByTrackId = {
      for (final t in await pc.getTransceivers()) ?t.receiver.track?.id: t,
    };
    for (final ids in _receiverTrackIds.values) {
      // Forget ids whose transceiver no longer exists (e.g. the server
      // rejected its media section), so the lookups below cannot fail.
      ids.removeWhere((id) => !transceiverByTrackId.containsKey(id));
    }
    for (final stopNegotiated in [false, true]) {
      for (final kind in _kinds) {
        final ids = _receiverTrackIds[kind]!;
        final excess = ids.length - wantedCount[kind]!;
        if (excess <= 0) continue;
        final toStop = ids
            .where(
              (id) => (transceiverByTrackId[id]!.mid != null) == stopNegotiated,
            )
            .take(excess)
            .toList();
        for (final id in toStop) {
          await transceiverByTrackId[id]!.stop();
          ids.remove(id);
        }
      }
    }
  }
}
