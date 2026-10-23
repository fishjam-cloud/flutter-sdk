import AVKit
import Flutter
import UIKit
import WebRTC

/// Handles `io.fishjam.client/pip`: each `PictureInPictureView` on the Dart
/// side gets its own `PipController` here, keyed by view id. This mirrors
/// the React Native SDK, where every `RTCView` with `pip` set owns one
/// `PIPController` (`react-native-webrtc/ios/RCTWebRTC/PIPController.m`):
/// there is no single "offered" view and no "most recently updated wins".
final class PictureInPictureManager: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var controllers: [Int: AnyObject] = [:]
  /// Controllers whose window is still closing. Releasing one while it is
  /// active leaves the system window up on the last frame.
  private var retiring: [AnyObject] = []

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let id = args["viewId"] as? Int else { return result(nil) }
    switch call.method {
    case "update":
      if #available(iOS 15.0, *) { update(viewId: id, args: args) }
      result(nil)
    case "start":
      if #available(iOS 15.0, *) { controller(id)?.start() }
      result(nil)
    case "stop":
      if #available(iOS 15.0, *) { controller(id)?.stop() }
      result(nil)
    case "unregister":
      tearDown(viewId: id)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 15.0, *)
  private func controller(_ id: Int) -> PipController? { controllers[id] as? PipController }

  @available(iOS 15.0, *)
  private func update(viewId id: Int, args: [String: Any]) {
    // Unsupported (e.g. on the simulator), `AVPictureInPictureController`
    // returns nil from an initializer Swift treats as non-failable.
    guard AVPictureInPictureController.isPictureInPictureSupported(),
      let sourceView = Self.flutterRootView()
    else { return }

    let pip: PipController
    if let existing = controller(id) {
      pip = existing
    } else {
      pip = PipController(rootView: sourceView) { [weak self] active in
        self?.eventSink?(["viewId": id, "isActive": active])
      }
      controllers[id] = pip
    }

    pip.setPlaceholder(
      label: args["fallbackLabel"] as? String ?? "No video",
      background: Self.color(args["fallbackBackgroundColor"], fallback: 0xFF1C2945),
      text: Self.color(args["fallbackTextColor"], fallback: 0xFFFFFFFF)
    )
    pip.videoTrack = (args["trackId"] as? String).flatMap(FlutterWebRtcLookup.videoTrack)
    pip.objectFitContain = (args["objectFit"] as? String) == "contain"
    if let rect = args["rect"] as? [String: Any] {
      pip.setSourceFrame(
        CGRect(
          x: number(rect["x"]),
          y: number(rect["y"]),
          width: number(rect["width"]),
          height: number(rect["height"])
        )
      )
    }
    pip.preferredSize = Self.preferredSize(args["preferredSize"])
    pip.startAutomatically = args["startAutomatically"] as? Bool ?? true
    pip.stopAutomatically = args["stopAutomatically"] as? Bool ?? true
    pip.allowsCameraInBackground = args["allowsCameraInBackground"] as? Bool ?? false
  }

  private func tearDown(viewId id: Int) {
    if #available(iOS 15.0, *) {
      let active = controller(id)?.isActive ?? false
      if let pip = controller(id), active {
        retiring.append(pip)
        pip.retire { [weak self] in
          self?.retiring.removeAll { $0 === pip }
        }
      } else {
        controller(id)?.invalidate()
      }
    }
    controllers.removeValue(forKey: id)
  }

  /// React Native uses 1920×1080 when `preferredSize` is missing or not a
  /// pair of positive numbers.
  private static func preferredSize(_ value: Any?) -> CGSize {
    let fallback = CGSize(width: 1920, height: 1080)
    guard let size = value as? [String: Any] else { return fallback }
    let width = CGFloat((size["width"] as? NSNumber)?.doubleValue ?? 0)
    let height = CGFloat((size["height"] as? NSNumber)?.doubleValue ?? 0)
    guard width > 0, height > 0 else { return fallback }
    return CGSize(width: width, height: height)
  }

  private func number(_ value: Any?) -> CGFloat {
    CGFloat((value as? NSNumber)?.doubleValue ?? 0)
  }

  /// `argb` is the 0xAARRGGBB int Dart sends for a [Color].
  private static func color(_ value: Any?, fallback: UInt32) -> UIColor {
    let argb = (value as? NSNumber)?.uint32Value ?? fallback
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }

  private static func flutterRootView() -> UIView? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    let window = windows.first(where: \.isKeyWindow) ?? windows.first
    return window?.rootViewController?.view
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

