# 架构

Round 1 按 SPEC §15.1–15.5 保留原生 SwiftUI 与 SwiftData，并把每日任务规则放到可独立测试的 Domain 层。UI 不再创建或去重周期；它通过依赖容器使用 Repository 和 `DailyCycleService`。

- `LexiDawn/Domain/DailyTasks/DailyTasks.swift`：`TaskStatus`、合法迁移、`DailyStudyCycle`、候选文章协议与每日周期服务。学习日期由注入的本地时区和 Calendar 计算，时间戳仍为 UTC；跨日计数使用 `lastCarryOverLocalDate` 幂等更新。
- `LexiDawn/Data/PersistenceModels.swift`：`ArticleRecord`、`DailyStudyCycleRecord`、`UserPreferencesRecord`。状态以 raw value 保存，偏好包含 schemaVersion 和规格默认值，不保存 API Key。
- `LexiDawn/Data/Repositories.swift`：SwiftData Repository，负责查询、upsert、保存失败传播和偏好默认记录创建。生产候选 provider 为空时返回明确的无候选结果；测试使用显式 `FixtureArticleCandidateProvider`。
- `LexiDawn/AppCore/DependencyContainer.swift`：创建共享 ModelContainer、Repository 和 Domain service；应用与测试均可注入独立的内存容器。
- `LexiDawn/Features/Today/TodayFeature.swift`：`TodayViewModel` 读取真实周期与文章记录并暴露 loading、无候选、失败、保存失败和周期状态；`TodayView` 只呈现状态并发出状态迁移意图。
- `LexiDawn/RootTabView.swift`：保留“今日、探索、词汇、复习、我的”顺序，其余入口继续诚实显示未接入模块。

周期完成条件是文章、复习、连线和拼写四个状态均为 `completed` 或合法 `deferred`。`blocked`、`failed`、`ready` 和 `inProgress` 不会被误认为完成。候选文章必须由 provider 返回，不能用 UI 或生产 fixture 生成伪文章。

SwiftData 当前采用默认本地容器；新增模型字段通过有默认值的属性兼容后续迁移。常规 Debug/Release 产品 Deployment Target 仍为 iOS 27.0；CI 使用单独的 `CI` build configuration（已批准的 iOS 26.5 兼容目标）构建与测试。
