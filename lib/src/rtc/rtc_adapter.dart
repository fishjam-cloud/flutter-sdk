/// The seam between the SDK and the WebRTC implementation.
///
/// The SDK talks to WebRTC only through these types, limited to what it
/// needs. The real implementation is `flutter_webrtc_adapter.dart`; tests
/// use `test/fakes/fake_rtc.dart`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Kind of a media track or transceiver.
enum MediaKind { audio, video }

enum TransceiverDirection { sendrecv, sendonly, recvonly, inactive, stopped }

/// State of a peer connection (`RTCPeerConnectionState`).
enum PeerConnectionState {
  newState,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

enum IceConnectionState {
  newState,
  checking,
  connected,
  completed,
  failed,
  disconnected,
  closed,
}

enum IceGatheringState { newState, gathering, complete }

enum SignalingState {
  stable,
  haveLocalOffer,
  haveRemoteOffer,
  haveLocalPranswer,
  haveRemotePranswer,
  closed,
}

enum DataChannelState { connecting, open, closing, closed }

enum SdpType { offer, answer }

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

@immutable
final class IceServer {
  const IceServer({required this.urls, this.username, this.credential});

  /// STUN/TURN URLs.
  final List<String> urls;

  final String? username;

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
/// `all`; adapters must apply them.
@immutable
final class RtcConfiguration {
  const RtcConfiguration({this.iceServers = const []});

  final List<IceServer> iceServers;
}

@immutable
final class SessionDescription {
  const SessionDescription({required this.type, required this.sdp});

  final SdpType type;

  final String sdp;

  @override
  bool operator ==(Object other) =>
      other is SessionDescription && other.type == type && other.sdp == sdp;

  @override
  int get hashCode => Object.hash(type, sdp);

  @override
  String toString() => 'SessionDescription($type, ${sdp.length} chars)';
}

@immutable
final class IceCandidate {
  const IceCandidate({
    required this.candidate,
    this.sdpMLineIndex,
    this.sdpMid,
    this.usernameFragment,
  });

  final String candidate;

  final int? sdpMLineIndex;

  final String? sdpMid;

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
  const RtpEncoding({
    this.rid,
    this.active = true,
    this.maxBitrateBps,
    this.scaleResolutionDownBy,
  });

  /// Simulcast layer id (`l`, `m`, `h`), or `null` for a single layer.
  final String? rid;

  final bool active;

  /// Bitrate cap in bits per second; `null` means unlimited.
  final int? maxBitrateBps;

  /// Resolution scale factor; `null` means 1.
  final double? scaleResolutionDownBy;

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
  const RtpSendParameters({required this.encodings});

  final List<RtpEncoding> encodings;

  RtpSendParameters copyWith({List<RtpEncoding>? encodings}) =>
      RtpSendParameters(encodings: encodings ?? this.encodings);
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

/// Options for [RtcPeerConnection.createDataChannel].
@immutable
final class DataChannelInit {
  const DataChannelInit({this.ordered = true, this.maxRetransmits});

  final bool ordered;

  /// Maximum retransmissions; `null` means reliable. `0` must be honored
  /// (the lossy channel relies on it).
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
  const RtcStats({
    required this.id,
    required this.type,
    required this.timestampMs,
    required this.values,
  });

  final String id;

  /// Report type, e.g. `inbound-rtp`, `outbound-rtp`, `media-source`.
  final String type;

  /// Timestamp in milliseconds.
  final double timestampMs;

  /// All fields of the report, as reported by the platform.
  final Map<String, Object?> values;
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

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
