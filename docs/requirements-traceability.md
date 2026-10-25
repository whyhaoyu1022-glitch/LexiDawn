# 需求追踪矩阵

原文引文均直接取自 `SPEC.md`；本矩阵区分规格理解、实现、测试和真机验收。

| ID | 规格章节/小节 | 原文短引文 | 类别 | 优先级 | 前置依赖 | 代码/文件 | 验收方法 | 测试/文档 | 状态 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|
| GOV-001 | 0.1 本文档的权威性 | “SPEC.md 是产品行为和架构的权威来源。” | 架构 | P0 | 无 | AGENTS.md, SPEC.md | 逐字核对仓库文件与规则 | docs/requirements-traceability.md | 已实现待验收 |
| M0-001 | 15.1 技术选型 | “使用 SwiftUI 与必要的原生 UIKit 桥接” | 架构/UI | P0 | GOV-001 | LexiDawn/*.swift | macOS runner 构建并检查源码 | docs/architecture.md | 进行中 |
| M0-002 | 3.1 五个主导航入口 | “五个主导航入口” | UI | P0 | M0-001 | LexiDawn/RootTabView.swift | XCTest/UI test 检查五个 tab | docs/test-plan.md | 已实现待验收 |
| M0-003 | 22.5 建议工作流 | “在 macOS runner 上执行” | CI | P0 | 无 | .github/workflows/ios-ci.yml | Actions 输出 Xcode/SDK 版本并构建 | STATUS.md | 已实现待验收 |
| M1-001 | 19. 数据模型设计 | “数据模型设计” | 产品行为/架构 | P0 | M0-001 | LexiDawn/Domain | 模型编码与持久化恢复测试 | ROADMAP.md | 未开始 |
| M3-001 | 6.2 每个英文单词都可点击 | “每个英文单词都可点击” | 产品行为/UI | P0 | M1-001 | LexiDawn/Reader | 分词点击命中测试 | docs/test-plan.md | 未开始 |
| M5-001 | 10.7 复习评分与排程更新 | “复习评分与排程更新” | 产品行为/测试 | P0 | M1-001 | LexiDawn/Review | 算法正常/边界测试 | docs/test-plan.md | 未开始 |
| M7-001 | 21.1 API Key 与认证 | “API Key 不应直接写入客户端” | 安全/隐私 | P0 | M1-001 | docs/privacy.md | 扫描仓库和 CI secret 检查 | docs/privacy.md | 未开始 |
| M9-001 | 22.2 推荐的 IPA 安装路径 | “Windows + AltServer/AltStore” | IPA/交付 | P1 | M8-001 | .github/workflows/ios-ci.yml, docs/signing.md | 真实签名安装并记录结果 | docs/signing.md | 阻塞 |
