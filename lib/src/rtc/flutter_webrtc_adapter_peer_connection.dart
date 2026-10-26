part of 'flutter_webrtc_adapter.dart';

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
      _fromNativeDescription(await _pc.createOffer(nativeOfferConstraints));

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

/// Constraints for `createOffer`. Without them `flutter_webrtc` sends
/// `OfferToReceiveAudio/Video: true`, and the platform adds receive
/// transceivers the server did not ask for.
const nativeOfferConstraints = <String, dynamic>{
  'mandatory': <String, dynamic>{},
  'optional': <dynamic>[],
};

final class _Transceiver implements RtcRtpTransceiver {
  _Transceiver(this._transceiver);

  final webrtc.RTCRtpTransceiver _transceiver;

  @override
  String? get mid => _midOrNull(_transceiver.mid);

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
