import Flutter
import UIKit

public class FishjamClientPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var audioEventSink: FlutterEventSink?
  private lazy var audioOutput = AudioOutputManager { [weak self] event in
    self?.audioEventSink?(event)
  }
  private let callKitEvents = EventSinkHandler()
  private let pictureInPicture = PictureInPictureManager()
  private lazy var callKit = CallKitManager { [weak self] event in
    self?.callKitEvents.sink?(event)
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

    let backgroundChannel = FlutterMethodChannel(
      name: "io.fishjam.client/background",
      binaryMessenger: registrar.messenger()
    )
    backgroundChannel.setMethodCallHandler { [weak instance] call, result in
      guard let instance else { return result(FlutterMethodNotImplemented) }
      instance.callKit.handle(call, result: result)
    }
    let callKitEvents = FlutterEventChannel(
      name: "io.fishjam.client/callkit_events",
      binaryMessenger: registrar.messenger()
    )
    callKitEvents.setStreamHandler(instance.callKitEvents)

    let pipChannel = FlutterMethodChannel(
      name: "io.fishjam.client/pip",
      binaryMessenger: registrar.messenger()
    )
    pipChannel.setMethodCallHandler { [weak instance] call, result in
      guard let instance else { return result(FlutterMethodNotImplemented) }
      instance.pictureInPicture.handle(call, result: result)
    }
    let pipEvents = FlutterEventChannel(
      name: "io.fishjam.client/pip_events",
      binaryMessenger: registrar.messenger()
    )
    pipEvents.setStreamHandler(instance.pictureInPicture)
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

final class EventSinkHandler: NSObject, FlutterStreamHandler {
  private(set) var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
