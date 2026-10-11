import 'package:collection/collection.dart';
import 'package:fishjam_client/src/livestream/livestream.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:http/http.dart' as http;

/// A running WHIP publication (internal; the public type is
/// `PublishLivestreamResult`).
abstract interface class WhipPublication {
  /// Sends `DELETE` to the resource and closes the peer connection.
  Future<void> stopPublishing();

  Future<List<RtcStats>> getStatistics();

  Stream<PeerConnectionState> get connectionState;
}

/// Publishes [stream]'s first video and first audio track to [url].
/// Throws [ArgumentError] without tracks and `LivestreamException` on
/// HTTP errors. [httpClient] defaults to a new client owned by the
/// publication; [logger] defaults to a disabled one. ICE gathering waits
/// at most [iceGatheringTimeout].
Future<WhipPublication> publishWhip({
  required RtcAdapter adapter,
  required RtcMediaStream stream,
  required Uri url,
  required String token,
  http.Client? httpClient,
  FishjamLogger? logger,
  Duration iceGatheringTimeout = defaultIceGatheringTimeout,
}) async {
  final tracks = [
    stream.tracks.firstWhereOrNull((t) => t.kind == MediaKind.video),
    stream.tracks.firstWhereOrNull((t) => t.kind == MediaKind.audio),
  ].nonNulls.toList();
  if (tracks.isEmpty) {
    throw ArgumentError.value(
      stream,
      'stream',
      'needs at least one video or audio track',
    );
  }
  final connection = await connectLivestream(
    adapter: adapter,
    url: url,
    token: token,
    publishing: true,
    httpClient: httpClient,
    logger: logger,
    iceGatheringTimeout: iceGatheringTimeout,
    configure: (pc) async {
      for (final track in tracks) {
        await pc.addTransceiverWithTrack(
          track,
          const TransceiverInit(direction: TransceiverDirection.sendonly),
        );
      }
    },
  );
  return _WhipPublication(connection);
}

final class _WhipPublication implements WhipPublication {
  _WhipPublication(this._connection);

  final LivestreamConnection _connection;

  @override
  Future<void> stopPublishing() => _connection.stop();

  @override
  Future<List<RtcStats>> getStatistics() => _connection.getStatistics();

  @override
  Stream<PeerConnectionState> get connectionState =>
      _connection.connectionState;
}
