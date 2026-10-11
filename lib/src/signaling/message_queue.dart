import 'dart:collection';
import 'dart:typed_data';

import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';

/// Whether [message] is sent immediately on the current socket instead of
/// going through the queue: `authRequest`, and the peer media events
/// `connect`, `renegotiateTracks`, `sdpOffer`, `candidate`.
bool bypassesQueue(PeerMessage message) => switch (message.whichContent()) {
  PeerMessage_Content.authRequest => true,
  PeerMessage_Content.peerMediaEvent => switch (message.peerMediaEvent
      .whichContent()) {
    peer.MediaEvent_Content.connect ||
    peer.MediaEvent_Content.renegotiateTracks ||
    peer.MediaEvent_Content.sdpOffer ||
    peer.MediaEvent_Content.candidate => true,
    _ => false,
  },
  _ => false,
};

/// Ordered queue in front of the socket. While held, enqueued frames are
/// kept; otherwise they are written at once in FIFO order through `send`.
class MessageQueue {
  MessageQueue({required this._send});

  final void Function(Uint8List frame) _send;
  final _frames = Queue<Uint8List>();
  bool _held = false;
  bool _flushing = false;

  int get length => _frames.length;

  /// Adds [frame]; writes it immediately (after older frames) unless held.
  void enqueue(Uint8List frame) {
    _frames.add(frame);
    _flush();
  }

  void hold() => _held = true;

  /// Stops holding and writes every waiting frame in order.
  void release() {
    _held = false;
    _flush();
  }

  /// Drops every waiting frame and stops holding (reconnection failed or the
  /// client left), so a held queue never outlives a reconnection.
  void clear() {
    _frames.clear();
    _held = false;
  }

  void _flush() {
    // A frame enqueued from inside `_send` is written by the running loop,
    // after the older frames.
    if (_flushing) return;
    _flushing = true;
    try {
      while (!_held && _frames.isNotEmpty) {
        _send(_frames.removeFirst());
      }
    } finally {
      _flushing = false;
    }
  }
}
