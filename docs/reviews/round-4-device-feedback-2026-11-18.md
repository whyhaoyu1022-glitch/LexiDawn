# Round 4 真机反馈整改

本表以负责人在 2026-11-18 提供的七张真机图及同批口述反馈为依据。原 Round 4 的 21 张整改图及 144 项账本沿用各自的历史证据。新改动的自动化和真机结果分别登记。

2026-11-19 再次逐张打开原 21 张 HEIC 的完整解码图（IMG_8854–IMG_8883）和三张词典原始参考 JPEG。原 ZIP 与单图 SHA 在打包时重新核对；最新构建截图独立记录，不把旧截图当作本批结果。

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
| 语境短语 | 在点击位置前后各两词内，优先匹配最长且有 MDX 中文的连续短语。支持词典的语法占位符，如 `look into sth` 与 `carry sth ↔ out`。浮窗用短语义，生词本保存短语、原文词形、位置和选定义项。 | `testRealMDXReaderPersistsTheSelectedPhraseAndExactForm` |
| 两小时文章和词汇推荐 | 入口使用 App 前台激活。两小时以内不自动重查。文章共用发现进度；推荐保留上次本地结果，阅读门禁控制展示。 | `testForegroundRefreshTwoHourBoundaryAndClockRollback` |
| 输入结束与自动保存 | 去掉自定义完成输入按钮。失焦、隐藏键盘和离页继续提交，与输入法合成和失败草稿兼容。 | 设置、个人义项及笔记失败恢复 UI |
| 每日上限、大量新词和旧词复习 | 单组连线与每日总量独立。有 12 个合格词且释义可区分时，两组各 6。同释义分开到不同组。已保存的旧会话恢复原先的题组。到期旧词按到期先后，新词按加入先后；混合积压时给新词预留约四分之一，其余词留到后续周期。已经到期的准确标记为已到期，答题后按实际时间保存下一次到期。 | `testFiftyNewWordsAndDueRepetitionsDoNotCollapseDailyBudget`、`testDailyCapTwelveResumesTwoBoardsAndSchedulesEachWordOnce` |

## 验证记录

| 提交 | 实际结果 | 证据 |
|---|---|---|
| `da94ab4` | 56 项核心 XCTest 和 9 项受影响 XCUITest 通过。 | [专项运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44319154099) |
| `946d418` | 57 项核心 XCTest 和 10 项受影响 XCUITest 通过。原生截图包含 applied 与 apply 的上下顺序、整段短语和移除既有词条。 | [专项运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44321906439) · [专项截图](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44321906439/artifacts/14436208453) |
| `5c1cd14` | 59 项核心 XCTest 中有一项失败。真实 MDX 的 `take account of` 和 `take sth into account` 共用义项，此版本只识别第一个标签。 | [专项运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44323377594) |
| `6df100d` | 修正共用义项的别名身份。仅选择失败用例，两次尝试在分配 macOS runner 前取消，没有执行此次复跑。全量回归和本批 IPA 待该用例通过。 | [单用例复跑](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44325053234) |
| `a101b35` | 真实 MDX 短语语法槽及共用义项别名、带音节点的独立词形迁移，2/2 XCTest 通过。已编译全部 App 与测试目标。 | [两项回归](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44417334553) |
| `0b7ec16` | 完成页“继续”明确请求下一批，去掉重复入口。额外复习重启、继续后空队列及不重复刚完成词的原生 UI 用例通过；截图导出成功。 | [单项 UI 回归](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44419033058) |
| `a9f9d5a` | 全量 245/245 XCTest 通过，iPhoneOS Release IPA 189 已检查。77 次 UI 执行有 9 次失败：主设备 59/67、SE 6/7、Pro Max 3/3。涉及 8 个主设备方法及 SE 冷启动重复执行，未作为最终通过结果。 | [全量运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44420940506) |

冷启动用例补上点击笔记标题空白区域结束输入，并明确检查键盘消失；保存状态和返回后数据校验均保留。先在 SE 和主设备只重跑该方法，通过后再执行最终全量；不恢复输入期间强行落盘的旧交互。

