import Flutter
import UIKit
import Vision
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Show reminders while the app is in the foreground and route taps /
    // actions (Done, Snooze) to flutter_local_notifications.
    UNUserNotificationCenter.current().delegate = self

    // Background work (auto backup to Drive, trash purge) — identifiers are
    // listed in Info.plist › BGTaskSchedulerPermittedIdentifiers and
    // scheduled from Dart (core/sync/background_tasks.dart).
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "com.iqballab.focusflow.backup")
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.iqballab.focusflow.maintenance",
      frequency: NSNumber(value: 12 * 60 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Background isolates (notification actions, workmanager tasks) need the
    // plugins registered too.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TextScannerPlugin") {
      TextScannerPlugin.register(with: registrar)
    }
  }
}

/// `focusflow/text_scanner` — on-device OCR for Quick Scan with Apple Vision
/// (no extra SDK, works offline). Android implements the same channel with
/// ML Kit in MainActivity.kt.
final class TextScannerPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "focusflow/text_scanner",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(TextScannerPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeText" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let image = UIImage(contentsOfFile: path),
      let cgImage = image.cgImage
    else {
      result(FlutterError(code: "bad_path", message: "Image not found", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
        }
        return
      }
      let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
      DispatchQueue.main.async { result(lines.joined(separator: "\n")) }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
