# CURRENT · Round 3 架构与数据模型

最新核查运行41357763875：182单元/0失败、主full-2 12/0、SE7/0、大屏3/0；full-4导出文件名断言失败（13/1），上传CreateArtifact另连续超时，其他取消。full-3获runner晚约11分钟，不能把排队/未完成视为失败。本次补充真实文件名可访问显示、系统实际保存回调反馈、取消/重试/过期结果保护，以及附件上传重试；原文件名断言保留并扩展到真实Save。新增三项截图要求，共137项，新原生复验待CI。 [核查证据与规格依据](reviews/round-3-ci-41357763875-repair.md)。

沿用 SwiftUI → ViewModel/Service → Domain/Repository → RepositoryWriter → SwiftData。网络不在 View，数据库操作在 Repository；UI只维护选择与草稿。每次写使用独立 context，关闭 autosave，同步 save/rollback，读取用新context，不复用失败上下文。

## 文章链路

`ArticleSourceRegistry/Audit → ArticleDiscoveryService → ArticleFetchService → ArticleWebPageExtractor/ArticleHTMLExtractor → ArticleDocumentNormalizer/QualityValidator → ContentRepository.importFullText`。候选只在内存，ephemeral URLSession无cookie/磁盘缓存、固定HTTPS白名单重定向、有限重试/退避、最多3来源并行。并发refresh加入同一Task；取消在持久化前检查。失败日志仅来源/诊断码/时间/计数。

ArticleRecord旧bodyText物理列为rawContent，新增structuredBody、author、rights evidence、extractionVersion、completenessVerifiedAt、favorite/readLater等optional列。正文与结构/证据同事务，canonical和SHA去重；失败不覆盖旧有效版本。个人模式importBasis与出版社授权scope分开。新增 `ArticleContentVersionRecord` 原样保存个人原文旧版本；只解锁后未指派user-local可显式更新，旧完成进度归档，不更改每日原文。

启动先before-round3冷备份、幂等回填；不完整或授权不可证明旧文章迁入 `ArticleHistoryArchiveRecord`，保留周期/生词/日志引用，不回流推荐/阅读。未知schema/迁移失败保留原库报错，不清库。

## 门禁与阅读器

ArticleLearningAccess以最早未完成周期为current，所有库/历史/收藏/稍后/探索及Reader打开/save/complete复用；全部必做完成且当前学习日有完成周期才允许自由阅读。收藏只改标记。探索开始写真实进度，重置需确认并归档；不会建每日周期。

ReaderTextProjection维护显示重排到原始UTF16映射，raw/hash不变；TextKit渲染原结构、动态字体、点击及复用可见词元AX。版本变化仅按唯一原段落恢复，否则回首并提示。Reader全页/导航/浮窗共用主题。简明词典仅最多2条原始义项（有中文时优先），详情保留全部；嵌套最多3层。

## 词典与生词

DictionaryAggregator并发隔离两英语Provider；本地CEDICT由actor加载。义项按原始POS/内容/来源合并，NL词性与词汇重合、可用时本机句向量排序，不生成或改写词义。DictionaryCacheRepository按语言/lemma/provider/version，30日新鲜；离线旧缓存保留实际获取日期。WordLookupModel generation丢弃过期UI结果。Provider失败不抹掉其他成功结果。

VocabularyEntry保留词形/语境/个人释义/笔记及安全撤销凭据。确认的中文义项ID/原文/证据独立持久化；清缓存不丢用户选择，修改个人释义后切换，固定旧题不变。查询基于一次快照，不逐搜索字符重读数据库。JSON/CSV只由用户主动原生导出，不上传。

VocabularyRecommendationService从真实完整正文提取实际词形与偏移、排除本中lemma，再查真实词典；锁定时拒绝，无结果不补造；详情/嵌套关闭自动加入，仅明确加入写本。

