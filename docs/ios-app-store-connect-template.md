# iOS App Store Connect Template

最后更新：2026-06-28

这是一份可直接复制到 App Store Connect 的填写草稿。带 `TODO` 的内容需要你最后确认。

## 基础信息

- App 名称：ESIM 管家
- 副标题：管理旅行卡、流量卡与待安装 eSIM
- 主类别：`TODO`
- 次类别：`TODO`
- Bundle ID：`com.qintx.esimTool`

## 关键词

```text
eSIM,SIM,流量卡,旅行卡,保号,二维码,激活码
```

## 描述

```text
ESIM 管家是一款面向个人用户的本地 eSIM / SIM 管理工具，适合整理旅行卡、流量卡、保号卡和待安装 eSIM 信息。

你可以用它记录名称、运营商、国家或地区、号码、ICCID、状态和备注，也可以保存运营商提供的 LPA 激活码，并在需要时重新展示二维码。

主要功能：
• 管理已安装与待安装的 SIM / eSIM
• 扫描或手动录入 LPA 激活码
• 记录保号消费日期并设置本地提醒
• 导入 / 导出 JSON 备份
• 敏感字段使用本地安全存储保存

隐私说明：
• 数据默认保存在本机
• 不要求注册账号
• 不提供云同步
• 删除应用内记录不会删除系统中已安装的 eSIM

注意：
iOS 对普通 App 可开放的蜂窝信息有限，部分号码、ICCID 或停用套餐信息可能无法直接读取，重要信息建议手动补充。
```

## Promotional Text

```text
本地管理你的 eSIM、旅行卡和保号提醒，支持扫描 LPA 激活码与 JSON 备份。
```

## What's New

```text
首个 iOS 版本发布，支持 eSIM 信息管理、LPA 激活码扫描、本地提醒与 JSON 备份。
```

## Support URL

- `TODO`

## Marketing URL

- 可留空，或填写 `TODO`

## Privacy Policy URL

- `TODO`
- 文案草稿见：`docs/privacy-policy.md`

## App Review Notes

```text
本应用用于本地管理用户自己的 SIM / eSIM 资料，不提供账号系统，也不提供运营商充值、开卡或购买服务。

iOS 端相机权限仅用于扫描用户主动提供的 eSIM 二维码（LPA 激活码）。
本地通知仅用于保号提醒。

iOS 对普通 App 的蜂窝信息访问有限，因此自动发现功能可能只能读取部分运营商信息，属于平台限制。
```

## App Privacy 草稿

下面内容是根据当前代码和已集成 iOS SDK 的 `PrivacyInfo.xcprivacy` 推导出的“待确认草稿”，提交前请人工复核。

### 代码层面可确认的事实

- 应用主数据保存在本机
- 敏感字段保存在本地安全存储
- 没有自建账号系统
- 没有自建服务端上传逻辑
- 没有接入广告、登录、支付、统计 SDK

### 需要特别注意的 SDK 声明

`mobile_scanner` 的 iOS 依赖链包含：

- `MLKitBarcodeScanning`
- `MLKitCommon`
- `GoogleDataTransport`

这些 SDK 的隐私清单声明了下列“可能收集”项：

- Device ID
- Other Data Types
- Other Diagnostic Data
- Other User Content
- Performance Data
- Product Interaction

其中多项标记为：

- `Linked = false`
- `Tracking = false`

### 建议的处理方式

你需要在 App Store Connect 中二选一：

1. 保守填写

- 按 SDK 隐私清单把这些数据类型如实录入
- 标注为不用于跟踪
- 标注为不与用户身份关联

2. 更激进地优化隐私标签

- 替换当前扫码实现
- 避免依赖这条 ML Kit / GoogleDataTransport 链
- 重新生成 Pods 后再复核隐私清单

如果你希望尽快上架，建议先走第 1 条。

## 年龄分级

建议初始按低风险填写，但仍需在 App Store Connect 中人工答题确认：

- 无暴力
- 无赌博
- 无成人内容
- 无用户生成公开社区
- 无网页登录

## 截图建议

- 6.7"：首页列表、添加入口、导入导出、自动发现
- 6.5" / 6.1"：至少再补 3-4 张

仓库现有参考图：

- `esim_imgs/1.png`
- `esim_imgs/2.png`
- `esim_imgs/3.png`
- `esim_imgs/4.png`
