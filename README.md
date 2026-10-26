# 词光 LexiDawn

个人使用的原生 iOS 英语阅读、词典与间隔复习应用。产品行为以 [SPEC.md](SPEC.md) 为准，当前仍处于 M0 验收阶段。

## 开发环境

工程使用 SwiftUI 和原生 Xcode 项目，不引入第三方 UI 框架。应用 target 的 bundle identifier 是 `com.lexidawn.app`，版本为 `0.1.0 (1)`，常规 Debug/Release 产品配置的最低系统版本为 iOS 27.0。CI 使用独立的 `CI` build configuration 和已批准的 iOS 26.5 兼容目标，并输出实际 Xcode、SDK 和 Swift 版本；兼容构建不替代 iOS 27.0 规格验收。

## 构建与测试

```sh
xcodebuild -list -project LexiDawn.xcodeproj
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 会自动选择可用的具体 iOS Simulator，使用 `-destination id=<具体设备>` 执行单元测试和 UI 测试。当前开发容器没有 Xcode，不能把本地命令结果写成 iOS 验收证据。

## 交付边界

模拟器/未签名构建与可安装签名 IPA 分开记录。Windows + AltServer/AltStore 路径和免费 Apple ID 限制见 [docs/signing.md](docs/signing.md)。
