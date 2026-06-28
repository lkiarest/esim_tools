import CoreTelephony
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "esim_tool/installed_esim_discovery"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerDiscoveryChannel(binaryMessenger: controller.binaryMessenger)
    }
    return ok
  }

  private func registerDiscoveryChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "discoverInstalledEsims" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.discoverInstalledEsims() ?? [
        "supported": true,
        "permissionGranted": true,
        "failureReason": "unknown",
        "note": "iOS eSIM discovery failed unexpectedly.",
        "profiles": []
      ])
    }
  }

  private func discoverInstalledEsims() -> [String: Any?] {
    let networkInfo = CTTelephonyNetworkInfo()
    var profiles: [[String: Any?]] = []

    if #available(iOS 12.0, *) {
      let providers = networkInfo.serviceSubscriberCellularProviders ?? [:]
      let dataServiceIdentifier = networkInfo.dataServiceIdentifier
      for (serviceIdentifier, carrier) in providers {
        profiles.append(carrierMap(
          carrier: carrier,
          serviceIdentifier: serviceIdentifier,
          isActive: serviceIdentifier == dataServiceIdentifier
        ))
      }
    } else if let carrier = networkInfo.subscriberCellularProvider {
      profiles.append(carrierMap(carrier: carrier, serviceIdentifier: nil, isActive: true))
    }

    let note: String
    let failureReason: String?
    if profiles.isEmpty {
      note = "iOS 不开放完整已安装 eSIM 列表给普通 App。当前也没有读取到蜂窝运营商信息，请手动添加。"
      failureReason = "platformRestricted"
    } else {
      note = "iOS 只能返回有限蜂窝运营商信息，不能确认是否为 eSIM，也不能列出已停用套餐；请导入后人工确认。"
      failureReason = nil
    }

    return [
      "supported": true,
      "permissionGranted": true,
      "failureReason": failureReason,
      "note": note,
      "profiles": profiles
    ]
  }

  private func carrierMap(carrier: CTCarrier, serviceIdentifier: String?, isActive: Bool) -> [String: Any?] {
    return [
      "carrierName": carrier.carrierName,
      "displayName": carrier.carrierName,
      "countryIso": carrier.isoCountryCode,
      "mobileCountryCode": carrier.mobileCountryCode,
      "mobileNetworkCode": carrier.mobileNetworkCode,
      "phoneNumber": nil,
      "iccid": nil,
      "systemIdentifier": serviceIdentifier.map { "ios-service-\($0)" },
      "isEmbedded": nil,
      "isActive": isActive,
      "platform": "ios",
      "confidence": "low",
      "serviceIdentifier": serviceIdentifier
    ]
  }
}
