# LexiDawn Round 1 整改报告

- 整改对象：Round 1 — Daily Study Cycle, Persistence, Today Dashboard
- 整改日期：2026-10-28（文件名按原验收批次日期保留）
- 起始 commit：`ab70b5a`（本地 main 保留审查报告并整合 `round1-daily-cycle`）
- 最终 commit：待整改提交完成后填写
- 仓库：`whyhaoyu1022-glitch/LexiDawn`

## 整合范围与分支状态

已在本地 `main` 上执行非快进整合，纳入 `round1-daily-cycle` 的第一轮领域模型、SwiftData 模型、Repository、Today 首页、测试和 CI 修复；原文件 `docs/reviews/round-1-acceptance-review-2026-10-27.md` 保留。整合提交为 `ab70b5a`，没有创建新的开发分支，没有 force push，也没有删除 `round1-daily-cycle`。

PR #1 在整改开始时仍为 open，尚未将有阻断缺陷的旧 PR 直接合并。整改代码完成后直接更新 main；只有最终代码、测试和 Actions 证据满足前置条件，才评估是否删除旧分支。

## R1-001 至 R1-014

| 编号 | 状态 | 文件与实现 | 规格依据 | 测试/证据 |
|---|---|---|---|---|
| R1-001 | 已实现，待 CI | `DailyTasks.swift` 要求文章状态为 `completed`；article deferred 明确抛错；`completionReason` 和 `completedAtUTC` 只在真实完成时写入。 | §2.1、§2.5、§19.3、§30.4 | `testArticleCannotBeDeferred`、`testDeferredReviewCannotCompleteCycleWhenArticleIsIncomplete` |
| R1-002 | 已实现，待 UI CI | `TodayFeature.swift` 对尚未实现的阅读/复习入口禁用并说明原因，点击不持久化 `inProgress`；启动时把旧的 inProgress 恢复为 blocked。 | §2.4、§2.5、§25.1 | `testTodayStartDoesNotPersistUnavailableInProgressState`；UI 测试待 Actions |
| R1-003 | 已实现，待 CI | `DailyStudyCycleRecord` 增加 `completionReason`；Repository 保存 current 周期时清除其他记录的 `isCurrent`。 | §19.3、§30.1 | `testRepositoryMaintainsSingleCurrentCycle` |
| R1-004 | 已实现，限制已记录 | `StudyCycleRepository` 在同一 `ModelContext.save()` 边界写入文章和周期，重复日期/canonicalURL 拒绝，失败 `rollback`。SwiftData 当前 API 未提供跨进程事务，本实现保证单容器主线程调用的一致保存边界，不宣称跨进程锁。 | §2.3、§19.10 | `testInvalidCandidateCannotCreateCycleOrArticle`、磁盘重开测试；并发跨进程未验证 |
| R1-005 | 已实现，待 CI | `TodayViewModel` 保留待重试写操作上下文；`retry` 重新执行写入，不把重试描述成重新加载。 | §2.2.1、§25.2 | `testRetryingFailedRepositoryWriteCanSucceedWithoutDuplicateCycle` |
| R1-006 | 已实现，待 CI | 使用临时磁盘 `ModelConfiguration(url:)`，释放容器后重开并验证周期、文章、偏好。 | §2.2、§20.1、§25.3 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` |
| R1-007 | 已实现，待 CI | `ArticleCandidate`/`ArticleRecord` 增加展示标题、难度、图片、许可和内容状态；分配前验证 ID、标题、来源、HTTP(S) URL、许可和可用正文；canonicalURL 规范化去重。 | §19.1、§21.3、§30.13 | `testInvalidCandidateCannotCreateCycleOrArticle`；重复 URL 由 Repository 拒绝 |
| R1-008 | 已补齐主要场景，待 CI | 增加文章 deferred、复习空队列、日期回拨、磁盘恢复、唯一 current、失败重试、未接入入口等分层测试；保持无候选生产空状态。 | §25、§30 | `LexiDawnTests.swift` 新增回归矩阵；UI/CI 结果待最终 run |
| R1-009 | 已实现，待 CI | 保留 Debug/Release iOS 27.0；workflow 在 runner checkout 临时使用 26.5，不声称存在 CI configuration；先用 generic simulator destination `build-for-testing` 编译应用和测试 target，失败时不启动 simulator；通过后保留 `-showdestinations` 诊断，兼容 Xcode 26.6 placeholder 行为并用 `simctl` 验证的具体设备 ID 运行测试；上传 unit/UI `.xcresult`。 | §15.2、§22.3、§25.6 | `.github/workflows/ios-ci.yml`；最终 run 待记录 |
| R1-010 | 已更新 | 更新 `STATUS.md`、`CHANGELOG.md`、`docs/architecture.md`、`docs/test-plan.md`、`docs/requirements-traceability.md` 和开发日志，区分本地未运行、CI 待确认和后续未实现。 | §0.3、§25.9 | 文档审查；最终 run URL/SHA 待填写 |
| R1-011 | 已实现，待 CI | carry-over 只在当前本地学习日期晚于分配日期时增加，日期回拨不增加。 | §2.3、§18.5、§30.2 | `testDateRollbackDoesNotIncreaseCarryOverCount` |
| R1-012 | 已实现，待 CI | 规范化 canonicalURL、校验候选字段和许可/正文状态；删除未变更的 `usedArticleIDs` 可变声明。 | §12.5、§19.1、§19.10 | 候选门禁和 Repository 测试 |
| R1-013 | 已实现，未本地运行 | `LexiDawnApp` 将 ModelContainer 创建失败显示为存储不可用页面，不 fatalError、不删除数据。 | §15.3、§25.2 | 源码审查；需 Xcode 启动失败注入环境验证 |
| R1-014 | 进行中 | 保留旧审查报告；本次提交说明按意图命名；真实设备、无障碍、动态字体、深色模式和 iOS 27 产品目标仍明确为未验证。 | §25、§32 | Git/文档审查；设备验证需要 macOS/Xcode/设备 |

## 实际运行的命令与结果

已运行：

- `git clone https://github.com/whyhaoyu1022-glitch/LexiDawn.git`
- `git diff --check`
- 分支、提交、PR、比较差异和 Actions 状态核查

