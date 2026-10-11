/// Socket URL, close-reason classification, and the mapping of a terminal
/// close to events and errors.
library;

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

const peerSocketPath = 'socket/peer/websocket';

/// Builds the socket URL from the Fishjam [url]: appends
/// [peerSocketPath] to its path (a trailing `/` is not duplicated, a query
/// string is kept); an `http` / `https` URL becomes `ws` / `wss`. Throws
/// [ArgumentError] for any other scheme or a relative URL.
Uri peerSocketUrl(String url) {
  final parsed = Uri.tryParse(url);
  final scheme = switch (parsed?.scheme) {
    'ws' || 'http' => 'ws',
    'wss' || 'https' => 'wss',
    _ => null,
  };
  if (parsed == null || scheme == null || parsed.host.isEmpty) {
    throw ArgumentError.value(
      url,
      'url',
      'expected a ws, wss, http or https URL',
    );
  }
  return parsed.replace(
    scheme: scheme,
    pathSegments: [
      ...parsed.pathSegments.where((s) => s.isNotEmpty),
      ...peerSocketPath.split('/'),
    ],
  );
}

/// The Fishjam URL for a Fishjam ID, as the web SDK resolves it: an
/// `http(s)` URL is used as is, anything else is the ID of a Fishjam Cloud
/// instance (from the developer dashboard).
String fishjamUrlFromId(String fishjamId) {
  if (RegExp('^https?://').hasMatch(fishjamId)) {
    return Uri.parse(fishjamId).toString();
  }
  return 'https://fishjam.io/api/v1/connect/$fishjamId';
}

String normalizeCloseReason(String reason) => reason.trim().toLowerCase();

/// A close without a close frame is always [RetryableClose].
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

/// A retryable close maps to [DisconnectReason.connectionLost]; after giving up
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

Disconnected disconnectedFor(CloseReason close) => Disconnected(
  disconnectReasonFor(close),
  closeCode: close.code,
  closeReason: close.reason,
);

/// The error event emitted before [Disconnected] for [close]: [AuthFailed]
/// or [JoinFailed]; `null` for every other class.
FishjamEvent? errorEventFor(CloseReason close) => switch (close) {
  AuthClose(:final authError) => AuthFailed(authError),
  JoinClose(:final joinError) => JoinFailed(joinError),
  _ => null,
};

/// The error `connect()` completes with when the session ends with [close]
/// before `Joined`.
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
