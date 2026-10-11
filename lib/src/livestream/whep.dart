/// Receiving a livestream over WHEP (SPEC §19).
///
/// Owner: **Data & Stats** agent.
library;

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:http/http.dart' as http;

/// A running WHEP playback.
abstract interface class ReceiveLivestreamResult {
  /// The received stream.
  RtcMediaStream get stream;

  /// Sends `DELETE` to the resource and closes the peer connection.
  Future<void> stop();

  /// Peer connection statistics.
  Future<List<RtcStats>> getStatistics();

  /// Connection state changes.
  Stream<PeerConnectionState> get connectionState;
}

/// Starts receiving the livestream at [url]; completes when the first
/// remote stream arrives. Throws `LivestreamException` on HTTP errors.
///
/// Owner: Data & Stats.
Future<ReceiveLivestreamResult> receiveLivestream({
  required RtcAdapter adapter,
  required Uri url,
  String? token,
  http.Client? httpClient,
}) => throw UnimplementedError('Data & Stats');
