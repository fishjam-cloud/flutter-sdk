/// Scriptable [RtcAdapter] for unit tests.
///
/// Behaves like a browser-grade WebRTC stack where it matters to the SDK:
/// mids are assigned by `setLocalDescription`, transceiver objects are
/// snapshots (re-fetch them to see new mids, like `flutter_webrtc`),
/// `removeTrack` drops the send direction, `stop` marks transceivers
/// stopped. Every call is recorded in [FakePeerConnection.calls] with
/// JSON-like arguments so fixtures can assert on them (`expectRtc`).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

int _ids = 0;
String _nextId(String prefix) => '$prefix-${++_ids}';

/// One recorded call on a fake.
class FakeRtcCall {
  /// Creates a record.
  FakeRtcCall(this.method, [this.args = const {}]);

  /// Method name, e.g. `addTransceiver`, `createDataChannel`,
  /// `dataChannelSend`, `setParameters`, `replaceTrack`.
  final String method;

  /// JSON-like arguments.
  final Map<String, Object?> args;

  @override
  String toString() => 'FakeRtcCall($method, $args)';
}

/// A fake media track.
class FakeMediaTrack implements RtcMediaTrack {
  /// Creates a track of [kind].
  FakeMediaTrack({required this.kind, String? id})
    : id = id ?? _nextId(kind.name);

  /// An audio track.
  factory FakeMediaTrack.audio({String? id}) =>
      FakeMediaTrack(kind: MediaKind.audio, id: id);

  /// A video track.
  factory FakeMediaTrack.video({String? id}) =>
      FakeMediaTrack(kind: MediaKind.video, id: id);

  @override
  final String id;

  @override
  final MediaKind kind;

  bool _live = true;

  @override
  bool get isLive => _live;

  /// Ends the track (e.g. the camera was unplugged).
  void end() => _live = false;

  @override
  String toString() => 'FakeMediaTrack($id)';
}

/// A fake media stream.
class FakeMediaStream implements RtcMediaStream {
  /// Creates an empty stream.
  FakeMediaStream([String? id]) : id = id ?? _nextId('stream');

  @override
  final String id;

  final List<RtcMediaTrack> _tracks = [];

  @override
  List<RtcMediaTrack> get tracks => List.unmodifiable(_tracks);

  @override
  Future<void> addTrack(RtcMediaTrack track) async => _tracks.add(track);

  @override
  Future<void> removeTrack(RtcMediaTrack track) async => _tracks.remove(track);
}

/// The fake adapter.
class FakeRtcAdapter implements RtcAdapter {
  /// Every peer connection created, in order.
  final List<FakePeerConnection> peerConnections = [];

  /// Every local stream created, in order.
  final List<FakeMediaStream> localStreams = [];

  /// The most recently created peer connection.
  FakePeerConnection get lastPeerConnection => peerConnections.last;

  @override
  Future<RtcPeerConnection> createPeerConnection(
    RtcConfiguration config,
  ) async {
    final pc = FakePeerConnection(config);
    peerConnections.add(pc);
    return pc;
  }

  @override
  Future<RtcMediaStream> createLocalMediaStream(String label) async {
    final stream = FakeMediaStream(label);
    localStreams.add(stream);
    return stream;
  }
}

/// Shared state of one transceiver; [FakeRtpTransceiver]s are views on it.
class FakeTransceiverState {
  FakeTransceiverState._({
    required this.kind,
    required this.direction,
    required this.sender,
    required this.receiver,
  });

  /// Media kind.
  final MediaKind kind;

  /// Desired direction.
  TransceiverDirection direction;

  /// Negotiated direction.
  TransceiverDirection? currentDirection;

  /// Mid, once assigned by `setLocalDescription`.
  String? mid;

  /// The sender.
  final FakeRtpSender sender;

  /// The receiver.
  final FakeRtpReceiver receiver;

  /// Whether `stop()` was called.
  bool get isStopped => direction == TransceiverDirection.stopped;
}

/// A snapshot view of a transceiver: [mid] is the value at the time the view
/// was obtained, like `flutter_webrtc`'s objects.
class FakeRtpTransceiver implements RtcRtpTransceiver {
  FakeRtpTransceiver._(this.state, this._pc) : mid = state.mid;

  /// The live state behind this view.
  final FakeTransceiverState state;
  final FakePeerConnection _pc;

