import Flutter
import UIKit

public class FishjamClientPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var audioEventSink: FlutterEventSink?
  private lazy var audioOutput = AudioOutputManager { [weak self] event in
    self?.audioEventSink?(event)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FishjamClientPlugin()

    let audioChannel = FlutterMethodChannel(
      name: "io.fishjam.client/audio_output",
      binaryMessenger: registrar.messenger()
    )
    audioChannel.setMethodCallHandler { [weak instance] call, result in
      instance?.handleAudio(call, result: result)
    }
    let audioEvents = FlutterEventChannel(
      name: "io.fishjam.client/audio_output_events",
      binaryMessenger: registrar.messenger()
    )
    audioEvents.setStreamHandler(instance)
  }

  private func handleAudio(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAvailableAudioOutputs":
      audioOutput.getAvailableAudioOutputs(result: result)
    case "getCurrentAudioOutput":
      audioOutput.getCurrentAudioOutput(result: result)
    case "overrideAudioOutput":
      audioOutput.overrideAudioOutput(call.arguments as? String, result: result)
    case "showAudioRoutePicker":
      audioOutput.showAudioRoutePicker(result: result)
    case "enterCommunicationMode":
      audioOutput.enterCommunicationMode()
      result(nil)
    case "exitCommunicationMode":
      audioOutput.exitCommunicationMode()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    audioEventSink = events
    // Sink first, then the observer. A route change after subscribe reaches
    // Dart even when the app has not read the device list (SPEC §20b).
    audioOutput.startObserving()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    audioOutput.stopObserving()
    audioEventSink = nil
    return nil
  }
}
