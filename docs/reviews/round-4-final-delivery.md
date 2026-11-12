# Round 4 开发交付记录（持续更新，未完成最终验收）

## 2026-11-13 · 统一中文释义来源

已保存的进行中题组如果明确使用已停用词典，预检会归档原题、尝试次数与已有进度，并按当前 MDX 重新准备新题。若检测到既有排程日志，会报告完整性错误并保留原记录。正常 MDX 和已准入个人快照按原题恢复。

生词行按需读取内置 MDX。新复习题直接使用本次预检结果生成匹配、拼写和冻结快照，选择学习义项复用当前详情数据。个人义项仅在内置 MDX 确认缺少本词中文后显示和用于符合条件的新题。压缩浮窗时允许滚动内容，保留操作栏；嵌套详情打开时隐藏底层词条的辅助功能树。源码包含 236 项 XCTest 和 65 项主设备 XCUITest。Linux 已验证 8 项分包边界与真实文件全索引，原生回归及最终验收仍待完成。

上一代码提交 54cd607 的 [原生 CI](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43233166087) 为 236/236 XCTest，主设备 UI 41 通过、7 失败、16 取消，小屏分片取消，大屏 2/3。CI 导出 [255 张实际 Simulator PNG](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43233166087/artifacts/13961012885)。P14 新增原生通过与截图；详情三主题和系统发音有部分截图，仍有嵌套页面及大字号回归失败。[0.1.0(36) 未签名 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43233165869/artifacts/13951969362) 的打包任务校验了完整 MDX。以上结果均属于上一代码提交。

进一步复核了上一版 255 张原始 PNG 的 SHA，并查看了大字号浮窗、嵌套详情、连线、来源检查、RFC 与 P14 证据画面。文章库备用 RFC 展开后使用独立按钮，空状态成为单个辅助功能元素，原文短语入口不再藏在长义项之后。连线提交核验实际选项身份并显示个人来源。新版原生结果待 CI。

[54cd607 截图复核记录](round-4-simulator-visual-review-54cd607.md)。

## 2026-11-12 · 六组截图恢复与追加复验

已恢复 8538fdf 的全部六组原生附件并实际按原图核对画面。共 262 张 PNG，183 张来自通过的方法，79 张来自失败的方法。原件、参考和运行图均核验 SHA，已生成带逐图索引的 ZIP。对照结果保留测试失败、局部画面及缺图状态。

提交 fe2cde3 的独立校验 IPA 为 0.1.0(34)。App 内含 38,774,534 字节完整 MDX，SHA 一致。IPA 未签名，最低 iOS 27.0，原生兼容回归使用 iOS 26.5 Simulator。

fe2cde3 的 Debug 全测试目标与 Release Simulator 编译均通过。236 项 XCTest 中 235 项通过。真实词典补充页、visits 动词语境、nod 点头语境均执行了断言。唯一失败为所有格后的 visits 名词排序。本批增加所有格与数量词条件，并把复习选义输入改为已保存的真实词形。专项同时检查冻结义项及拼写答案，结果待复跑。

补了 P14 同一来源的两处真实点词，P17 真实 MDX 推荐及浏览不写入，P19 错误纠正、亲自重输和换题截图。发现页维持显式加入入口，加入后从推荐中移除，当前词典详情保持打开。当前源码保留 236 XCTest 和 64 XCUITest。

[21 图对照记录](round-4-simulator-visual-review-8538fdf.md) · [独立校验 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43230590749/artifacts/13950786810)。

## 2026-11-12 · 修复全量原生测试暴露的问题

前一提交 8538fdf 的 236 项 XCTest 有 235 项通过。唯一失败为真实 MDX 的 visits 在动词语境排到名词义项。63 个主设备 XCUITest 有 40 个通过，设备专项中大屏 3/3，小屏 5/7。已解包并独立核验同一提交的 0.1.0(30) 未签名 IPA 和完整 MDX。

本批修正原句词性排序、键盘上方的拼写提交、焦点变更时的设置保存、同一失败草稿的连续自动保存、词义选择与来源列表的无障碍标记，并恢复文章库次级 RFC 官方刷新。词典用同一原生详情内容，支持长义项滚动，保留参考布局。

