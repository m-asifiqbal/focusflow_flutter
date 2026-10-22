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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboardPlugin") {
      SecureClipboardPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LauncherShortcutsPlugin") {
      LauncherShortcutsPlugin.register(with: registrar)
    }
  }
}

/// `focusflow/shortcuts` (Dart: core/platform/launcher_shortcuts.dart) — the
/// Home Screen quick actions of the app icon (Info.plist ›
/// UIApplicationShortcutItems; the item *type* is the shortcut key).
/// The one that cold-started the app arrives in the scene's connection
/// options and is parked until Dart asks (`getInitial`); later ones are
/// pushed as `onShortcut`. Android implements the same channel in
/// MainActivity.kt.
final class LauncherShortcutsPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?
  private var pending: String?
  private var listening = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LauncherShortcutsPlugin()
    let channel = FlutterMethodChannel(
      name: "focusflow/shortcuts",
      binaryMessenger: registrar.messenger()
    )
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitial":
      // Dart is listening from now on: later shortcuts are pushed.
      listening = true
      result(pending)
      pending = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func deliver(_ type: String) {
    if listening, let channel = channel {
      channel.invokeMethod("onShortcut", arguments: type)
    } else {
      pending = type
    }
  }

  // Cold start: the chosen shortcut is in the connection options. Not
  // claimed as handled, so Flutter's own connection work (deep links, state
  // restoration) still runs.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let item = connectionOptions?.shortcutItem { deliver(item.type) }
    return false
  }

  // The app was already running (or suspended).
  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    deliver(shortcutItem.type)
    completionHandler(true)
    return true
  }
}

/// `focusflow/secure_clipboard` (Dart: core/crypto/secure_clipboard.dart).
/// Copied vault secrets are local-only (never synced to other devices via
/// Universal Clipboard) and expire on their own; "clear" only wipes the
/// pasteboard if it still holds what the vault copied (unchanged
/// changeCount), so a newer copy by the user is never erased.
final class SecureClipboardPlugin: NSObject, FlutterPlugin {
  private var lastChangeCount: Int?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "focusflow/secure_clipboard",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(SecureClipboardPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let pasteboard = UIPasteboard.general
    switch call.method {
    case "setSensitive":
      let text = args?["text"] as? String ?? ""
      var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: true]
      if let ms = args?["expiresInMs"] as? Int, ms > 0 {
        options[.expirationDate] = Date().addingTimeInterval(Double(ms) / 1000)
      }
      pasteboard.setItems([["public.utf8-plain-text": text]], options: options)
      lastChangeCount = pasteboard.changeCount
      result(nil)
    case "clear":
      let unconditional = (args?["sha256"] as? String) == nil
      if unconditional || pasteboard.changeCount == lastChangeCount {
        pasteboard.items = []
        lastChangeCount = nil
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
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
