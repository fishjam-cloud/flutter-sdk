/// [RtcAdapter] implemented with `flutter_webrtc`.
///
/// This is the **only** file that imports `flutter_webrtc`. It is a thin
/// translation layer without logic of its own, verified by integration
/// tests on devices rather than unit tests (excluded from the coverage
/// gate). Owner: Architect.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

/// The default [RtcAdapter].
final class FlutterWebrtcAdapter implements RtcAdapter {
  /// Creates the adapter.
  const FlutterWebrtcAdapter();

  @override
  Future<RtcPeerConnection> createPeerConnection(
    RtcConfiguration config,
  ) async {
    final pc = await webrtc.createPeerConnection({
      'iceServers': [
        for (final server in config.iceServers)
          {
            'urls': server.urls,
            if (server.username != null) 'username': server.username,
            if (server.credential != null) 'credential': server.credential,
          },
      ],
      'bundlePolicy': 'max-bundle',
      'iceTransportPolicy': 'all',
      'sdpSemantics': 'unified-plan',
    });
    return _PeerConnection(pc);
  }

  @override
  Future<RtcMediaStream> createLocalMediaStream(String label) async =>
      FlutterWebrtcMediaStream(await webrtc.createLocalMediaStream(label));
}

/// Wraps a `flutter_webrtc` media track for use with the SDK.
final class FlutterWebrtcMediaTrack implements RtcMediaTrack {
  /// Wraps [native]. Chains (does not replace) an existing `onEnded`.
  FlutterWebrtcMediaTrack(this.native) {
    final previous = native.onEnded;
    native.onEnded = () {
      _ended = true;
      previous?.call();
    };
  }

  /// The wrapped track (e.g. to render it).
  final webrtc.MediaStreamTrack native;

  bool _ended = false;

  @override
  String get id => native.id ?? '';

  @override
  MediaKind get kind =>
      native.kind == 'audio' ? MediaKind.audio : MediaKind.video;

  @override
  bool get isLive => !_ended;
}

/// Wraps a `flutter_webrtc` media stream for use with the SDK.
final class FlutterWebrtcMediaStream implements RtcMediaStream {
  /// Wraps [native].
  FlutterWebrtcMediaStream(this.native);

  /// The wrapped stream (e.g. `RTCVideoRenderer.srcObject`).
  final webrtc.MediaStream native;

  @override
  String get id => native.id;

  @override
  List<RtcMediaTrack> get tracks =>
      native.getTracks().map(FlutterWebrtcMediaTrack.new).toList();

  @override
  Future<void> addTrack(RtcMediaTrack track) =>
      native.addTrack(_unwrapTrack(track));

  @override
  Future<void> removeTrack(RtcMediaTrack track) =>
      native.removeTrack(_unwrapTrack(track));

  @override
  Future<void> dispose() => native.dispose();
}

/// Wraps an app-provided `flutter_webrtc` track for the internal seam.
RtcMediaTrack wrapNativeTrack(webrtc.MediaStreamTrack track) =>
    FlutterWebrtcMediaTrack(track);

/// Wraps a `flutter_webrtc` stream for the internal seam.
RtcMediaStream wrapNativeStream(webrtc.MediaStream stream) =>
    FlutterWebrtcMediaStream(stream);

/// The `flutter_webrtc` track behind [track]; `null` when [track] is `null`
/// or not backed by `flutter_webrtc` (e.g. a test fake).
webrtc.MediaStreamTrack? nativeTrackOf(RtcMediaTrack? track) =>
    track is FlutterWebrtcMediaTrack ? track.native : null;

/// The `flutter_webrtc` stream behind [stream]; `null` otherwise.
webrtc.MediaStream? nativeStreamOf(RtcMediaStream? stream) =>
    stream is FlutterWebrtcMediaStream ? stream.native : null;

webrtc.MediaStreamTrack _unwrapTrack(RtcMediaTrack track) {
  if (track is FlutterWebrtcMediaTrack) return track.native;
  throw ArgumentError.value(track, 'track', 'not a FlutterWebrtcMediaTrack');
}