修复截图索引对同名附件的处理，按 xcresult 测试与附件序号关联实际 PNG。已从五个分组恢复 207 张原始图，155 张来自通过的方法，52 张来自失败的方法。剩余分组通过 GitHub Actions 单独导出。逐图验收与最新代码复验仍在进行。

已重新打开 P04、P05、P06、P07、P08、P21 的对应原图与 8538fdf 运行图，以及三张词典参考和同一真实 MDX 词头的运行首屏。P04 的入口原先仅显示图标，文章库和探索现使用可见文字按钮。P07 的段落仍偏疏，现只用一个显示换行，并显示列表编号。原始正文与词元偏移保持原样。P21 的 nod 动词语境误把「打盹」放到首条，已补真实词义排序断言。F22 的 nod 补充链接确认为 MDX 中的同类词语页，现显示在可折叠的「另见」中。当前截图仍对应前一提交。新布局与词典链接待同一提交的原生复验。

[前一提交原生运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43041791921) · [前一提交 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43041791995/artifacts/13866535940)。

## 2026-11-11 · 原生验证与逐图整改

提交 `524d1ad` 的[原生运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236272)已通过 Debug 全目标和 Release Simulator 构建。235 项 XCTest 全部通过，包括 27 项真实词典/边界测试和 15 项文章网络测试。大屏 3/3 通过，小屏 3/7 通过。小屏四处失败涉及搜索空状态、实时文章词义资格、已完成连线滚动与保存重试。当前源码 236 项 XCTest、63 项 XCUITest，以上运行数字对应前一提交。

本批依据负责人“逐张图片，逐张原图进行对照”和“美观、简洁、实用”的指示。P02/P05 显示每个来源的实际检查或入库结果。P03 保留原始标题，展示时修正 ScienceDaily 重复编码的撇号。P07 按结构保留标题、引用、列表和有用图注，旧 DW 固定播放器提示按完整独立段落处理，阅读进度仍定位原正文。P10/P16/P17 词形与语境参与可靠义项排序。P14 将同来源上下文归组，保留各句。P15/F22 的共享阅读布局收起已保存个人义项的编辑控件。P21 在参考胶囊内分别提供返回与关闭，退出后检查原文词位置。

独立核验的[未签名 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236319/artifacts/13863316237)为 0.1.0(29)，arm64、最低 iOS 27.0，文件 43,822,877 字节。实际包内 MDX 为 38,774,534 字节，指定 SHA-256 一致。原生 UI 在 iOS 26.5 Simulator 运行。

- [235 项逐方法原生记录](../../artifacts/round-4/unit-43034236272.json)与[IPA 核验](../../artifacts/round-4/ipa-524d1ad-verification.json)。
- [大屏原始运行证据](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236272/artifacts/13864067867)及[小屏失败和通过证据](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236272/artifacts/13864741877)。
- [144 条矩阵](round-4-acceptance-status.json)中 83 条关联到此提交已执行通过的候选 XCTest，验收仍需独立核对。
- [21 张真实原图逐图记录](round-4-original-image-recheck-2026-11-11.md)与[原图对照矩阵](round-4-image-remediation-matrix.md)。截图发布脚本按原件 SHA、参考图 SHA、原生 PNG SHA 和 ZIP CRC 校验。当前工作区中断，尚未把上传原图与本次所有运行图合并成最终 ZIP。
- 本次提交使用 `[keep-native-evidence]` 保留前一提交尚在采集的原生图，并发启动本提交独立的完整 CI。

## 2026-11-11 · 原图映射与真实词典边界

原图审查提交 `c1e5220` 的 [43031419700](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43031419700) 完成全部目标与 Release Simulator 编译，234 XCTest 中232通过、2失败，15项真实文章网络测试全部通过。两处失败为实际 `do` 的索引还包含 `do.`、`doh` 等其他主词记录，以及 `hospital` 的原始参见含自身。双语用法和联想词读取本次已通过相关断言。新增真正匹配的词头分组优先和自链接去除，仍待原生复跑。

解析版本 SHA + html-8。直/弯撇号匹配同一实际记录，`don’t` 可识别为真实已收录但缺中文，个人资格由持久证据重新检查。按既有只使用英中释义的规范收起英英正文。保存的个人词义仅在 MDX 已确认缺中文时进入简明/完整详情，保持个人身份与复习确认规则。短语或习语不充当其父词的新题答案。同词新旧查询的资格提交按开始时间保护，冻结会话恢复路径保留。

