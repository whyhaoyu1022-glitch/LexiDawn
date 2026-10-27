# 架构

Round 1 按 SPEC §15.1–15.5 保留原生 SwiftUI 与 SwiftData，并把每日任务规则放到可独立测试的 Domain 层。UI 不再创建或去重周期；它通过依赖容器使用 Repository 和 `DailyCycleService`。

- `LexiDawn/Domain/DailyTasks/DailyTasks.swift`：`TaskStatus`、合法迁移、`DailyStudyCycle`、候选文章协议与每日周期服务。学习日期由注入的本地时区和 Calendar 计算，时间戳仍为 UTC；跨日计数使用 `lastCarryOverLocalDate` 幂等更新。
- `LexiDawn/Data/PersistenceModels.swift`：`ArticleRecord`、`DailyStudyCycleRecord`、`UserPreferencesRecord`。文章保存展示标题、难度、图片署名、许可和正文可用性；周期保存 `completionReason`、当前标记和任务原因；状态以 raw value 保存，偏好包含 schemaVersion 和规格默认值，不保存 API Key。
- `LexiDawn/Data/Repositories.swift`：SwiftData Repository，负责规范化 URL、候选去重、同一学习日期防重复、唯一当前标记、保存失败传播和偏好默认记录创建。周期与文章通过同一 `ModelContext.save()` 边界创建；SwiftData 当前没有跨进程事务接口，失败时调用 rollback。生产候选 provider 为空时返回明确的无候选结果；测试使用显式 `FixtureArticleCandidateProvider`。
- `LexiDawn/AppCore/DependencyContainer.swift`：创建共享 ModelContainer、Repository 和 Domain service；应用与测试均可注入独立的内存容器。
- `LexiDawn/Features/Today/TodayFeature.swift`：`TodayViewModel` 读取真实周期与文章记录并暴露 loading、无候选、失败、保存失败和周期状态；`TodayView` 只呈现状态并发出状态迁移意图。
- `LexiDawn/RootTabView.swift`：保留“今日、探索、词汇、复习、我的”顺序，其余入口继续诚实显示未接入模块。

周期完成条件是文章状态必须为 `completed`，复习及两个阶段为 `completed` 或带原因的合法 `deferred`。文章不得 deferred；`blocked`、`failed`、`ready` 和 `inProgress` 不会被误认为完成。候选文章必须通过 URL、标题、来源、许可核验和可用正文门禁，不能用 UI 或生产 fixture 生成伪文章。

SwiftData 当前采用默认本地容器；新增可选字段和默认值用于轻量迁移，旧数据中的缺省 `completionReason` 保持为空。当前周期唯一性和日期/URL 去重由 Repository 在单一 ModelContext 内维护；并发跨进程写入不由 SwiftData 当前 API 保证，失败窗口与回滚行为记录在整改报告中。常规 Debug/Release 产品 Deployment Target 仍为 iOS 27.0；CI 在 checkout 中临时使用 iOS 26.5 兼容目标，并保存 XCTest/XCUITest 的 `.xcresult` artifact。
