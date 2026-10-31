# 当前状态

> 前半部分保留 Round 1 历史基线与不变量；当前生产功能、Round 2 验证结果和未完成项见文末及 Round 2 开发交付自述。

- 2026-10-31：Round 1 第二次整改的适用代码、回归和证据已提交；等待下一次独立验收，不自称已满足整个 SPEC §25。
- 起始 main：`b894bdacadbee3a52073f6c300ab043c7e43caa8`。旧基线 run40706618129 的25 XCTest/2 UI不是本次证明。
- 代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。
- 已修复：任意字符串deferred、无证据阅读完成、非法构造/恢复、非原子fallback、失败context残留、文章/周期关联与去重、最早未完成current、文章元数据/许可与缓存、偏好、跨日高水位、任务错误说明和真实启动重试。
- 新增旧复习时间/终态凭据替换回归、两条真实历史schema磁盘升级、同模型磁盘重开、只读真实save错误/rollback/可写重试均在上述61个XCTest中通过；FakeStore、内存注入与真实磁盘证据分开记录。
- 用户指出的两次UI失败已按日志和xcresult排查：旧定位固定重复滑动、没有进展检测；现代设备窗口却是320×480。原生launch/scene配置与有界定向定位已修复，新增实际现代窗口尺寸断言，保留全部禁用/可见/实际点击/状态断言。
- Debug/Release三个target的产品目标均保持iOS27.0；上述结果仅适用于Xcode26.6、iOS26.5、iPhone17Pro兼容模拟器，不等于真机/签名IPA/iOS27/无障碍通过。
- 本地无Swift/Xcode；实际执行静态差异、YAML/scheme/测试索引与旧报告保留检查。iOS运行证据来自GitHub Actions。
- 生产文章来源、阅读器、复习队列/保存会话仍未接入；默认拒绝伪造完成或空队列，按钮禁用。UI fixture仅DEBUG模拟器显式隔离启用。
- PR#1 closed、merged=false；旧分支保留。旧报告中的ab70b5a不再作为整合证据。三份旧报告原文不改，新证据见 [本轮整改报告](docs/reviews/round-1-second-remediation-report-2026-10-31.md)。
- 未验证：跨进程/多容器同时写、磁盘满/断电/OS强杀、真实用户旧库、iOS27/真机/IPA、完整无障碍/动态字体/深色模式。未知损坏/历史重复记录保留报错，暂无自动合并或人工修复UI。
- 本文及报告属于后续docs-only提交；上述CI严格对应列明代码SHA。docs提交自己的运行状态以Actions为准，不冒用代码run。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](docs/reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。


## 2026-10-31 截图验收补充（运行结果待核对）

按用户要求补充7个实际XCUITest场景及数十个keepAlways截图点：正式生产依赖首次启动与RFC8890、真实RFC隔离库的主题/横屏/词条/复习、导入空状态与校验、许可到期、429后退避、跨日和缺失复习状态。P为真实生产内容，S为真实RFC加预置学习状态，F为隔离原创测试文章，X为明确故障注入；旧Round1截图另标历史，不冒充当前生产页面。CI额外导出原始附件PNG和manifest，保留xcresult与原回归；UI步骤超时扩至45分钟容纳截图，不改产品iOS27目标。截图数量、最终SHA、实际成功/失败与下载包在本次交付答复核对，不预填通过。SPEC §24.6原文：“加载、空状态、错误状态和锁定状态都可通过 VoiceOver 理解。”截图辅助审阅，不等于完整VoiceOver验收。


截图首轮547fbde / Actions41199999648已结束：93 XCTest/0；20 UI/3失败。实际下载原始PNG与AX附件，确认Form惰性列表尚未载入禁用保存按钮、overflow菜单没有继承SwiftUI identifier（原生label为“阅读外观”）、主题Picker应匹配原生label且先结束键盘输入。保留三个场景及断言，修正真实控件定位后再次运行；结果不预填成功。