这批源码235 XCTest、63 XCUITest。编译成功后即使某个 XCTest 失败，仍可复用同一产物运行 UI 分片和收集故障画面，整轮依旧报告 XCTest 失败。截图包新添 COMPARISON.md，把21个真实原图的文件名和 SHA 连到本次运行图；重复字节会标出。使用较早的42张原生图实际核对过索引和原 PNG 字节一致，这些图仍属于较早构建。

[IPA 43031420226](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43031420226/artifacts/13860649346) 下载后独立核验。43,810,680 bytes，SHA-256 `a49251f8d42e67d4bf0b6d34fac0499549bd316533bf810412c2f443b2f4815b`，0.1.0(27)、arm64、最低 iOS 27.0，App 内38,774,534字节MDX与批准SHA完全一致。该包未签名、未真机安装。

## 2026-11-11 · 21张上传原图复核与界面修正

已实际逐张打开用户上传的21张 HEIC，核对 ZIP 和逐件 SHA，复核具体圈注及相邻界面。三张词典参考 JPEG 也再次打开。详细证据在[原图复核](round-4-original-image-recheck-2026-11-11.md)，原图记录仍需逐项匹配最新版 Simulator 实拍。

[原生运行42923122043](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42923122043)通过全部目标与 Release Simulator 编译，233 XCTest 中232通过、1失败，15项真实文章网络测试通过。失败是实际 hospital 的联想词补充页只有词条链接，被要求有双语正文的旧解析器误报。已按两种原始 DOM 结构分别读取双语说明与参见，并继续核对例句译文。UI 当轮未执行。

当前解析版本为文件 SHA + html-7。保留同形词上标以外的实际词头，持久保存同 SHA 的派生记录位置以便清缓存后仍可重查短语。详情中展示真正的 MDX 英文释义，中文资格和复习答案仍只用可靠中文。补齐自动保存回读状态、来源进度去重、标题实体/异常换行、搜索与筛选、阅读副标题和复习提示等界面改进。当前源代码234 XCTest、62 XCUITest，等待本批原生验证。

当前不能宣布 Round 4 完成。下面只列实际代码和运行证据；144 项、24 个测试族、所有截图与最终 IPA 尚未全部关闭。

## 仓库与提交

- 仓库 whyhaoyu1022-glitch/LexiDawn，核实初始 main 为 `30311f806d587453c601a0a44bf5cc8a6c338ec4`。
- 全程直接 main，无新分支/PR。首批 `5d54f21f410ebadd43c2ceed548075ae5362fcb3`，第二批 `d186c9f29e84c6ec91babdc624830c04fe4f7929`，第三批 `47397084871c8fff6db9932674f6777c42d75b29`。
- Linux 本地无 Swift/Xcode/Simulator；原生构建、测试和截图由 GitHub Actions 的 macOS/Xcode 执行，不能把宿主 C/Python 检查算作 iOS 测试。

## 实际新增与改动

| 层 | 文件 | 代码变化 |
|---|---|---|
| 原生引擎 | `LexiDawn/Data/MDX/MDXReader.c/.h` | 有界文件读取、MDX2 头/索引/记录块/校验、按需解压与单块缓存 |
| DOM 桥 | `LexiDawn/Data/MDX/MDXHTML.c/.h`, `MDXBridge.h` | 系统 libxml2，禁止网络解析，不执行脚本/媒体 |
| Provider | `LexiDawn/Data/BundledMDXDictionary.swift` | Swift Actor，惰性 SHA 验证与索引、128 词 LRU、内部链接、原 HTML 结构化义项 |
| 词典策略 | `DictionaryAggregation.swift`, `BilingualDictionary.swift`, `VocabularyRepository.swift` | 唯一 MDX、类型化错误、版本缓存、中文资格锁定、个人多词性/义项与历史导出 |
| 复习 | `ReviewRepository.swift`, `LearningModels.swift`, `ClozeContext.swift`, `ReviewFeature.swift` | 冻结义项/原句/词形/掩码；反馈身份；揭示后纠正与 Again；实际数量、延期与幂等 |
| 原生 UI | `ReaderFeature.swift`, `VocabularyFeature.swift`, `DictionarySearchView.swift`, `SystemPronunciation.swift` | 共享完整详情、小浮层、离线搜索、独立词条、结构化个人编辑、系统 TTS、保存与错误状态 |
| 文章/设置 | `ArticleNetwork.swift`, `LearningHome.swift`, `ArticleLibraryFeature.swift`, `SettingsFeature.swift` | 真实共同发现进度/阶段、明确停止、设置自动保存失败重试与关于页 |
| 构建 | `project.pbxproj`, `bundle-dictionary.sh`, `verify-bundled-dictionary.py` | 构建中恢复 MDX、实际 App/IPA 资源校验，移除旧词典资源 |
| 验证 | `MDXDictionaryTests.swift`, 原单元/UI文件、CI与证据脚本 | 保留原方法；迁移旧交互/来源断言；真实文件/磁盘/资源错误/截图证据 |

