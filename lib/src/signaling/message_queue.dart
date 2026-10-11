/// The outgoing message queue (SPEC §5).
///
/// Owner: **Signaling** agent.
library;

// Constructor fields are kept for the Signaling implementation.
// ignore_for_file: unused_field

import 'dart:typed_data';

import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';

/// Whether [message] is sent immediately on the current socket instead of
/// going through the queue: `authRequest`, and the peer media events
/// `connect`, `renegotiateTracks`, `sdpOffer`, `candidate` (SPEC §5).
///
/// Owner: Signaling.
bool bypassesQueue(PeerMessage message) =>
    throw UnimplementedError('Signaling');

/// Ordered queue in front of the socket (SPEC §5).
///
/// While held, enqueued frames are kept; otherwise they are written at once
/// in FIFO order through the `send` callback given to the constructor.
///
/// Owner: Signaling.
class MessageQueue {
  /// Creates a queue that writes frames with `send`.
  MessageQueue({required this._send});

  final void Function(Uint8List frame) _send;

  /// Whether frames are currently held (during reconnection).
  bool get isHeld => throw UnimplementedError('Signaling');

  /// Number of frames waiting.
  int get length => throw UnimplementedError('Signaling');

  /// Adds [frame]; writes it immediately (after older frames) unless held.
  void enqueue(Uint8List frame) => throw UnimplementedError('Signaling');

  /// Starts holding frames.
  void hold() => throw UnimplementedError('Signaling');

  /// Stops holding and writes every waiting frame in order.
  void release() => throw UnimplementedError('Signaling');

  /// Drops every waiting frame (reconnection failed or the client left).
  void clear() => throw UnimplementedError('Signaling');
}
