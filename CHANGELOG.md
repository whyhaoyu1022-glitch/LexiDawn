# Changelog

## Round 1 — 2026-10-26

- 新增每日学习周期领域模型和 `TaskStatus` 状态迁移，区分 locked、ready、inProgress、completed、deferred、blocked、failed。
- 新增跨日任务保留、最早未完成周期优先、同日幂等、文章去重和无候选结果规则。
- 新增 SwiftData 的文章、每日周期和用户偏好模型，以及周期、文章和偏好 Repository。
- 应用启动时创建共享持久化容器；偏好默认值符合 06:20/21:20 和自动加入生词本规则。
- 今日首页改为读取 Repository 的真实周期，显示状态、原始分配日期、逾期、空状态和重试操作。
- 新增领域、状态迁移、跨日/时区、SwiftData 恢复与首页 ViewModel 测试；保留原有导航测试。
- CI 目的地选择改为以 `xcodebuild -showdestinations` 为准，找不到 scheme 接受的 concrete iOS Simulator 时明确失败。
- 新增专用 `CI` build configuration（iOS 26.5 兼容目标），常规 Debug/Release 产品配置仍为 iOS 27.0；push 到 `round1-daily-cycle` 也触发 CI。

已知限制：本地容器没有 Xcode；真实文章 provider、阅读器、复习题目、通知和真实设备验收属于后续轮次。新 Actions 结果尚未确认。
