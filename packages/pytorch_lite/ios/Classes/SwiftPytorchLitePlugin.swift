import Flutter
import UIKit

/// Entry point for the pytorch_lite Flutter plugin on iOS.
/// All inference is handled by ModelApiImpl (ObjC) via Pigeon channels.
public class SwiftPytorchLitePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let api = ModelApiImpl()
    ModelApiSetup(registrar.messenger(), api)
  }
}
