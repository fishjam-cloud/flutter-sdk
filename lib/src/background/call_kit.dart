import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why a CallKit call ended.
enum CallEndedReason {
  local,
  rejected,
  missed,
  remote,
  answeredElsewhere,
  failed,
}

/// The call shown in the iOS system call UI.
@immutable
class CallKitConfig {
  const CallKitConfig({
    required this.displayName,
    required this.isVideo,
    this.handle,
    this.isDialing = false,
  });

  /// Label shown in the system call UI and in Recents. Must not be empty.
  final String displayName;

  /// Stable identifier of the other party (e.g. a user id), the identity
  /// iOS keeps in Recents. Defaults to [displayName].
  final String? handle;
  final bool isVideo;

  /// The call is ringing the other side. Call
  /// `CallKit.reportOutgoingCallConnected` once it joins; otherwise the call
  /// is reported as connected right away.
  final bool isDialing;
}

/// A change reported by CallKit, often made by the user in the system UI.
@immutable
sealed class CallKitAction {
  const CallKitAction();
}

/// The call was started.
final class CallKitStarted extends CallKitAction {
  const CallKitStarted();

  @override
  bool operator ==(Object other) => other is CallKitStarted;

  @override
  int get hashCode => (CallKitStarted).hashCode;

  @override
  String toString() => 'CallKitStarted()';
}

/// The call ended, e.g. the user tapped the end button in the system UI.
final class CallKitEnded extends CallKitAction {
  const CallKitEnded(this.reason);

  final CallEndedReason reason;

  @override
  bool operator ==(Object other) =>
      other is CallKitEnded && other.reason == reason;

  @override
  int get hashCode => Object.hash(CallKitEnded, reason);

  @override
  String toString() => 'CallKitEnded(${reason.name})';
}

/// CallKit refused to start the call.
final class CallKitFailed extends CallKitAction {
  const CallKitFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is CallKitFailed && other.message == message;

  @override
  int get hashCode => Object.hash(CallKitFailed, message);

  @override
  String toString() => 'CallKitFailed($message)';
}

/// The microphone was muted or unmuted in the system UI. Apply it to the
/// microphone track.
final class CallKitMuted extends CallKitAction {
  const CallKitMuted({required this.isMuted});

  final bool isMuted;

  @override
  bool operator ==(Object other) =>
      other is CallKitMuted && other.isMuted == isMuted;

  @override
  int get hashCode => Object.hash(CallKitMuted, isMuted);

  @override
  String toString() => 'CallKitMuted($isMuted)';
}

/// The call was put on hold or resumed, e.g. by another incoming call.
final class CallKitHeld extends CallKitAction {
  const CallKitHeld({required this.isHeld});

  final bool isHeld;

  @override
  bool operator ==(Object other) =>
      other is CallKitHeld && other.isHeld == isHeld;

  @override
  int get hashCode => Object.hash(CallKitHeld, isHeld);

  @override
  String toString() => 'CallKitHeld($isHeld)';
}

/// iOS CallKit session: shows the call in the system UI and keeps its audio
/// running in the background. Start it after joining, end it after leaving.
/// Every call is a no-op on other platforms.
///
/// The app must add `audio` and `voip` to `UIBackgroundModes` in
/// `Info.plist`.
class CallKit {
  /// A CallKit wrapper on custom channels and platform (tests only).
  @internal
  CallKit.internal({
    MethodChannel methodChannel = const MethodChannel(
      'io.fishjam.client/background',
    ),
    this._eventChannel = const EventChannel('io.fishjam.client/callkit_events'),
    TargetPlatform Function()? platform,
  }) : _methods = methodChannel,
       _platform = platform ?? (() => defaultTargetPlatform);

  static final CallKit instance = CallKit.internal();

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final TargetPlatform Function() _platform;

  bool get _isIos => _platform() == TargetPlatform.iOS;

  /// Reports a new call to CallKit. Ignored while a call is active; a
  /// refusal arrives as [CallKitFailed].
  ///
  /// Throws `ArgumentError` when `displayName` is empty.
  Future<void> startSession(CallKitConfig config) async {
    if (config.displayName.isEmpty) {
      throw ArgumentError.value(
        config.displayName,
        'displayName',
        'must not be empty',
      );
    }
    if (!_isIos) return;
    await _methods.invokeMethod<void>('startCallKitSession', {
      'displayName': config.displayName,
      'handle': config.handle ?? config.displayName,
      'isVideo': config.isVideo,
      'isDialing': config.isDialing,
    });
  }

  Future<void> endSession([CallEndedReason reason = CallEndedReason.local]) =>
      _call('endCallKitSession', reason.name);

  /// Reports a dialing call (`CallKitConfig.isDialing`) as connected.
  Future<void> reportOutgoingCallConnected() =>
      _call('reportOutgoingCallConnected');

  /// The result arrives as [CallKitHeld].
  Future<void> setHeld({required bool onHold}) =>
      _call('setCallKitCallHeld', onHold);

  /// The result arrives as [CallKitMuted].
  Future<void> setMuted({required bool muted}) =>
      _call('setCallKitMuted', muted);

  Future<bool> hasActiveSession() => _flag('hasActiveCallKitSession');

  Future<bool> isHeld() => _flag('isCallKitCallHeld');

  /// Changes reported by CallKit (broadcast). Never emits on other
  /// platforms.
  late final Stream<CallKitAction> actions = _isIos
      ? _eventChannel.receiveBroadcastStream().expand(_parse)
      : const Stream.empty();

  Future<void> _call(String method, [Object? arguments]) async {
    if (_isIos) await _methods.invokeMethod<void>(method, arguments);
  }

  Future<bool> _flag(String method) async =>
      _isIos && (await _methods.invokeMethod<bool>(method) ?? false);

  static Iterable<CallKitAction> _parse(Object? event) {
    final map = event! as Map<Object?, Object?>;
    return [
      if (map.containsKey('started')) const CallKitStarted(),
      if (map['ended'] case final String reason)
        CallKitEnded(
          CallEndedReason.values.firstWhere(
            (r) => r.name == reason,
            orElse: () => CallEndedReason.local,
          ),
        ),
      if (map['failed'] case final String message) CallKitFailed(message),
      if (map['muted'] case final bool isMuted) CallKitMuted(isMuted: isMuted),
      if (map['held'] case final bool isHeld) CallKitHeld(isHeld: isHeld),
    ];
  }
}
