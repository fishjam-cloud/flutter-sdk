/// The seam between the SDK and the WebRTC implementation.
///
/// Everything in the SDK talks to WebRTC through these types only. The real
/// implementation lives in `flutter_webrtc_adapter.dart` (the only file that
/// imports `flutter_webrtc`); tests use `test/fakes/fake_rtc.dart`.
///
/// The surface is deliberately limited to what the SDK needs (SPEC §8–§19).
/// Owner: Architect. Changes need agreement of every module that uses it.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Kind of a media track or transceiver.
enum MediaKind {
  /// Audio.
  audio,

  /// Video.
  video,
}

/// Direction of an RTP transceiver.
enum TransceiverDirection {
  /// Send and receive.
  sendrecv,

  /// Send only.
  sendonly,

  /// Receive only.
  recvonly,

  /// Neither send nor receive.
  inactive,

  /// The transceiver was stopped.
  stopped,
}

/// State of a peer connection.
enum PeerConnectionState {
  /// Just created.
  newState,

  /// Connecting.
  connecting,

  /// Connected.
  connected,

  /// Temporarily disconnected.
  disconnected,

  /// Failed.
  failed,

  /// Closed.
  closed,
}

/// ICE connection state of a peer connection.
enum IceConnectionState {
  /// Just created.
  newState,

  /// Checking candidate pairs.
  checking,

  /// Connected.
  connected,

  /// Completed.
  completed,

  /// Failed.
  failed,

  /// Temporarily disconnected.
  disconnected,

  /// Closed.
  closed,
}

/// ICE gathering state of a peer connection.
enum IceGatheringState {
  /// Not started.
  newState,

  /// Gathering candidates.
  gathering,

  /// Done gathering.
  complete,
}

/// Signaling state of a peer connection.
enum SignalingState {
  /// No offer/answer exchange in progress.
  stable,

  /// A local offer was applied.
  haveLocalOffer,

  /// A remote offer was applied.
  haveRemoteOffer,

  /// A local provisional answer was applied.
  haveLocalPranswer,

  /// A remote provisional answer was applied.
  haveRemotePranswer,

  /// The connection is closed.
  closed,
}

/// State of a data channel.
enum DataChannelState {
  /// Opening.
  connecting,

  /// Open; messages can be sent.
  open,

  /// Closing.
  closing,

  /// Closed.
  closed,
}

/// Type of a session description.
enum SdpType {
  /// An offer.
  offer,

  /// An answer.
  answer,
}

/// A media track (local or remote).
///
/// Local tracks are created by the app (e.g. from the camera) and wrapped by
/// the adapter; remote tracks are produced by [RtcPeerConnection.onTrack].
abstract interface class RtcMediaTrack {
  /// Unique id of the media track.
  String get id;

  /// Audio or video.
  MediaKind get kind;

  /// Whether the track still produces media (it has not ended).
  bool get isLive;
}

/// A group of media tracks (used to associate audio and video for sync).
abstract interface class RtcMediaStream {
  /// Unique id of the stream.
  String get id;

  /// Tracks currently in the stream.
  List<RtcMediaTrack> get tracks;

  /// Adds [track] to the stream.
  Future<void> addTrack(RtcMediaTrack track);

  /// Removes [track] from the stream.
  Future<void> removeTrack(RtcMediaTrack track);

  /// Releases the stream. Platforms may also release tracks still in it, so
  /// remove tracks the caller does not own first.
  Future<void> dispose();
}

/// An ICE server used by a peer connection.
@immutable
final class IceServer {
  /// Creates an ICE server entry.
  const IceServer({required this.urls, this.username, this.credential});

  /// STUN/TURN URLs.
  final List<String> urls;

  /// TURN username, if any.
  final String? username;

  /// TURN credential, if any.
  final String? credential;

  @override
  bool operator ==(Object other) =>
      other is IceServer &&
      _listEquals(other.urls, urls) &&
      other.username == username &&
      other.credential == credential;

  @override
  int get hashCode => Object.hash(Object.hashAll(urls), username, credential);

  @override
  String toString() => 'IceServer($urls, username: $username)';
}

/// Configuration of a new peer connection.
///
/// The SDK always uses bundle policy `max-bundle` and ICE transport policy
/// `all` (SPEC §8.4); adapters must apply them.
@immutable
final class RtcConfiguration {
  /// Creates a configuration.
  const RtcConfiguration({this.iceServers = const []});

  /// ICE servers to use.
  final List<IceServer> iceServers;
}

/// An SDP offer or answer.
@immutable
final class SessionDescription {
  /// Creates a session description.
  const SessionDescription({required this.type, required this.sdp});

  /// Offer or answer.
  final SdpType type;

  /// The SDP text.
  final String sdp;

  @override
  bool operator ==(Object other) =>
      other is SessionDescription && other.type == type && other.sdp == sdp;

  @override
  int get hashCode => Object.hash(type, sdp);

  @override
  String toString() => 'SessionDescription($type, ${sdp.length} chars)';
}

