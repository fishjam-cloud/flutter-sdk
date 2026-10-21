import AVFoundation
import CallKit
import Flutter
import os.log
import UIKit

/// Reports the room as a CallKit call so iOS keeps its audio running in the
/// background. Port of the outgoing-call path of the React Native SDK's
/// CallKitManager; incoming calls and VoIP push are not supported.
final class CallKitManager: NSObject, CXProviderDelegate {
  private let emit: ([String: Any]) -> Void
  private let provider: CXProvider
  private let callController = CXCallController()
  private var currentCallUUID: UUID?
  private var isDialing = false
  private var isCallOnHold = false
  private var isVideoCall = false

  init(emit: @escaping ([String: Any]) -> Void) {
    self.emit = emit
    let configuration: CXProviderConfiguration
    if #available(iOS 14.0, *) {
      configuration = CXProviderConfiguration()
    } else {
      configuration = CXProviderConfiguration(
        localizedName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
      )
    }
    configuration.supportsVideo = true
    configuration.supportedHandleTypes = [.generic]
    configuration.maximumCallsPerCallGroup = 1
    configuration.maximumCallGroups = 1
    configuration.includesCallsInRecents = false
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCallKitSession":
      let args = call.arguments as? [String: Any] ?? [:]
      guard let displayName = args["displayName"] as? String, !displayName.isEmpty else {
        result(
          FlutterError(
            code: "E_CALLKIT_INVALID_DISPLAY_NAME", message: "displayName is required", details: nil
          ))
        return
      }
      let handle = (args["handle"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? displayName
      startCall(
        displayName: displayName,
        handle: handle,
        isVideo: args["isVideo"] as? Bool ?? false,
        isDialing: args["isDialing"] as? Bool ?? false
      )
      result(nil)
    case "endCallKitSession":
      endCall(reason: call.arguments as? String ?? "local")
      result(nil)
    case "reportOutgoingCallConnected":
      reportOutgoingCallConnected()
      result(nil)
    case "setCallKitCallHeld":
      if let uuid = activeCall(), let onHold = call.arguments as? Bool {
        request(CXSetHeldCallAction(call: uuid, onHold: onHold))
      }
      result(nil)
    case "setCallKitMuted":
      if let uuid = activeCall(), let muted = call.arguments as? Bool {
        request(CXSetMutedCallAction(call: uuid, muted: muted))
      }
      result(nil)
    case "hasActiveCallKitSession":
      result(currentCallUUID != nil)
    case "isCallKitCallHeld":
      result(isCallOnHold)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCall(displayName: String, handle: String, isVideo: Bool, isDialing: Bool) {
    guard currentCallUUID == nil else {
      os_log("[CallKitManager] Call already in progress")
      return
    }
    let uuid = UUID()
    currentCallUUID = uuid
    self.isDialing = isDialing
    isVideoCall = isVideo
    if isVideo { setMultitaskingCameraAccess(true) }

    let action = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: handle))
    action.isVideo = isVideo
    action.contactIdentifier = displayName

    callController.request(CXTransaction(action: action)) { [weak self] error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error {
          os_log("[CallKitManager] Failed to start call: %{public}@", error.localizedDescription)
          self.cleanupCurrentCall()
          self.emit(["failed": error.localizedDescription])
          return
        }
        self.emit(["started": NSNull()])
        let update = CXCallUpdate()
        update.localizedCallerName = displayName
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        update.hasVideo = isVideo
        self.provider.reportCall(with: uuid, updated: update)
      }
    }
  }

  private func endCall(reason: String) {
    guard let uuid = currentCallUUID else {
      os_log("[CallKitManager] No active call to end")
      return
    }
    if reason == "local" || reason == "rejected" {
      // performEndCallAction emits `ended` once the transaction is fulfilled.
      callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { error in
        if let error {
          os_log("[CallKitManager] Failed to end call: %{public}@", error.localizedDescription)
        }
      }
      return
    }
    provider.reportCall(with: uuid, endedAt: Date(), reason: endedReason(reason))
    emit(["ended": reason])
    cleanupCurrentCall()
  }

  private func endedReason(_ reason: String) -> CXCallEndedReason {
    switch reason {
    case "missed": return .unanswered
    case "answeredElsewhere": return .answeredElsewhere
    case "failed": return .failed
    default: return .remoteEnded
    }
  }

  private func reportOutgoingCallConnected() {
    guard let uuid = currentCallUUID, isDialing else {
      os_log("[CallKitManager] No dialing call to report as connected")
      return
    }
    isDialing = false
    provider.reportOutgoingCall(with: uuid, connectedAt: Date())
  }

  private func activeCall() -> UUID? {
    if currentCallUUID == nil {
      os_log("[CallKitManager] No active call")
    }
    return currentCallUUID
  }

  private func request(_ action: CXCallAction) {
    callController.request(CXTransaction(action: action)) { error in
      if let error {
        os_log("[CallKitManager] Call action failed: %{public}@", error.localizedDescription)
      }
    }
  }

  private func cleanupCurrentCall() {
    currentCallUUID = nil
    isDialing = false
    isCallOnHold = false
    if isVideoCall { setMultitaskingCameraAccess(false) }
    isVideoCall = false
  }

  /// iOS stops the camera when the app backgrounds. A video call opts the
  /// capture session into multitasking camera access, which is what keeps it
  /// running. The session may not exist yet when the call starts, so this
  /// runs again as the app resigns active.
  @objc private func willResignActive() {
    guard isVideoCall else { return }
    setMultitaskingCameraAccess(true)
  }

  private static var didLogCameraAccessFailure = false

  private func setMultitaskingCameraAccess(_ enabled: Bool) {
    guard #available(iOS 16.0, *) else { return }
    guard let session = Self.captureSession() else { return }
    guard session.isMultitaskingCameraAccessSupported else {
      if enabled { Self.logCameraAccessFailure() }
      return
    }
    guard session.isMultitaskingCameraAccessEnabled != enabled else { return }
    session.beginConfiguration()
    session.isMultitaskingCameraAccessEnabled = enabled
    session.commitConfiguration()
  }

  private static func captureSession() -> AVCaptureSession? {
    guard let type = NSClassFromString("FlutterWebRTCPlugin") as? NSObject.Type else { return nil }
    let selector = NSSelectorFromString("sharedSingleton")
    guard type.responds(to: selector),
      let plugin = type.perform(selector)?.takeUnretainedValue() as? NSObject
    else { return nil }
    return (plugin.value(forKey: "videoCapturer") as? NSObject)?
      .value(forKey: "captureSession") as? AVCaptureSession
  }

  private static func logCameraAccessFailure() {
    guard !didLogCameraAccessFailure else { return }
    didLogCameraAccessFailure = true
    os_log(
      "[CallKitManager] The camera will stop in the background: multitasking camera access is not supported. On iOS 18 or newer, add voip to UIBackgroundModes. Before that, the com.apple.developer.avfoundation.multitasking-camera-access entitlement is also required."
    )
  }

  /// RTCAudioSession comes from flutter_webrtc's WebRTC framework. Looking it
  /// up by name keeps this plugin free of a build dependency on that pod.
  private func forwardToRtcAudioSession(_ selector: String, _ session: AVAudioSession) {
    guard let rtcClass = NSClassFromString("RTCAudioSession") as? NSObject.Type,
      let shared = rtcClass.perform(NSSelectorFromString("sharedInstance"))?
        .takeUnretainedValue() as? NSObject
    else {
      os_log("[CallKitManager] RTCAudioSession not found; is flutter_webrtc linked?")
      return
    }
    shared.perform(NSSelectorFromString(selector), with: session)
  }

  // MARK: - CXProviderDelegate

  func providerDidReset(_ provider: CXProvider) {
    cleanupCurrentCall()
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    let now = Date()
    provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: now)
    if !isDialing {
      provider.reportOutgoingCall(with: action.callUUID, connectedAt: now)
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard action.callUUID == currentCallUUID else {
      action.fulfill()
      return
    }
    emit(["ended": "local"])
    action.fulfill()
    cleanupCurrentCall()
  }

  func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    isCallOnHold = action.isOnHold
    emit(["held": action.isOnHold])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    emit(["muted": action.isMuted])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
    action.fail()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    forwardToRtcAudioSession("audioSessionDidActivate:", audioSession)
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    forwardToRtcAudioSession("audioSessionDidDeactivate:", audioSession)
  }
}