生词详情将唯一释义/笔记保存动作放在导航栏，键盘存在时仍可访问；成功反馈仍依赖真实Repository写入和读回。文章库同一List行内按钮显式隔离样式；重置确认捕获呈现文章快照，避免关闭绑定时丢失对象或同行误触打开阅读器。空探索池与仅筛选无结果分别说明，均不创建替代文章。

## 复习

MatchingBoard用AnchorPreference/Canvas画Bezier线；双端禁用，ReviewQueueService事务拒绝重复消费。FSRSScheduler为FSRS4.5固定参数DSR实现，保存版本/S/D/间隔/计数/日志。旧basic日志不改写；下次真实复习才转换状态。

题组持久化原句、实际surface答案、整词/短语遮空与明确原文拼写变体，旧题语境安全回填不改变答案/尝试/提示/完成。缺可靠中文阻止出题。回答、反馈、排程、日志和周期同事务；重新载入清理旧输入/反馈。额外复习purpose=extra、extra|sessionID命名空间，不建DailyStudyCycle或重锁探索。

## CI与支持范围

一次Debug test-products编译后，全单元/真实网络/Release关卡，通过才在同工具链/架构4主UI组与2设备专项test-without-building；原始PNG和xcresult失败也上传。旧计数不作当前证明，准确结果见STATUS。产品iOS27保持，当前验证仅已批准iOS26.5/Xcode26.6。单应用单容器MainActor串行写受支持；不承诺跨进程多容器竞争。真机/iOS27/Instruments/完整VoiceOver尚无通过证据。

以下保留历史架构演进记录；旧“未接入”和旧basic排程叙述仅表示当时状态。


生词语境新增nullable contextKind/contextTitle/contextAttribution，reader/dictionary/historical分别表示原文、实际词典文本、历史未知类型。词典语境保存原词/原始来源行，关联文章仅作为阅读会话关联；导出保留kind与证据。未知旧类型不推断，显式新点词才补证。短语的完整源范围由Domain在原始全文/词典文本中核验，WordLookupModel协调读取与创建子查词，错误与生词提交错误分离。新ReviewState写入new及零评分计数，首次Again为learning，已复习失败为relearning；旧日志不改写。

---

# 架构

> 前半部分保留 Round 1 历史基线与不变量；当前生产功能、Round 2 验证结果和未完成项见文末及 Round 2 开发交付自述。

依据 SPEC §15.3：“数据修改通过 Repository / Use Case 统一执行。”保留 SwiftUI / Domain / Repository / SwiftData 分层，领域与 Repository 写入在 MainActor；Round 2 词典资源由独立 actor 加载。

- Domain：`DailyStudyCycle` 可抛错初始化、只读对外状态和统一 `validate()`。通用更新不能 completed/deferred。阅读完成需文章 ID、内容哈希、有效进度及明确确认；手动确认允许低进度，不增加查词要求。复习空队列只由完整可复习集合的 reader 生成绑定 cycleID/版本/时间的证据，三个复习状态一次性解析；不可用 reader 抛错。正常/部分复习结果由 reader 读取固定已保存会话、题目与已答 ID 的结构化结果约束，源事件时间保持不变。生产未实现这些模块，不产生伪结果。
- Data：新增字段均可选，保留原有字段/实体。Record.domain() 走同一领域验证。已知旧 deferred/无证据完成状态在显式恢复事务中存档全部原标量与证据后变成说明清楚的 blocked；无法辨认的状态或关联异常终止恢复，不删除或合并数据。
- Repository：`RepositoryWriter` 关闭 autosave，每次同步写入使用专属ModelContext，统一save/catch/rollback，失败上下文直接弃用，不复用其缓存；读取使用新context。真只读磁盘测试证实仅rollback不足以清除注册幽灵对象。创建必须同一上下文写文章和周期；移除非原子 fallback。普通保存验证文章存在、身份不变、日期/文章指派唯一、状态不回退、完成证据和内容版本匹配。current 总是最早未完成周期；历史多个未完成记录保留。文章相同 ID 仅接受完全相同快照重试，不覆盖已分配正文。
- Article：Candidate 负责许可/缓存期限、来源与图片署名、HTTP(S) URL、正文/主题门禁；正文 SHA-256、英文词数和按 200 词/分钟估算阅读时间由正文计算。所有 Repository 文章入口复用门禁。历史缺少缓存权利的文章不推断获得许可，后续阅读器必须重新核验。
- AppCore：生产打开原默认数据库 URL，先创建父目录并保留一次升级前数据库/WAL/SHM 冷启动备份；自动轻量迁移仅新增可选列。不支持活动外部写入下文件备份；当前无 extension/后台独立写进程。打开失败提供真实重试，无删除重建分支。
- Today：读取偏好固定/设备时区；统一使用 Gregorian yyyy-MM-dd 学习日期。显示四任务原因；未接入操作 disabled，说明当前尚不能恢复学习。“重新读取已保存状态”只重读/执行安全恢复；启动“重新打开存储”重新执行初始化。