webrtc.MediaStream _unwrapStream(RtcMediaStream stream) {
  if (stream is FlutterWebrtcMediaStream) return stream.native;
  throw ArgumentError.value(stream, 'stream', 'not a FlutterWebrtcMediaStream');
}

final class _PeerConnection implements RtcPeerConnection {
  _PeerConnection(this._pc) {
    _pc.onIceCandidate = (c) {
      final candidate = c.candidate;
      if (candidate == null || candidate.isEmpty) return;
      _iceCandidates.add(
        IceCandidate(
          candidate: candidate,
          sdpMLineIndex: c.sdpMLineIndex,
          sdpMid: c.sdpMid,
        ),
      );
    };
    _pc.onTrack = (e) {
      _tracks.add(
        RtcTrackEvent(
          track: FlutterWebrtcMediaTrack(e.track),
          streams: e.streams.map(FlutterWebrtcMediaStream.new).toList(),
          mid: _midOrNull(e.transceiver?.mid),
        ),
      );
    };
    _pc.onConnectionState = (s) {
      _connectionState = _mapConnectionState(s);
      _connectionStates.add(_connectionState);
    };
    _pc.onIceConnectionState = (s) {
      _iceConnectionState = _mapIceConnectionState(s);
      _iceConnectionStates.add(_iceConnectionState);
    };
    _pc.onIceGatheringState = (s) {
      _iceGatheringState = _mapIceGatheringState(s);
      _iceGatheringStates.add(_iceGatheringState);
    };
    _pc.onSignalingState = (s) {
      _signalingState = _mapSignalingState(s);
      _signalingStates.add(_signalingState);
    };
  }

  final webrtc.RTCPeerConnection _pc;

  final _iceCandidates = StreamController<IceCandidate>.broadcast();
  final _tracks = StreamController<RtcTrackEvent>.broadcast();
  final _connectionStates = StreamController<PeerConnectionState>.broadcast();
  final _iceConnectionStates = StreamController<IceConnectionState>.broadcast();
  final _iceGatheringStates = StreamController<IceGatheringState>.broadcast();
  final _signalingStates = StreamController<SignalingState>.broadcast();

  PeerConnectionState _connectionState = PeerConnectionState.newState;
  IceConnectionState _iceConnectionState = IceConnectionState.newState;
  IceGatheringState _iceGatheringState = IceGatheringState.newState;
  SignalingState _signalingState = SignalingState.stable;

  @override
  PeerConnectionState get connectionState => _connectionState;

  @override
  IceConnectionState get iceConnectionState => _iceConnectionState;

  @override
  IceGatheringState get iceGatheringState => _iceGatheringState;

  @override
  SignalingState get signalingState => _signalingState;

  @override
  Stream<IceCandidate> get onIceCandidate => _iceCandidates.stream;

  @override
  Stream<RtcTrackEvent> get onTrack => _tracks.stream;

  @override
  Stream<PeerConnectionState> get onConnectionState => _connectionStates.stream;

  @override
  Stream<IceConnectionState> get onIceConnectionState =>
      _iceConnectionStates.stream;

  @override
  Stream<IceGatheringState> get onIceGatheringState =>
      _iceGatheringStates.stream;

  @override
  Stream<SignalingState> get onSignalingState => _signalingStates.stream;

  @override
  Future<RtcRtpTransceiver> addTransceiverWithTrack(
    RtcMediaTrack track,
    TransceiverInit init,
  ) async {
    final native = _unwrapTrack(track);
    final transceiver = await _pc.addTransceiver(
      track: native,
      kind: native.kind == 'audio'
          ? webrtc.RTCRtpMediaType.RTCRtpMediaTypeAudio
          : webrtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: _transceiverInit(init),
    );
    return _Transceiver(transceiver);
  }

