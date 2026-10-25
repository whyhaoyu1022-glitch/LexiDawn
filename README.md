# 词光 LexiDawn

个人使用的原生 iOS 英语阅读、词典与间隔复习应用。产品行为以 [SPEC.md](SPEC.md) 为准，当前处于 M0 初始化。

## 开发与验证

M0 使用 SwiftUI；GitHub Actions 在 `macos-latest` 检测 Xcode/SDK 并执行包清单检查。当前开发容器没有 Xcode，因此不能声称本地完成 iOS 构建、模拟器或真机测试。详见 [docs/test-plan.md](docs/test-plan.md)。

## 交付边界

模拟器/未签名构建与可安装签名 IPA 分开记录。Windows + AltServer/AltStore 路径和免费 Apple ID 限制见 [docs/signing.md](docs/signing.md)。
