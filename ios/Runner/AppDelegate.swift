import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "ShopHopDeviceSettings") {
      let channel = FlutterMethodChannel(name: "shophop/device_settings", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "appInfo" {
          result(["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                  "build_number": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
