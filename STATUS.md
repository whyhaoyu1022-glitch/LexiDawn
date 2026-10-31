# 当前状态

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