2026-11-19 补查：身份迁移排序的两端统一使用持久词形，防止音节点旧词覆盖已固定的独立 MDX 词形；测试验证重复迁移、笔记和两份学习状态保留。CI 固定 macOS 26 ARM 镜像。新建的隔离 Simulator 最多启动两次，每次有明确超时；失败保留诊断。旧任务普通取消未结束时，在复查 main 身份后强制取消旧运行，不删除运行记录或产物。所有专项回归通过后，执行最终全量验证与新 IPA 构建；该批结果待运行结束登记。

宿主恢复与完整扫描通过，分包异常测试 8 项。字典为 MDX 2.0、UTF-8、38,774,534 bytes，共校验 203,181 条索引记录及别名链。SHA-256 为 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。

自动化使用 Xcode 26.6 与 iOS 26.5 Simulator。长词条滚动性能、系统发音和覆盖安装仍需用本批 IPA 在 iOS 27 设备复测。

## 实现与数据兼容

| 模块 | 本批主要修改 |
|---|---|
| MDX 与语境身份 | `BundledMDXDictionary.swift`、`DictionaryAggregation.swift`、`BilingualDictionary.swift`、`EnglishPhraseRecognizer.swift`：独立词形、词干、语法槽、短语别名与选定义项共用真实 MDX。 |
| 生词与阅读 | `VocabularyRepository.swift`、`ReaderFeature.swift`、`VocabularyFeature.swift`：固定查询键、去音节点、历史合并、原文位置和显式移除。 |
| 词典排版 | `ReaderFeature.swift`、`InteractiveEnglishText.swift`：词形在前、词干在后，词性与编号义项层级、关联词布局、稳定高度与富文本缓存。 |
| 复习 | `ReviewRepository.swift`、`ReviewFeature.swift`、`LearningRules.swift`：每日总量、连线分板、旧词与新词队列、取消处理、真实到期标签、完成后继续。 |
| 自动检查与界面 | `LearningServices.swift`、`VocabularyRecommendations.swift`、`LexiDawnApp.swift`：两小时检查及推荐快照；探索、推荐、设置和搜索页面清理多余控件。 |
| 原生验证 | MDX / Round 3 / Round 4 XCTest、XCUITest，以及 CI 启动、分组与取消脚本。 |

[完整代码差异](https://github.com/whyhaoyu1022-glitch/LexiDawn/compare/4be478e2e778bea4da2095e65a637e5df117f7be...a9f9d5a66bb1aa8bbd39f623cfc0556b5cb243af)。本批相对该历史基线新增 9 个 XCTest、2 个主设备 XCUITest；已有方法保留并按新交互修订断言。

- 没有新增持久模型或删除数据库。既有 `dictionaryEntryID` 保存固定的 MDX 查询键，旧记录为空时按旧词头读取。
- 音节点合并保留重复词条为历史别名，迁移可重复执行；不清除笔记、上下文、学习状态或复习证据。
- 连线板使用既有题目 `position` 编码。旧位置仍属于原单板，已保存题组保持原题量、义项和掩码。
- MDX 派生数据与 `SHA + html-12` 绑定。缓存更新不能替换进行中复习题冻结的答案，也不能把外部历史词义改标为 MDX。

## 全量 UI 失败后的专项修复

- 导入表单与嵌套正文编辑器使用滚动立即收起键盘；个人词条滚动有稳定标识。测试手势限定在键盘上方的可见区域，不能在键盘上反复拖动后宣称控件不可达。保留输入、确认、保存、重开与版本更新断言。
- 真实冷启动场景改用正常生产来源注册表，移除只访问 Wikipedia 的测试限制。每个隔离测试数据库有对应的刷新偏好 suite，重启沿用相同 suite，不与其他测试互相抑制两小时检查。
- 多来源阅读遍历跨过 Simulator 午夜时，通过真实阅读和空队列复习操作完成新学习日，再继续原来源；不改系统时间，不注入完成状态。文章库在重大时间变化与回到前台时重新读取本地门禁。
- 单独复跑发生 Xcode 启动超时的首启方法。错误记录与原失败产物保留，不增加隐藏式重复启动。
- 专项范围为原失败的 8 个主设备方法及 SE 冷启动，共 9 次执行；其余 59 个主设备方法不在该轮复跑。通过后再做最终全量。
