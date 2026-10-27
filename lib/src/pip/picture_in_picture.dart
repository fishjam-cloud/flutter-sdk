import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Picture-in-picture settings of a [PictureInPictureView]. Mirrors the React
/// Native SDK's `RTCPIPOptions`.
@immutable
class PictureInPictureOptions {
  const PictureInPictureOptions({
    this.enabled = true,
    this.preferredSize = const Size(1920, 1080),
    this.startAutomatically = true,
    this.stopAutomatically = true,
    this.allowsCameraInBackground = false,
    this.fallbackLabel = 'No video',
    this.fallbackBackgroundColor = const Color(0xFF1C2945),
    this.fallbackTextColor = const Color(0xFFFFFFFF),
  });

  /// Whether this view can be shown in picture-in-picture. Any
  /// [PictureInPictureView] can set this, independently of any other: there
  /// is no app-wide "offered view", each view has its own native controller
  /// (like the React Native SDK's per-`RTCView` `PIPController`).
  final bool enabled;

  /// Preferred window size in logical pixels. Defaults to 1920×1080, the same
  /// default as the React Native SDK. Android uses it as the aspect ratio,
  /// and uses the view size for a side that is 0. iOS sets the window's
  /// preferred content size to this.
  final Size preferredSize;

  /// Starts picture-in-picture when the app goes to the background. Android:
  /// API 31+ only.
  final bool startAutomatically;

  /// iOS only: stops picture-in-picture when the app returns to the
  /// foreground. On Android the system exits it when the user expands the
  /// window.
  final bool stopAutomatically;

  /// iOS 16+ only: keeps the local camera running while in
  /// picture-in-picture. Before iOS 18 this needs the
  /// `com.apple.developer.avfoundation.multitasking-camera-access`
  /// entitlement.
  ///
  /// The React Native SDK's docs recommend using picture-in-picture with a
  /// remote track rather than the local camera, since the camera may stop
  /// in the background; this option is the escape hatch for using it with
  /// the local camera anyway.
  final bool allowsCameraInBackground;

  /// Text drawn in this view, and in the picture-in-picture window, when the
  /// video track is gone.
  final String fallbackLabel;

  /// Background behind [fallbackLabel].
  final Color fallbackBackgroundColor;

  /// Color of [fallbackLabel].
  final Color fallbackTextColor;

  @override
  bool operator ==(Object other) =>
      other is PictureInPictureOptions &&
      other.enabled == enabled &&
      other.preferredSize == preferredSize &&
      other.startAutomatically == startAutomatically &&
      other.stopAutomatically == stopAutomatically &&
      other.allowsCameraInBackground == allowsCameraInBackground &&
      other.fallbackLabel == fallbackLabel &&
      other.fallbackBackgroundColor == fallbackBackgroundColor &&
      other.fallbackTextColor == fallbackTextColor;

  @override
  int get hashCode => Object.hash(
    enabled,
    preferredSize,
    startAutomatically,
    stopAutomatically,
    allowsCameraInBackground,
    fallbackLabel,
    fallbackBackgroundColor,
    fallbackTextColor,
  );
}

/// Starts and stops picture-in-picture for the [PictureInPictureView] it is
/// passed to. Replaces the React Native ref given to `startPIP` / `stopPIP`.
class PictureInPictureController {
  _PictureInPictureViewState? _view;
  bool _isActive = false;

  /// Whether the view is shown in the picture-in-picture window.
  bool get isActive => _isActive;

  /// Does nothing if the view has no [PictureInPictureView.pipOptions], or
  /// when the OS cannot start it now.
  Future<void> start() => _view?._send('start') ?? Future.value();

  /// Does nothing on Android: the user closes or expands the window.
  Future<void> stop() => _view?._send('stop') ?? Future.value();

