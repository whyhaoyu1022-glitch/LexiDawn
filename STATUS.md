# CURRENT · Round 3 开发与验证中（2026-11-02）

最新核查41361046807：Debug/Release及测试目标编译成功；182 XCTest中181通过、Free Dictionary真实book查词1失败，三次HTTP404；UI和合并全部跳过。本次为404后的限次请求加入中间缓存重新验证头，保留原接口/词条及真实非空noun断言；新增2确定性测试，源码184/49，原生复验待新CI。持续真实404仍必须报失败，不冒称外网已恢复。 [失败证据、规格及验证边界](docs/reviews/round-3-ci-41361046807-repair.md)。

尚未达到统一验收条件。**本次源码清单为 184 XCTest / 49 XCUITest，包含原 93 / 20；新增清单不是通过结果。** 所有远端开发直接提交 main，没有新建分支。本次修复将由新的 Actions 验证，准确 SHA 与运行链接见 GitHub main/Actions。

## 最近已核验结果

| 代码 SHA | Actions | 实际结果 |
|---|---|---|
| 03a4b0edad02a18de2d644822b545536d45dd92d | [41361046807](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41361046807) | Debug/Release和测试目标编译成功；182单元/1失败（Free真实book三次404）；UI及合并跳过，整次失败。 |
| 714db6605df7c0cf578d63bcf94ba09d6486b3a1 | [41357763875](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41357763875) | Debug/Release、182单元/0失败；full-2 12/0、SE7/0、大屏3/0；full-4 13/1及上传超时，其他取消，整次失败。 |
| 0126709082265a3b2648b502772df889488c4b9f | [41326351407](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41326351407) | Debug/Release、180单元/0失败；SE7/0、大屏3/0；full-4 13/1导出失败，其余取消，整次失败。 |
| 89ccd99e7978006470d36e7814ba64c1114438bc | [41318724181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41318724181) | Debug/Release、180 XCTest/0失败，真实10源29篇；大屏3/0；SE7/1，主UI另发现重置确认与空库文案失败；其余取消，整次失败。 |
| 747d7c322e5d11bc1aae9a94ec7d2a47723140ae | [41314198717](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41314198717) | Debug/Release、175 XCTest/0失败，真实10源29篇；UI full-3为13/1失败，其他组取消，整次失败。 |
| d7f402025d87cd90ca35bff658b23eeda0ecf4da | [41312535622](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41312535622) | Debug/Release、174 XCTest/0失败；大屏3/1失败，其余未完成；整次失败。 |

最新失败已核对原生录像/AX与日志：SE 键盘遮挡个人释义保存按钮，文章库同行默认按钮让重置同时误开阅读器，探索空库说明发生回归。源码已将唯一保存动作移到导航栏、隔离库内按钮并捕获确认文章快照、恢复原空库说明；加强键盘/取消重置/重新打开读回断言。原生复验尚待本次新 CI，详见[失败核查报告](docs/reviews/round-3-ci-41318724181-repair.md)。此前同义词展开及来源语境修复的180单元已通过；被取消的相关UI仍待验证。

## 本次实际修改

- 修复上述三处实际 UI 回归；保留原20 UI全部断言，并加强真实冷启动持久化和重置取消/确认验证。

- 生词上下文分为 reader、dictionary、historical：词典句子保存原词和原始来源证据，关联文章单独显示；旧记录缺类型时保持未知，不在迁移中猜测。
- 短语按原始全文或原始词典文本核验完整 UTF16 范围，包含首词及原有硬换行；同句其他相同单词不能冒充当前短语位置。位置核验失败与生词保存错误分开，不会用“重试保存”错误地保存另一个词。
- 新词明确写入 new 状态，首次 Again 保持 learning；既有 review 失败才进入 relearning。成功次数由已保存 Hard/Good 计数派生，历史未知计数不伪造。
- 新增一万条 RSS 候选和千段 HTML 的实际解析时钟/内存测量，同时断言完整性；原长文原生滚动/内存 UI 保留，不作真机帧率承诺。
- 补充嵌套词典词→生词本真实来源 UI 与 D66/D67 原生截图点；共137项实际PNG状态覆盖要求，逐源首/中/末及SE/大屏主题横屏仍是最终合并关卡。

## 已实装范围与业务保护

六大模块主体已写入：多源全文发现/准入/原子入库、文章库/搜索/收藏/稍后/历史、多词典/离线缓存、真实连线、三主题原生阅读器、FSRS原句复习与学习闭环。另有额外复习、完整探索、词汇推荐、导出及个人全文版本保留。实现和20项Round 2矩阵见[开发记录](docs/reviews/round-3-development-delivery.md)。

最早未完成周期优先；每日分配原子且不重复；阅读/复习独立；库/历史/收藏/稍后/探索及Reader打开/save/complete共用门禁；收藏不建周期。Repository独立context/save/rollback，失败无成功提示或孤儿记录。撤销只针对本次创建，复习和缓存清理不删除用户生词、个人内容或日志。

按负责人批准的个人模式，13个候选适配器中最近实际成功10源：BBC、Guardian、NPR、DW、VOA、NASA、Wikipedia、Wikinews、ScienceDaily、Phys.org。Reuters401、AP403、Smithsonian不完整被舍弃；不绕过登录/验证码/付费墙，无摘要/URL/浏览器阅读降级。详见[来源审查](docs/article-source-eligibility-audit.md)。

## 仍待完成的验收

1. 本次代码的完整构建、180单元/网络/迁移测试、49主UI及SE/大屏专项。
2. 全部137项状态对应的真实PNG核对与逐图审阅，同一代码的完整ZIP、manifest、CSV、索引和xcresult。
3. 最终报告、真实main SHA及运行结果回填。尚未取得iOS27/真机、完整VoiceOver听读或Instruments通过证据；现有CI是已批准Xcode26.6/iOS26.5兼容模拟器。

CI已采用一次编译共享产物、4主UI分组+设备专项、fail-fast、旧main运行清理和PNG打包去重复压缩。没有删除旧测试或降低断言；不能用历史绿色关卡或部分截图代替最终验收。

## 历史

[Round 2独立审核](docs/reviews/round-2-independent-acceptance-and-91-screenshot-audit-2026-10-31.md)、[Round 2交付](docs/reviews/round-2-development-delivery.md)保留原文。旧STATUS记录可从[本次整理前版本](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/747d7c322e5d11bc1aae9a94ec7d2a47723140ae/STATUS.md)追溯，旧计数和待运行描述不代表CURRENT。
