import AVFoundation
import Accelerate
import UIKit
import WebRTC

/// Draws WebRTC frames into an `AVSampleBufferDisplayLayer`, the only kind
/// of content an `AVPictureInPictureVideoCallViewController` keeps updating
/// while the app is in the background.
final class SampleBufferVideoCallView: UIView, RTCVideoRenderer {
  override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

  var sampleBufferLayer: AVSampleBufferDisplayLayer {
    layer as! AVSampleBufferDisplayLayer
  }

  /// Read on the WebRTC render thread. The picture-in-picture controller
  /// turns this on while the window is open, and also while automatic start
  /// is on, because iOS will not start an empty layer.
  var shouldRender = false

  private let converter = I420Converter()
  private var currentRotation = -1

  func requestScaleRecalculation() {
    currentRotation = -1
  }

  func setSize(_ size: CGSize) {}

  func renderFrame(_ frame: RTCVideoFrame?) {
    guard shouldRender, let frame, let sampleBuffer = makeSampleBuffer(frame) else {
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.shouldRender else { return }
      self.recalculateScale(rotation: frame.rotation.rawValue)
      self.enqueue(sampleBuffer)
    }
  }

  private func enqueue(_ sampleBuffer: CMSampleBuffer) {
    if #available(iOS 17.0, *) {
      let renderer = sampleBufferLayer.sampleBufferRenderer
      if renderer.requiresFlushToResumeDecoding { renderer.flush() }
      guard renderer.isReadyForMoreMediaData else { return }
      renderer.enqueue(sampleBuffer)
    } else {
      let renderer = sampleBufferLayer
      if renderer.requiresFlushToResumeDecoding { renderer.flush() }
      guard renderer.isReadyForMoreMediaData else { return }
      renderer.enqueue(sampleBuffer)
    }
  }

  private func recalculateScale(rotation: Int) {
    guard currentRotation != rotation else { return }
    currentRotation = rotation
    var scale: CGFloat = 1
    if (rotation == 90 || rotation == 270) && bounds.width > 0 {
      scale = bounds.height / bounds.width
    }
    sampleBufferLayer.transform = CATransform3DConcat(
      CATransform3DMakeRotation(CGFloat(rotation) / 180 * .pi, 0, 0, 1),
      CATransform3DMakeScale(scale, scale, 1)
    )
  }

  private func makeSampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
    guard let pixelBuffer = pixelBuffer(from: frame) else { return nil }
    var format: CMVideoFormatDescription?
    guard
      CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &format
      ) == noErr, let format
    else { return nil }

    // RTCVideoFrame timestamps use a 90 kHz clock.
    let time = CMTime(value: CMTimeValue(frame.timeStamp), timescale: 90_000)
    var timing = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: time,
      decodeTimeStamp: time
    )
    var sampleBuffer: CMSampleBuffer?
    guard
      CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: format,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
      ) == noErr, let sampleBuffer
    else { return nil }

    if let attachments = CMSampleBufferGetSampleAttachmentsArray(
      sampleBuffer,
      createIfNecessary: true
    ), CFArrayGetCount(attachments) > 0 {
      let dictionary = unsafeBitCast(
        CFArrayGetValueAtIndex(attachments, 0),
        to: CFMutableDictionary.self
      )
      CFDictionarySetValue(
        dictionary,
        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
      )
    }
    return sampleBuffer
  }

  private func pixelBuffer(from frame: RTCVideoFrame) -> CVPixelBuffer? {
    if let buffer = frame.buffer as? RTCCVPixelBuffer {
      return buffer.pixelBuffer
    }
    return converter.convert(frame.buffer.toI420())
  }
}

/// Converts I420 frames (e.g. from software decoders) to BGRA pixel buffers.
private final class I420Converter {
  private var conversion = vImage_YpCbCrToARGB()
  private let prepared: Bool
  private var pool: CVPixelBufferPool?
  private var poolWidth = 0
  private var poolHeight = 0

  init() {
    // I420 uses the limited (video) range.
    var range = vImage_YpCbCrPixelRange(
      Yp_bias: 16,
      CbCr_bias: 128,
      YpRangeMax: 235,
      CbCrRangeMax: 240,
      YpMax: 255,
      YpMin: 0,
      CbCrMax: 255,
      CbCrMin: 0
    )
    prepared =
      vImageConvert_YpCbCrToARGB_GenerateConversion(
        kvImage_YpCbCrToARGBMatrix_ITU_R_601_4,
        &range,
        &conversion,
        kvImage420Yp8_Cb8_Cr8,
        kvImageARGB8888,
        vImage_Flags(kvImageNoFlags)
      ) == kvImageNoError
  }

  func convert(_ buffer: RTCI420BufferProtocol) -> CVPixelBuffer? {
    guard prepared else { return nil }
    let width = Int(buffer.width)
    let height = Int(buffer.height)
    if pool == nil || poolWidth != width || poolHeight != height {
      createPool(width: width, height: height)
    }
    guard let pool else { return nil }

    var output: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &output) == kCVReturnSuccess,
      let output
    else { return nil }

    CVPixelBufferLockBaseAddress(output, [])
    defer { CVPixelBufferUnlockBaseAddress(output, []) }

    var yPlane = vImage_Buffer(
      data: UnsafeMutableRawPointer(mutating: buffer.dataY),
      height: vImagePixelCount(height),
      width: vImagePixelCount(width),
      rowBytes: Int(buffer.strideY)
    )
    var uPlane = vImage_Buffer(
      data: UnsafeMutableRawPointer(mutating: buffer.dataU),
      height: vImagePixelCount(buffer.chromaHeight),
      width: vImagePixelCount(buffer.chromaWidth),
      rowBytes: Int(buffer.strideU)
    )
    var vPlane = vImage_Buffer(
      data: UnsafeMutableRawPointer(mutating: buffer.dataV),
      height: vImagePixelCount(buffer.chromaHeight),
      width: vImagePixelCount(buffer.chromaWidth),
      rowBytes: Int(buffer.strideV)
    )
    var destination = vImage_Buffer(
      data: CVPixelBufferGetBaseAddress(output),
      height: vImagePixelCount(height),
      width: vImagePixelCount(width),
      rowBytes: CVPixelBufferGetBytesPerRow(output)
    )
    let bgra: [UInt8] = [3, 2, 1, 0]
    let error = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(
      &yPlane,
      &uPlane,
      &vPlane,
      &destination,
      &conversion,
      bgra,
      255,
      vImage_Flags(kvImageNoFlags)
    )
    return error == kvImageNoError ? output : nil
  }

  private func createPool(width: Int, height: Int) {
    poolWidth = width
    poolHeight = height
    let attributes: [CFString: Any] = [
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey: width,
      kCVPixelBufferHeightKey: height,
      kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any],
    ]
    pool = nil
    CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
  }
}
