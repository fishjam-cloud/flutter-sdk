import AVFoundation
import AVKit
import Flutter
import UIKit

/// Lists, reads and switches the iOS audio route. Port of the React Native
/// SDK's audio output devices module.
final class AudioOutputManager {
  private let emit: ([String: Any]) -> Void
  private var routeObserver: NSObjectProtocol?
  private var releaseGeneration = 0

  init(emit: @escaping ([String: Any]) -> Void) {
    self.emit = emit
  }

  deinit {
    stopObserving()
  }

  func stopObserving() {
    if let observer = routeObserver {
      NotificationCenter.default.removeObserver(observer)
      routeObserver = nil
    }
  }

  /// Starts delivering route changes. Call this only after the event sink is
  /// set: a notification posted before that has nowhere to go (SPEC §20b).
  func startObserving() {
    guard routeObserver == nil else { return }
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.emit([
        "currentAudioOutput": self.currentDevice() ?? NSNull(),
        "availableAudioOutputs": self.availableDevices(),
      ])
    }
  }

  func getAvailableAudioOutputs(result: FlutterResult) {
    result(availableDevices())
  }

  func getCurrentAudioOutput(result: FlutterResult) {
    result(currentDevice())
  }

  func overrideAudioOutput(_ output: String?, result: FlutterResult) {
    let port: AVAudioSession.PortOverride
    switch output {
    case "speaker": port = .speaker
    case "none": port = .none
    default:
      result(
        FlutterError(
          code: "E_AUDIO_OUTPUT_INVALID",
          message: "Invalid output '\(output ?? "nil")', expected 'speaker' or 'none'",
          details: nil
        )
      )
      return
    }
    do {
      try AVAudioSession.sharedInstance().overrideOutputAudioPort(port)
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "E_AUDIO_OUTPUT_OVERRIDE",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  /// Drops a release scheduled by [exitCommunicationMode]. flutter_webrtc
  /// activates the call session; this method does not.
  func enterCommunicationMode() {
    releaseGeneration += 1
  }

  /// Deactivates the call session and tells other apps they can resume.
  /// Retried while capture is still running. See SPEC §20b.
  func exitCommunicationMode() {
    releaseGeneration += 1
    releaseOtherApps(generation: releaseGeneration, attempt: 0)
  }

  func showAudioRoutePicker(result: FlutterResult) {
    let picker = AVRoutePickerView(frame: .zero)
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    keyWindow?.addSubview(picker)
    // AVRoutePickerView has no API to open itself; tapping its button does.
    picker.subviews
      .compactMap { $0 as? UIButton }
      .first?
      .sendActions(for: .touchUpInside)
    picker.removeFromSuperview()
    result(nil)
  }

  /// `setActive(false)` without `notifyOthersOnDeactivation` leaves a paused
  /// app paused. flutter_webrtc deactivates that way. When this session is
  /// no longer silencing other apps, activate it once so the resume signal
  /// is attached to a real transition back to inactive (SPEC §20b).
  private func releaseOtherApps(generation: Int, attempt: Int) {
    guard generation == releaseGeneration else { return }
    let session = AVAudioSession.sharedInstance()
    guard Self.isCallCategory(session.category) else { return }

    if !session.secondaryAudioShouldBeSilencedHint {
      do {
        try session.setActive(true)
      } catch {
        NSLog(
          "FishjamClient: audio session not activated for release: %@",
          error.localizedDescription
        )
        scheduleReleaseRetry(generation: generation, attempt: attempt)
        return
      }
    }

    do {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      NSLog(
        "FishjamClient: audio session not released: %@",
        error.localizedDescription
      )
      scheduleReleaseRetry(generation: generation, attempt: attempt)
    }
  }

  private func scheduleReleaseRetry(generation: Int, attempt: Int) {
    guard attempt < Self.releaseRetryDelays.count else { return }
    let delay = Self.releaseRetryDelays[attempt]
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.releaseOtherApps(generation: generation, attempt: attempt + 1)
    }
  }

  private static func isCallCategory(_ category: AVAudioSession.Category) -> Bool {
    category == .playAndRecord || category == .record || category == .multiRoute
  }

  private static let releaseRetryDelays: [TimeInterval] = [0.2, 0.6, 1.2]

  private func availableDevices() -> [[String: Any]] {
    var devices: [[String: Any]] = [
      ["type": "speaker", "nativeType": "builtInSpeaker", "name": "Speaker", "id": "speaker"],
      ["type": "earpiece", "nativeType": "builtInReceiver", "name": "iPhone", "id": "receiver"],
    ]
    // Headsets show up as inputs; the built-in mic is covered by the two above.
    for port in AVAudioSession.sharedInstance().availableInputs ?? []
    where port.portType != .builtInMic {
      devices.append(serialize(port))
    }
    return devices
  }

  private func currentDevice() -> [String: Any]? {
    AVAudioSession.sharedInstance().currentRoute.outputs.first.map(serialize)
  }

  private func serialize(_ port: AVAudioSessionPortDescription) -> [String: Any] {
    [
      "type": Self.normalizedTypes[port.portType] ?? "unknown",
      "nativeType": Self.nativeTypes[port.portType] ?? port.portType.rawValue,
      "name": port.portName,
      "id": deviceId(port),
    ]
  }

  private func deviceId(_ port: AVAudioSessionPortDescription) -> String {
    switch port.portType {
    case .builtInSpeaker: return "speaker"
    case .builtInReceiver: return "receiver"
    default: return port.uid
    }
  }

  private static let nativeTypes: [AVAudioSession.Port: String] = [
    .builtInMic: "builtInMic",
    .headsetMic: "headsetMic",
    .lineIn: "lineIn",
    .lineOut: "lineOut",
    .headphones: "headphones",
    .bluetoothA2DP: "bluetoothA2DP",
    .builtInReceiver: "builtInReceiver",
    .builtInSpeaker: "builtInSpeaker",
    .HDMI: "HDMI",
    .airPlay: "airPlay",
    .bluetoothLE: "bluetoothLE",
    .bluetoothHFP: "bluetoothHFP",
    .usbAudio: "usbAudio",
    .carAudio: "carAudio",
  ]

  private static let normalizedTypes: [AVAudioSession.Port: String] = [
    .builtInReceiver: "earpiece",
    .builtInSpeaker: "speaker",
    .bluetoothHFP: "bluetooth",
    .bluetoothA2DP: "bluetooth",
    .bluetoothLE: "bluetooth",
    .headphones: "wiredHeadset",
    .headsetMic: "wiredHeadset",
    .usbAudio: "usb",
    .HDMI: "hdmi",
    .airPlay: "airplay",
    .carAudio: "carAudio",
    .lineOut: "lineOut",
  ]
}
