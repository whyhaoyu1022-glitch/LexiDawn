# 需求追踪矩阵

原文引文均直接取自 `SPEC.md`；状态只在有代码或测试证据时标记。CI 和真实设备结果与本地静态检查分开记录。

| ID | 规格章节/小节 | 原文短引文 | 类别 | 优先级 | 代码/文件 | 验收方法 | 测试/证据 | 状态 |
|---|---|---|---|---|---|---|---|---|
| GOV-001 | 0.1 | “SPEC.md 是产品行为和架构的权威来源。” | 架构 | P0 | SPEC.md, AGENTS.md | 规格与实现审查 | 本矩阵 | 已实现待验收 |
| M0-001 | 15.1、15.2；26 M0 | “使用 SwiftUI 与必要的原生 UIKit 桥接” | 架构/UI | P0 | LexiDawn/*.swift, project.pbxproj | xcodebuild -list/build | 旧 Actions 构建通过；新 Actions 未确认 | 进行中 |
| M0-002 | 3.1 | “主导航固定为五项” | UI | P0 | RootTabView.swift | XCUITest 五入口切换 | `testFivePrimaryTabsAreVisibleAndSelectable` | 已实现待 CI |
| M0-003 | 22.3、22.5 | “在 macOS runner 上使用指定 Xcode 构建。” | CI | P0 | .github/workflows/ios-ci.yml、CI build configuration | CI 配置、showdestinations、concrete simulator、build/test | run 40337877307 构建通过但目的地选择失败；专用 CI configuration 已加入，后续 Actions 待确认 | 进行中 |
| M1-001 | 2.1–2.6、19.3、26 M1 | “未完成任务必须保存在本地数据库” | 领域/数据 | P0 | Domain/DailyTasks/DailyTasks.swift, Data/PersistenceModels.swift | 状态迁移、完成判断、恢复查询 | 状态机与周期测试 | 已实现待 CI |
| M1-002 | 19.1、19.9、19.10 | “本地优先，保存 UTC 时间戳和明确的本地日期/时区字段” | 持久化 | P0 | Data/PersistenceModels.swift, Data/Repositories.swift | SwiftData 创建、更新、重建 Repository | `testSwiftDataCycleAndPreferencesSurviveRepositoryRebuild` | 已实现待 CI |
| M1-003 | 2.2、2.3、24.2 | “旧任务优先，未完成不覆盖” | 业务规则 | P0 | DailyCycleService | 同日幂等、跨日保留、carry-over 幂等 | 周期与时区测试 | 已实现待 CI |
| M1-004 | 19.9 | “默认阅读提醒 06:20、复习提醒 21:20、自动加入默认开启” | 偏好 | P0 | UserPreferencesRecord, PreferencesRepository | 默认值与保存恢复 | 持久化测试 | 已实现待 CI |
| M2-001 | 4.1–4.4、26 M2 | “首页显示当前必做任务与空状态” | UI/业务 | P1 | TodayFeature.swift | ViewModel 真实读取、无候选与失败状态、重试 | `testTodayViewModelShowsNoCandidateAndFixtureCycleState`, UI 空状态测试 | 已实现待 CI |
| M2-002 | 4.2、2.2.1 | “任务卡片必须显示原始分配日期和当前状态” | UI | P1 | TodayFeature.swift | 周期快照显示文章、日期、四项状态和逾期 | 代码审查；CI UI 待确认 | 已实现待 CI |
| ENG-M0-TEST | 24.1、25 | “相关单元测试或集成测试通过” | 测试 | P0 | LexiDawnTests, LexiDawnUITests | Xcode test 真实执行 | 当前容器未运行 | 未确认 |
| ENG-M0-CI | 22.3、22.5 | “保存构建日志和测试结果。” | CI | P0 | ios-ci.yml, STATUS.md | Actions workflow | 新 run 未确认 | 未确认 |
| M3-001 | 6.2 | “每个英文单词都可点击” | 后续 | P0 | — | — | 后续轮次 | 未开始 |
| M5-001 | 10.7 | “复习评分与排程更新” | 后续 | P0 | — | — | 后续轮次 | 未开始 |
| M7-001 | 21.1 | “API Key 不应直接写入客户端” | 安全 | P0 | docs/privacy.md | 仓库与 CI secret 检查 | 本轮未引入 API Key | 持续 |
