/// Minimal pure-Dart stand-ins for `flutter_webrtc` objects, used to test
/// the public boundary without a platform.
library;

import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

/// A native-typed track.
class NativeTrack extends webrtc.MediaStreamTrack {
  /// Creates a track.
  NativeTrack(this._id, this._kind);

  final String _id;
  final String _kind;

  @override
  String? get id => _id;

  @override
  String? get kind => _kind;

  @override
  String? get label => _id;

  @override
  bool enabled = true;

  @override
  bool? get muted => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// A native-typed stream.
class NativeStream extends webrtc.MediaStream {
  /// Creates a stream.
  NativeStream(String id) : super(id, 'local');

  final List<webrtc.MediaStreamTrack> _tracks = [];

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(
    webrtc.MediaStreamTrack track, {
    bool addToNative = true,
  }) async => _tracks.add(track);

  @override
  Future<void> removeTrack(
    webrtc.MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async => _tracks.remove(track);

  @override
  Future<void> getMediaTracks() async {}

  @override
  List<webrtc.MediaStreamTrack> getTracks() => List.unmodifiable(_tracks);

  @override
  List<webrtc.MediaStreamTrack> getAudioTracks() =>
      _tracks.where((t) => t.kind == 'audio').toList();

  @override
  List<webrtc.MediaStreamTrack> getVideoTracks() =>
      _tracks.where((t) => t.kind == 'video').toList();
}
