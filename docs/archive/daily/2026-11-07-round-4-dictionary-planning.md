# Round 4词典补充规划日志

2026-11-07按负责人新增三张词典参考升级Round 4至v1.1：完整页按词性/编号义项/搭配/双语例句/短语动词分层，Wiktionary、可配置Oxford、Free为可靠优先组并保留字段来源；有可靠英文也禁用用户释义，确认无可靠来源才允许结构化多词性/多义项/例句录入。笔记仍可用，旧个人义无损只读，复习统一sense/版本/来源快照。新增F22–F24、36条验收、T22–T24，当前总计24项/144条/24族；原21图不重排。仅文档，没有Swift/测试/CI/IPA变更或新通过结果。

## 实际完成

三张JPEG逐张完整读取，记录哈希/尺寸和首中末布局；明确参考中底栏遮挡不照搬、不把截图文字当生产词库。核查现有Free/Wiktionary适配、单字符串userMeaning和复习选义路径；查阅Oxford、Free与MediaWiki/Wiktionary官方文档，能力调查与Live结果分开。

新增[完整补充](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/6054b03932e036ab3205488ed9e5af60fa7495fa/docs/plans/round-4-dictionary-detail-addendum.md)和[参考审阅](../reviews/round-4/round-4-dictionary-reference-audit-2026-11-07.md)，将36条验收/3族并入主任务书和机器清单。严格保留原21原件身份、批注和108个既有验收编号，修改规范冲突不改历史画面事实。

## 边界与后续

基线main203483b83fe9581c436f551938050a4c8c00febe。本次只更新.md/.json及三张字节不变的文档参考JPEG；无产品实现、新测试方法、原生测试结果、CI通过或新IPA。旧R3结果仍是历史。下一次实现须同时覆盖原21项与F22–F24，按专项→最终完整回归→实际截图/真机复验统一关闭。