  @override
  final String? mid;

  @override
  Future<TransceiverDirection> getDirection() async => state.direction;

  @override
  Future<TransceiverDirection?> getCurrentDirection() async =>
      state.currentDirection;

  @override
  RtcRtpSender get sender => state.sender;

  @override
  RtcRtpReceiver get receiver => state.receiver;

  @override
  Future<void> stop() async {
    _pc._record('stopTransceiver', {'mid': state.mid, 'kind': state.kind.name});
    state
      ..direction = TransceiverDirection.stopped
      ..currentDirection = TransceiverDirection.stopped;
  }
}

/// A fake sender.
class FakeRtpSender implements RtcRtpSender {
  FakeRtpSender._(this._pc, this._track, List<RtpEncoding> encodings)
    : _parameters = RtpSendParameters(encodings: List.unmodifiable(encodings));

  final FakePeerConnection _pc;
  RtcMediaTrack? _track;
  RtpSendParameters _parameters;

  /// Every parameter set applied, in order.
  final List<RtpSendParameters> parameterHistory = [];

  /// When set, the next [replaceTrack] throws it (and is cleared).
  Object? failNextReplaceTrack;

  /// When set, the next [setParameters] throws it (and is cleared).
  Object? failNextSetParameters;

  /// Returned by [getStats].
  List<RtcStats> stats = [];

  @override
  RtcMediaTrack? get track => _track;

  @override
  RtpSendParameters getParameters() => _parameters;

