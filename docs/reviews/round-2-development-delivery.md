# LexiDawn Round 2 开发交付自述

日期：2026-10-31。本文是开发方自述，不是独立验收报告。所有历史审核与整改文件保留。正式验收须复核源码、固定提交和实际 Actions，不以本文声明代替验证。

## 1. 基线与真实新增功能

重新核对起点 main 为 `4ccfbfb472a2f079523613b4386123a349c4347b`，其父提交才是任务书参考 `706078c07aab0f4f8cc61983a383c5237e413c86`。起点已含 Round 2 批次 1，不能把其中所有代码说成本次继续开发新写，也没有覆盖回旧 SHA。本次在其上补充可操作的文章库与阅读历史、首页元数据和进度、探索去重、阅读器外观菜单、详细词典的生词管理和英文点击、中文释义搜索、学习事件统计、合法重新取得同版正文、错误隔离，并增加真实 UI/磁盘/网络/故障证据。

| 模块与 SPEC | 用户可以实际操作的行为 | 关键代码 |
|---|---|---|
| A §12/19.1/21.3 | 启动可读官方 RFC；导航栏导入有权本地使用的英文；预览字数时间；自行选择是否进入未来每日候选；官方刷新有超时/退避/恢复 | Data/ContentRepository.swift、Domain/Learning/LearningRules.swift |
| B §2.5/6/19.2 | 今日打开原生阅读器、逐段滚动、退出后续读、前后台保存；明确常规/手动完成；阅读器菜单保存字号和主题 | Features/Learning/ReaderFeature.swift、InteractiveEnglishText.swift、Data/ReaderRepository.swift |
| C §6.2/7/8 | 点识别到的英文词、查看当前句子和开放词典可能对应、无结果/加载/错误、详细页系统朗读；详细英文和上下文继续查词，深度有界 | ReaderFeature.swift、VocabularyRepository.swift |
| D §7.5/9/19.4 | 默认查词自动加入；关闭后手动加入；重复词幂等；新建安全撤销；搜索英文/已缓存中文，区分词与短语，保存笔记和个人释义，确认移除 | VocabularyRepository.swift、VocabularyFeature.swift |
| E §10/19.7–19.8 | 从本地新词和到期状态建立固定会话；点英文和中文完成配对；拼写输入、错误重试/提示/显示答案；保存结果、日志、排程和周期；合法空队列不阻塞 | ReviewRepository.swift、ReviewFeature.swift、LearningRules.swift |
| F §4/16 | 当前真实文章 hero、来源主题/时长/进度/原日期/逾期、三项任务状态与操作、真实统计；文章库和历史继续阅读 | LearningHome.swift、AppCore/LearningServices.swift |
| G §5/11 | 昵称/年龄/目标/兴趣、字号/行距/主题、自动加入、复习上限和学习时区保存；探索锁定说明和继续今日；完成后显示合法未使用文章 | SettingsFeature.swift、LearningHome.swift、LearningServices.swift |

路径均相对仓库 `LexiDawn/`。生产已使用 LearningRootView，今日/词汇生词本/复习/我的均是实际页面；Reader、查词浮窗和详细词典已具真实行为。Round 1 的旧占位视图保留用于显式隔离回归，不是生产 root。词汇 Tab 按本轮用户要求承担核心生词本；高级词汇推荐仍未实现。

## 2. 数据与迁移

批次 1 增加 ContentGrant、SourceAcquisition、ArticleProgress、VocabularyEntry/SourceContext、DictionaryEntry/Sense、ReviewState/Session/Exercise/Log；职责互相独立。继续开发批次未删除、重命名或重建这些实体或 Round 1 列。

原数据库 URL 不变；打开前保留 store/WAL/SHM 冷备份，单独 before-round2-features 备份代际；失败不清库。旧模型由两份冻结历史 schema 创建真实磁盘库后升级；本轮另外实际写入和重开新学习数据库，读取正文、位置、词条、设置和固定题组。仅支持单应用容器串行 MainActor 写入口，不自称有跨进程数据库锁。

