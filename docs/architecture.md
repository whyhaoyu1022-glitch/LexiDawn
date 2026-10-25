# 架构

依据 SPEC.md §15.1–15.4，项目采用原生 SwiftUI，必要时使用 UIKit 桥接；不引入第三方 UI 框架。M0 的边界是可构建的应用 target、五入口导航和基础 DesignSystem。业务模型、存储、网络和 AI 仍留在后续里程碑。

- `LexiDawn/LexiDawnApp.swift`：应用入口。
- `LexiDawn/RootTabView.swift`：固定五入口导航与占位页面。
- `LexiDawn/DesignSystem/DesignTokens.swift`：颜色、状态色和 4 pt 间距 token。
- `LexiDawnTests`：M0 单元测试。
- `LexiDawnUITests`：应用启动和五入口可操作性测试。
- `LexiDawn.xcodeproj`：应用、单元测试、UI 测试 target 及共享 scheme。

应用 target 使用 `GENERATE_INFOPLIST_FILE=YES`，bundle identifier 为 `com.lexidawn.app`，版本为 `0.1.0 (1)`，最低系统版本配置为审核提案中的 iOS 27.0。最终可用性由 Actions 上实际 Xcode/SDK 输出决定。
