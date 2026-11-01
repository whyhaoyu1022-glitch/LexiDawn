# CURRENT · Round 3 开发与验证中（2026-11-01）

尚未达到统一验收条件，不能标为完成。当前源码有 **175 XCTest / 48 XCUITest**，包含原 93 / 20；新增清单不是运行结果。所有远端开发直接在 main，没有新建分支。

## 当前真实验证

| 代码 SHA | Actions | 实际结果 |
|---|---|---|
| d37b9aa65aebd6bc010de57294ee243c1a95d825 | [41295662878](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41295662878) | Debug、Release、169 单元/网络测试通过；大屏 3/0。full-4 为 12/4 失败，其余分组取消，整次失败。 |
| c96015ab68827df96572a25236345c7cd972dda5 | [41309801722](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41309801722) | 第一次 Debug/Release 通过；170 测试中 169 通过，Free Dictionary 对 book 连续 404 导致 1 失败。个人原文版本回归通过。第二次关卡 Debug/Release、170测试/0失败；Free Dictionary 真实 noun 释义通过，10源29篇；UI尚未完成。 |

最近真实来源测试已从 10 个来源导入完整正文：BBC、Guardian、NPR、DW、VOA、NASA、Wikipedia、Wikinews、ScienceDaily、Phys.org。Reuters 401、AP 403 和 Smithsonian 不完整正文被舍弃。运行级精确数量/HTTP 结果留在相应日志，不能把 13 个配置写成 13 个成功来源。

## 已写入的产品实现

全文发现与准入、双正文原子持久化及去重；本地文章库/搜索/筛选/收藏/稍后/历史；多 Provider 词典及版本缓存；真实 Canvas 连线和双端禁用；三主题/动态字体原生阅读器；FSRS 4.5、原句拼写及排程反馈；统一全入口学习门禁；独立额外复习；真实全文词汇推荐；生词高级管理与导出；个人全文版本更新和历史保留。实现细节、20 项 Round 2 矩阵与证据缺口见 [开发记录](docs/reviews/round-3-development-delivery.md)。

本次补充：结构化原创全文入库一致性/事务回归及 UI，个人原文更新/版本恢复 UI，分类/时间/历史 UI，确认义项/原生导出 UI，刷新失败仍可阅读本地全文。待新提交执行。

## 正在处理

1. 原始失败附件确认：导入 Form 被向下拖动关闭；查词 medium 浮窗中生词状态/短语被义项列表推到屏外。已加显式取消并禁止意外拖动关闭，将状态/短语提前且初始展开，保留旧测试断言，待真实回归。
2. Free Dictionary 真实外网间歇 404；同端点有界重试仍保留非空释义测试，不能用其他来源冒充该 Provider 成功。
3. 最终同一代码提交的全量 UI、双尺寸/主题、所有必需状态原始 PNG、manifest/CSV/ZIP/xcresult 和逐图审阅。
4. 补充同义词对照加载/空/失败/重试成功、文章导入实际提交失败、复习作答实际提交失败及重启截图；损坏单个词典缓存不再阻断其他Provider，新增可修复回归，待新提交运行。
5. 真实设备/iOS 27、完整 VoiceOver 听读和 Instruments 不在当前 Linux/兼容模拟器能力内，尚无对应通过证据；不作真机帧率承诺。

## 业务不变量

最早未完成周期优先；每日文章原子分配并去重；阅读/复习独立；所有正文打开和进度写入执行同一门禁；收藏不创建周期。Repository 使用独立 context/统一 save/rollback；失败无成功提示或孤儿记录。生词仅用户明确移除，撤销只影响本次创建；缓存清理不删学习数据。历史 schema 磁盘升级与旧 93/20 测试保留。

## 历史记录

[Round 2 独立审核](docs/reviews/round-2-independent-acceptance-and-91-screenshot-audit-2026-10-31.md) 与 [Round 2 交付](docs/reviews/round-2-development-delivery.md) 保留原文。旧 STATUS 的时间顺序记录可从 [main 在本次整理前的版本](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/c96015ab68827df96572a25236345c7cd972dda5/STATUS.md) 查阅；旧测试计数和“未接入”描述不代表当前实现。


补齐截图覆盖：今日原文卡片优先每源一篇，全部仍来自本地完整库；真实多源UI返回今日采集R3-S01。连线全部完成后可展开查看已保存全部连接，进入拼写不删除线条证据；新增M08全部双端禁用/实线和M11滚动后锚点实线PNG断言，主用例数量不变。新增截图仍待当前代码运行。


验收补强：133项状态→实际PNG检查与逐源首/中/末、SE/大屏主题横屏检查加入最终合并关卡，缺图会失败但仍上传已有证据/COVERAGE.md；不把截图调用数当真实产物数。补充生词搜索无结果V13、嵌套短语返回D62–65。损坏可丢弃Provider缓存不能阻断生词读取/导出或可靠个人释义复习，新增真实SwiftData回归；数据库fetch错误仍抛出。当前175 XCTest/48主UI清单，新增待当前代码执行。


已核验d7f4020运行41312535622：Debug/Release、174 XCTest/0失败，10源29篇；大屏3 UI/1失败。原始AX层级证实：DisclosureGroup父标识覆盖了内部matching-board标识，实际三端已禁用；改为独立展开按钮和独立连线容器，保留实线像素断言且增加词端存在断言。另发现旧嵌套查词用例同时看到父/子两个close-word；展示详情/子浮窗时隐藏背景无障碍节点及父关闭按钮，不用firstMatch弱化旧测试。最新源码175 XCTest/48 UI待执行。

CI打包优化：实际旧附件含约52MB MP4，PNG ZIP只收原始PNG/JSON，视频仍保留在原始附件和xcresult；真实41张索引PNG重导出SHA全部一致。UI/汇总artifact关闭对既有压缩数据的重复压缩。取消时没有完成的xcresult不再调用导出器报二次错误，日志保留且不当作成功截图证据。
