/// [RtcAdapter] implemented with `flutter_webrtc`.
///
/// A thin translation layer without logic of its own, verified by
/// integration tests on devices rather than unit tests (it is excluded from
/// the coverage gate).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

part 'flutter_webrtc_adapter_data_channel.dart';
part 'flutter_webrtc_adapter_mappers.dart';
part 'flutter_webrtc_adapter_peer_connection.dart';

final class FlutterWebrtcAdapter implements RtcAdapter {
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

final class FlutterWebrtcMediaTrack implements RtcMediaTrack {
  /// Chains (does not replace) an existing `onEnded` of [native].
  FlutterWebrtcMediaTrack(this.native) {
    final previous = native.onEnded;
    native.onEnded = () {
      _ended = true;
      previous?.call();
    };
  }

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

final class FlutterWebrtcMediaStream implements RtcMediaStream {
  FlutterWebrtcMediaStream(this.native);

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

RtcMediaTrack wrapNativeTrack(webrtc.MediaStreamTrack track) =>
    FlutterWebrtcMediaTrack(track);

RtcMediaStream wrapNativeStream(webrtc.MediaStream stream) =>
    FlutterWebrtcMediaStream(stream);

/// The `flutter_webrtc` track behind [track]; `null` when [track] is `null`
/// or not backed by `flutter_webrtc` (e.g. a test fake).
webrtc.MediaStreamTrack? nativeTrackOf(RtcMediaTrack? track) =>
    track is FlutterWebrtcMediaTrack ? track.native : null;

/// Like [nativeTrackOf], for streams.
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
