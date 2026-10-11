/// Value types passed across the `RtcAdapter` seam.
library;

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

@immutable
final class IceServer {
  const IceServer({required this.urls, this.username, this.credential});

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
/// expose here when `RtcRtpSender.setParameters` is called.
@immutable
final class RtpSendParameters {
  const RtpSendParameters({required this.encodings});

  final List<RtpEncoding> encodings;

  RtpSendParameters copyWith({List<RtpEncoding>? encodings}) =>
      RtpSendParameters(encodings: encodings ?? this.encodings);
}

/// Options for `RtcPeerConnection.createDataChannel`.
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

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