/// Port of the React Native SDK's `PIPController`
/// (`react-native-webrtc/ios/RCTWebRTC/PIPController.m`): one instance per
/// view, holding its own `AVPictureInPictureController`.
@available(iOS 15.0, *)
private final class PipController: NSObject, AVPictureInPictureControllerDelegate {
  private let sampleView = SampleBufferVideoCallView()
  private let callViewController = AVPictureInPictureVideoCallViewController()
  private let pip: AVPictureInPictureController
  private let onChange: (Bool) -> Void
  private var activeObservation: NSKeyValueObservation?
  private var cameraAccessApplied = false
  private var retireCompletion: (() -> Void)?
  private let fallbackView = PipFallbackView()
  /// The window's `activeVideoCallSourceView`. iOS animates picture-in-picture
  /// to and from this view's frame, so the frame is the video tile, not the
  /// screen. Removing it (in `stop()`) is what lets iOS close the window
  /// while the app is hidden. The Flutter root retains it until
  /// [detachSourceView] on teardown.
  private let sourceView = UIView()
  /// Safety net for `stop()` in the background: if removing [sourceView]
  /// does not make iOS close the window on its own, force the close once the
  /// app returns (iOS honors `stopPictureInPicture()` again then).
  private var closeOnForeground = false

  var stopAutomatically = true

  deinit {
    sourceView.removeFromSuperview()
  }