保障范围：同一应用单一容器、串行 MainActor Repository 是受支持写入口。不同 context 的顺序读取有测试；没有对多容器/跨进程竞争作数据库唯一约束承诺。唯一性使用同一同步 unit of work 的事务性去重，不能把主线程串行解释成跨进程锁。Preferences返回用于编辑的托管记录，save先捕获完整独立快照、回滚编辑context，再在专属写context应用。调用者不要跨await悬置编辑；UI保存后重新load。

迁移支持范围与计数语义见 ADR-004–007；实际升级成功必须以两个历史 schema 磁盘测试为准，当前模型重开测试不能替代迁移测试。

原生窗口和CI定位：App Debug/Release均启用标准UILaunchScreen与UIApplicationSceneManifest生成，CI读取真实产物plist校验；XCUITest实际验证现代窗口尺寸。UI定位仅操作标识today-scroll，按可用viewport和目标方向滚动，无进展附截图/层级失败；不通过跳过点击来隐藏不可见控件。固定iPhone17Pro/iOS26.5兼容环境，共享derivedData但不跳过target。详见ADR-010及本轮报告。

实际验证：代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。

复习源结果的recordedAt相对上一个已保存会话结果不可回退；复习已完成时，其完整结果凭据即保持不变，即使文章仍未完成。领域命令与直接Repository更新都执行该检查；初次延迟结果仍可早于周期updatedAt高水位，保留源事件时间。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。

### Round 2 实际层级

`LearningRootView → ViewModel/意图 → Content/Reader/Vocabulary/Review 服务 → RepositoryWriter → SwiftData`。Today 仍通过原 DailyCycleService 获取最早周期；复习和阅读在同一 context 内调用原 StudyCycleRepository.applyInTransaction，不建立第二套任务状态。UI 仅保存页面选择与输入草稿，持久化真值在 Repository。

正文入口与元数据分开：ContentRepository.read 返回 ReadableArticle，library 仅返回不含正文的 ArticleLibraryItem；授权失效时保留 hash/关联，阻止展示并提供原文入口。探索路由与 ReaderProgressService 写入口均有门禁；已指派文章只能沿原周期继续。统计从完成证据/进度/会话结果重建，不维护多个页面计数器。

词典数据加载在 actor 内，主线程只提交必要缓存实体；TextKit 按正文版本解析token，点击二分命中；不在每帧重新hash/分词。进度2秒节流，离开/后台刷写。短英文详情复用同一命中组件；动态高度与嵌套深度受控。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。



2026-11-01 · 负责人特别指示的公开官网全文模式：允许个人使用场景下直接尝试11个官网来源（BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian）；旧出版社许可审核不改写为授权。FullTextRightsEvidence.importBasis=owner-directed-personal-use-2026-11-01，grant.scope=personal-full-text，与audited-full-text分开。只请求公开HTTPS页面，固定主机白名单及重定向检查，无登录、验证码处理、浏览器、代理或付费墙绕过。RSS/列表只在内存中发现候选；完整闭合正文子树或明确articleBody、正文长度/段落/原文一致性和数据库事务验证通过后才入库；任何失败不留下候选。Wikinews另按CC BY4.0及2024-12-17创建日期门槛接入。最多3条来源管线并行，首篇原文导入后更新首页，各来源独立失败/退避。新增8个确定性测试及真实网络五来源导入门槛测试，尚未执行，不把配置11源当作11源成功。


