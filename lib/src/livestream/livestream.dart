/// Shared WHIP/WHEP plumbing (SPEC §19).
///
/// Owner: **Data & Stats** agent.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:http/http.dart' as http;

/// How long to wait for ICE gathering before sending the offer with the
/// candidates gathered so far (SPEC §19).
const defaultIceGatheringTimeout = Duration(seconds: 3);

/// How long WHEP playback waits for the first remote stream (SPEC §19).
const defaultFirstStreamTimeout = Duration(seconds: 10);

/// Maps a failed POST status to a [LivestreamError] (SPEC §19).
LivestreamError livestreamErrorForStatus(
  int statusCode, {
  required bool publishing,
}) => switch (statusCode) {
  401 => LivestreamError.unauthorized,
  404 => LivestreamError.streamNotFound,
  409 when publishing => LivestreamError.streamerAlreadyConnected,
  _ => LivestreamError.unknownError,
};

/// A peer connection negotiated with a WHIP/WHEP endpoint, plus the HTTP
/// resource that represents it.
class LivestreamConnection {
  LivestreamConnection._({
    required this.peerConnection,
    required this._client,
    required this._ownsClient,
    required this._authHeaders,
    required this._logger,
  });

  /// The negotiated peer connection.
  final RtcPeerConnection peerConnection;

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _authHeaders;
  final FishjamLogger _logger;

  /// The resource from the `Location` header, resolved against the endpoint.
  Uri? _resource;
  Future<void>? _stopping;

  /// Peer connection statistics.
  Future<List<RtcStats>> getStatistics() => peerConnection.getStats();

  /// Connection state changes.
  Stream<PeerConnectionState> get connectionState =>
      peerConnection.onConnectionState;

  /// Sends `DELETE` to the resource (failures are logged) and closes the
  /// peer connection. Idempotent.
  Future<void> stop() => _stopping ??= _stop();

  Future<void> _stop() async {
    final resource = _resource;
    if (resource == null) {
      _logger.debug('No livestream resource to DELETE');
    } else {
      try {
        final response = await _client.delete(resource, headers: _authHeaders);
        if (response.statusCode >= 300) {
          _logger.warn(
            'Livestream DELETE $resource failed with ${response.statusCode}',
          );
        }
      } on Object catch (error, stackTrace) {
        _logger.warn('Livestream DELETE $resource failed', error, stackTrace);
      }
    }
    await _closeQuietly();
  }

  Future<void> _closeQuietly() async {
    try {
      await peerConnection.close();
    } on Object catch (error, stackTrace) {
      _logger.warn(
        'Closing the livestream connection failed',
        error,
        stackTrace,
      );
    }
    if (_ownsClient) _client.close();
  }
}

/// Creates a peer connection, lets [configure] add transceivers, and runs
/// the offer/answer exchange with [url] (SPEC §19).
///
/// Every failure closes the connection and is thrown as a
/// [LivestreamException]; HTTP errors are mapped by
/// [livestreamErrorForStatus].
Future<LivestreamConnection> connectLivestream({
  required RtcAdapter adapter,
  required Uri url,
  required String? token,
  required bool publishing,
  required Future<void> Function(RtcPeerConnection pc) configure,
  http.Client? httpClient,
  FishjamLogger? logger,
  Duration iceGatheringTimeout = defaultIceGatheringTimeout,
}) async {
  final pc = await adapter.createPeerConnection(const RtcConfiguration());
  final connection = LivestreamConnection._(
    peerConnection: pc,
    client: httpClient ?? http.Client(),
    ownsClient: httpClient == null,
    authHeaders: {if (token != null) 'Authorization': 'Bearer $token'},
    logger: logger ?? FishjamLogger.disabled(),
  );
  try {
    await configure(pc);
    await pc.setLocalDescription(await pc.createOffer());
    await _iceGatheringComplete(pc, iceGatheringTimeout, connection._logger);
    final offer = await pc.getLocalDescription();

    final response = await connection._client.post(
      url,
      headers: {'Content-Type': 'application/sdp', ...connection._authHeaders},
      body: utf8.encode(offer!.sdp),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LivestreamException(
        livestreamErrorForStatus(response.statusCode, publishing: publishing),
        statusCode: response.statusCode,
      );
    }
    final location = response.headers['location'];
    if (location != null) connection._resource = url.resolve(location);

    await pc.setRemoteDescription(
      SessionDescription(type: SdpType.answer, sdp: response.body),
    );
    return connection;
  } on Object catch (error, stackTrace) {
    connection._logger.error('Livestream connection failed', error, stackTrace);
    await connection.stop();
    if (error is LivestreamException) rethrow;
    throw LivestreamException(LivestreamError.unknownError, cause: error);
  }
}

Future<void> _iceGatheringComplete(
  RtcPeerConnection pc,
  Duration timeout,
  FishjamLogger logger,
) async {
  if (pc.iceGatheringState == IceGatheringState.complete) return;
  final done = Completer<void>();
  final subscription = pc.onIceGatheringState.listen(
    (state) {
      if (state == IceGatheringState.complete && !done.isCompleted) {
        done.complete();
      }
    },
    onDone: () {
      if (done.isCompleted) return;
      done.completeError(StateError('connection closed during ICE gathering'));
    },
  );
  final timer = Timer(timeout, () {
    if (done.isCompleted) return;
    logger.warn(
      'ICE gathering did not complete within $timeout; sending the '
      'candidates gathered so far',
    );
    done.complete();
  });
  try {
    await done.future;
  } finally {
    timer.cancel();
    await subscription.cancel();
  }
}
