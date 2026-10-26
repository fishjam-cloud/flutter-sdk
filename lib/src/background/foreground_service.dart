import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Importance of the foreground service notification channel.
enum ForegroundServiceImportance {
  /// Silent, persistent ongoing-call indicator.
  low,

  /// Heads-up popup with sound.
  high,
}

/// Settings of the Android foreground service that keeps a call running in
/// the background.
@immutable
class ForegroundServiceConfig {
  const ForegroundServiceConfig({
    this.enableCamera = false,
    this.enableMicrophone = false,
    this.enableScreenSharing = false,
    this.channelId,
    this.channelName,
    this.notificationTitle,
    this.notificationContent,
    this.importance = ForegroundServiceImportance.high,
    this.onlyAlertOnce = false,
  });

  /// Adds the `camera` service type. Takes effect only once `CAMERA` is
  /// granted.
  final bool enableCamera;

  /// Adds the `microphone` service type. Takes effect only once
  /// `RECORD_AUDIO` is granted.
  final bool enableMicrophone;

  /// Adds the `mediaProjection` service type. Get the user's consent with
  /// `Helper.requestCapturePermission()` before starting the service.
  final bool enableScreenSharing;

  /// Defaults to `com.fishjam.foregroundservice.channel`.
  final String? channelId;

  /// Defaults to `Fishjam Notifications`.
  final String? channelName;
  final String? notificationTitle;
  final String? notificationContent;

  /// Android binds the importance to the channel when it is first created
  /// and ignores later changes for the same [channelId]. Use a distinct
  /// [channelId] per importance to switch it at runtime.
  final ForegroundServiceImportance importance;
  final bool onlyAlertOnce;

  Map<String, Object> _toMap() => {
    'enableCamera': enableCamera,
    'enableMicrophone': enableMicrophone,
    'enableScreenSharing': enableScreenSharing,
    'channelId': ?channelId,
    'channelName': ?channelName,
    'notificationTitle': ?notificationTitle,
    'notificationContent': ?notificationContent,
    'importance': importance.name,
    'onlyAlertOnce': onlyAlertOnce,
  };
}

/// Android foreground service that keeps the app, and so the call, running
/// while it is in the background. Start it after joining, stop it after
/// leaving. A no-op on other platforms.
///
/// The app must declare the service and its permissions in
/// `AndroidManifest.xml`; see the README.
class ForegroundService {
  /// A service on a custom channel and platform (tests only).
  @internal
  ForegroundService.internal({
    MethodChannel methodChannel = const MethodChannel(
      'io.fishjam.client/background',
    ),
    TargetPlatform Function()? platform,
  }) : _methods = methodChannel,
       _platform = platform ?? (() => defaultTargetPlatform);

  static final ForegroundService instance = ForegroundService.internal();

  final MethodChannel _methods;
  final TargetPlatform Function() _platform;

  bool get _isAndroid => _platform() == TargetPlatform.android;

  /// Starts the service, or updates the running one with [config].
  ///
  /// On Android 13+ the first call asks for `POST_NOTIFICATIONS`. If the
  /// user refuses, the service still runs without a visible notification.
  Future<void> start(ForegroundServiceConfig config) async {
    if (_isAndroid) {
      await _methods.invokeMethod<void>(
        'startForegroundService',
        config._toMap(),
      );
    }
  }

  Future<void> stop() async {
    if (_isAndroid) {
      await _methods.invokeMethod<void>('stopForegroundService');
    }
  }
}
