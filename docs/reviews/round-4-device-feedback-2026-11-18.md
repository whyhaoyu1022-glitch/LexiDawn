# Round 4 真机反馈整改

本表以负责人在 2026-11-18 提供的七张真机图及同批口述反馈为依据。原 Round 4 的 21 张整改图及 144 项账本沿用各自的历史证据。新改动的自动化和真机结果分别登记。

| 真机图或反馈 | 整改规格 | 证据入口 |
|---|---|---|
| IMG_8994 · applied 与 apply | 先查点中的词形和词干，识别独立 MDX 词头。默认先呈现独立词形及自己的音标和义项，下面放原形完整释义。语境明确指向动词时，优先词干的动词义，入库保留该变形。别名没有独立义且语境不足时回到原形。 | `testRealMDXIndependentInflectionsAliasesAndSyllableSpelling` |
| IMG_8947 · cured 重复词头和斜箭头 | 词干只在节首显示。移除界面右上斜箭头，浮窗用右向箭头进入详情。 | 真机对照及词典原生 UI 用例 |
| IMG_8949 · 探索主题行、卡片边角 | 主题选择使用独立圆角背景，探索和词汇推荐使用渐变卡片。整卡操作与收藏、稍后阅读分别命中。 | 探索及推荐 UI |
| IMG_8955 · document 的另见区 | 关联词改为可换列的左对齐圆角入口，展开后仍可访问实际 MDX 词条。 | 词典原生 UI 与真机对照 |
| IMG_8958 · 复习进入后弹出取消错误 | 正常取消静默结束，过期加载状态不能覆盖正在作答的题组，存储/义项错误仍保留预检入口。额外复习由用户开始，已开始的会话重启仍恢复。 | `testCancellationDoesNotProduceReviewPreparationError`；额外复习重启 UI |
| IMG_8960 · representative 长详情 | 替换估算高度的嵌套懒栈，缓存例句富文本与点词索引。审核直立/横屏、深浅色、暖纸及大字。滚动流畅度需要目标设备实测。 | 词典视图及目标设备验收 |
| IMG_8961 · 含音节点的词头和加入按钮 | 从标识与展示去除词内音节点，保留标点语义和原历史数据，重复身份以既有别名合并。 | 真实 MDX 音节点用例、旧词条迁移测试 |
| 同词重复点击与快速移除 | 加入后可在浮窗和完整详情显式移除，首次加入可撤销。实际持久化后才更新状态。软删除保留历史。生词详情提供足够大的红色描边操作。 | `testRepeatedReaderLookupCanRemoveExistingWordFromDetail` |
| 语境短语 | 在点击位置前后各两词内，优先匹配最长且有 MDX 中文的连续短语。浮窗用短语义，生词本保存短语、原文词形、位置和选定义项。 | `testRealMDXReaderPersistsTheSelectedPhraseAndExactForm` |
| 两小时文章和词汇推荐 | 入口使用 App 前台激活。两小时以内不自动重查。文章共用发现进度；推荐保留上次本地结果，阅读门禁控制展示。 | `testForegroundRefreshTwoHourBoundaryAndClockRollback` |
| 输入结束与自动保存 | 去掉自定义完成输入按钮。失焦、隐藏键盘和离页继续提交，与输入法合成和失败草稿兼容。 | 设置、个人义项及笔记失败恢复 UI |
| 每日上限、大量新词和旧词复习 | 单组连线与每日总量独立。有 12 个合格词且释义可区分时，两组各 6。同释义分开到不同组。已保存的旧会话恢复原先的题组。到期旧词按到期先后，新词按加入先后；混合积压时给新词预留约四分之一，其余词留到后续周期。已经到期的准确标记为已到期，答题后按实际时间保存下一次到期。 | `testFiftyNewWordsAndDueRepetitionsDoNotCollapseDailyBudget`、`testDailyCapTwelveResumesTwoBoardsAndSchedulesEachWordOnce` |

## 当前验证

- 代码 `da94ab4651518c2300bf8bf690aeb306b3e75104`。宿主恢复及完整扫描通过。分包异常测试 8 项；MDX 2.0、UTF-8、38,774,534 bytes；校验 203,181 条索引记录及别名链。SHA-256 为 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。
- [受影响 macOS Actions](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44319154099)首批 App 与全部测试目标完成编译。该专项包含 Round 4 核心与受影响原生 UI，编译通过后仍需完成用例。
- 本批的长词条滚动、音频与实际 iOS 27 安装待目标设备验证。
