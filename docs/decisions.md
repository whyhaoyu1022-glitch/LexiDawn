# 技术决策记录

## ADR-001 原生 SwiftUI
- 日期：2026-10-25
- 依据：SPEC.md §15.1、§15.3
- 决策：采用 SwiftUI，必要时以 UIKit 桥接。
- 影响：保持系统组件与无障碍能力；不引入第三方 UI 框架。

## ADR-002 macOS runner 负责 iOS 验证
- 日期：2026-10-25
- 依据：SPEC.md §22
- 决策：Actions 检测实际 Xcode/SDK 后构建测试；本地 Windows/容器不声称完成 iOS 验证。

## ADR-003 M0 工程配置采用规格提案值
- 日期：2026-10-25
- 依据：本日计划、SPEC.md §15.2、§26 M0
- 决策：暂以 `com.lexidawn.app`、`0.1.0 (1)`、iOS 27.0 配置工程；Xcode 27/SDK 可用性由 Actions 实测决定，旧工具链通过不能替代规格验收。
- Apple 依据：Apple 的 [Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference) 说明 `GENERATE_INFOPLIST_FILE` 会让构建系统根据 build settings 生成并合并信息属性列表内容；本工程采用该设置，最终行为仍以 Actions 实测为准。
