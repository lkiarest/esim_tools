# iOS App Store Release Checklist

最后更新：2026-06-28

这份清单按“仓库内已完成 / 仍需人工完成”拆分，方便发布到 App Store Connect 前逐项核对。

## 已在仓库内完成

- iOS 端相机权限说明已配置：
  - `NSCameraUsageDescription`
- 导出合规免重复确认已配置：
  - `ITSAppUsesNonExemptEncryption = false`
- iOS Pod 依赖已能本地安装并完成模拟器构建
- App Store 准备文档已补齐：
  - `docs/privacy-policy.md`
  - `docs/ios-app-store-release-checklist.md`
  - `docs/ios-app-store-connect-template.md`

## 发布前仍需人工完成

### 1. Apple 账号与签名

- 在 Apple Developer 中确认付费开发者账号可用
- 在 Xcode `Signing & Capabilities` 中为 `Runner` 选择正确的 `Team`
- 确认 Bundle ID 可注册且未与别的 App 冲突
- 为 `Release` 配置有效的 iOS Distribution signing

当前工程里的主 Bundle ID 是：

- `com.qintx.esimTool`

### 2. App Store Connect 元数据

- App 名称
- 副标题
- 关键词
- 描述
- 隐私政策 URL
- 支持 URL
- App Review 联系人信息
- 年龄分级问卷
- 价格与销售范围

可先用：

- `docs/ios-app-store-connect-template.md`

### 3. App Privacy 填写

这一步不能直接填“无数据收集”。

原因：

- `mobile_scanner` 的 iOS 依赖链会引入 `MLKitBarcodeScanning` / `MLKitCommon`
- 这些 SDK 自带的 `PrivacyInfo.xcprivacy` 声明了若干可能收集的数据类型
- `GoogleDataTransport` 也声明了 `Other Diagnostic Data` 用于 `Analytics`

仓库中可见的相关文件：

- `ios/Pods/MLKitBarcodeScanning/Frameworks/MLKitBarcodeScanning.framework/PrivacyInfo.xcprivacy`
- `ios/Pods/MLKitCommon/Frameworks/MLKitCommon.framework/PrivacyInfo.xcprivacy`
- `ios/Pods/GoogleDataTransport/GoogleDataTransport/Resources/PrivacyInfo.xcprivacy`

我已经把一个“待人工确认后填写”的草稿整理到：

- `docs/ios-app-store-connect-template.md`

建议你在正式提交前再做一次法务/产品确认，重点确认：

- 是否接受保留扫码能力并按 SDK 清单填写隐私标签
- 如果不接受这些隐私标签，是否改为不依赖当前 `mobile_scanner / ML Kit` 方案

### 4. 隐私政策落地为可访问 URL

App Store Connect 需要公开可访问的隐私政策地址。

仓库里已经准备好文案：

- `docs/privacy-policy.md`

你还需要把它发布到一个公网 URL，例如：

- GitHub Pages
- 你自己的官网
- Notion 公开页

### 5. 截图与商店素材

- iPhone 6.7" 截图
- iPhone 6.5" 或 6.1" 截图
- 如支持 iPad，再补 iPad 截图
- 检查 App Icon、启动图、商店文案是否一致

仓库里已有可参考的界面截图源文件：

- `esim_imgs/`

### 6. 真机 Release 验证

模拟器构建通过不等于可上架。

建议至少验证：

- 真机安装 `Release` 包可正常启动
- 相机扫码权限弹窗正常
- 本地通知权限与提醒正常
- JSON 导入导出正常
- 不联网情况下核心功能正常

## 建议发布命令

在签名配置完成后，可用 Flutter 打出 iOS 归档：

```bash
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

如果你沿用本机的 CocoaPods 用户安装路径，推荐先带上 UTF-8 环境：

```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

## 官方文档

- App Store Review Guidelines:
  - https://developer.apple.com/app-store/review/guidelines/
- App Store Connect required properties:
  - https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties
- App privacy:
  - https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Export compliance:
  - https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