/// An ICE candidate (local or remote).
@immutable
final class IceCandidate {
  /// Creates an ICE candidate.
  const IceCandidate({
    required this.candidate,
    this.sdpMLineIndex,
    this.sdpMid,
    this.usernameFragment,
  });

  /// The candidate line.
  final String candidate;

  /// Index of the m-line the candidate belongs to.
  final int? sdpMLineIndex;

  /// Mid of the m-line the candidate belongs to.
  final String? sdpMid;

  /// ICE username fragment.
  final String? usernameFragment;

  @override
  bool operator ==(Object other) =>
      other is IceCandidate &&
      other.candidate == candidate &&
      other.sdpMLineIndex == sdpMLineIndex &&
      other.sdpMid == sdpMid &&
      other.usernameFragment == usernameFragment;

  @override
  int get hashCode =>
      Object.hash(candidate, sdpMLineIndex, sdpMid, usernameFragment);

  @override
  String toString() => 'IceCandidate($sdpMid/$sdpMLineIndex: $candidate)';
}

/// One RTP encoding of a sender (one simulcast layer, or the only layer).
@immutable
final class RtpEncoding {
  /// Creates an encoding description.
  const RtpEncoding({
    this.rid,
    this.active = true,
    this.maxBitrateBps,
    this.scaleResolutionDownBy,
  });

  /// Simulcast layer id (`l`, `m`, `h`), or `null` for a single layer.
  final String? rid;

  /// Whether the layer is sent.
  final bool active;

  /// Bitrate cap in bits per second; `null` means unlimited.
  final int? maxBitrateBps;

  /// Resolution scale factor; `null` means 1.
  final double? scaleResolutionDownBy;

  /// Returns a copy with the given fields replaced.
  ///
  /// Use [clearMaxBitrate] to remove the bitrate cap.
  RtpEncoding copyWith({
    String? rid,
    bool? active,
    int? maxBitrateBps,
    bool clearMaxBitrate = false,
    double? scaleResolutionDownBy,
  }) => RtpEncoding(
    rid: rid ?? this.rid,
    active: active ?? this.active,
    maxBitrateBps: clearMaxBitrate ? null : maxBitrateBps ?? this.maxBitrateBps,
    scaleResolutionDownBy: scaleResolutionDownBy ?? this.scaleResolutionDownBy,
  );

  @override
  bool operator ==(Object other) =>
      other is RtpEncoding &&
      other.rid == rid &&
      other.active == active &&
      other.maxBitrateBps == maxBitrateBps &&
      other.scaleResolutionDownBy == scaleResolutionDownBy;

  @override
  int get hashCode =>
      Object.hash(rid, active, maxBitrateBps, scaleResolutionDownBy);

  @override
  String toString() =>
      'RtpEncoding(rid: $rid, active: $active, maxBitrateBps: $maxBitrateBps, '
      'scaleResolutionDownBy: $scaleResolutionDownBy)';
}

/// Send parameters of a sender. Adapters preserve every field they do not
/// expose here when [RtcRtpSender.setParameters] is called.
@immutable
final class RtpSendParameters {
  /// Creates send parameters.
  const RtpSendParameters({required this.encodings});

  /// The sender's encodings.
  final List<RtpEncoding> encodings;

  /// Returns a copy with [encodings] replaced.
  RtpSendParameters copyWith({List<RtpEncoding>? encodings}) =>
      RtpSendParameters(encodings: encodings ?? this.encodings);
}

/// Options for `RtcPeerConnection.addTransceiver`.
@immutable
final class TransceiverInit {
  /// Creates transceiver options.
  const TransceiverInit({
    required this.direction,
    this.sendEncodings = const [],
    this.streams = const [],
  });

  /// Initial direction.
  final TransceiverDirection direction;

  /// Send encodings; empty means the platform default (one unlimited layer).
  final List<RtpEncoding> sendEncodings;

  /// Streams the sent track is associated with.
  final List<RtcMediaStream> streams;
}

/// Options for [RtcPeerConnection.createDataChannel].
@immutable
final class DataChannelInit {
  /// Creates data channel options.
  const DataChannelInit({this.ordered = true, this.maxRetransmits});

  /// Whether messages are delivered in order.
  final bool ordered;

  /// Maximum retransmissions; `null` means reliable. `0` must be honored
  /// (the lossy channel relies on it, SPEC §16).
  final int? maxRetransmits;

  @override
  bool operator ==(Object other) =>
      other is DataChannelInit &&
      other.ordered == ordered &&
      other.maxRetransmits == maxRetransmits;

  @override
  int get hashCode => Object.hash(ordered, maxRetransmits);

  @override
  String toString() =>
      'DataChannelInit(ordered: $ordered, maxRetransmits: $maxRetransmits)';
}

/// One WebRTC statistics report.
@immutable
final class RtcStats {
  /// Creates a stats report.
  const RtcStats({
    required this.id,
    required this.type,
    required this.timestampMs,
    required this.values,
  });

  /// Report id.
  final String id;

  /// Report type, e.g. `inbound-rtp`, `outbound-rtp`, `media-source`.
  final String type;

  /// Timestamp in milliseconds.
  final double timestampMs;

