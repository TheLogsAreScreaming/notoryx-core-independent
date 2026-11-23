import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Screens holding secrets (SARNEG code words) keep the window out of
    // screenshots and screen sharing while they're open.
    FlutterMethodChannel(
      name: "notoryx/screen_privacy",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSecure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.sharingType = (call.arguments as? Bool ?? false) ? .none : .readOnly
      result(nil)
    }

    super.awakeFromNib()
  }
}