  @override
  Future<void> setParameters(RtpSendParameters parameters) async {
    final failure = failNextSetParameters;
    if (failure != null) {
      failNextSetParameters = null;
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    _parameters = RtpSendParameters(
      encodings: List.unmodifiable(parameters.encodings),
    );
    parameterHistory.add(_parameters);
    _pc._record('setParameters', {
      'trackId': _track?.id,
      'encodings': parameters.encodings.map(encodingToJson).toList(),
    });
  }

  @override
  Future<void> replaceTrack(RtcMediaTrack? track) async {
    final failure = failNextReplaceTrack;
    if (failure != null) {
      failNextReplaceTrack = null;
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    _pc._record('replaceTrack', {'from': _track?.id, 'to': track?.id});
    _track = track;
  }

  @override
  Future<List<RtcStats>> getStats() async => stats;
}

/// A fake receiver; it always has a remote track of its kind.
class FakeRtpReceiver implements RtcRtpReceiver {
  FakeRtpReceiver._(this.kind) : track = FakeMediaTrack(kind: kind);

  @override
  final MediaKind kind;

  @override
  final RtcMediaTrack track;
}

/// A fake data channel.
class FakeDataChannel implements RtcDataChannel {
  FakeDataChannel._(this._pc, this.label, this.init);

  final FakePeerConnection _pc;

  @override
  final String label;

  /// Options it was created with.
  final DataChannelInit init;

  /// Messages sent by the client.
  final List<Uint8List> sent = [];

  DataChannelState _state = DataChannelState.connecting;
  final _states = StreamController<DataChannelState>.broadcast();
  final _messages = StreamController<Uint8List>.broadcast();

  @override
  DataChannelState get state => _state;

  @override
  Stream<DataChannelState> get onStateChange => _states.stream;

  @override
  Stream<Uint8List> get onMessage => _messages.stream;

  /// The channel opens.
  void open() => _setState(DataChannelState.open);

  /// The remote side closes the channel.
  void closeFromRemote() => _setState(DataChannelState.closed);

  /// A message arrives.
  void receive(Uint8List data) => _messages.add(data);

  @override
  Future<void> send(Uint8List data) async {
    if (_state != DataChannelState.open) {
      throw StateError('Data channel $label is ${_state.name}');
    }
    sent.add(data);
    _pc._record('dataChannelSend', {'label': label, 'data': data.toList()});
  }

  @override
  Future<void> close() async => _setState(DataChannelState.closed);

  void _setState(DataChannelState state) {
    if (_state == state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}

/// The fake peer connection.
class FakePeerConnection implements RtcPeerConnection {
  /// Creates a connection with [configuration].
  FakePeerConnection(this.configuration);

  /// Configuration it was created with.
  final RtcConfiguration configuration;

  /// Every call made by the SDK, in order.
  final List<FakeRtcCall> calls = [];

  /// Remote candidates added by the SDK.
  final List<IceCandidate> remoteCandidates = [];

  /// Data channels created by the SDK.
  final List<FakeDataChannel> dataChannels = [];

  /// Returned by [getStats].
  List<RtcStats> stats = [];

  /// Last applied local description.
  SessionDescription? localDescription;

  /// Last applied remote description.
  SessionDescription? remoteDescription;

  /// Whether [close] was called.
  bool isClosed = false;

  final List<FakeTransceiverState> _transceivers = [];
  final Map<String, Object> _failures = {};
  int _offers = 0;
  int _mids = 0;

  final _iceCandidates = StreamController<IceCandidate>.broadcast();
  final _tracks = StreamController<RtcTrackEvent>.broadcast();
  final _connection = StreamController<PeerConnectionState>.broadcast();
  final _ice = StreamController<IceConnectionState>.broadcast();
  final _gathering = StreamController<IceGatheringState>.broadcast();
  final _signaling = StreamController<SignalingState>.broadcast();

  PeerConnectionState _connectionState = PeerConnectionState.newState;
  IceConnectionState _iceConnectionState = IceConnectionState.newState;
  IceGatheringState _iceGatheringState = IceGatheringState.newState;
  SignalingState _signalingState = SignalingState.stable;

  /// Makes the next call to [method] throw [error].
  void failNext(String method, Object error) => _failures[method] = error;

  /// Live transceiver states (for assertions).
  List<FakeTransceiverState> get transceiverStates =>
      List.unmodifiable(_transceivers);

  /// Calls of [method].
  List<FakeRtcCall> callsOf(String method) =>
      calls.where((c) => c.method == method).toList();

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
  Stream<PeerConnectionState> get onConnectionState => _connection.stream;

  @override
  Stream<IceConnectionState> get onIceConnectionState => _ice.stream;

  @override
  Stream<IceGatheringState> get onIceGatheringState => _gathering.stream;

  @override
  Stream<SignalingState> get onSignalingState => _signaling.stream;

  // ------------------------------------------------------------ scripting

  /// A local ICE candidate was gathered.
  void emitIceCandidate(IceCandidate candidate) =>
      _iceCandidates.add(candidate);

  /// Remote media arrived on the transceiver with [mid].
  void emitTrack({
    required String mid,
    required MediaKind kind,
    String? streamId,
  }) => _tracks.add(
    RtcTrackEvent(
      track: FakeMediaTrack(kind: kind),
      streams: [FakeMediaStream(streamId)],
      mid: mid,
    ),
  );

  /// Changes the connection state.
  void setConnectionState(PeerConnectionState state) {
    _connectionState = state;
    _connection.add(state);
  }

  /// Changes the ICE connection state.
  void setIceConnectionState(IceConnectionState state) {
    _iceConnectionState = state;
    _ice.add(state);
  }

  /// Changes the ICE gathering state.
  void setIceGatheringState(IceGatheringState state) {
    _iceGatheringState = state;
    _gathering.add(state);
  }

  void _setSignalingState(SignalingState state) {
    _signalingState = state;
    if (!_signaling.isClosed) _signaling.add(state);
  }

  // ------------------------------------------------------- RtcPeerConnection

  @override
  Future<RtcRtpTransceiver> addTransceiverWithTrack(
    RtcMediaTrack track,
    TransceiverInit init,
  ) async {
    _maybeFail('addTransceiver');
    _record('addTransceiver', {
      'kind': track.kind.name,
      'trackId': track.id,
      ..._initToJson(init),
    });
    return _addTransceiver(track.kind, track, init);
  }

  @override
  Future<RtcRtpTransceiver> addTransceiverOfKind(
    MediaKind kind,
    TransceiverInit init,
  ) async {
    _maybeFail('addTransceiver');
    _record('addTransceiver', {'kind': kind.name, ..._initToJson(init)});
    return _addTransceiver(kind, null, init);
  }

  FakeRtpTransceiver _addTransceiver(
    MediaKind kind,
    RtcMediaTrack? track,
    TransceiverInit init,
  ) {
    final state = FakeTransceiverState._(
      kind: kind,
      direction: init.direction,
      sender: FakeRtpSender._(
        this,
        track,
        init.sendEncodings.isEmpty ? const [RtpEncoding()] : init.sendEncodings,
      ),
      receiver: FakeRtpReceiver._(kind),
    );
    _transceivers.add(state);
    return FakeRtpTransceiver._(state, this);
  }

  @override
  Future<List<RtcRtpTransceiver>> getTransceivers() async => [
    for (final t in _transceivers) FakeRtpTransceiver._(t, this),
  ];

  @override
  Future<List<RtcRtpSender>> getSenders() async => [
    for (final t in _transceivers) t.sender,
  ];

  @override
  Future<void> removeTrack(RtcRtpSender sender) async {
    _maybeFail('removeTrack');
    final state = _transceivers.firstWhere((t) => identical(t.sender, sender));
    _record('removeTrack', {'trackId': sender.track?.id, 'mid': state.mid});
    state.sender._track = null;
    state.direction = switch (state.direction) {
      TransceiverDirection.sendrecv => TransceiverDirection.recvonly,
      TransceiverDirection.sendonly => TransceiverDirection.inactive,
      final other => other,
    };
  }

  @override
  Future<SessionDescription> createOffer() async {
    _maybeFail('createOffer');
    _record('createOffer');
    _offers++;
    return SessionDescription(
      type: SdpType.offer,
      sdp:
          'v=0\r\no=- $_offers 0 IN IP4 127.0.0.1\r\ns=fake-offer-$_offers\r\n',
    );
  }

  @override
  Future<void> setLocalDescription(SessionDescription description) async {
    _maybeFail('setLocalDescription');
    _record('setLocalDescription', {'type': description.type.name});
    for (final t in _transceivers) {
      if (t.mid == null && !t.isStopped) t.mid = '${_mids++}';
    }
    localDescription = description;
    _setSignalingState(SignalingState.haveLocalOffer);
  }

  @override
  Future<void> setRemoteDescription(SessionDescription description) async {
    _maybeFail('setRemoteDescription');
    _record('setRemoteDescription', {'type': description.type.name});
    remoteDescription = description;
    for (final t in _transceivers) {
      if (t.mid != null && !t.isStopped) t.currentDirection = t.direction;
    }
    _setSignalingState(SignalingState.stable);
  }

  @override
  Future<SessionDescription?> getLocalDescription() async => localDescription;

  @override
  Future<void> addIceCandidate(IceCandidate candidate) async {
    _maybeFail('addIceCandidate');
    _record('addIceCandidate', {'candidate': candidate.candidate});
    remoteCandidates.add(candidate);
  }

  @override
  Future<RtcDataChannel> createDataChannel(
    String label,
    DataChannelInit init,
  ) async {
    _maybeFail('createDataChannel');
    _record('createDataChannel', {
      'label': label,
      'ordered': init.ordered,
      if (init.maxRetransmits != null) 'maxRetransmits': init.maxRetransmits,
    });
    final channel = FakeDataChannel._(this, label, init);
    dataChannels.add(channel);
    return channel;
  }

  @override
  Future<List<RtcStats>> getStats([RtcMediaTrack? track]) async {
    _maybeFail('getStats');
    return stats;
  }

  @override
  Future<void> close() async {
    _record('close');
    isClosed = true;
    _setSignalingState(SignalingState.closed);
    for (final c in dataChannels) {
      await c.close();
    }
    await Future.wait([
      _iceCandidates.close(),
      _tracks.close(),
      _connection.close(),
      _ice.close(),
      _gathering.close(),
      _signaling.close(),
    ]);
  }

  void _record(String method, [Map<String, Object?> args = const {}]) =>
      calls.add(FakeRtcCall(method, args));

  void _maybeFail(String method) {
    final failure = _failures.remove(method);
    if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
  }
}

/// JSON-like form of an encoding (omits defaults), as used in fixtures.
Map<String, Object?> encodingToJson(RtpEncoding e) => {
  if (e.rid != null) 'rid': e.rid,
  'active': e.active,
  if (e.maxBitrateBps != null) 'maxBitrate': e.maxBitrateBps,
  if (e.scaleResolutionDownBy != null)
    'scaleResolutionDownBy': e.scaleResolutionDownBy,
};

Map<String, Object?> _initToJson(TransceiverInit init) => {
  'direction': init.direction.name,
  if (init.sendEncodings.isNotEmpty)
    'sendEncodings': init.sendEncodings.map(encodingToJson).toList(),
  if (init.streams.isNotEmpty)
    'streams': init.streams.map((s) => s.id).toList(),
};