  /// Replaces the native picture-in-picture video without rebuilding its
  /// [PictureInPictureView].
  ///
  /// Use this when a remote track is replaced while the Flutter app is in the
  /// background, such as after that peer reconnects. Pass `null` to show the
  /// configured fallback. Does nothing if the view is not offered.
  Future<void> setMediaStream(MediaStream? stream) =>
      _view?._setMediaStream(stream) ?? Future.value();
}

/// Renders the first video track of [mediaStream] and, if [pipOptions] is
/// set, offers it for picture-in-picture. Mirrors the React Native SDK's
/// `RTCPIPView`: each view manages its own native picture-in-picture
/// controller, so any number of views can set [pipOptions] independently
/// (e.g. a peer's camera and, later, your own, when the peer leaves and
/// that view unmounts).
///
/// Needs iOS 15+ or Android 8+ and the app setup described in the README.
class PictureInPictureView extends StatefulWidget {
  const PictureInPictureView({
    required this.mediaStream,
    super.key,
    this.pipOptions,
    this.controller,
    this.onPictureInPictureChange,
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  });

  /// The stream to render, e.g. `TrackContext.stream`.
  final MediaStream? mediaStream;

  /// `null` means the view is not offered for picture-in-picture.
  final PictureInPictureOptions? pipOptions;
  final PictureInPictureController? controller;

  /// Called when this view enters (`true`) or leaves (`false`)
  /// picture-in-picture.
  final ValueChanged<bool>? onPictureInPictureChange;

  final bool mirror;
  final RTCVideoViewObjectFit objectFit;

  @override
  State<PictureInPictureView> createState() => _PictureInPictureViewState();
}

class _PictureInPictureViewState extends State<PictureInPictureView> {
  static int _nextId = 0;

  final int _id = _nextId++;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _rendererReady = false;
  Rect? _rect;
  bool _active = false;
  bool _registered = false;
  Map<String, Object?>? _lastUpdate;

  bool get _offered => widget.pipOptions?.enabled ?? false;

  String? get _trackId => widget.mediaStream?.getVideoTracks().firstOrNull?.id;

  @override
  void initState() {
    super.initState();
    widget.controller?._view = this;
    _PipChannel.instance.register(_id, this);
    unawaited(_initRenderer());
  }

