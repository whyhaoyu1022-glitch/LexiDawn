# Round 4 开发交付记录（持续更新，未完成最终验收）

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

源码方法数量：原208单元保留，加22个MDX专项为230；原57 UI保留，加4条真实 MDX/错误/搜索/三主题路径为61。这个数量不代表执行结果，也不代替24测试族逐项证据。完整测试分片仍覆盖所有方法，单组失败不再取消其他组。

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