继续修复公开来源：RSS候选http仅升级为同站https后再抓取，绝不降级HTTPS；添加仅来源ID/计数/诊断码的发现与提取诊断，无候选URL、标题或正文。NASA补充article语义根，仍要求完整闭合和全文验证。Wiktionary按英文节补充原始IPA/词形/词源/例句，例句不作为独立义项，缓存schema升级3；提供同义词真实义项/例句对照页面及独立加载失败重试，不生成词义解释。新增确定性英文节测试。当前源码147单元/31 UI，待新SHA验证。


修复Wikimedia批量发现请求误用只适用于单页的revisions rvlimit/rvdir：恢复info批量发现，Wikinews创建日期另发单页请求；固定revision全文和日期门槛保留。到期正文现在同事务迁出ArticleRecord到历史归档，历史引用/标题/计数仍可恢复但不可阅读推荐；已核验同版本RFC可恢复到原身份，用户学习关系不变。新增到期无partial ArticleRecord与持久刷新退避测试；原到期、时钟回拨和RFC恢复旧测试未删除或改断言。源码149 XCTest/31 UI，待对应新SHA验证。


语境排序补充Apple公开NaturalLanguage句向量的本机语义相似度：仅在模型可用时参与，缺失时回退原词性/词汇规则；原始义项不改写不生成。排序预计算各义项分数，避免sort比较器重复模型推理。CI在UI回归前立即上传单元日志便于定位真实外网与迁移错误，完整UI测试和最终xcresult上传不变。


继续补齐验收：文章库搜索绑定公开searchFocused并提供完成搜索，保留结果与收藏持久化断言；阅读浮窗继承三主题，补充三主题浮窗截图；新增took/taken及look into、carry out、take into account、play a role in逐项真实UI嵌套查询/返回测试（原创语境夹具与真实本地词典明确区分）。复习反馈展示评分依据、原定日期→下次日期，新增Hard/Good实际作答、重启持久化截图；原Again显示答案截图测试保留。正文提取优先显式正文根，标题作者日期作为独立元数据保留，支持WebPage/Person引用及毫秒日期，不编造作者；新增确定性测试。当前源码152 XCTest/35 UI（旧93/20全保留），新增内容待对应SHA执行；最新已完成151/0的结果不冒用于新增测试。


并发与状态补齐：同一发现服务的并发调用加入同一Task并返回相同真实入库结果，取消传播并在入库前再次检查；不再把正在刷新误报成无新文章。新增并发原子导入测试。文章库按业务门禁禁用未解锁文章，收藏不建周期；网络失败与本地读写失败使用相应安全重试，避免把本地问题误导为重新抓网。源码154 XCTest/35 UI，待最新SHA执行。


语境拼写完整性：新题组固定保存sourceContext和contextSnapshotVersion；按原句实际词形（took/taken）出题，整段短语统一遮空。旧题组只回填可安全遮空的语境，答案/提示/尝试/完成/排程不变，不能匹配时用原有独立拼写题。两个新增确定性测试覆盖语法、短语答案不泄露、语境不可被后续源数据改写及旧会话恢复。新增字段为optional轻量迁移，冻结Round2磁盘迁移测试保留。源码156 XCTest/35 UI，待对应SHA验证。


数据失败UI补齐：编辑释义/笔记后清除旧“已保存”，每次保存先取消成功状态，失败保留草稿；词典异步完成不能清掉笔记保存错误。复习提交失败清理上一次正确反馈。新增第三次实际Repository保存单次失败场景，验证先成功→改草稿→失败无旧成功标签→安全重试→重启保留笔记，四张原始PNG截图。源码156 XCTest/36 UI，原93/20全部保留。


