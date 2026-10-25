# 架构

规格书 15 章确定原生 SwiftUI 为主、必要处使用 UIKit 桥接；采用分层结构：Presentation、Domain、Data、Infrastructure。M0 仅提供 Presentation 导航骨架，后续按 M1 起逐步加入模型、状态机、本地优先存储、网络与 AI 抽象。第三方 UI 框架不引入。

当前模块：`LexiDawn/LexiDawnApp.swift` 负责入口；`RootTabView.swift` 提供五个主导航入口及占位页面。测试位于 `LexiDawnTests`。
