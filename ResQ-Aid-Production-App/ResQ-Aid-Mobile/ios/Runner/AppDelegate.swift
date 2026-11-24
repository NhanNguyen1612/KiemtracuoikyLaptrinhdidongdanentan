import CoreGraphics
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UIDevice.current.isBatteryMonitoringEnabled = true
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "vn.edu.vku.resq_aid/device_health",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "decodeImageToRgb":
        guard
          let args = call.arguments as? [String: Any],
          let rawData = args["bytes"] as? FlutterStandardTypedData
        else {
          result(nil)
          return
        }
        let targetSize = (args["targetSize"] as? Int) ?? 48
        let roiLeft = args["roiLeft"] as? Double
        let roiTop = args["roiTop"] as? Double
        let roiRight = args["roiRight"] as? Double
        let roiBottom = args["roiBottom"] as? Double

        DispatchQueue.global(qos: .userInitiated).async {
          let rgb = Self.decodeCpuRgbPatch(
            data: rawData.data,
            targetSize: targetSize,
            roiLeft: roiLeft,
            roiTop: roiTop,
            roiRight: roiRight,
            roiBottom: roiBottom
          )
          DispatchQueue.main.async {
            if let rgb = rgb {
              result(FlutterStandardTypedData(bytes: rgb))
            } else {
              result(nil)
            }
          }
        }

      case "getBatteryTemperature":
        let thermal = ProcessInfo.processInfo.thermalState
        let estimatedTemp: Double
        switch thermal {
        case .nominal: estimatedTemp = 35.5
        case .fair: estimatedTemp = 38.5
        case .serious: estimatedTemp = 42.0
        case .critical: estimatedTemp = 45.5
        @unknown default: estimatedTemp = 36.5
        }
        result(estimatedTemp)

      case "getMemoryInfo":
        let totalRamMb = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        let availRamMb = Int(Double(totalRamMb) * 0.45)
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let recommended = totalRamMb >= 5500
          ? "Qwen2.5-1.5B-Instruct-Q4_K_M"
          : "Qwen2.5-0.5B-Instruct-Q4_K_M"
        result([
          "totalRamMb": totalRamMb,
          "availRamMb": availRamMb,
          "lowMemory": ProcessInfo.processInfo.isLowPowerModeEnabled,
          "cpuCores": cores,
          "recommendedModel": recommended,
        ])

      case "setKeepScreenOn":
        let args = call.arguments as? [String: Any]
        let enabled = (args?["enabled"] as? Bool) ?? false
        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
        result(enabled)

      case "getSpeechCapabilities":
        var supportsOnDevice = false
        if #available(iOS 13.0, *) {
          let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
          supportsOnDevice = recognizer?.supportsOnDeviceRecognition ?? false
        }
        let available = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))?.isAvailable ?? true
        result([
          "recognitionAvailable": available,
          "onDeviceRecognitionAvailable": supportsOnDevice,
          "sdkInt": 17,
        ])

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func decodeCpuRgbPatch(
    data: Data,
    targetSize: Int,
    roiLeft: Double?,
    roiTop: Double?,
    roiRight: Double?,
    roiBottom: Double?
  ) -> Data? {
    guard let uiImage = UIImage(data: data) else { return nil }
    let imgW = uiImage.size.width
    let imgH = uiImage.size.height
    if imgW <= 0 || imgH <= 0 { return nil }

    let l = roiLeft ?? 0.0
    let t = roiTop ?? 0.0
    let r = roiRight ?? 1.0
    let b = roiBottom ?? 1.0
    let spanW = max(0.05, r - l)
    let spanH = max(0.05, b - t)

    var rgba = [UInt8](repeating: 0, count: targetSize * targetSize * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
      data: &rgba,
      width: targetSize,
      height: targetSize,
      bitsPerComponent: 8,
      bytesPerRow: targetSize * 4,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .medium
    UIGraphicsPushContext(ctx)
    ctx.translateBy(x: 0, y: CGFloat(targetSize))
    ctx.scaleBy(x: 1.0, y: -1.0)

    let scaleX = CGFloat(Double(targetSize) / spanW)
    let scaleY = CGFloat(Double(targetSize) / spanH)
    let drawRect = CGRect(
      x: -CGFloat(l) * scaleX,
      y: -CGFloat(t) * scaleY,
      width: scaleX,
      height: scaleY
    )
    uiImage.draw(in: drawRect)
    UIGraphicsPopContext()

    var rgb = Data(count: targetSize * targetSize * 3)
    rgb.withUnsafeMutableBytes { rawOut in
      guard let outPtr = rawOut.bindMemory(to: UInt8.self).baseAddress else { return }
      var outIdx = 0
      for i in 0..<(targetSize * targetSize) {
        let base = i * 4
        outPtr[outIdx] = rgba[base]
        outPtr[outIdx + 1] = rgba[base + 1]
        outPtr[outIdx + 2] = rgba[base + 2]
        outIdx += 3
      }
    }
    return rgb
  }
}
