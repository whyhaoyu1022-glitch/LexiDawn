# 当前状态

- 当前开发轮次：Round 1（M1 数据模型与任务状态机、M2 今日首页第一版）
- 已实现：`TaskStatus` 状态机、`DailyStudyCycle` 与跨日幂等、候选文章协议、SwiftData 三个模型、周期/文章/偏好 Repository、共享 ModelContainer、真实数据驱动今日首页、无候选/加载失败/保存失败状态、13 个领域与持久化/ViewModel 单元测试、无候选 UI 测试。
- 已保留：五个主导航入口顺序；探索、词汇、复习、我的继续诚实显示后续模块未接入。
- CI 修复：workflow 现在以 `xcodebuild -showdestinations` 返回的 concrete iOS Simulator 为唯一选择来源，并在缺少可接受目的地时输出诊断后失败；不再随机采用 `simctl list` 的设备 ID。
- 产品 Deployment Target：iOS 27.0；CI 兼容参数：已批准的 iOS 26.5。
- 本地验证：已运行 `git diff --check`；当前容器没有 Swift/Xcode，未运行 xcodebuild、XCTest 或 XCUITest。
- 最近可确认的 Actions：run [40184339319](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40184339319) 失败，构建通过，测试因 `simctl` 返回的设备 ID 不在 xcodebuild scheme 目的地列表中而退出 70。
- 新代码 Actions：尚未触发或确认；不得视为通过。
- 下一轮：接入真实、许可可核验的文章候选池和阅读器；把阅读器与复习题流程连接到本轮已持久化的状态迁移接口。
