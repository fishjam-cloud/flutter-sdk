part of 'flutter_webrtc_adapter.dart';

List<RtcStats> _mapStats(List<webrtc.StatsReport> reports) => [
  for (final r in reports)
    RtcStats(
      id: r.id,
      type: r.type,
      timestampMs: r.timestamp,
      values: {for (final e in r.values.entries) e.key.toString(): e.value},
    ),
];

String? _midOrNull(String? mid) => mid == null || mid.isEmpty ? null : mid;

SessionDescription _fromNativeDescription(
  webrtc.RTCSessionDescription description,
) => SessionDescription(
  type: description.type == 'answer' ? SdpType.answer : SdpType.offer,
  sdp: description.sdp ?? '',
);

webrtc.RTCSessionDescription _toNativeDescription(
  SessionDescription description,
) => webrtc.RTCSessionDescription(description.sdp, description.type.name);

TransceiverDirection _fromNativeDirection(webrtc.TransceiverDirection d) =>
    switch (d) {
      webrtc.TransceiverDirection.SendRecv => TransceiverDirection.sendrecv,
      webrtc.TransceiverDirection.SendOnly => TransceiverDirection.sendonly,
      webrtc.TransceiverDirection.RecvOnly => TransceiverDirection.recvonly,
      webrtc.TransceiverDirection.Inactive => TransceiverDirection.inactive,
      webrtc.TransceiverDirection.Stopped => TransceiverDirection.stopped,
    };

webrtc.TransceiverDirection _toNativeDirection(TransceiverDirection d) =>
    switch (d) {
      TransceiverDirection.sendrecv => webrtc.TransceiverDirection.SendRecv,
      TransceiverDirection.sendonly => webrtc.TransceiverDirection.SendOnly,
      TransceiverDirection.recvonly => webrtc.TransceiverDirection.RecvOnly,
      TransceiverDirection.inactive => webrtc.TransceiverDirection.Inactive,
      TransceiverDirection.stopped => webrtc.TransceiverDirection.Stopped,
    };

PeerConnectionState _mapConnectionState(webrtc.RTCPeerConnectionState s) =>
    switch (s) {
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateNew =>
        PeerConnectionState.newState,
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting =>
        PeerConnectionState.connecting,
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
        PeerConnectionState.connected,
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
        PeerConnectionState.disconnected,
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
        PeerConnectionState.failed,
      webrtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed =>
        PeerConnectionState.closed,
    };

IceConnectionState _mapIceConnectionState(webrtc.RTCIceConnectionState s) =>
    switch (s) {
      webrtc.RTCIceConnectionState.RTCIceConnectionStateNew =>
        IceConnectionState.newState,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateChecking =>
        IceConnectionState.checking,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateConnected =>
        IceConnectionState.connected,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateCompleted =>
        IceConnectionState.completed,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateFailed =>
        IceConnectionState.failed,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected =>
        IceConnectionState.disconnected,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateClosed =>
        IceConnectionState.closed,
      webrtc.RTCIceConnectionState.RTCIceConnectionStateCount =>
        IceConnectionState.newState,
    };

IceGatheringState _mapIceGatheringState(webrtc.RTCIceGatheringState s) =>
    switch (s) {
      webrtc.RTCIceGatheringState.RTCIceGatheringStateNew =>
        IceGatheringState.newState,
      webrtc.RTCIceGatheringState.RTCIceGatheringStateGathering =>
        IceGatheringState.gathering,
      webrtc.RTCIceGatheringState.RTCIceGatheringStateComplete =>
        IceGatheringState.complete,
    };

SignalingState _mapSignalingState(webrtc.RTCSignalingState s) => switch (s) {
  webrtc.RTCSignalingState.RTCSignalingStateStable => SignalingState.stable,
  webrtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer =>
    SignalingState.haveLocalOffer,
  webrtc.RTCSignalingState.RTCSignalingStateHaveRemoteOffer =>
    SignalingState.haveRemoteOffer,
  webrtc.RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer =>
    SignalingState.haveLocalPranswer,
  webrtc.RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer =>
    SignalingState.haveRemotePranswer,
  webrtc.RTCSignalingState.RTCSignalingStateClosed => SignalingState.closed,
};

DataChannelState _mapDataChannelState(
  webrtc.RTCDataChannelState s,
) => switch (s) {
  webrtc.RTCDataChannelState.RTCDataChannelConnecting =>
    DataChannelState.connecting,
  webrtc.RTCDataChannelState.RTCDataChannelOpen => DataChannelState.open,
  webrtc.RTCDataChannelState.RTCDataChannelClosing => DataChannelState.closing,
  webrtc.RTCDataChannelState.RTCDataChannelClosed => DataChannelState.closed,
};