写入经 RepositoryWriter：独立 context、关闭 autosave、失败 rollback 且弃用上下文。进度与阅读完成证据/周期同一次提交；最终复习答案、结果凭据、全部日志、排程及周期同一次提交。故障测试验证失败不残留孤立词条、来源上下文、状态、答案或日志；重试继续原题。读失败/写失败均不显示已完成。

未完成周期优先、每日文章唯一、阅读与复习独立、合法证据、原内容 hash、时区日期与旧库审计恢复规则继续保留。授权过期清正文而保留文章标识/历史/进度/词条；重新获取仅恢复同一核验版本。时钟高水位只防已经观察到的到期被回拨复活，不能保证识别设备从未观察到的时间变化。

## 3. 来源与许可

- RFC Editor 官方原文：<https://www.rfc-editor.org/rfc/rfc8890.txt>，M. Nottingham，2020-08，保留全文、版权、署名和声明。
- IETF 官方 TLP 5 §3(c)(i)：<https://trustee.ietf.org/documents/trust-legal-provisions/tlp-5/>，允许全文不改动的复制/展示/分发。本轮重新读取官方条款，不将其标成公共领域；不使用图片，不概括为普遍衍生授权。官方请求与随附原文指纹必须相同。
- 用户导入：来源标为 user-import，授权依据仅本地声明；不上传、不公开分发、不自动访问原 URL，不推断第三方公开版权。私有 URI 与原始 URL 分开，原 URL 参与去重。
- 词典：MDBG 官方 CC-CEDICT <https://www.mdbg.net/chinese/dictionary?page=cc-cedict>，2026-10-30；官方页面明确数据为 CC BY-SA 4.0。本地 JSON 是反向索引，同许可分发并保留源行。它提供可能的中文对应词和原英文 gloss，不声称确定语境义。没有英语 IPA/词性/例句时说明来源未提供。
- 许可与变换说明：`LexiDawn/Resources/CONTENT-LICENSES.txt`；生成工具：`scripts/build-cedict-index.py`，只读取用户下载的官方 gzip，不抓取 MDBG 网页。当前 21,579 个反向 key；源行 smoke check 已本地执行，未重新下载完整 gzip 重建全部索引。

普通网页、摘要权限或未经核验的来源不能通过全文入口。没有商业词典复制、付费 API、长期客户端密钥或 AI 假释义。缓存与生词实体分离；缓存删除不移除生词。

## 4. 实际可体验流程

1. 使用兼容工具链运行生产 App：首次有官方真实 RFC 原文；今日点开始阅读。或从导航栏导入自己有权本地使用的英文，确认授权声明与未来每日分配开关。导入不替换旧未完成周期。
2. 滚动文章、返回今日、退出重开再进入，恢复接近原可见位置。正文按原有段落渲染，大屏限宽，动态字体和纸色/浅色/深色可用；返回不丢位置。
3. 点击英文词，默认本地加入后显示浮窗。已有词不重复、没有误删式撤销；关闭自动添加时手动加入。详细页可朗读、管理生词并继续点英文查词。
4. 生词本查找、编辑个人释义或笔记、查看来源上下文；删除需明确确认。无可靠中文的词可填写标为个人内容的释义用于复习，不伪装成词典。
5. 明确完成阅读后，复习未完成仍保留周期。复习页完成点击配对，再键盘输入拼写。完成保存后今日显示任务清空、探索解锁；同一答案重提不会重复排程或计数。
6. 文章库/历史保留已分配、已开始、已完成和授权失效元数据。未分配文章按探索门禁进入；已分配文章从原周期继续，不把它重新指派为探索。探索默认不推荐已开始内容。

