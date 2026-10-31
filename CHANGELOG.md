# Changelog

## Round 1 第二次整改 — 2026-10-31

- 引入完成/空队列证据与所有入口不变量校验；严格区分模块不可用与队列为空。
- 所有 Repository 写入统一 rollback；原子创建、关联/重复/身份保护及最早 current。
- 文章指纹、词数、估算时长、主题/来源/缓存与图片许可；可选年龄段和规格默认偏好。
- 历史 schema 升级前备份、已知非法状态审计归档、启动重试与任务原因说明。
- 补充真实 SwiftData、只读磁盘故障、磁盘重开、两版历史升级及 XCUITest；本轮最终代码61 XCTest/8 UI、0失败，具体SHA/run见下。
- 修正此前把 FakeStore/源码数量扩大为持久化证明的文档。旧审查/整改报告保留，纠正说明见本轮新报告。
- 修复真实save失败后rollback仍有context幽灵对象、VM读重试误重放写、固定时区/非Gregorian日期、时间非有限值/计数溢出及正文指纹恢复漏洞。
- 修复UI固定重复滚动与原生launch/scene配置缺失；新增窗口尺寸断言、滚动无进展失败诊断，保留可见/disabled/实际点击和状态断言。

本轮代码验证：代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。 产品27.0/CI26.5不变；不代表真机或全部SPEC完成。

历史条目按日期保留。2026-10-28条目曾把blocked称作“可恢复”，当前真实学习模块仍未接入，只能重读/重开存储；旧运行不能证明本次代码，历史证据纠正见新报告。


## Round 1 整改 — 2026-10-28

- 修复必做文章 deferred 绕过周期完成规则的问题；新增周期级 `completionReason`，完成时间只在所有真实条件满足时写入。
- Repository 维护唯一 `isCurrent`、同一本地日期幂等、规范化 canonicalURL 去重，并在同一 ModelContext 保存文章和周期；失败时回滚。
- ArticleRecord/ArticleCandidate 补齐展示标题、难度、图片署名、许可、正文和内容状态；候选进入周期前执行字段和许可门禁。
- 首页未接入的阅读/复习入口改为禁用并明确说明，不再写入无法完成的 `inProgress`；遗留进行中状态启动时转为可恢复的 blocked。
- 保存失败重试保留写操作上下文；新增时区回拨、非法候选、磁盘重开、唯一当前周期和失败重试回归测试。
- ModelContainer 初始化失败显示存储不可用页面，不清空或覆盖本地数据。
- CI 保持 Debug/Release 工程配置和 iOS 27.0 产品目标，workflow 只在 main push/PR 触发；runner checkout 临时使用 iOS 26.5 兼容目标，先在 simulator 启动前执行 `build-for-testing`，再运行 unit/UI tests 并上传 xcresult。

验证状态：当前容器没有 Xcode/Swift；本地只完成静态 diff 检查。最终 main run 40597791954 success，对应 SHA `874b3626c00a745767e9d95fbd2cf4c09abf3ca0`；UI 2 tests/0 failures，unit step success，xcresult artifact 已保存。

## Round 1 — 2026-10-26

- 新增每日学习周期领域模型和 `TaskStatus` 状态迁移，区分 locked、ready、inProgress、completed、deferred、blocked、failed。
- 新增跨日任务保留、最早未完成周期优先、同日幂等、文章去重和无候选结果规则。
- 新增 SwiftData 的文章、每日周期和用户偏好模型，以及周期、文章和偏好 Repository。
- 应用启动时创建共享持久化容器；偏好默认值符合 06:20/21:20 和自动加入生词本规则。
- 今日首页改为读取 Repository 的真实周期，显示状态、原始分配日期、逾期、空状态和重试操作。
- 新增领域、状态迁移、跨日/时区、SwiftData 恢复与首页 ViewModel 测试；保留原有导航测试。
- CI 目的地选择改为以 `xcodebuild -showdestinations` 为准，找不到 scheme 接受的 concrete iOS Simulator 时明确失败。
- CI 在 runner checkout 中临时应用 iOS 26.5 兼容目标；常规 Debug/Release 产品配置仍为 iOS 27.0。

已知限制：本地容器没有 Xcode；真实文章 provider、阅读器、复习题目、通知和真实设备验收属于后续轮次。run 40597791954 已通过；真实设备和 iOS 27 产品目标仍未验证。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](docs/reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。