  init(rootView: UIView, onChange: @escaping (Bool) -> Void) {
    self.onChange = onChange
    callViewController.view.backgroundColor = .black
    sourceView.backgroundColor = .clear
    sourceView.isUserInteractionEnabled = false
    sourceView.isAccessibilityElement = false
    // On top of the Flutter view, clear, so iOS treats the tile frame as
    // visible. Touches pass through.
    rootView.addSubview(sourceView)
    pip = AVPictureInPictureController(
      contentSource: .init(
        activeVideoCallSourceView: sourceView,
        contentViewController: callViewController
      )
    )
    super.init()
    pip.canStartPictureInPictureAutomaticallyFromInline = true
    pip.delegate = self
    activeObservation = pip.observe(\.isPictureInPictureActive, options: [.initial, .new]) {
      [weak self] _, _ in
      self?.updateShouldRender()
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  var isActive: Bool { pip.isPictureInPictureActive }

  var videoTrack: RTCVideoTrack? {
    didSet {
      guard oldValue !== videoTrack else { return }
      oldValue?.remove(sampleView)
      if let videoTrack {
        videoTrack.add(sampleView)
        fallbackView.removeFromSuperview()
        if sampleView.superview == nil { fill(callViewController.view, with: sampleView) }
      } else {
        sampleView.removeFromSuperview()
        if pip.isPictureInPictureActive { showFallback() }
      }
      updateShouldRender()
    }
  }

  var objectFitContain = false {
    didSet {
      sampleView.sampleBufferLayer.videoGravity = objectFitContain ? .resizeAspect : .resizeAspectFill
    }
  }

  var preferredSize: CGSize {
    get { callViewController.preferredContentSize }
    set {
      guard newValue.width > 0, newValue.height > 0,
        newValue != callViewController.preferredContentSize
      else { return }
      callViewController.preferredContentSize = newValue
      sampleView.requestScaleRecalculation()
    }
  }

  var startAutomatically: Bool {
    get { pip.canStartPictureInPictureAutomaticallyFromInline }
    set {
      pip.canStartPictureInPictureAutomaticallyFromInline = newValue
      updateShouldRender()
    }
  }

  /// An empty sample-buffer layer is not started when the app backgrounds.
  /// Render while automatic start is on, not only after the window is up.
  /// Starting the window from code during the hide cancels the hide.
  private func updateShouldRender() {
    sampleView.shouldRender = videoTrack != nil
      && (pip.isPictureInPictureActive || startAutomatically)
  }

  var allowsCameraInBackground = false {
    didSet {
      if allowsCameraInBackground || cameraAccessApplied {
        cameraAccessApplied = Self.setMultitaskingCameraAccess(allowsCameraInBackground)
          && allowsCameraInBackground
      }
    }
  }

  /// `frame` is the video tile in the Flutter view's coordinates (logical
  /// pixels, same as points). That rectangle is where the system animation
  /// starts and ends.
  func setSourceFrame(_ frame: CGRect) {
    guard frame.width > 1, frame.height > 1 else { return }
    sourceView.frame = frame
    sourceView.superview?.bringSubviewToFront(sourceView)
  }

  func start() {
    if pip.isPictureInPicturePossible { pip.startPictureInPicture() }
  }

  /// The window's aspect ratio stays [preferredSize] (e.g. 16:9, matching the
  /// React Native SDK's default) while floating. If that does not match the
  /// tile's aspect ratio, closing to the tile animates in two visible steps:
  /// the window first grows to fit the screen at its own aspect ratio, with
  /// black bars for the gap to the tile's aspect, then only after that jumps
  /// to the tile's shape. Matching the tile's aspect ratio just before the
  /// window closes removes that first step.
  private func matchContentSizeToTile() {
    preferredSize = sourceView.bounds.size
  }

  func stop() {
    guard pip.isPictureInPictureActive else { return }
    matchContentSizeToTile()
    if UIApplication.shared.applicationState == .background {
      // iOS ignores an explicit stopPictureInPicture() call while the app is
      // hidden. Removing the source view from the screen is a close the
      // system drives itself, the same way it closes React Native's window
      // once its RTCView unmounts, so it works while hidden too.
      closeOnForeground = true
      videoTrack = nil
      sourceView.removeFromSuperview()
    }
    pip.stopPictureInPicture()
  }

  /// Text and colors for [fallbackView]. Applied on every update, so a
  /// change shows up even while the window is already open.
  func setPlaceholder(label: String, background: UIColor, text: UIColor) {
    fallbackView.apply(label: label, background: background, text: text)
  }

  /// Same role as the React Native `PIPController` fallback view: what the
  /// window shows once the camera track is gone.
  private func showFallback() {
    if fallbackView.superview == nil { fill(callViewController.view, with: fallbackView) }
  }

  /// Stop the window, then drop this controller only after iOS has closed it.
  /// Clearing the track or releasing `self` earlier freezes the window.
  func retire(completion: @escaping () -> Void) {
    retireCompletion = completion
    if pip.isPictureInPictureActive {
      stop()
    } else {
      finishRetirement()
    }
  }

  private func finishRetirement() {
    videoTrack = nil
    if cameraAccessApplied { allowsCameraInBackground = false }
    activeObservation = nil
    NotificationCenter.default.removeObserver(self)
    detachSourceView()
    let completion = retireCompletion
    retireCompletion = nil
    completion?()
  }

  func invalidate() {
    stop()
    videoTrack = nil
    if cameraAccessApplied { allowsCameraInBackground = false }
    activeObservation = nil
    NotificationCenter.default.removeObserver(self)
    detachSourceView()
  }

  /// The Flutter root keeps [sourceView] until this runs. `stop()` may
  /// already have removed it.
  private func detachSourceView() {
    sourceView.removeFromSuperview()
  }

  /// The capture session may not exist when the option is first set (the
  /// camera starts later), and a new session drops the flag. Set it again at
  /// the last moment iOS still allows it.
  @objc private func willResignActive() {
    if allowsCameraInBackground {
      cameraAccessApplied = Self.setMultitaskingCameraAccess(true)
    }
  }

  @objc private func willEnterForeground() {
    guard stopAutomatically || closeOnForeground else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.stop() }
  }

  private func fill(_ container: UIView, with view: UIView) {
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      view.topAnchor.constraint(equalTo: container.topAnchor),
      view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  private static var didLogCameraAccessFailure = false

  private static func setMultitaskingCameraAccess(_ enabled: Bool) -> Bool {
    guard #available(iOS 16.0, *) else { return false }
    guard let session = FlutterWebRtcLookup.captureSession() else { return false }
    guard session.isMultitaskingCameraAccessSupported else {
      if enabled { logCameraAccessFailure() }
      return false
    }
    if session.isMultitaskingCameraAccessEnabled != enabled {
      session.beginConfiguration()
      session.isMultitaskingCameraAccessEnabled = enabled
      session.commitConfiguration()
    }
    return true
  }

  private static func logCameraAccessFailure() {
    guard !didLogCameraAccessFailure else { return }
    didLogCameraAccessFailure = true
    NSLog(
      "[FISHJAM] The camera will stop in the background: multitasking camera access is not supported. "
        + "On iOS 18 or newer, add voip to UIBackgroundModes. Before that, the "
        + "com.apple.developer.avfoundation.multitasking-camera-access entitlement is also required."
    )
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
      @escaping (Bool) -> Void
  ) {
    // The user tapped the window's own restore button, not `stop()`: match
    // the tile's aspect ratio here too, for the same reason as in `stop()`.
    matchContentSizeToTile()
    // The tile is already on screen. Waiting here is the full-screen
    // letterbox that plays before the move onto the tile.
    completionHandler(true)
  }

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    onChange(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    closeOnForeground = false
    fallbackView.removeFromSuperview()
    updateShouldRender()
    onChange(false)
    if retireCompletion != nil { finishRetirement() }
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("[FISHJAM] Picture-in-picture failed to start: %@", error.localizedDescription)
  }
}

/// What the picture-in-picture window shows after the camera track is gone.
/// Matches the React Native example's "No video" placeholder. A Flutter
/// widget cannot be placed in this view.
private final class PipFallbackView: UIView {
  private let labelView = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    labelView.font = .preferredFont(forTextStyle: .headline)
    labelView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(labelView)
    NSLayoutConstraint.activate([
      labelView.centerXAnchor.constraint(equalTo: centerXAnchor),
      labelView.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    apply(
      label: "No video",
      background: UIColor(red: 0.11, green: 0.16, blue: 0.27, alpha: 1),
      text: .white
    )
  }

  func apply(label: String, background: UIColor, text: UIColor) {
    labelView.text = label
    labelView.textColor = text
    backgroundColor = background
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// Reaches flutter_webrtc's native objects by name, so this plugin does not
/// compile against flutter_webrtc's headers.
private enum FlutterWebRtcLookup {
  private static func plugin() -> NSObject? {
    guard let type = NSClassFromString("FlutterWebRTCPlugin") as? NSObject.Type else { return nil }
    let selector = NSSelectorFromString("sharedSingleton")
    guard type.responds(to: selector) else { return nil }
    return type.perform(selector)?.takeUnretainedValue() as? NSObject
  }

  static func videoTrack(id: String) -> RTCVideoTrack? {
    guard let plugin = plugin() else { return nil }
    let selector = NSSelectorFromString("trackForId:peerConnectionId:")
    guard plugin.responds(to: selector) else { return nil }
    return plugin.perform(selector, with: id, with: nil)?.takeUnretainedValue() as? RTCVideoTrack
  }

  static func captureSession() -> AVCaptureSession? {
    (plugin()?.value(forKey: "videoCapturer") as? RTCCameraVideoCapturer)?.captureSession
  }
}