排程为 lexidawn-basic-1，不是 FSRS。Good 为 max(4,上次间隔×2)天，Hard 为 max(2,上次间隔+2)天，Again 为1天，上限3650天；同样输入固定输出。题目和掩码持久化。学习日只计有效阅读完成或整次非空复习完成，使用真实事件时间，不把原分配日当作完成日。

## 5. 测试与 Actions

源码现有 93 个 XCTest 方法、13 个 UI 方法；这只是清单，不是运行通过数。本地无 Swift/Xcode，因此 iOS 运行证据只来自实际 Actions。应用代码93 XCTest/13 UI已实际通过，见下方最终代码证据；后续测试定位和文档提交仍单独核对。

| 提交/运行 | 实际结果 |
|---|---|
| 基线 4ccfbfb / [41176478882](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41176478882) | success；已读取完整日志：71 XCTest/0失败，8 UI/0失败；只证明起点 |
| 037e0b5 / [41178666260](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41178666260) | app 编译失败，测试未运行；已修复持久化字段名错误，不掩盖失败 |
| 17b9dd2 / [41178773199](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41178773199) | app/test target 编译通过，unit step success，88 XCTest/0失败；12 UI/4失败，根因见下文 |
| ab8da39 / [41179258125](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41179258125) | 91 XCTest/0失败；12 UI/4失败（相同词元/Toggle问题） |
| 67174fb / [41179938274](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41179938274) | 91 XCTest/0；13 UI/5失败，包含新增详情用例 |
| 0e8a0ba / [41192856507](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41192856507) | 91 XCTest/0；13 UI/2失败，词元/开关修复生效 |
| 2f46b18 / [41193034745](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41193034745) | 92 XCTest/0；13 UI/2失败 |
| ce21104 / [41194143665](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194143665) | 92 XCTest/0；13 UI/1失败，详情嵌套返回通过 |
| 8e59f0e / [41194173024](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194173024) | 92 XCTest/0；13 UI/1失败，完整学习流程通过，单次重启导航失败 |
| fcac01b / [41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) | **93 XCTest/0；13 UI/0，success** |

新增测试覆盖：原 URL 去重、非候选导入在库可见、探索双门禁和排除已使用、精确授权到期/离线/回拨/撤回/恢复、唯一段落锚点、具体句子、词条和最终复习事务故障、缓存删除保留、完整 eligible 缺状态报错、实际学习日、真实官方网络与429/timeout、到期/上限/跨日新周期、3504词分词及二分命中 measure、新模型磁盘重开。原61回归和两旧schema迁移没有删除或降级。

五个新增 XCUITest 实际运行 App：完整阅读/查词/生词搜索/两阶段复习/探索解锁、滚动退出重启恢复、设置和自动添加/手动加入/撤销、空库填写生产导入表单、详情和嵌套英文查词返回。测试库由 DEBUG 模拟器显式开关及独立 UUID 隔离；另有生产真实源及数据库集成，fixture 不进入 Release。

xcresult、完整 unit/UI 日志及 keepAlways 原生截图由现有 workflow 上传；应用代码 artifact 为13040631627；交付源代码基准（含测试定位增强）为1b2e26b39c33aff434298ab141eff426725caf24，后续文档提交不自引用未知SHA，精确main HEAD与其运行在最终交付答复列出。产品27.0/兼容CI26.5严格区分，不代表iOS27/真机/签名IPA。编译警告和故障用例预期 CoreData 日志将在最终 job 完整日志核对。

## 6. 尚未交付或未验证

- 完整 FSRS、额外复习轮、丰富短语变形识别、语境消歧、完整英文词典的词性/IPA/例句/词源/近义词辨析。
- 更丰富合法文章来源、主题质量排序、高级词汇推荐、导出、通知/后台刷新/AI代理、签名IPA。
- 真机、iOS27工具链、最大动态字体/深色/高对比/小屏/横屏完整人工验收、VoiceOver全流程、Instruments滚动帧率和主线程分析尚未执行；有基础标签、动态缩放和微基准不等于这些已通过。
- 探索完成日目前按所选时区展示；未来应保存独立事件时区以减少旅行后的历史重算。没有可信硬件时钟或跨进程并发保障。
- 当前单来源耗尽后应合法导入更多内容，不伪造推荐；无可靠中文对应需用户个人释义才能出题，不会把未解决释义的队列假定为空。

