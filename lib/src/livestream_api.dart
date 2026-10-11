/// Public WHIP/WHEP API on `flutter_webrtc` types, wrapping the internal
/// `livestream/` module.
library;

import 'package:fishjam_client/src/livestream/whep.dart';
import 'package:fishjam_client/src/livestream/whip.dart';
import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A running livestream publication.
abstract interface class PublishLivestreamResult {
  /// Stops publishing (HTTP `DELETE`) and closes the connection.
  Future<void> stopPublishing();

  Future<List<RtcStats>> getStatistics();

  Stream<PeerConnectionState> get connectionState;
}

/// A running livestream playback.
abstract interface class ReceiveLivestreamResult {
  /// The received stream, ready for `RTCVideoRenderer.srcObject`.
  MediaStream get stream;

  /// Stops playback (HTTP `DELETE`) and closes the connection.
  Future<void> stop();

  Future<List<RtcStats>> getStatistics();

  Stream<PeerConnectionState> get connectionState;
}

/// Publishes the first video and first audio track of [stream] to the WHIP
/// endpoint [url]. Throws `ArgumentError` when [stream] has no tracks and
/// `LivestreamException` on HTTP errors.
Future<PublishLivestreamResult> publishLivestream(
  MediaStream stream, {
  required Uri url,
  required String token,
}) => publishLivestreamWith(stream, url: url, token: token);

/// [publishLivestream] on a custom adapter and HTTP client (tests only).
@internal
Future<PublishLivestreamResult> publishLivestreamWith(
  MediaStream stream, {
  required Uri url,
  required String token,
  RtcAdapter? rtcAdapter,
  http.Client? httpClient,
}) async {
  final publication = await publishWhip(
    adapter: rtcAdapter ?? const FlutterWebrtcAdapter(),
    stream: wrapNativeStream(stream),
    url: url,
    token: token,
    httpClient: httpClient,
  );
  return _PublishLivestreamResult(publication);
}

/// Plays the livestream at the WHEP endpoint [url]; completes when the first
/// remote stream arrives. Throws `LivestreamException` on HTTP errors.
Future<ReceiveLivestreamResult> receiveLivestream({
  required Uri url,
  String? token,
}) => receiveLivestreamWith(url: url, token: token);

/// [receiveLivestream] on a custom adapter and HTTP client (tests only).
@internal
Future<ReceiveLivestreamResult> receiveLivestreamWith({
  required Uri url,
  String? token,
  RtcAdapter? rtcAdapter,
  http.Client? httpClient,
}) async {
  final playback = await receiveWhep(
    adapter: rtcAdapter ?? const FlutterWebrtcAdapter(),
    url: url,
    token: token,
    httpClient: httpClient,
  );
  return _ReceiveLivestreamResult(playback);
}

final class _PublishLivestreamResult implements PublishLivestreamResult {
  _PublishLivestreamResult(this._publication);

  final WhipPublication _publication;

  @override
  Future<void> stopPublishing() => _publication.stopPublishing();

  @override
  Future<List<RtcStats>> getStatistics() => _publication.getStatistics();

  @override
  Stream<PeerConnectionState> get connectionState =>
      _publication.connectionState;
}

final class _ReceiveLivestreamResult implements ReceiveLivestreamResult {
  _ReceiveLivestreamResult(this._playback);

  final WhepPlayback _playback;

  @override
  MediaStream get stream =>
      nativeStreamOf(_playback.stream) ??
      (throw StateError('The stream is not a flutter_webrtc stream'));

  @override
  Future<void> stop() => _playback.stop();

  @override
  Future<List<RtcStats>> getStatistics() => _playback.getStatistics();

  @override
  Stream<PeerConnectionState> get connectionState => _playback.connectionState;
}
