/// One authenticated socket session (SPEC §2, §3.2, §4, §5).
///
/// Owner: **Signaling** agent.
library;

// Constructor fields are kept for the Signaling implementation.
// ignore_for_file: unused_field

import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/signaling/message_queue.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

/// Thrown by [SignalingSession.open] when the socket closes before
/// `authenticated` arrives.
final class SignalingClosedException implements Exception {
  /// Creates the exception.
  const SignalingClosedException(this.reason);

  /// Classified close reason.
  final CloseReason reason;

  @override
  String toString() => 'SignalingClosedException($reason)';
}

/// One socket session: opens the transport, authenticates, then exchanges
/// media events. Single use; a reconnection creates a new session.
///
/// Outgoing messages that do not bypass the queue (SPEC §5) go through the
/// shared [MessageQueue], which outlives sessions; the owner of the queue
/// routes its writes to the current session's transport via [sendNow].
///
/// Owner: Signaling.
class SignalingSession {
  /// Creates a session over `transport`.
  SignalingSession({
    required this._transport,
    required this._queue,
    required this._logger,
    required this._sdkVersion,
  });

  final SignalingTransport _transport;
  final MessageQueue _queue;
  final FishjamLogger _logger;
  final String _sdkVersion;

  /// Opens the socket at the peer socket URL for [url], sends `authRequest`
  /// with [token] and completes with the `authenticated` message.
  ///
  /// Throws [SignalingClosedException] when the socket closes first, and
  /// [TransportException] when it cannot be opened.
  Future<PeerMessage_Authenticated> open({
    required String url,
    required String token,
  }) => throw UnimplementedError('Signaling');

  /// Server media events, in arrival order. Done when the session closes.
  Stream<server.MediaEvent> get serverMediaEvents =>
      throw UnimplementedError('Signaling');

  /// Completes once with the classified reason when the socket closes for
  /// any reason other than [close].
  Future<CloseReason> get closed => throw UnimplementedError('Signaling');

  /// Sends a peer media event: immediately when it bypasses the queue,
  /// through the queue otherwise (SPEC §5).
  void sendMediaEvent(peer.MediaEvent event) =>
      throw UnimplementedError('Signaling');

  /// Sends `rtcStatsReport{data: json}` through the queue (SPEC §17).
  void sendStatsReport(String json) => throw UnimplementedError('Signaling');

  /// Writes an already encoded frame on this session's socket (used by the
  /// queue owner). A no-op when the socket is closed.
  void sendNow(List<int> frame) => throw UnimplementedError('Signaling');

  /// Closes the socket with code 1000. [closed] does not complete.
  Future<void> close() => throw UnimplementedError('Signaling');
}
