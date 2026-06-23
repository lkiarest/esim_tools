# eSIM Tool

一个用于管理 eSIM / SIM 信息的 Flutter Android 工具应用。

## 本地验证

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release APK 输出位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

当前 release 构建使用 Android debug signing config，适合个人测试和临时安装，不适合作为正式上架签名包。

## 整表导入 / 导出

首页右上角「导入导出」入口支持：

- 查看/复制整表 JSON 字符串，适合复制到编辑器里快速批量修改。
- 从 JSON 字符串导入，导入后会替换当前整个 eSIM 列表。
- 导出 JSON 文件，通过 Android 文件保存器生成 `.json` 文件。
- 导入 JSON 文件，通过 Android 文件选择器读取 `.json` 文件后替换整个列表。

导出的 JSON 顶层格式为：

```json
{
  "schema": "esim_tool_profiles_v1",
  "exportedAt": "2026-06-23T00:00:00.000Z",
  "profiles": []
}
```

导入时也支持直接粘贴 `profiles` 数组。

## 发布 APK 到 GitHub Release

仓库已配置 GitHub Actions：

- 推送 `v*` tag 时自动构建 APK 并上传到对应 Release。
- 也可以在 GitHub Actions 页面手动运行 `Build Android APK Release`，可选填写 release tag。

本地也可以用脚本一键构建并上传：

```bash
scripts/build_release.sh
# 或指定 tag
scripts/build_release.sh v1.0.0-20260623
```

上传后可在这里下载：

```text
https://github.com/lkiarest/esim_tools/releases
```
