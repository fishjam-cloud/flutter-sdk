/// Publishing a livestream over WHIP (SPEC §19).
///
/// Owner: **Data & Stats** agent.
library;

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:http/http.dart' as http;

/// A running WHIP publication.
abstract interface class PublishLivestreamResult {
  /// Sends `DELETE` to the resource and closes the peer connection.
  Future<void> stopPublishing();

  /// Peer connection statistics.
  Future<List<RtcStats>> getStatistics();

  /// Connection state changes.
  Stream<PeerConnectionState> get connectionState;
}

/// Publishes [stream]'s first video and first audio track to [url].
/// Throws [ArgumentError] without tracks and `LivestreamException` on
/// HTTP errors.
///
/// Owner: Data & Stats.
Future<PublishLivestreamResult> publishLivestream({
  required RtcAdapter adapter,
  required RtcMediaStream stream,
  required Uri url,
  required String token,
  http.Client? httpClient,
}) => throw UnimplementedError('Data & Stats');
