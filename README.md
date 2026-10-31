# 词光 LexiDawn

个人使用的原生 iOS 英语阅读、词典与间隔复习应用。产品行为以 [SPEC.md](SPEC.md) 为准，当前正在推进 Round 2 功能交付。

## 开发环境

工程使用 SwiftUI 和原生 Xcode 项目，不引入第三方 UI 框架。应用 target 的 bundle identifier 是 `com.lexidawn.app`，版本为 `0.1.0 (1)`，常规 Debug/Release 产品配置的最低系统版本为 iOS 27.0。CI 在 runner checkout 中临时把该目标替换为已批准的 iOS 26.5 兼容目标，再使用 Debug 配置构建和测试；工程中没有独立的 `CI` build configuration。兼容构建不替代 iOS 27.0 规格验收。

## 构建与测试

```sh
xcodebuild -list -project LexiDawn.xcodeproj
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 先使用 `build-for-testing` 和 `generic/platform=iOS Simulator` 编译应用及测试 target；这一步失败时不会启动具体 simulator。编译通过后才创建并校验具体 iOS Simulator，保留 `xcodebuild -showdestinations` 诊断后使用该设备 ID 执行单元测试和 UI 测试，并上传 `.xcresult` 结果包。workflow 只在 `main` push 和面向 `main` 的 pull request 上触发。当前开发容器没有 Xcode，不能把本地命令结果写成 iOS 验收证据。

## 交付边界

模拟器/未签名构建与可安装签名 IPA 分开记录。Windows + AltServer/AltStore 路径和免费 Apple ID 限制见 [docs/signing.md](docs/signing.md)。


## Round 1 第二次整改状态

代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。

已实施领域证据、严格状态恢复、隔离事务上下文、真实磁盘故障/重开、两版旧schema升级和UI禁用/错误/启动恢复回归。UI长循环已排查，补齐原生启动配置并改为有界定向定位；未减少业务断言。CI固定iPhone17Pro/iOS26.5，共享derivedData，保留完整日志与xcresult。

此段为 Round 1 历史验证；兼容模拟器结果不等于iOS27、真机、IPA或完整产品验收。准确边界见 [STATUS.md](STATUS.md)、[测试计划](docs/test-plan.md) 和 [本轮整改报告](docs/reviews/round-1-second-remediation-report-2026-10-31.md)。后续文档提交的Actions与上述代码运行分别记录。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](docs/reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。

### 如何体验

1. 在 Xcode 打开工程，使用与产品版本匹配的工具链运行；兼容模拟器验证不代表 iOS 27 或真机安装。
2. 生产首次启动安装官方 RFC 原文，可立即开始阅读；也可从导航栏“导入”粘贴有权使用的正文，确认本地使用和是否允许未来每日分配。旧周期不会被替换。
3. 今日 → 开始/继续阅读；滚动、退出、重开可恢复。点击英文词看可能含义并自动保存；关闭自动添加后需手动加入。
4. 词汇页搜索、编辑个人释义、查词、确认移除；未知词没有可靠中文时可自行填写明确标为个人释义的内容供复习。
5. 阅读后明确完成；复习页点击英文和对应中文配对，再输入完整拼写。作答、排程和周期更新同一事务提交。
6. 必做全部完成才解锁探索；已分配/已开始文章从探索候选移除，历史可从今日页“文章库与历史”继续。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。