  Future<void> _initRenderer() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.mediaStream;
    setState(() => _rendererReady = true);
  }

  @override
  void didUpdateWidget(PictureInPictureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._view == this) {
        oldWidget.controller!
          .._view = null
          .._isActive = false;
      }
      widget.controller
        ?.._view = this
        .._isActive = _active;
    }
    if (_rendererReady && oldWidget.mediaStream != widget.mediaStream) {
      _renderer.srcObject = widget.mediaStream;
    }
  }

  @override
  void dispose() {
    if (_registered) {
      _registered = false;
      _setActive(false, notify: false);
      unawaited(_PipChannel.instance.unregisterNative(_id));
    }
    _PipChannel.instance.forget(_id);
    if (widget.controller?._view == this) {
      widget.controller!
        .._view = null
        .._isActive = false;
    }
    unawaited(_renderer.dispose());
    super.dispose();
  }

  /// The rect is re-measured after each build only. iOS animates
  /// picture-in-picture to and from it. A view moved without a rebuild
  /// (e.g. scrolled) keeps its last rect.
  void _sync(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      _rect = box.localToGlobal(Offset.zero) & box.size;
    }
    if (_offered && _PipChannel.supported) {
      _registered = true;
      final args = _updateArgs();
      if (const DeepCollectionEquality().equals(args, _lastUpdate)) return;
      _lastUpdate = args;
      unawaited(_PipChannel.instance.update(args));
    } else if (_registered) {
      _registered = false;
      _lastUpdate = null;
      _setActive(false, notify: false);
      unawaited(_PipChannel.instance.unregisterNative(_id));
    }
  }

  Map<String, Object?> _updateArgs() {
    final options = widget.pipOptions!;
    final size = options.preferredSize;
    final rect = _rect;
    return {
      'viewId': _id,
      'trackId': _trackId,
      'rect': rect == null
          ? null
          : {
              'x': rect.left,
              'y': rect.top,
              'width': rect.width,
              'height': rect.height,
            },
      'mirror': widget.mirror,
      'objectFit':
          widget.objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          ? 'contain'
          : 'cover',
      'preferredSize': {'width': size.width, 'height': size.height},
      'startAutomatically': options.startAutomatically,
      'stopAutomatically': options.stopAutomatically,
      'allowsCameraInBackground': options.allowsCameraInBackground,
      'fallbackLabel': options.fallbackLabel,
      'fallbackBackgroundColor': options.fallbackBackgroundColor.toARGB32(),
      'fallbackTextColor': options.fallbackTextColor.toARGB32(),
    };
  }

  Future<void> _send(String method) {
    if (!_registered) return Future.value();
    return _PipChannel.instance.send(_id, method);
  }

  Future<void> _setMediaStream(MediaStream? stream) {
    if (!_registered) return Future.value();
    final args = Map<String, Object?>.from(_lastUpdate ?? _updateArgs())
      ..['trackId'] = stream?.getVideoTracks().firstOrNull?.id;
    _lastUpdate = args;
    return _PipChannel.instance.update(args);
  }

  void _setActive(bool active, {required bool notify}) {
    if (_active == active) return;
    _active = active;
    if (widget.controller?._view == this) widget.controller!._isActive = active;
    if (notify) widget.onPictureInPictureChange?.call(active);
  }

  /// Label and colors for a missing video track. Same ones the native window
  /// draws. `pipOptions` may be null: this view can render without being
  /// offered.
  Widget _noVideo() {
    final options = widget.pipOptions ?? const PictureInPictureOptions();
    return ColoredBox(
      color: options.fallbackBackgroundColor,
      child: Center(
        child: Text(
          options.fallbackLabel,
          textAlign: TextAlign.center,
          style: TextStyle(color: options.fallbackTextColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback(_sync);
    if (!_rendererReady || _trackId == null) return _noVideo();
    return RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: widget.objectFit,
      placeholderBuilder: (_) => _noVideo(),
    );
  }
}

/// Talks to the native plugin. Each [PictureInPictureView] registers its own
/// native controller, keyed by its view id: there is no "offered" list or
/// arbitration here, only routing calls and events to the right view, like
/// a lookup table of independent per-view controllers (the React Native
/// SDK's model, where each `RTCView` owns one `PIPController`).
class _PipChannel {
  _PipChannel._();

  static final _PipChannel instance = _PipChannel._();

  static const _methods = MethodChannel('io.fishjam.client/pip');
  static const _events = EventChannel('io.fishjam.client/pip_events');

  final _views = <int, _PictureInPictureViewState>{};
  StreamSubscription<Object?>? _eventSubscription;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void register(int id, _PictureInPictureViewState view) {
    _views[id] = view;
    _eventSubscription ??= _events.receiveBroadcastStream().listen(_onEvent);
  }

  /// Stops routing events to [id]. Does not tell the native side: call
  /// [unregisterNative] first if it was told about this view.
  void forget(int id) {
    _views.remove(id);
    if (_views.isEmpty) {
      unawaited(_eventSubscription?.cancel());
      _eventSubscription = null;
    }
  }

  Future<void> unregisterNative(int id) =>
      _invoke('unregister', {'viewId': id});

  Future<void> update(Map<String, Object?> args) {
    if (!supported) return Future.value();
    return _invoke('update', args);
  }

  Future<void> send(int id, String method) async {
    if (!supported) return;
    await _invoke(method, {'viewId': id});
  }

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fishjam_client',
          context: ErrorDescription('while sending picture-in-picture $method'),
        ),
      );
    }
  }

  void _onEvent(Object? event) {
    if (event case {'viewId': final int id, 'isActive': final bool active}) {
      _views[id]?._setActive(active, notify: true);
    }
  }
}
