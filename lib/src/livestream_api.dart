/// Public WHIP/WHEP API on `flutter_webrtc` types (SPEC §19).
///
/// Owner: **Integrator**. Wraps the internal `livestream/` module
/// (`publishWhip` / `receiveWhep`, owned by Data & Stats); conversion
/// between `flutter_webrtc` and the internal seam happens only here.
library;

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;

/// A running livestream publication.
abstract interface class PublishLivestreamResult {
  /// Stops publishing (HTTP `DELETE`) and closes the connection.
  Future<void> stopPublishing();

  /// Connection statistics.
  Future<List<RtcStats>> getStatistics();

  /// Connection state changes.
  Stream<PeerConnectionState> get connectionState;
}

/// A running livestream playback.
abstract interface class ReceiveLivestreamResult {
  /// The received stream, ready for `RTCVideoRenderer.srcObject`.
  MediaStream get stream;

  /// Stops playback (HTTP `DELETE`) and closes the connection.
  Future<void> stop();

  /// Connection statistics.
  Future<List<RtcStats>> getStatistics();

  /// Connection state changes.
  Stream<PeerConnectionState> get connectionState;
}

/// Publishes the first video and first audio track of [stream] to the WHIP
/// endpoint [url]. Throws `ArgumentError` when [stream] has no tracks and
/// `LivestreamException` on HTTP errors.
///
/// Owner: Integrator.
Future<PublishLivestreamResult> publishLivestream(
  MediaStream stream, {
  required Uri url,
  required String token,
}) => throw UnimplementedError('Integrator');

/// Plays the livestream at the WHEP endpoint [url]; completes when the first
/// remote stream arrives. Throws `LivestreamException` on HTTP errors.
///
/// Owner: Integrator.
Future<ReceiveLivestreamResult> receiveLivestream({
  required Uri url,
  String? token,
}) => throw UnimplementedError('Integrator');