  @override
  Future<RtcRtpTransceiver> addTransceiverOfKind(
    MediaKind kind,
    TransceiverInit init,
  ) async {
    final transceiver = await _pc.addTransceiver(
      kind: kind == MediaKind.audio
          ? webrtc.RTCRtpMediaType.RTCRtpMediaTypeAudio
          : webrtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: _transceiverInit(init),
    );
    return _Transceiver(transceiver);
  }

  @override
  Future<List<RtcRtpTransceiver>> getTransceivers() async =>
      (await _pc.getTransceivers()).map(_Transceiver.new).toList();

  @override
  Future<List<RtcRtpSender>> getSenders() async =>
      (await _pc.getSenders()).map(_Sender.new).toList();

  @override
  Future<void> removeTrack(RtcRtpSender sender) async {
    await _pc.removeTrack((sender as _Sender)._sender);
  }

  @override
  Future<SessionDescription> createOffer() async =>
      _fromNativeDescription(await _pc.createOffer());

  @override
  Future<void> setLocalDescription(SessionDescription description) =>
      _pc.setLocalDescription(_toNativeDescription(description));

  @override
  Future<void> setRemoteDescription(SessionDescription description) =>
      _pc.setRemoteDescription(_toNativeDescription(description));

  @override
  Future<SessionDescription?> getLocalDescription() async {
    final description = await _pc.getLocalDescription();
    return description == null ? null : _fromNativeDescription(description);
  }

  @override
  Future<void> addIceCandidate(IceCandidate candidate) => _pc.addCandidate(
    webrtc.RTCIceCandidate(
      candidate.candidate,
      candidate.sdpMid,
      candidate.sdpMLineIndex,
    ),
  );

  @override
  Future<RtcDataChannel> createDataChannel(
    String label,
    DataChannelInit init,
  ) async {
    final channel = await _pc.createDataChannel(label, _DataChannelInit(init));
    return _DataChannel(channel, label);
  }

  @override
  Future<List<RtcStats>> getStats([RtcMediaTrack? track]) async =>
      _mapStats(await _pc.getStats(track == null ? null : _unwrapTrack(track)));

  @override
  Future<void> close() async {
    await _pc.close();
    await _pc.dispose();
    await Future.wait([
      _iceCandidates.close(),
      _tracks.close(),
      _connectionStates.close(),
      _iceConnectionStates.close(),
      _iceGatheringStates.close(),
      _signalingStates.close(),
    ]);
  }
}

/// The options map sent to the platform for [init].
///
/// Works around two `flutter_webrtc` defaults: it drops `maxRetransmits: 0`
/// (the lossy channel needs it, SPEC §16), and it always sends `id: 0`,
/// which the platform applies to every channel, so the reliable and lossy
/// channels would collide on SCTP stream 0. Without `id` the stack picks one.
Map<String, dynamic> nativeDataChannelInit(DataChannelInit init) => {
  ...(webrtc.RTCDataChannelInit()..ordered = init.ordered).toMap(),
  if (init.maxRetransmits != null) 'maxRetransmits': init.maxRetransmits,
}..remove('id');

final class _DataChannelInit extends webrtc.RTCDataChannelInit {
  _DataChannelInit(this._init);

  final DataChannelInit _init;

  @override
  Map<String, dynamic> toMap() => nativeDataChannelInit(_init);
}

final class _Transceiver implements RtcRtpTransceiver {
  _Transceiver(this._transceiver);

  final webrtc.RTCRtpTransceiver _transceiver;

  @override
  String? get mid => _midOrNull(_transceiver.mid);

  @override
  Future<TransceiverDirection> getDirection() async =>
      _fromNativeDirection(await _transceiver.getDirection());

  @override
  Future<TransceiverDirection?> getCurrentDirection() async {
    final direction = await _transceiver.getCurrentDirection();
    return direction == null ? null : _fromNativeDirection(direction);
  }

  @override
  RtcRtpSender get sender => _Sender(_transceiver.sender);

  @override
  RtcRtpReceiver get receiver => _Receiver(_transceiver.receiver);

  @override
  Future<void> stop() => _transceiver.stop();
}