该表表示存在代码，不表示每一项已通过所有环境验收。完整文件清单以基线到 main 的 git diff 为准。

## ZIP 恢复与实际格式

原 ZIP 保留。按仓库 `Dictionary Data/merge.py` 的 manifest 顺序恢复，分块和整文件校验没有绕过。恢复文件：

- 38,774,534 bytes。
- SHA256 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。
- `file` 只识别为 data；格式确认依据实际 UTF-16LE XML 头、MDX2 结构及完整块解析，未把 `file` 输出冒充格式证明。
- 实际 RequiredEngineVersion=2.0、Encoding=UTF-8、Format=Html、Encrypted=No。218 key blocks、203,181 索引项、4,419 record blocks、270,665,044 解压记录字节。
- 宿主原生 C 扫描全部记录：151,528 内部链接、51,653 HTML 记录；块校验、UTF-8、目标存在与无环检查通过。索引数包含别名，不冒称有 203,181 个独立定义。
- 8 个 ZIP 故障/恢复测试通过：缺任一包、manifest 不同、分块缺失/顺序/SHA、整文件 SHA、正确恢复。失败保留先前有效输出。
- 宿主证据：[mdx-host-verification.json](../../artifacts/round-4/mdx-host-verification.json)，明确记录源码状态与 C 源哈希。

