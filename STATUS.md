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


## Round 2 开发批次 1（2026-10-31，验证中）

本批次新增合法用户导入、官方 RFC 8890 全文、许可访问策略、原生 TextKit 阅读与进度、CC-CEDICT 反向查词、生词本、固定两阶段复习、真实设置与统计的生产链路。保留 Round 1 的全部回归测试、原模型字段、完成证据与失败上下文隔离。新模型仅新增实体；完整验证与交付结果见后续 `docs/reviews/round-2-development-delivery.md`。当前尚未取得本批次编译、测试与 CI 结果，不标记完成。

内容依据：IETF TLP 5 §3(c)(i)（完整、不改动、保留原版权声明）；MDBG 官方下载 CC-CEDICT 2026-10-30（CC BY-SA 4.0，派生数据索引同许可，应用代码独立）。原文及声明随安装包提供，数据并非测试 fixture。用户声明仅作为本地导入确认，不等于第三方公开版权授权。