final class _Sender implements RtcRtpSender {
  _Sender(this._sender);

  final webrtc.RTCRtpSender _sender;

  @override
  RtcMediaTrack? get track {
    final track = _sender.track;
    return track == null ? null : FlutterWebrtcMediaTrack(track);
  }

  @override
  RtpSendParameters getParameters() => RtpSendParameters(
    encodings: [
      for (final e in _sender.parameters.encodings ?? <webrtc.RTCRtpEncoding>[])
        RtpEncoding(
          rid: e.rid,
          active: e.active,
          maxBitrateBps: e.maxBitrate,
          scaleResolutionDownBy: e.scaleResolutionDownBy,
        ),
    ],
  );

  @override
  Future<void> setParameters(RtpSendParameters parameters) async {
    final native = _sender.parameters;
    final current = native.encodings ?? <webrtc.RTCRtpEncoding>[];
    native.encodings = [
      for (var i = 0; i < parameters.encodings.length; i++)
        _mergeEncoding(
          i < current.length ? current[i] : webrtc.RTCRtpEncoding(),
          parameters.encodings[i],
        ),
    ];
    await _sender.setParameters(native);
  }

  @override
  Future<void> replaceTrack(RtcMediaTrack? track) =>
      _sender.replaceTrack(track == null ? null : _unwrapTrack(track));

  @override
  Future<List<RtcStats>> getStats() async =>
      _mapStats(await _sender.getStats());
}

final class _Receiver implements RtcRtpReceiver {
  _Receiver(this._receiver);

  final webrtc.RTCRtpReceiver _receiver;

  @override
  MediaKind get kind =>
      _receiver.track?.kind == 'audio' ? MediaKind.audio : MediaKind.video;

  @override
  RtcMediaTrack? get track {
    final track = _receiver.track;
    return track == null ? null : FlutterWebrtcMediaTrack(track);
  }
}

final class _DataChannel implements RtcDataChannel {
  _DataChannel(this._channel, this.label) {
    _channel.onDataChannelState = (s) {
      _state = _mapDataChannelState(s);
      _states.add(_state);
    };
    _channel.onMessage = (m) {
      _messages.add(
        m.isBinary ? m.binary : Uint8List.fromList(utf8.encode(m.text)),
      );
    };
  }

  final webrtc.RTCDataChannel _channel;
  final _states = StreamController<DataChannelState>.broadcast();
  final _messages = StreamController<Uint8List>.broadcast();
  DataChannelState _state = DataChannelState.connecting;

  @override
  final String label;

  @override
  DataChannelState get state => _state;

  @override
  Stream<DataChannelState> get onStateChange => _states.stream;

  @override
  Stream<Uint8List> get onMessage => _messages.stream;

  @override
  Future<void> send(Uint8List data) =>
      _channel.send(webrtc.RTCDataChannelMessage.fromBinary(data));

  @override
  Future<void> close() async {
    await _channel.close();
    await _states.close();
    await _messages.close();
  }
}

webrtc.RTCRtpEncoding _mergeEncoding(
  webrtc.RTCRtpEncoding native,
  RtpEncoding encoding,
) => native
  ..rid = encoding.rid ?? native.rid
  ..active = encoding.active
  ..maxBitrate = encoding.maxBitrateBps
  ..scaleResolutionDownBy =
      encoding.scaleResolutionDownBy ?? native.scaleResolutionDownBy;

webrtc.RTCRtpTransceiverInit _transceiverInit(TransceiverInit init) =>
    webrtc.RTCRtpTransceiverInit(
      direction: _toNativeDirection(init.direction),
      streams: init.streams.map(_unwrapStream).toList(),
      sendEncodings: init.sendEncodings.isEmpty
          ? null
          : [
              for (final e in init.sendEncodings)
                webrtc.RTCRtpEncoding(
                  rid: e.rid,
                  active: e.active,
                  maxBitrate: e.maxBitrateBps,
                  scaleResolutionDownBy: e.scaleResolutionDownBy,
                ),
            ],
    );

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
