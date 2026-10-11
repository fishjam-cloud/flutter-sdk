/// Client configuration and status types (SPEC §3.1, §6). Owner: Architect.
library;

import 'package:meta/meta.dart';

/// Reconnection settings (SPEC §6).
@immutable
final class ReconnectConfig {
  /// Creates reconnection settings; the defaults enable reconnection.
  const ReconnectConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.delay = const Duration(milliseconds: 500),
    this.addTracksOnReconnect = false,
  });

  /// Reconnection turned off.
  static const disabled = ReconnectConfig(
    maxAttempts: 0,
    initialDelay: Duration.zero,
    delay: Duration.zero,
  );

  /// Maximum number of attempts; `0` disables reconnection.
  final int maxAttempts;

  /// Delay before the first attempt.
  final Duration initialDelay;

  /// Additional delay added for every following attempt.
  final Duration delay;

  /// Whether local tracks are published again after reconnecting.
  final bool addTracksOnReconnect;

  /// Whether reconnection is enabled.
  bool get isEnabled => maxAttempts > 0;

  /// Delay before attempt [attempt] (1-based):
  /// `initialDelay + (attempt - 1) * delay`.
  Duration delayBeforeAttempt(int attempt) =>
      initialDelay + delay * (attempt - 1);

  @override
  bool operator ==(Object other) =>
      other is ReconnectConfig &&
      other.maxAttempts == maxAttempts &&
      other.initialDelay == initialDelay &&
      other.delay == delay &&
      other.addTracksOnReconnect == addTracksOnReconnect;

  @override
  int get hashCode =>
      Object.hash(maxAttempts, initialDelay, delay, addTracksOnReconnect);
}

/// Connection status of the client (SPEC §3.1).
enum ConnectionStatus {
  /// Never connected.
  idle,

  /// Opening the socket or waiting for authentication.
  connecting,

  /// Authenticated; waiting to join.
  authenticated,

  /// In the room.
  joined,

  /// Re-establishing a lost connection.
  reconnecting,

  /// Not connected; `connect()` may be called again.
  disconnected,
}

/// Why the client is no longer connected (SPEC §3, §4, §6).
enum DisconnectReason {
  /// The app called `leave()`.
  left,

  /// The server removed this peer from the room (media event).
  removedByServer,

  /// The server reported an error and the client left.
  serverError,

  /// The token or room is not valid.
  authError,

  /// The server refused the join.
  joinError,

  /// The server ended the session (peer removed, room stopped, replaced).
  sessionEnded,

  /// The server rejected a malformed message.
  protocolError,

  /// The connection was lost and reconnection is disabled or not applicable.
  connectionLost,

  /// Every reconnection attempt failed.
  reconnectionFailed,
}

/// Room types reported on authentication (SPEC §20).
enum RoomType {
  /// Audio and video.
  conference,

  /// Audio only; video tracks are rejected.
  audioOnly,

  /// Livestream room (normally used via WHIP/WHEP).
  livestream,

  /// Unknown or not reported.
  unspecified,
}
