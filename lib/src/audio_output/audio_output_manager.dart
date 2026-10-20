import 'dart:async';

import 'package:fishjam_client/src/models/errors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device categories shared by iOS and Android.
enum AudioDeviceType {
  earpiece,
  speaker,
  bluetooth,
  wiredHeadset,
  usb,
  hdmi,
  airplay,
  carAudio,
  hearingAid,
  lineOut,
  unknown,
}

/// One audio output device.
@immutable
class AudioDevice {
  const AudioDevice({
    required this.type,
    required this.nativeType,
    required this.name,
    required this.id,
  });

  @internal
  factory AudioDevice.fromMap(Map<Object?, Object?> map) => AudioDevice(
    type: AudioDeviceType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => AudioDeviceType.unknown,
    ),
    nativeType: map['nativeType'] as String? ?? '',
    name: map['name'] as String? ?? '',
    id: map['id']?.toString() ?? '',
  );

  final AudioDeviceType type;

  /// Platform device type, e.g. `bluetoothHFP` on iOS, `bluetoothSCO` on
  /// Android.
  final String nativeType;

  /// Human-readable name.
  final String name;

  /// Pass to `AndroidAudioOutput.selectAudioOutput`. On iOS the built-in
  /// speaker is `speaker` and the receiver is `receiver`.
  final String id;

  @override
  bool operator ==(Object other) =>
      other is AudioDevice &&
      other.type == type &&
      other.nativeType == nativeType &&
      other.name == name &&
      other.id == id;

  @override
  int get hashCode => Object.hash(type, nativeType, name, id);

  @override
  String toString() =>
      'AudioDevice(${type.name}, $nativeType, "$name", id: $id)';
}

/// Emitted when the active output or the list of devices changes.
@immutable
class AudioOutputChangedInfo {
  const AudioOutputChangedInfo({
    required this.currentAudioOutput,
    required this.availableAudioOutputs,
  });

  /// `null` when unknown.
  final AudioDevice? currentAudioOutput;
  final List<AudioDevice> availableAudioOutputs;
}

/// Value for `IosAudioOutput.overrideAudioOutput`.
enum IosAudioOutputOverride {
  /// Force the built-in speaker.
  speaker,

  /// Clear the override and use the default route.
  none,
}

/// Lists, reads and switches the device that plays call audio.
///
/// Use [ios] and [android] for the platform-specific switching calls.
class AudioOutputManager {
  /// A manager on custom channels and platform (tests only).
  @internal
  AudioOutputManager.internal({
    MethodChannel methodChannel = const MethodChannel(
      'io.fishjam.client/audio_output',
    ),
    this._eventChannel = const EventChannel(
      'io.fishjam.client/audio_output_events',
    ),
    TargetPlatform Function()? platform,
  }) : _methods = methodChannel,
       _platform = platform ?? (() => defaultTargetPlatform);

  static final AudioOutputManager instance = AudioOutputManager.internal();

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final TargetPlatform Function() _platform;

  /// iOS-only controls. Each call throws `UnsupportedError` elsewhere.
  late final IosAudioOutput ios = IosAudioOutput._(this);

  /// Android-only controls. Each call throws `UnsupportedError` elsewhere.
  late final AndroidAudioOutput android = AndroidAudioOutput._(this);

  /// Every device audio can currently be routed to.
  Future<List<AudioDevice>> getAvailableAudioOutputs() async =>
      _devices(await _invoke<List<Object?>>('getAvailableAudioOutputs'));

  /// The device audio is routed to; `null` when unknown.
  Future<AudioDevice?> getCurrentAudioOutput() async {
    final map = await _invoke<Map<Object?, Object?>>('getCurrentAudioOutput');
    return map == null ? null : AudioDevice.fromMap(map);
  }

  /// Fires when the route or the device list changes (broadcast).
  late final Stream<AudioOutputChangedInfo> onAudioOutputChanged = _eventChannel
      .receiveBroadcastStream()
      .map((event) {
        final map = event as Map<Object?, Object?>;
        final current = map['currentAudioOutput'] as Map<Object?, Object?>?;
        return AudioOutputChangedInfo(
          currentAudioOutput: current == null
              ? null
              : AudioDevice.fromMap(current),
          availableAudioOutputs: _devices(
            map['availableAudioOutputs'] as List<Object?>?,
          ),
        );
      });

  /// Puts Android into call audio mode and routes to a connected Bluetooth
  /// headset. A no-op on other platforms.
  @internal
  Future<void> enterCommunicationMode() async {
    if (_platform() == TargetPlatform.android) {
      await _invoke<void>('enterCommunicationMode');
    }
  }

  /// Returns Android to normal audio mode. A no-op on other platforms.
  @internal
  Future<void> exitCommunicationMode() async {
    if (_platform() == TargetPlatform.android) {
      await _invoke<void>('exitCommunicationMode');
    }
  }

  void _require(TargetPlatform platform, String method) {
    if (_platform() != platform) {
      final group = platform == TargetPlatform.iOS ? 'ios' : 'android';
      throw UnsupportedError(
        'AudioOutputManager.$group.$method is not available on '
        '${_platform().name}',
      );
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw AudioOutputException(_codes[e.code] ?? .unknown, e.message);
    }
  }

  static List<AudioDevice> _devices(List<Object?>? list) => [
    for (final map in (list ?? const []).whereType<Map<Object?, Object?>>())
      AudioDevice.fromMap(map),
  ];

  static const Map<String, AudioOutputErrorCode> _codes = {
    'E_AUDIO_OUTPUT_SELECT': AudioOutputErrorCode.select,
    'E_AUDIO_OUTPUT_SUPERSEDED': AudioOutputErrorCode.superseded,
    'E_AUDIO_OUTPUT_TIMEOUT': AudioOutputErrorCode.timeout,
    'E_AUDIO_OUTPUT_CANCELLED': AudioOutputErrorCode.cancelled,
    'E_AUDIO_OUTPUT_INVALID': AudioOutputErrorCode.invalid,
    'E_AUDIO_OUTPUT_OVERRIDE': AudioOutputErrorCode.override,
  };
}

/// iOS audio output controls.
class IosAudioOutput {
  IosAudioOutput._(this._manager);

  final AudioOutputManager _manager;

  /// Opens the system route picker. This is the way to pick a specific
  /// Bluetooth or AirPlay device on iOS.
  Future<void> showAudioRoutePicker() {
    _manager._require(TargetPlatform.iOS, 'showAudioRoutePicker');
    return _manager._invoke<void>('showAudioRoutePicker');
  }

  /// Forces the built-in speaker, or clears the override with
  /// [IosAudioOutputOverride.none].
  Future<void> overrideAudioOutput(IosAudioOutputOverride output) {
    _manager._require(TargetPlatform.iOS, 'overrideAudioOutput');
    return _manager._invoke<void>('overrideAudioOutput', output.name);
  }
}

/// Android audio output controls.
class AndroidAudioOutput {
  AndroidAudioOutput._(this._manager);

  final AudioOutputManager _manager;

  /// Routes audio to the device with [deviceId] (`AudioDevice.id`).
  ///
  /// Completes once the system reports the device as current. Throws
  /// `AudioOutputException`; `superseded` is safe to ignore.
  Future<void> selectAudioOutput(String deviceId) {
    _manager._require(TargetPlatform.android, 'selectAudioOutput');
    return _manager._invoke<void>('selectAudioOutput', deviceId);
  }
}