未运行：

- `xcodebuild -list/build/test`
- XCTest、XCUITest、磁盘 SwiftData 测试
- 真实 iPhone、VoiceOver、动态字体、深色模式、签名 IPA

原因是当前工作容器没有 `xcodebuild` 或 Swift 工具链。不能把源码检查写成 iOS 构建或设备验收通过。

## Actions 证据

整改代码推送后的最终 main Actions 尚未完成，以下旧结果不能作为整改通过证据：

- main 旧失败 run：`https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40184339319`
- 第一轮分支旧绿色 run：`https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416668214`（对应旧分支代码，不是本整改提交）

最终 main run URL、状态、commit SHA、单元/UI 测试数量、失败数量和 xcresult artifact 将在推送后补记。若 Actions 失败，必须读取日志修复根因后再更新本报告。

## 未实施的后续里程碑

本轮没有伪造真实文章来源、阅读器、阅读进度、词典浮窗、详细词典页、生词本、连线题、拼写补全题、探索/推荐解锁、通知安排、后台刷新或签名 IPA。生产候选 provider 继续为空；未接入入口不改变任务持久化状态。

## 未解决、未验证和下一步

- SwiftData 的跨进程并发写入和真实迁移升级需要在 Xcode/macOS 环境验证；当前实现只保证单容器 Repository 的保存边界和回滚。
- 最终 main Actions 必须在最终 commit 上完成；结果不得用旧分支 run 代替。
- 需要在 macOS/Xcode 环境运行单元、磁盘集成和 UI 测试，并完成真实设备、无障碍、动态字体、深色模式和 iOS 27 产品目标验证。
- `round1-daily-cycle` 在上述证据齐全、P0 修复通过且 main CI 完成前不得删除。
