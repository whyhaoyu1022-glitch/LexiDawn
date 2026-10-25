# 需求追踪矩阵

原文引文均直接取自 `SPEC.md`；规格理解、代码实现、自动化测试和真实设备验收分别记录。M0-004、M0-005 在规格和现有矩阵中没有可确认的定义，本批次保留为未映射，不猜测含义。

| ID | 规格章节/小节 | 原文短引文 | 类别 | 优先级 | 前置依赖 | 代码/文件 | 验收方法 | 测试/文档 | 状态 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|
| GOV-001 | 0.1 本文档的权威性 | “SPEC.md 是产品行为和架构的权威来源。” | 架构 | P0 | 无 | AGENTS.md, SPEC.md | 逐字核对规则与实现 | 本矩阵 | 已实现待验收 | 当前 commit |
| M0-001 | 15.1、15.2；26 M0 | “使用 SwiftUI 与必要的原生 UIKit 桥接” | 架构/UI | P0 | GOV-001 | LexiDawn/*.swift, LexiDawn.xcodeproj | xcodebuild -list/build，核验 target 与产物 Info.plist | docs/architecture.md, docs/test-plan.md | 进行中 | 新 Actions run |
| M0-002 | 3.1 五个主导航入口 | “采用原生 SwiftUI TabView，主导航固定为五项” | UI | P0 | M0-001 | LexiDawn/RootTabView.swift | UI 测试定位并点击“今日、探索、词汇、复习、我的” | LexiDawnUITests | 已实现待验收 | 新 Actions run |
| M0-003 | 22.3、22.5 | “在 macOS runner 上使用指定 Xcode 构建。” | CI | P0 | M0-001 | .github/workflows/ios-ci.yml | 检查工具链输出、构建和测试步骤 | docs/test-plan.md | 进行中 | 新 Actions run |
| ENG-M0-XCODE | 26 M0 | “bundle identifier、版本号和最低系统版本有明确配置。” | 构建配置 | P0 | M0-001 | project.pbxproj | 核验 build settings 与生成的 Info.plist | docs/architecture.md | 已实现待验收 | 新 Actions run |
| ENG-M0-DESIGN | 16.2、16.4 | “建议使用 4 pt 基础网格” | UI | P1 | M0-001 | DesignTokens.swift, RootTabView.swift | 单元测试与源码审查 | LexiDawnTests | 已实现待验收 | 新 Actions run |
| ENG-M0-TEST | 24.1、25 | “UI 测试：导航、浮窗、详情页、连线题、拼写题、锁定页面和设置保存。” | 测试 | P0 | M0-001, M0-002 | LexiDawnTests, LexiDawnUITests, xcscheme | xcodebuild test 确认 target 实际执行 | docs/test-plan.md | 已实现待验收 | 新 Actions run |
| ENG-M0-CI | 22.3、22.5 | “保存构建日志和测试结果。” | CI | P0 | ENG-M0-XCODE, ENG-M0-TEST | ios-ci.yml | workflow 成功且日志可复核 | STATUS.md, daily log | 进行中 | 新 Actions run |
| M0-004 | 26 M0 | 未在现有规格追踪中找到可确认定义 | 未映射 | — | 待确认 | 不分配代码 | 完整规格检索并记录 | STATUS.md | 阻塞 | 本矩阵 |
| M0-005 | 26 M0 | 未在现有规格追踪中找到可确认定义 | 未映射 | — | 不分配代码 | 完整规格检索并记录 | STATUS.md | 阻塞 | 本矩阵 |
| M1-001 | 19 数据模型设计 | “数据模型设计” | 产品行为/架构 | P0 | M0 | LexiDawn/Domain | 模型与持久化恢复测试 | ROADMAP.md | 未开始 | — |
| M3-001 | 6.2 每个英文单词都可点击 | “每个英文单词都可点击” | 产品行为/UI | P0 | M1 | LexiDawn/Reader | 分词点击命中测试 | docs/test-plan.md | 未开始 | — |
| M5-001 | 10.7 复习评分与排程更新 | “复习评分与排程更新” | 产品行为/测试 | P0 | M1 | LexiDawn/Review | 算法正常/边界测试 | docs/test-plan.md | 未开始 | — |
| M7-001 | 21.1 API Key 与认证 | “API Key 不应直接写入客户端” | 安全/隐私 | P0 | M1 | docs/privacy.md | 仓库和 CI secret 检查 | docs/privacy.md | 未开始 | — |
| M9-001 | 22.2 IPA 安装路径 | “Windows + AltServer/AltStore” | IPA/交付 | P1 | M8 | ios-ci.yml, docs/signing.md | 真实签名安装并记录 | docs/signing.md | 阻塞 | — |
