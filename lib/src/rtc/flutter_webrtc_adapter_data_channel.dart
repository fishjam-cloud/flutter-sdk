part of 'flutter_webrtc_adapter.dart';

/// The options map sent to the platform for [init].
///
/// Works around two `flutter_webrtc` defaults: it drops `maxRetransmits: 0`
/// (the lossy channel needs it), and it always sends `id: 0`, which the
/// platform applies to every channel, so the reliable and lossy channels
/// would collide on SCTP stream 0. Without `id` the stack picks one.
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
