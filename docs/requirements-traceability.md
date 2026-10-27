# 需求追踪矩阵

原文引文均直接取自 `SPEC.md`；状态只在有代码或测试证据时标记。CI 和真实设备结果与本地静态检查分开记录。

| ID | 规格章节/小节 | 原文短引文 | 类别 | 优先级 | 代码/文件 | 验收方法 | 测试/证据 | 状态 |
|---|---|---|---|---|---|---|---|---|
| GOV-001 | 0.1 | “SPEC.md 是产品行为和架构的权威来源。” | 架构 | P0 | SPEC.md, AGENTS.md | 规格与实现审查 | 本矩阵 | 已实现待验收 |
| M0-001 | 15.1、15.2；26 M0 | “使用 SwiftUI 与必要的原生 UIKit 桥接” | 架构/UI | P0 | LexiDawn/*.swift, project.pbxproj | xcodebuild -list/build | run 40597791954 app build success；本地未运行 | 已实现，CI 通过 |
| M0-002 | 3.1 | “主导航固定为五项” | UI | P0 | RootTabView.swift | XCUITest 五入口切换 | `testFivePrimaryTabsAreVisibleAndSelectable`; run 40597791954 | 已实现，CI 通过 |
| M0-003 | 22.3、22.5 | “在 macOS runner 上使用指定 Xcode 构建。” | CI | P0 | .github/workflows/ios-ci.yml、project.pbxproj | CI 配置、showdestinations、concrete simulator、build/test | run 40597791954 success；工程保留 Debug/Release；artifact 12776278533 | 已实现，CI 通过 |
| M1-001 | 2.1–2.6、19.3、26 M1 | “未完成任务必须保存在本地数据库” | 领域/数据 | P0 | Domain/DailyTasks/DailyTasks.swift, Data/PersistenceModels.swift | 状态迁移、完成判断、恢复查询 | 文章 deferred、复习空队列、跨日与完成时间回归测试；run 40597791954 | 已实现，CI 通过 |
| M1-002 | 19.1、19.9、19.10 | “本地优先，保存 UTC 时间戳和明确的本地日期/时区字段” | 持久化 | P0 | Data/PersistenceModels.swift, Data/Repositories.swift | SwiftData 创建、更新、磁盘容器重开 | `testDiskContainerReopenRestoresCycleArticleAndPreferences`; run 40597791954 | 已实现，CI 通过 |
| M1-003 | 2.2、2.3、24.2 | “旧任务优先，未完成不覆盖” | 业务规则 | P0 | DailyCycleService | 同日幂等、跨日保留、carry-over 幂等 | 周期与时区测试；run 40597791954 | 已实现，CI 通过 |
| M1-004 | 19.9 | “默认阅读提醒 06:20、复习提醒 21:20、自动加入默认开启” | 偏好 | P0 | UserPreferencesRecord, PreferencesRepository | 默认值与保存恢复 | 持久化测试；run 40597791954 | 已实现，CI 通过 |
| M2-001 | 4.1–4.4、26 M2 | “首页显示当前必做任务与空状态” | UI/业务 | P1 | TodayFeature.swift | ViewModel 真实读取、无候选与失败状态、重试 | `testTodayViewModelShowsNoCandidateAndFixtureCycleState`, `testTodayStartDoesNotPersistUnavailableInProgressState`; run 40597791954 | 已实现，CI 通过 |
| M2-002 | 4.2、2.2.1 | “任务卡片必须显示原始分配日期和当前状态” | UI | P1 | TodayFeature.swift | 周期快照显示文章、日期、四项状态和逾期 | 代码审查；run 40597791954 UI step success | 已实现，CI 通过 |
| ENG-M0-TEST | 24.1、25 | “相关单元测试或集成测试通过” | 测试 | P0 | LexiDawnTests, LexiDawnUITests | Xcode test 真实执行 | run 40597791954 success；本地未运行 | 已实现，CI 通过 |
| ENG-M0-CI | 22.3、22.5 | “保存构建日志和测试结果。” | CI | P0 | ios-ci.yml, STATUS.md | Actions workflow、xcresult artifact | run 40597791954 + artifact 12776278533 | 已实现，CI 通过 |
| M3-001 | 6.2 | “每个英文单词都可点击” | 后续 | P0 | — | — | 后续轮次 | 未开始 |
| M5-001 | 10.7 | “复习评分与排程更新” | 后续 | P0 | — | — | 后续轮次 | 未开始 |
| M7-001 | 21.1 | “API Key 不应直接写入客户端” | 安全 | P0 | docs/privacy.md | 仓库与 CI secret 检查 | 本轮未引入 API Key | 持续 |

## Round 1 整改项

| 编号 | 规格依据 | 代码与测试证据 | 当前状态 |
|---|---|---|---|
| R1-001 | §2.1、§2.5、§19.3、§30.4 | `DailyStudyCycle.isComplete` 要求文章 `completed`；`update` 拒绝 article deferred；`testArticleCannotBeDeferred`、`testDeferredReviewCannotCompleteCycleWhenArticleIsIncomplete` | 已实现，CI 通过 |
| R1-002 | §2.4、§2.5、§25.1 | `TodayFeature` 对未接入功能禁用入口；`start` 不写入 inProgress；`testTodayStartDoesNotPersistUnavailableInProgressState` | 已实现，CI 通过 |
| R1-003 | §19.3、§30.1 | `completionReason` 字段；Repository 保存时唯一化 `isCurrent`；`testRepositoryMaintainsSingleCurrentCycle` | 已实现，CI 通过 |
| R1-004 | §2.3、§19.10、§30.1/3 | 同一 ModelContext 保存文章/周期，重复日期和 canonicalURL 拒绝，失败 rollback；无跨进程事务承诺 | 已实现，限制已记录 |
| R1-005 | §2.2.1、§25.2 | `TodayViewModel` 保存 pending 写操作；`retry` 调用原写入；`testRetryingFailedRepositoryWriteCanSucceedWithoutDuplicateCycle` 覆盖 Repository 重试 | 已实现，CI 通过 |
| R1-006 | §2.2、§20.1、§25.3 | 临时磁盘 `ModelConfiguration(url:)` 关闭/重开测试 | 已实现，CI 通过 |
| R1-007 | §19.1、§21.3、§30.13 | ArticleRecord 元数据、许可、内容状态；服务门禁；`testInvalidCandidateCannotCreateCycleOrArticle` | 已实现，CI 通过 |
| R1-008 | §25、§30 | 文章 deferred、复习独立、时区回拨、磁盘恢复、失败重试、唯一当前等分层回归测试 | 已补齐主要场景，CI 通过 |
| R1-009 | §15.2、§22.3、§25.6 | Debug/Release 保持 iOS 27.0；workflow 临时使用 26.5，push/PR 触发与文档一致；上传 xcresult | 已实现，CI 通过 |
| R1-010 | §0.3、§25.9 | STATUS、CHANGELOG、架构、测试计划、每日记录和本报告同步真实限制 | 已更新 |
| R1-011 | §2.3、§18.5、§30.2 | `markCarryOverIfNeeded` 只在本地日期向前时增加；`testDateRollbackDoesNotIncreaseCarryOverCount` | 已实现，CI 通过 |
| R1-012 | §12.5、§19.1、§19.10 | canonicalURL 规范化/去重、候选字段和 URL/许可/正文校验，移除未变更 `var` | 已实现，CI 通过 |
| R1-013 | §15.3、§25.2 | `LexiDawnApp` 显示存储不可用状态，不 fatalError、不清空数据 | 已实现；启动错误路径未在本地 Xcode 运行 |
| R1-014 | §25、§32 | 保留原报告；整改提交使用明确说明；真实设备、无障碍、iOS 27 产品目标继续标为未验证 | 进行中 |
