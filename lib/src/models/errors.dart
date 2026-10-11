import 'package:meta/meta.dart';

/// Close reasons that mean the peer token or room is not valid.
enum AuthErrorReason {
  /// No token was sent.
  missingToken('missing token'),

  /// The token is malformed or not signed for this server.
  invalidToken('invalid token'),

  expiredToken('expired token'),

  /// The room in the token does not exist.
  roomNotFound('room not found'),

  /// The peer in the token does not exist.
  peerNotFound('peer not found');

  AuthErrorReason(this.wireReason);

  /// The normalized close reason.
  final String wireReason;
}

/// Close reasons that mean the server refused to let the peer join.
enum JoinErrorReason {
  /// The room is full.
  reachedPeersLimit('reached peers limit'),

  /// The server node hosting the room is unreachable.
  nodeNotFound('node not found'),

  /// The SDK version is not accepted.
  invalidSdkVersion('invalid sdk version');

  JoinErrorReason(this.wireReason);

  /// The normalized close reason.
  final String wireReason;
}

/// Close reasons that mean the server ended this peer's session.
enum SessionEndReason {
  /// The peer was removed from the room by the app's backend.
  peerRemoved('peer removed'),

  /// The room was deleted.
  roomStopped('room stopped'),

  /// Another client connected with the same peer token.
  replacedByNewClient('new client connected as this peer');

  SessionEndReason(this.wireReason);

  /// The normalized close reason.
  final String wireReason;
}

/// Classification of a socket close; see `classifyClose`.
@immutable
sealed class CloseReason {
  const CloseReason({this.code, this.reason});

  /// WebSocket close code, if a close frame was received.
  final int? code;

  /// Raw (not normalized) close reason, if any.
  final String? reason;

  bool get isRetryable => this is RetryableClose;
}

/// The token or room is not valid.
final class AuthClose extends CloseReason {
  const AuthClose(this.authError, {super.code, super.reason});

  final AuthErrorReason authError;
}

/// The server refused to let the peer join.
final class JoinClose extends CloseReason {
  const JoinClose(this.joinError, {super.code, super.reason});

  final JoinErrorReason joinError;
}

/// The server ended the session on purpose.
final class SessionEndedClose extends CloseReason {
  const SessionEndedClose(this.sessionEnd, {super.code, super.reason});

  final SessionEndReason sessionEnd;
}

/// The server rejected a message as malformed; indicates an SDK bug.
final class ProtocolErrorClose extends CloseReason {
  const ProtocolErrorClose({super.code, super.reason});
}

/// Any other close, including network loss and liveness timeouts.
final class RetryableClose extends CloseReason {
  const RetryableClose({super.code, super.reason, this.error});

  /// The transport error, when the connection ended without a close frame.
  final Object? error;
}

/// Base class of exceptions thrown by the SDK.
sealed class FishjamException implements Exception {
  const FishjamException(this.message);

  final String message;

  @override
  String toString() => 'FishjamException: $message';
}

/// `connect()` failed because the token or room is not valid.
final class AuthException extends FishjamException {
  AuthException(this.reason) : super('Authentication failed: ${reason.name}');

  final AuthErrorReason reason;
}

/// `connect()` failed because the server refused the join.
final class JoinException extends FishjamException {
  JoinException(this.reason) : super('Join failed: ${reason.name}');

  final JoinErrorReason reason;
}

/// `connect()` failed because the connection ended before joining.
final class ConnectionException extends FishjamException {
  ConnectionException({this.code, this.reason, this.cause})
    : super('Connection closed before joining (code: $code, reason: $reason)');

  final int? code;

  final String? reason;

  final Object? cause;
}

/// Why a livestream (WHIP/WHEP) request failed.
enum LivestreamError {
  /// HTTP 401.
  unauthorized,

  /// HTTP 404.
  streamNotFound,

  /// HTTP 409 when publishing.
  streamerAlreadyConnected,

  /// Any other failure.
  unknownError,
}

/// Thrown by livestream functions.
final class LivestreamException extends FishjamException {
  LivestreamException(this.error, {this.statusCode, this.cause})
    : super('Livestream failed: ${error.name} (status: $statusCode)');

  final LivestreamError error;

  /// HTTP status code, if a response was received.
  final int? statusCode;

  final Object? cause;
}

/// Thrown when a video track is added to an audio-only room.
final class TrackTypeError extends Error {
  TrackTypeError();

  final String message =
      'Attempted to add video track to audio-only room. '
      'Please refer to the docs at https://docs.fishjam.io/audio-calls';

  @override
  String toString() => 'TrackTypeError: $message';
}
