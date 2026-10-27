import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _channel = MethodChannel('io.fishjam.client/video_mirror');

/// How [RTCView] fits the video inside its box.
enum RTCViewObjectFit { contain, cover }

/// Renders [mediaStream]. [mirror] mirrors the picture.
///
/// On Android the mirror is applied by the renderer on the next drawn
/// frame. [selectCamera] pauses that drawing until the mirror is applied.
class RTCView extends StatefulWidget {
  const RTCView({
    required this.mediaStream,
    super.key,
    this.mirror = false,
    this.objectFit = RTCViewObjectFit.contain,
  });

  final MediaStream? mediaStream;
  final bool mirror;
  final RTCViewObjectFit objectFit;

  @override
  State<RTCView> createState() => _RTCViewState();
}

class _RTCViewState extends State<RTCView> {
  final _renderer = RTCVideoRenderer();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    await _renderer.initialize();
    if (!mounted) {
      await _renderer.dispose();
      return;
    }
    final textureId = _renderer.textureId;
    if (textureId != null) {
      registerVideoPreview(textureId: textureId, shows: _shows);
      await applyVideoMirror(textureId, mirror: widget.mirror);
    }
    if (!mounted) {
      if (textureId != null) unregisterVideoPreview(textureId);
      await _renderer.dispose();
      return;
    }
    _renderer.srcObject = widget.mediaStream;
    setState(() => _ready = true);
  }

  bool _shows(MediaStreamTrack track) {
    final stream = widget.mediaStream;
    if (stream == null) return false;
    return stream.getVideoTracks().any((item) => item.id == track.id);
  }

  @override
  void didUpdateWidget(RTCView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.mediaStream != widget.mediaStream) {
      _renderer.srcObject = widget.mediaStream;
    }
    final textureId = _renderer.textureId;
    final mirrorChanged = oldWidget.mirror != widget.mirror;
    final streamChanged = oldWidget.mediaStream != widget.mediaStream;
    if (textureId != null &&
        (mirrorChanged || (streamChanged && _paused.contains(textureId)))) {
      unawaited(applyVideoMirror(textureId, mirror: widget.mirror));
    }
  }

  @override
  void dispose() {
    final textureId = _renderer.textureId;
    if (textureId != null) unregisterVideoPreview(textureId);
    unawaited(_renderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: Color(0xFF000000));
    return RTCVideoView(
      _renderer,
      mirror: !videoPreviewIsAndroid() && widget.mirror,
      objectFit: widget.objectFit == RTCViewObjectFit.cover
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}

/// A camera from [cameraDevices]. Same fields as the React Native SDK's
/// `cameraDevices` entries: `deviceId` and `label`.
class CameraDevice {
  const CameraDevice({required this.deviceId, required this.label});

  final String deviceId;
  final String label;
}

/// Cameras available to [selectCamera].
Future<List<CameraDevice>> cameraDevices() async {
  final devices = await enumerateCameras();
  return [
    for (final device in devices)
      if (device.kind == 'videoinput')
        CameraDevice(deviceId: device.deviceId, label: device.label),
  ];
}

/// Selects [deviceId] and returns the video stream to show.
///
/// [current] is the preview already showing. The same `deviceId` returns
/// [current]. A camera that is already open is switched in place and
/// [current] is returned; opening a second camera and then stopping the
/// first makes `replaceTrack` fail on Android and iOS. With no [current]
/// video track, this opens [deviceId]. An empty [deviceId] throws
/// [ArgumentError].
Future<MediaStream> selectCamera(
  String deviceId, {
  MediaStream? current,
}) async {
  if (deviceId.isEmpty) throw ArgumentError.value(deviceId, 'deviceId');
  final video = current?.getVideoTracks().firstOrNull;
  if (video?.getSettings()['deviceId'] == deviceId) return current!;
  if (video != null) {
    final paused = await _pauseShowing(video);
    try {
      await switchVideoCamera(video);
      if (paused.isNotEmpty) _scheduleResume();
      return current!;
    } on Object {
      await _resume(paused);
      rethrow;
    }
  }
  return await openCamera(deviceId);
}

/// Remembers a preview so [selectCamera] can pause it.
@visibleForTesting
void registerVideoPreview({
  required int textureId,
  required bool Function(MediaStreamTrack track) shows,
}) {
  _previews.removeWhere((preview) => preview.textureId == textureId);
  _previews.add(_Preview(textureId, shows));
}

/// Drops a preview registered with [registerVideoPreview].
@visibleForTesting
void unregisterVideoPreview(int textureId) {
  _previews.removeWhere((preview) => preview.textureId == textureId);
  _paused.remove(textureId);
}

/// Applies [mirror] on Android. Resumes a preview paused for a switch.
@visibleForTesting
Future<void> applyVideoMirror(int textureId, {required bool mirror}) async {
  if (!videoPreviewIsAndroid()) return;
  final resume = _paused.remove(textureId);
  await sendVideoMirror(textureId: textureId, mirror: mirror);
  if (resume) await sendVideoPaused(textureId: textureId, paused: false);
}

@visibleForTesting
Future<void> Function({required int textureId, required bool mirror})
sendVideoMirror = _sendMirror;

@visibleForTesting
Future<void> Function({required int textureId, required bool paused})
sendVideoPaused = _sendPaused;

@visibleForTesting
Future<List<MediaDeviceInfo>> Function() enumerateCameras =
    navigator.mediaDevices.enumerateDevices;

@visibleForTesting
Future<MediaStream> Function(String deviceId) openCamera = _openCamera;

@visibleForTesting
Future<bool> Function(MediaStreamTrack track) switchVideoCamera =
    Helper.switchCamera;

@visibleForTesting
bool Function() videoPreviewIsAndroid = _defaultAndroid;

@visibleForTesting
void resetVideoPreview() {
  _previews.clear();
  _paused.clear();
  _resumeScheduled = false;
  sendVideoMirror = _sendMirror;
  sendVideoPaused = _sendPaused;
  enumerateCameras = navigator.mediaDevices.enumerateDevices;
  openCamera = _openCamera;
  switchVideoCamera = Helper.switchCamera;
  videoPreviewIsAndroid = _defaultAndroid;
}

final _previews = <_Preview>[];
final _paused = <int>{};
var _resumeScheduled = false;

class _Preview {
  _Preview(this.textureId, this.shows);

  final int textureId;
  final bool Function(MediaStreamTrack track) shows;
}

bool _defaultAndroid() {
  if (kIsWeb) return false;
  return Platform.isAndroid;
}

Future<MediaStream> _openCamera(String deviceId) {
  return navigator.mediaDevices.getUserMedia({
    'video': {
      // flutter_webrtc reads this value as a String on Android and iOS.
      // `{exact: deviceId}` is the web constraint shape and crashes both.
      'deviceId': deviceId,
    },
  });
}

Future<List<int>> _pauseShowing(MediaStreamTrack track) async {
  if (!videoPreviewIsAndroid()) return const [];
  final ids = [
    for (final preview in _previews)
      if (preview.shows(track)) preview.textureId,
  ];
  for (final id in ids) {
    await sendVideoPaused(textureId: id, paused: true);
    _paused.add(id);
  }
  return ids;
}

Future<void> _resume(List<int> ids) async {
  for (final id in ids) {
    _paused.remove(id);
    await sendVideoPaused(textureId: id, paused: false);
  }
}

void _scheduleResume() {
  if (_resumeScheduled) return;
  _resumeScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _resumeScheduled = false;
    final ids = _paused.toList();
    for (final id in ids) {
      _paused.remove(id);
      unawaited(sendVideoPaused(textureId: id, paused: false));
    }
  });
}

Future<void> _sendMirror({required int textureId, required bool mirror}) {
  return _channel.invokeMethod<void>('setMirror', {
    'textureId': textureId,
    'mirror': mirror,
  });
}

Future<void> _sendPaused({required int textureId, required bool paused}) {
  return _channel.invokeMethod<void>('setPaused', {
    'textureId': textureId,
    'paused': paused,
  });
}
