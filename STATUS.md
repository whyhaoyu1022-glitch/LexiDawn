# 当前状态

- 当前开发轮次：Round 1 整改（M1 数据模型与任务状态机、M2 今日首页第一版）
- 已实现：文章只能通过 `completed` 满足周期；复习空队列可带原因 deferred；周期保存 `completionReason`；Repository 维护唯一当前周期、同日幂等、canonicalURL 去重和文章/周期的单一保存边界；候选文章许可/正文门禁；未接入的任务入口保持禁用，不写入无法完成的 `inProgress`；SwiftData 磁盘重开回归测试；启动存储失败显示可理解错误页。
- 已保留：五个主导航入口顺序；探索、词汇、复习、我的继续诚实显示后续模块未接入。
- CI 修复：workflow 以 `xcodebuild -showdestinations` 返回的 concrete iOS Simulator 为选择来源，在 runner checkout 中临时把 27.0 目标替换为已批准的 26.5 兼容目标；工程没有独立 `CI` build configuration。单元/UI 测试分别上传 `.xcresult` artifact。
- CI 触发：只在 `main` push 和面向 `main` 的 pull request 上运行；`round1-daily-cycle` push 不属于独立触发条件。
- 产品 Deployment Target：常规 Debug/Release 为 iOS 27.0；兼容 CI 结果只代表 26.5 simulator 验证。
- 本地验证：已运行 `git diff --check`；当前容器没有 Swift/Xcode，未运行 xcodebuild、XCTest 或 XCUITest。
- 最新 main Actions：整改代码尚未推送，当前远端 main 仍为旧的失败运行；推送后会记录最终 run URL、commit SHA 和测试结果。
- 未实施的后续里程碑：真实文章来源、阅读器、词典、生词本、连线/拼写题、通知和真实设备验收；本轮保持诚实空状态，入口不改变持久化任务状态。