  /// All fields of the report, as reported by the platform.
  final Map<String, Object?> values;
}

/// Emitted by [RtcPeerConnection.onTrack] when remote media arrives.
@immutable
final class RtcTrackEvent {
  /// Creates a track event.
  const RtcTrackEvent({
    required this.track,
    required this.streams,
    required this.mid,
  });

  /// The remote media track.
  final RtcMediaTrack track;

  /// Streams the track belongs to.
  final List<RtcMediaStream> streams;

  /// Mid of the transceiver that received the track, if known.
  final String? mid;
}

/// The sending half of a transceiver.
abstract interface class RtcRtpSender {
  /// The media track being sent, or `null` (e.g. muted or removed).
  RtcMediaTrack? get track;

  /// Current send parameters.
  RtpSendParameters getParameters();

  /// Applies [parameters].
  Future<void> setParameters(RtpSendParameters parameters);

  /// Replaces the sent track without renegotiation.
  Future<void> replaceTrack(RtcMediaTrack? track);

  /// Statistics for this sender only.
  Future<List<RtcStats>> getStats();
}

/// The receiving half of a transceiver.
abstract interface class RtcRtpReceiver {
  /// Kind of media this receiver receives.
  MediaKind get kind;

  /// The receiver's media track, if any.
  RtcMediaTrack? get track;
}

/// An RTP transceiver.
abstract interface class RtcRtpTransceiver {
  /// Media id; `null` until a local description was applied.
  String? get mid;

  /// Desired direction.
  Future<TransceiverDirection> getDirection();

  /// Negotiated direction; `null` before the first negotiation.
  Future<TransceiverDirection?> getCurrentDirection();

  /// The sender.
  RtcRtpSender get sender;

  /// The receiver.
  RtcRtpReceiver get receiver;

  /// Stops the transceiver permanently.
  Future<void> stop();
}

/// A data channel.
abstract interface class RtcDataChannel {
  /// The label the channel was created with.
  String get label;

  /// Current state.
  DataChannelState get state;

  /// State changes.
  Stream<DataChannelState> get onStateChange;

  /// Incoming messages. Text messages are delivered as UTF-8 bytes.
  Stream<Uint8List> get onMessage;

  /// Sends a binary message.
  Future<void> send(Uint8List data);

  /// Closes the channel.
  Future<void> close();
}

/// A peer connection.
abstract interface class RtcPeerConnection {
  /// Last known connection state.
  PeerConnectionState get connectionState;

  /// Last known ICE connection state.
  IceConnectionState get iceConnectionState;

  /// Last known ICE gathering state.
  IceGatheringState get iceGatheringState;

  /// Last known signaling state.
  SignalingState get signalingState;

  /// Local ICE candidates as they are gathered.
  Stream<IceCandidate> get onIceCandidate;

  /// Remote tracks as they arrive.
  Stream<RtcTrackEvent> get onTrack;

  /// Connection state changes.
  Stream<PeerConnectionState> get onConnectionState;

  /// ICE connection state changes.
  Stream<IceConnectionState> get onIceConnectionState;

  /// ICE gathering state changes.
  Stream<IceGatheringState> get onIceGatheringState;

  /// Signaling state changes.
  Stream<SignalingState> get onSignalingState;

  /// Adds a transceiver that sends [track].
  Future<RtcRtpTransceiver> addTransceiverWithTrack(
    RtcMediaTrack track,
    TransceiverInit init,
  );

  /// Adds a transceiver of [kind] with no track (e.g. receive only).
  Future<RtcRtpTransceiver> addTransceiverOfKind(
    MediaKind kind,
    TransceiverInit init,
  );

  /// All transceivers, in creation order.
  Future<List<RtcRtpTransceiver>> getTransceivers();

  /// All senders, in creation order.
  Future<List<RtcRtpSender>> getSenders();

  /// Stops sending [sender]'s track.
  Future<void> removeTrack(RtcRtpSender sender);

  /// Creates an offer.
  Future<SessionDescription> createOffer();

  /// Applies a local description.
  Future<void> setLocalDescription(SessionDescription description);

  /// Applies a remote description.
  Future<void> setRemoteDescription(SessionDescription description);

  /// The current local description, if any (includes gathered candidates;
  /// used by WHIP/WHEP after gathering completes).
  Future<SessionDescription?> getLocalDescription();

  /// Adds a remote ICE candidate.
  Future<void> addIceCandidate(IceCandidate candidate);

  /// Creates a data channel.
  Future<RtcDataChannel> createDataChannel(String label, DataChannelInit init);

  /// Statistics for the whole connection, or only for [track].
  Future<List<RtcStats>> getStats([RtcMediaTrack? track]);

  /// Closes the connection. All streams of this object complete.
  Future<void> close();
}

/// Factory for WebRTC objects.
abstract interface class RtcAdapter {
  /// Creates a peer connection (bundle policy `max-bundle`).
  Future<RtcPeerConnection> createPeerConnection(RtcConfiguration config);

  /// Creates an empty local media stream.
  Future<RtcMediaStream> createLocalMediaStream(String label);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
