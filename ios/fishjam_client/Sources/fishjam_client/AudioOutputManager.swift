import AVFoundation
import AVKit
import Flutter
import UIKit

/// Lists, reads and switches the iOS audio route. Port of the React Native
/// SDK's audio output devices module.
final class AudioOutputManager {
  private let emit: ([String: Any]) -> Void
  private var routeObserver: NSObjectProtocol?

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

  func getAvailableAudioOutputs(result: FlutterResult) {
    ensureRouteObserver()
    result(availableDevices())
  }

  func getCurrentAudioOutput(result: FlutterResult) {
    ensureRouteObserver()
    result(currentDevice())
  }

  func overrideAudioOutput(_ output: String?, result: FlutterResult) {
    ensureRouteObserver()
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

  func showAudioRoutePicker(result: FlutterResult) {
    ensureRouteObserver()
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

  private func ensureRouteObserver() {
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