词典数据质量复核：Wiktionary音标和词形按实际词性章节归属，避免把名词/动词不同发音和变形混在每个义项中；不明确归属时不补造。新增record名词/动词独立音标/变形夹具测试，Provider缓存schema升级4。源码157 XCTest/36 UI，既有测试断言不变。


2026-11-01 · 生词本与额外复习实装（待对应提交验证）：生词本新增待复习/逾期/近7日/较熟悉筛选及最近添加/到期/字母/复习优先级排序，展示可用音标/词性/最近和下次时间；原全部/单词/短语筛选保留。用户主动导出JSON/CSV包含实际词条、个人释义/笔记、来源上下文、真实词典缓存义项、排程和不可变日志，不上传。额外复习使用purpose=extra及extra|sessionID独立命名空间，不创建DailyStudyCycle，复用实际配对/拼写/事务排程，恢复未完成额外题组且不重复刚完成的未来到期词。purpose新增optional字段，历史required会话不重写。个人中文释义生成复习无需英语外网，其他中文从真实本地词典按句子语境排序；无可靠中文仍阻止出题。拼写优先近期遗忘/较长词形，答案与原句继续固定。新增3个确定性回归及1个原生额外复习重启UI；当前164 XCTest/39 UI，原93/20保留。探索完整呈现和词汇推荐继续实现，不宣称统一完成。


2026-11-01 · 探索和推荐融合实现（新代码待运行）：探索读取完整本地文章，按集中配置的25/20/20/15/10/5/5权重排序，原生主题封面、来源/日期/词数/阅读时长和未开始状态；支持主题筛选、直接收藏/稍后、发现/取消及安全错误重试。首次真正进入Reader即保存inProgress；用户确认重新标记时归档原进度（新增optional archivedAt，原百分比/完成日期保留）而非删除学习历史；每日任务不可重置。词汇Tab保留可管理生词本，并新增高级词汇/短语推荐入口，未完成任务时锁定；候选从实际本地全文词元提取、保留实际词形/偏移、排除已有词，再查询真实词典，没有可靠数据则不展示。仅显式加入写生词；推荐详情及嵌套查词禁用自动加入。新增词形/推荐无自动添加/探索归档确定性测试及3项原生UI场景，当前167 XCTest/42 UI，旧93/20保留。上一提交4b09989的快速关卡发现生词本toolbar少一个闭括号，已静态确认修复；不是CI通过声明。ebd7f44的编译/Release/完整单元关卡已success，后续新提交不借用该结果。


2026-11-01 · 复习义项与拼写变体补齐：用户可在生词详情明确选择中文义项，来源ID、原文中文和原始来源证据独立持久化，清词典缓存不丢用户选择；修改个人释义才切换选择，笔记更新不改义项。新题组优先使用明确选择，已固定题组不被后续修改改写。英美拼写仅从Provider原始释义中明确的Alternative/British/American spelling of关系生成并固定可接受答案，不猜测词形、不把其他时态视为正确。新增2项确定性测试覆盖清缓存、题组不变及明确变体判定。新增均optional字段，旧schema磁盘测试保留。当前169 XCTest/42 UI待新SHA验证。25f7fdb的快速构建关卡发现推荐Model.catch中error同名遮蔽，已更正为self.error；其他同名赋值一并静态检查。


2026-11-01 · 恢复并提交个人全文版本更新：仅允许解锁后的未指派user-local文章，显式确认完整原文；旧全文/结构/署名保存在新增ArticleContentVersionRecord，旧完成进度归档，未完成位置按唯一原段落恢复且新进度归零。每日已指派文章拒绝更新。新增事务故障回归检查失败不留版本孤儿、不替换当前正文/授权，原周期数量不变。170单元/42 UI源码，新增版本UI与其余截图补充继续恢复，未声明新功能验收通过。
