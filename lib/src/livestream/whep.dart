/// Receiving a livestream over WHEP (SPEC §19).
///
/// Owner: **Data & Stats** agent.
library;

import 'dart:async';

import 'package:fishjam_client/src/livestream/livestream.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:http/http.dart' as http;

/// A running WHEP playback (internal; the public type is
/// `ReceiveLivestreamResult`).
abstract interface class WhepPlayback {
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
/// remote stream arrives. Throws `LivestreamException` on HTTP errors, or
/// when the connection fails or closes before a stream arrived.
/// [httpClient] defaults to a new client owned by the playback; [logger]
/// defaults to a disabled one.
Future<WhepPlayback> receiveWhep({
  required RtcAdapter adapter,
  required Uri url,
  String? token,
  http.Client? httpClient,
  FishjamLogger? logger,
}) async {
  final firstStream = Completer<RtcMediaStream>();
  // Errors are delivered by the await below; this only avoids reporting
  // them as unhandled when the exchange itself failed first.
  firstStream.future.ignore();
  void fail(String reason) {
    if (firstStream.isCompleted) return;
    firstStream.completeError(
      LivestreamException(
        LivestreamError.unknownError,
        cause: StateError(reason),
      ),
    );
  }

  final subscriptions = <StreamSubscription<Object?>>[];
  try {
    final connection = await connectLivestream(
      adapter: adapter,
      url: url,
      token: token,
      publishing: false,
      httpClient: httpClient,
      logger: logger,
      configure: (pc) async {
        subscriptions
          ..add(
            pc.onTrack.listen((event) {
              if (event.streams.isEmpty || firstStream.isCompleted) return;
              firstStream.complete(event.streams.first);
            }, onDone: () => fail('connection closed before a stream arrived')),
          )
          ..add(
            pc.onConnectionState.listen((state) {
              if (state == PeerConnectionState.failed) {
                fail('connection failed before a stream arrived');
              }
            }),
          );
        for (final kind in const [MediaKind.video, MediaKind.audio]) {
          await pc.addTransceiverOfKind(
            kind,
            const TransceiverInit(direction: TransceiverDirection.recvonly),
          );
        }
      },
    );
    try {
      return _WhepPlayback(await firstStream.future, connection);
    } on Object {
      await connection.stop();
      rethrow;
    }
  } finally {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
  }
}

final class _WhepPlayback implements WhepPlayback {
  _WhepPlayback(this.stream, this._connection);

  @override
  final RtcMediaStream stream;

  final LivestreamConnection _connection;

  @override
  Future<void> stop() => _connection.stop();

  @override
  Future<List<RtcStats>> getStatistics() => _connection.getStatistics();

  @override
  Stream<PeerConnectionState> get connectionState =>
      _connection.connectionState;
}