格式参考：[FreeMdict](https://freemdict.com/2018/09/29/decompress-mdd-mdx/) 与 [writemdict/fileformat.md](https://github.com/zhansliu/writemdict/blob/master/fileformat.md)。本项目引擎针对这份实测文件格式；不宣称支持任意版本、编码、LZO 或加密 MDX。

## 实际 App Bundle 与 IPA 边界

Xcode Build Phase 在中间目录运行原 merge.py 并验证，复制单一 `BundledDictionary.mdx` 到实际 App Resources，再检查大小、SHA、头。运行时没有 Python、ZIP 合并或 GitHub 下载。2026-11-09 两轮原生 Debug build-for-testing 均实际检查该资源并成功，证据在各构建日志及 MDX XCTest。

第三批 arm64 Release IPA 已有实际成功产物，见下面新增证据。当前布局/例句修复仍须重新构建，不能沿用旧SHA作为最终交付。打包脚本验证 IPA 内 MDX、CRC、实际 Info.plist、架构、图标与签名状态；当前最低系统版本为 iOS27.0。CI iOS26.5兼容结果不等于 iOS27真机验证，未签名包也不等于已安装。

## 数据保护与迁移

FrozenRound3Schema.ArticleRecord 的 candidate 映射从真实历史代码恢复，完整映射来源/正文/主题/权利/缓存等字段，未改冻结存储字段。第二轮真实历史 schema 磁盘升级通过；原始正文、结构 Data、哈希、笔记、上下文、周期/排程和关系在两次重开后核对。

新增字段为 optional；旧多 Provider 缓存保留历史，不转成 MDX。旧个人字符串逐字保留并迁为未确认 legacyPersonal，不猜词性、不自动成为新题答案。个人编辑与删除保存前一完整修订；笔记独立，用户内容/周期/日志不被普通缓存清理删除。新题查询唯一 MDX 后冻结快照，正在进行的有效旧题不暗换答案。

首次运行失败定位在历史测试夹具缺合法主题/原词数，以及重新编码 JSON 的非固定键序比较；修正夹具并保留原始 Data 比较断言，没有放宽生产全文门禁或删迁移测试。

新增个人义项真实磁盘重开、资源错误后资格撤销/重试、独立词条和额外延期测试仍须以最新完整运行结果核对，不能借用已通过旧提交。

## 已完成的原生运行

| 提交 / Actions | 实际结果 |
|---|---|
| `5d54f21` / [42647936727](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42647936727) | 所有目标编译成功；12 MDX 测试通过；22 Round4 方法中迁移方法 4 个断言失败；整体失败，无 UI/IPA 通过结论 |
| `d186c9f` / [42650595539](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42650595539) | 所有目标编译成功；12 MDX + 22 Round4 全部通过；10 UI 中 8 通过、2 失败；导出42张实际 PNG；整体失败 |

第二轮 UI 通过：真实 MDX 首/中/短语详情与发音调用状态、真实资源缺失/损坏、加载/空/失败、真实服务发现/取消、个人自动保存进程重启、可见多连线与恢复/纠正、预检明确延期、10次旋转/三主题。发音测试仅验证 API/状态，不冒称听音验收。

两处 UI 失败保留：参考布局查找 v. 词性头时滚动越过目标；关于页 LabeledContent 被旧 StaticText 定位方式误判。已修改滚动方向判断及实际标识/开发者值核对，需复跑证据。

第二轮 [原始 artifact](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42650595539/artifacts/13692760176) 包含 xcresult/日志/原始附件/PNG ZIP。直接下载接口重试后成功；42张原始PNG已下载并逐张核对SHA，实际逐图视觉复核进行中。保留原图，不重新画图、改图或冒充后来提交截图。

## 144 项、24 测试族和截图

机器合同保留原108 + 补充36，共144唯一验收ID、24功能/测试族；F16/F23按最新唯一 MDX 规则替换来源冲突，其他原图与 UI/个人词/复习合同保留。

当前只有部分专项证据，**144 项均未被整体签为通过**。截图索引必须记录实际提交、设备/iOS、方向/主题/字号、方法、图片SHA、结果与 Fixture/真实数据性质。索引中的关联不等于验收成功；未截图功能明确标缺失。不得用42张部分截图宣布21项全部完成。

源码方法数量：原208单元保留，加25个MDX专项为233；原57 UI保留，加5条真实 MDX/错误/搜索/三主题/今日库存路径为62。这个数量不代表执行结果，也不代替24测试族逐项证据。完整测试分片仍覆盖所有方法，单组失败不再取消其他组。

## 尚待完成与已知限制

- 第三批227单元、Debug/Release和IPA成功；UI被跳过。当前230单元、61 UI及设备专项、修改后Release/IPA仍须完整验证。
- 全部21项反馈的对应截图、词典首/中/末及三主题/横屏/大字、重要失败状态的完整包尚未逐图验收；现42图属于第二次提交的部分证据。
- 144项/24族尚待逐条整理代码、运行和视觉结论，不能以计划或测试数量代替。
- 长词条的用法说明、内部参见导航等非主要字段覆盖仍需逐项核对，不能宣称所有原HTML信息完整展示。
- iOS27 SDK/真机、本次未签名IPA安装、完整VoiceOver听读及Instruments没有本轮实测结果。

工作继续；只有最终证据补齐并修复剩余问题后才能将本报告改为完成状态。

## 2026-11-10 新增证据与按参考图修正


main `47397084871c8fff6db9932674f6777c42d75b29` 的 [42657203329](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42657203329) 完成 Debug 全目标、Release Simulator 和全部 227 XCTest（0失败，包括19 MDX专项）。该轮 UI 与截图合并因 skipped 祖先的隐式 success 条件被跳过；整体绿色**不等于完整 UI 通过**。本批为 UI 显式声明 always/未取消/构建成功条件，新增所有分片必须成功的门禁和逐方法实际执行核对。

[未签名 IPA 42659832536](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42659832536) 实际产物已下载独立检查：43,719,709 bytes，SHA256 `06b6eb6d9552221d6387b77893d23476d7edb9f0d746d35f761af6b6aadb04f6`；arm64 Release，iOS最低27.0，0.1.0(20)，内含38,774,534字节及指定SHA的完整MDX。未签名、未真机安装，不等于iOS27运行验收。

第二轮42张原始PNG已成功取回，逐张SHA核对通过，正在实际逐图检查。发现词典音标重复、整段例句强调色、状态栏区域文字、习语结构漏识别、主题截图被外观面板遮挡等问题，本批修复并扩展真实MDX三主题首/中/末及横屏大字截图。源代码新增范围/例句身份冻结，避免重复词误挖空及借用其他个人义项例句；MDX子词条从原文件重新解析，缓存只作记录号索引提示。

当前源码230单元/61 UI方法，新增3单元与1 UI尚待本批原生执行。原21张HEIC当前不可访问，逐图依据仓库原审核和机器清单；三张JPEG词典参考图本批再次实际查看。144项/24族和全部截图尚未整体关闭，工作继续。


真实 IPA artifact：[13692674476](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42659832536/artifacts/13692674476)。下载实际IPA后运行 `scripts/verify-bundled-dictionary.py --ipa` 通过，确认资源进入最终 `.app`，不是只检查pbxproj。Xcode26.6(17F113)/SDK26.5兼容工具链，signed=false、installedOnDevice=false。

词典当前解析版本为批准MDX SHA + `-html-5`。`t-idm-g` 与 `t-idm` 按实际HTML识别；父词音标不赋给短语/习语，搭配与双语例句一一分组；名词/动词 A/B、圆圈编号、PHRASAL VERBS/IDIOMS分节、44pt发音/关闭按钮与底部胶囊，仍须实际新图验证。没有按参考图编造实际MDX不存在的词性或字段。

## 2026-11-10 · 逐图42张复核与新原生回归问题

`567840f3f04b4182f31c7853278cf1034a1f340b` 的 [42918659786](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42918659786) Debug全目标/Release编译成功；230 XCTest中229通过、1失败，22个MDX专项全部通过，真实文章网络15项全部通过。UI依赖单元关卡而未执行，整体失败。

失败是历史夹具在清空sourceContext模拟旧schema时，仍带本轮新加range字段；生产完整性校验正确拒绝。已在该历史夹具同时清空当时不存在的range/exampleID可选列，所有原answer/prompt/attempts/hint/恢复断言保留；另用真实已保存新题破坏range验证必须报错且不删题组。修复尚待新原生运行。

旧提交d186c9f的42张实际PNG已全部逐张查看及SHA核对，[逐张发现/修改记录](../../artifacts/round-4/screenshots/VISUAL-REVIEW.md)。它们不是新修改后的最终截图。原21张HEIC缺失，依原逐图审阅与机器清单；三张词典JPEG已实际查看。新增[原21项逐项整改矩阵](round-4-image-remediation-matrix.md)与[144项逐条未关闭状态](round-4-acceptance-status.json)，不把关联索引当通过。

本批继续实际修复：选择连线的文字提示、键盘/拼写区自然高度、显示答案收键盘及纠正状态、延期专用文案、真实全部本地数量；结构化个人编辑收起高级可选项但保留全部字段。解析HTML5保留词条内原始义项位置、双语用法提示/真实参见，例句点词携带实际所在例句全文。旧MDX缓存只作经相同SHA校验后的记录号索引提示，内容必须重读；同一SHA已知中文不会被后续空结果解除锁定。当前232单元/62UI源码，不代表本批已经执行通过。

## 2026-11-10 · 补充用法记录与截图结果关联

`00f287e7722ee9d35215d43e70973c231683dc52` 的 [42922034693](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42922034693) 在新增测试的旧缓存夹具构造中编译失败：误给DictionarySense的let中文字段重新赋值。已改为独立构造历史测试sense，生产只读模型未改弱；该次没有执行单元或UI，不报通过。

继续接入同一MDX内部链接指向的用法补充记录，保持双语说明/例句逐条对应及原记录身份，缺补充内容真实显示错误细节；不向网页、MDD或其他词典取数据。解析版本SHA+html-6。新增真实hospital用法补充测试待执行，源码233单元/62UI。

截图导出器修复测试类模块前缀差异，并按截图设备关联该设备对应的测试日志，防止主设备通过覆盖SE失败。用旧xcresult原始附件和日志实测重新索引42张：37张来自通过方法、5张来自失败方法，实际10方法8通过/2失败。PNG逐张SHA不变、CSV列不重复、40张有具体验收关联；2张失败诊断不冒认功能验收。没有把图片数量当成验收通过。

Release及IPA校验增加退役在线词典域名不得出现在实际可执行文件的门禁；已下载的旧4739708 IPA实查这些域名均不存在。这是二进制检查和生产调用链证据，不冒称对最新代码已完成全时段网络抓包。