93 XCTest/13 UI的应用代码运行已验证最小学习闭环；这不代表整个 SPEC §25、M2–M5全量、iOS27/真机或独立验收通过。


### 历史 UI 故障追踪（当时状态，后续通过见第7节）

67174fb / run41179938274：91 XCTest/0，13 UI/5失败。原8 UI均继续通过；新用例失败集中在词元不可见和Toggle外层行点击。实际下载17b9dd2的artifact13034590947并解码zstd/AX记录：UITextView仍暴露段落，导入授权为0且保存disabled。改用UIView词级AX容器，明确隐藏TextView系统段落AX，布局后生成词元；测试点击内层原生switch，并增加即时值和保存成功精确断言，没有删除原失败断言。新增UIKit真实布局/glyph物理点击及标点拒绝回归。该阶段修复0e8a0ba4caef789512ea5b2e93ac9138b8b0c005的run41192856507当时尚未结束；后来结果为91 XCTest/0、13 UI/2失败，最终通过证据见第7节。


## 7. 已结束的应用代码最终验证

- 应用业务代码 SHA：`fcac01b3d40b311b51c7a0fea4e6329d0300ca92`。
- [Actions run41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948)：success。93 XCTest/0、13 XCUITest/0，106个精确方法名逐项比对，无遗漏。原61 XCTest和原8 UI全部保留并通过。UI用例合计615.006秒，微基准平均0.024秒且相对标准差23.705%，不承诺固定性能。
- [artifact13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627)：6,982,373字节，unit/UI xcresult及完整日志、keepAlways原生截图。
- 完整真实操作场景（阅读/查词/搜索/连线/拼写/解锁）、滚动退出重启与可见词元位置恢复、设置持久化与手动加入撤销、表单导入、详情嵌套查词返回均通过。官方RFC真网络请求成功测试、429/timeout替身、真实SwiftData事务故障、旧schema和磁盘恢复同属93项，不把mock当真实联网。
- 日志仍有AppIntents未依赖导致metadata skipped、已签名测试framework未strip、Node/punycode等runner弃用提示及multiple destination提示；故障测试预期CoreData259/SQLite26、只读save513。未发现新的Swift源代码编译警告，不声称日志没有任何系统错误/警告。
- 8e59f0e的run41194173024曾有1个重启导航失败；其AX显示首页持久化27%正确但单次自动化tap没有进入阅读器，无存储错误页。1b2e26b增加foreground/hittable等待与一次坐标触摸，所有恢复断言保留，需其后续运行单独验证。
- 本报告自身为后续docs提交；精确最终SHA无法预先写入自身。以最终答复和本文件GitHub History核对，不把fcac01b的run冒充后续SHA证明。

### 可复核代码与文档

- [阅读器/查词/首页/生词/复习/设置](https://github.com/whyhaoyu1022-glitch/LexiDawn/tree/main/LexiDawn/Features/Learning)
- [数据模型及Repository](https://github.com/whyhaoyu1022-glitch/LexiDawn/tree/main/LexiDawn/Data)
- [规则与排程](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/Learning/LearningRules.swift)
- [Round2 XCTest](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/Round2Tests.swift)、[UI测试](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnUITests/LexiDawnUITests.swift)
- [需求追踪](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/requirements-traceability.md)、[测试计划](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/test-plan.md)、[开发日志](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/daily/2026-10-31-round-2.md)


本文CI表为已经结束的应用代码运行记录。最终文档和测试定位增强提交自己的CI在交付答复单独列出；不将运行中状态预填为成功。后续独立验收应使用答复中的最终main SHA、Actions及artifact核对。
