# 技术决策记录

## ADR-001 原生 SwiftUI
- 日期：2026-10-25
- 依据：SPEC.md §15.1、§15.3
- 决策：采用 SwiftUI，必要时以 UIKit 桥接。
- 影响：保持系统组件与无障碍能力；M0 不引入第三方 UI 框架。

## ADR-002 macOS runner 负责 iOS 验证
- 日期：2026-10-25
- 依据：SPEC.md §22
- 决策：Actions 检测实际 Xcode/SDK 后构建测试；本地 Windows/容器不声称完成 iOS 验证。
- 备选：本地模拟器（当前不可用）。
