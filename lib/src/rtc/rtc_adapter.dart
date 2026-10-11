/// The seam between the SDK and the WebRTC implementation.
///
/// The SDK talks to WebRTC only through these types, limited to what it
/// needs. The real implementation is `flutter_webrtc_adapter.dart`; tests
/// use `test/fakes/fake_rtc.dart`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/rtc/rtc_types.dart';
import 'package:meta/meta.dart';

export 'package:fishjam_client/src/rtc/rtc_types.dart';

/// A media track (local or remote).
///
/// Local tracks are created by the app (e.g. from the camera) and wrapped by
/// the adapter; remote tracks are produced by [RtcPeerConnection.onTrack].
abstract interface class RtcMediaTrack {
  String get id;

  MediaKind get kind;

  /// Whether the track still produces media (it has not ended).
  bool get isLive;
}

/// A group of media tracks (used to associate audio and video for sync).
abstract interface class RtcMediaStream {
  String get id;

  List<RtcMediaTrack> get tracks;

  Future<void> addTrack(RtcMediaTrack track);

  Future<void> removeTrack(RtcMediaTrack track);

  /// Releases the stream. Platforms may also release tracks still in it, so
  /// remove tracks the caller does not own first.
  Future<void> dispose();
}

/// Options for `RtcPeerConnection.addTransceiver`.
@immutable
final class TransceiverInit {
  const TransceiverInit({
    required this.direction,
    this.sendEncodings = const [],
    this.streams = const [],
  });

  final TransceiverDirection direction;

  /// Send encodings; empty means the platform default (one unlimited layer).
  final List<RtpEncoding> sendEncodings;

  /// Streams the sent track is associated with.
  final List<RtcMediaStream> streams;
}

/// Remote media arriving on [RtcPeerConnection.onTrack].
@immutable
final class RtcTrackEvent {
  const RtcTrackEvent({
    required this.track,
    required this.streams,
    required this.mid,
  });

  final RtcMediaTrack track;

  final List<RtcMediaStream> streams;

  /// Mid of the transceiver that received the track, if known.
  final String? mid;
}

/// The sending half of a transceiver.
abstract interface class RtcRtpSender {
  /// The media track being sent, or `null` (e.g. muted or removed).
  RtcMediaTrack? get track;

  RtpSendParameters getParameters();

  Future<void> setParameters(RtpSendParameters parameters);

  /// Replaces the sent track without renegotiation.
  Future<void> replaceTrack(RtcMediaTrack? track);

  Future<List<RtcStats>> getStats();
}

/// The receiving half of a transceiver.
abstract interface class RtcRtpReceiver {
  MediaKind get kind;

  RtcMediaTrack? get track;
}

abstract interface class RtcRtpTransceiver {
  /// Media id; `null` until a local description was applied.
  String? get mid;

  /// Desired direction.
  Future<TransceiverDirection> getDirection();

  /// Negotiated direction; `null` before the first negotiation.
  Future<TransceiverDirection?> getCurrentDirection();

  RtcRtpSender get sender;

  RtcRtpReceiver get receiver;

  /// Stops the transceiver permanently.
  Future<void> stop();
}

abstract interface class RtcDataChannel {
  String get label;

  DataChannelState get state;

  Stream<DataChannelState> get onStateChange;

  /// Incoming messages. Text messages are delivered as UTF-8 bytes.
  Stream<Uint8List> get onMessage;

  Future<void> send(Uint8List data);

  Future<void> close();
}

abstract interface class RtcPeerConnection {
  /// The state getters return the last state seen on the matching stream.
  PeerConnectionState get connectionState;

  IceConnectionState get iceConnectionState;

  IceGatheringState get iceGatheringState;

  SignalingState get signalingState;

  Stream<IceCandidate> get onIceCandidate;

  Stream<RtcTrackEvent> get onTrack;

  Stream<PeerConnectionState> get onConnectionState;

  Stream<IceConnectionState> get onIceConnectionState;

  Stream<IceGatheringState> get onIceGatheringState;

  Stream<SignalingState> get onSignalingState;

  Future<RtcRtpTransceiver> addTransceiverWithTrack(
    RtcMediaTrack track,
    TransceiverInit init,
  );

  /// Adds a transceiver with no track (e.g. receive only).
  Future<RtcRtpTransceiver> addTransceiverOfKind(
    MediaKind kind,
    TransceiverInit init,
  );

  /// All transceivers, in creation order.
  Future<List<RtcRtpTransceiver>> getTransceivers();

  Future<List<RtcRtpSender>> getSenders();

  /// Stops sending [sender]'s track.
  Future<void> removeTrack(RtcRtpSender sender);

  Future<SessionDescription> createOffer();

  Future<void> setLocalDescription(SessionDescription description);

  Future<void> setRemoteDescription(SessionDescription description);

  /// Includes the candidates gathered so far (WHIP/WHEP read it after
  /// gathering completes).
  Future<SessionDescription?> getLocalDescription();

  Future<void> addIceCandidate(IceCandidate candidate);

  Future<RtcDataChannel> createDataChannel(String label, DataChannelInit init);

  /// Statistics for the whole connection, or only for [track].
  Future<List<RtcStats>> getStats([RtcMediaTrack? track]);

  /// Closes the connection; every stream of this object completes.
  Future<void> close();
}

abstract interface class RtcAdapter {
  Future<RtcPeerConnection> createPeerConnection(RtcConfiguration config);

  Future<RtcMediaStream> createLocalMediaStream(String label);
}
