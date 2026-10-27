# Changelog

## Round 1 整改 — 2026-10-28

- 修复必做文章 deferred 绕过周期完成规则的问题；新增周期级 `completionReason`，完成时间只在所有真实条件满足时写入。
- Repository 维护唯一 `isCurrent`、同一本地日期幂等、规范化 canonicalURL 去重，并在同一 ModelContext 保存文章和周期；失败时回滚。
- ArticleRecord/ArticleCandidate 补齐展示标题、难度、图片署名、许可、正文和内容状态；候选进入周期前执行字段和许可门禁。
- 首页未接入的阅读/复习入口改为禁用并明确说明，不再写入无法完成的 `inProgress`；遗留进行中状态启动时转为可恢复的 blocked。
- 保存失败重试保留写操作上下文；新增时区回拨、非法候选、磁盘重开、唯一当前周期和失败重试回归测试。
- ModelContainer 初始化失败显示存储不可用页面，不清空或覆盖本地数据。
- CI 保持 Debug/Release 工程配置和 iOS 27.0 产品目标，workflow 只在 main push/PR 触发，runner checkout 临时使用 iOS 26.5 兼容目标并上传 xcresult。

验证状态：当前容器没有 Xcode/Swift；本地只完成静态 diff 检查。最终 Actions run、commit SHA 和测试数量在推送后补记。

## Round 1 — 2026-10-26

- 新增每日学习周期领域模型和 `TaskStatus` 状态迁移，区分 locked、ready、inProgress、completed、deferred、blocked、failed。
- 新增跨日任务保留、最早未完成周期优先、同日幂等、文章去重和无候选结果规则。
- 新增 SwiftData 的文章、每日周期和用户偏好模型，以及周期、文章和偏好 Repository。
- 应用启动时创建共享持久化容器；偏好默认值符合 06:20/21:20 和自动加入生词本规则。
- 今日首页改为读取 Repository 的真实周期，显示状态、原始分配日期、逾期、空状态和重试操作。
- 新增领域、状态迁移、跨日/时区、SwiftData 恢复与首页 ViewModel 测试；保留原有导航测试。
- CI 目的地选择改为以 `xcodebuild -showdestinations` 为准，找不到 scheme 接受的 concrete iOS Simulator 时明确失败。
- CI 在 runner checkout 中临时应用 iOS 26.5 兼容目标；常规 Debug/Release 产品配置仍为 iOS 27.0。

已知限制：本地容器没有 Xcode；真实文章 provider、阅读器、复习题目、通知和真实设备验收属于后续轮次。新 Actions 结果尚未确认。
