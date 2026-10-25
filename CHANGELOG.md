# 变更记录

## 未发布 · 2026-10-25

- 修复 Xcode 工程中的 DesignTokens 源文件路径，恢复应用 target 构建。
- 修复 CI 测试没有具体模拟器 destination 的问题，动态选择并启动可用 iOS Simulator。
- 按用户批准将 CI 兼容目标固定为 iOS 26.5；产品工程目标仍记录为 iOS 27.0。
- 修复 Xcode 工程的源码、框架和资源构建阶段，加入应用、单元测试和 UI 测试 target 及共享 scheme。
- 配置自动生成 Info.plist、bundle identifier、版本号和最低系统版本。
- 将主导航修正为“今日、探索、词汇、复习、我的”。
- 建立第一版 SwiftUI DesignSystem token 与实际 UI 引用。
- 加入间距 token 单元测试和五入口导航 UI 测试。
