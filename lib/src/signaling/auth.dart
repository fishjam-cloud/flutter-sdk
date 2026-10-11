/// Socket URL, close-reason normalization and classification (SPEC §2.1,
/// §4), and the mapping of a terminal close to events and errors (SPEC §3.2).
///
/// Owner: **Signaling** agent.
library;

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

/// Path of the peer socket, appended to the Fishjam URL.
const peerSocketPath = 'socket/peer/websocket';

/// Builds the socket URL from the Fishjam [url] (SPEC §2.1): appends
/// [peerSocketPath] without duplicating a trailing `/`.
Uri peerSocketUrl(String url) => Uri.parse(
  url.endsWith('/') ? '$url$peerSocketPath' : '$url/$peerSocketPath',
);

/// `reason.trim().toLowerCase()` (SPEC §4).
String normalizeCloseReason(String reason) => reason.trim().toLowerCase();

/// Classifies a transport close (SPEC §4). A close without a close frame is
/// always [RetryableClose].
CloseReason classifyClose(TransportClosed closed) {
  final code = closed.code;
  final reason = closed.reason;
  if (code == null) return RetryableClose(reason: reason, error: closed.error);

  final normalized = normalizeCloseReason(reason ?? '');
  for (final auth in AuthErrorReason.values) {
    if (auth.wireReason == normalized) {
      return AuthClose(auth, code: code, reason: reason);
    }
  }
  for (final join in JoinErrorReason.values) {
    if (join.wireReason == normalized) {
      return JoinClose(join, code: code, reason: reason);
    }
  }
  for (final end in SessionEndReason.values) {
    if (end.wireReason == normalized) {
      return SessionEndedClose(end, code: code, reason: reason);
    }
  }
  if (normalized == 'unauthenticated' || normalized == 'malformed protobuf') {
    return ProtocolErrorClose(code: code, reason: reason);
  }
  return RetryableClose(code: code, reason: reason, error: closed.error);
}

/// The [DisconnectReason] of a session that ended with [close] (SPEC §4). A
/// retryable close maps to [DisconnectReason.connectionLost]; after giving up
/// on reconnection the caller uses [DisconnectReason.reconnectionFailed].
DisconnectReason disconnectReasonFor(CloseReason close) => switch (close) {
  AuthClose() => DisconnectReason.authError,
  JoinClose() => DisconnectReason.joinError,
  SessionEndedClose(:final sessionEnd) => DisconnectReason.fromSessionEnd(
    sessionEnd,
  ),
  ProtocolErrorClose() => DisconnectReason.protocolError,
  RetryableClose() => DisconnectReason.connectionLost,
};

/// The [Disconnected] event for a session that ended with [close], carrying
/// its close code and raw reason.
Disconnected disconnectedFor(CloseReason close) => Disconnected(
  disconnectReasonFor(close),
  closeCode: close.code,
  closeReason: close.reason,
);

/// The error event emitted before [Disconnected] for [close]: [AuthFailed]
/// or [JoinFailed]; `null` for every other class (SPEC §4).
FishjamEvent? errorEventFor(CloseReason close) => switch (close) {
  AuthClose(:final authError) => AuthFailed(authError),
  JoinClose(:final joinError) => JoinFailed(joinError),
  _ => null,
};

/// The error `connect()` completes with when the session ends with [close]
/// before `Joined` (SPEC §3.2).
FishjamException connectExceptionFor(CloseReason close) => switch (close) {
  AuthClose(:final authError) => AuthException(authError),
  JoinClose(:final joinError) => JoinException(joinError),
  RetryableClose(:final error) => ConnectionException(
    code: close.code,
    reason: close.reason,
    cause: error,
  ),
  _ => ConnectionException(code: close.code, reason: close.reason),
};
