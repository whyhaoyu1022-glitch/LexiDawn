# CURRENT · Round 3 需求追踪

功能存在、持久化、测试、真实截图和 CI 都必须有同一代码证据才能标记完成。当前仍在验证；180 XCTest / 49 UI 为源码清单。20 项 R2-A01–A20 的逐项实现及证据缺口见 [本轮矩阵](reviews/round-3-development-delivery.md)。

本次失败整改依据 SPEC §5.5 原文“但必须确认并重置该文章的探索状态”与“若候选池耗尽，显示"正在寻找新文章"并提供重试”；§30“网络、数据库、签名或 AI 失败不能被伪装成成功”。导航栏保存、独立库按钮/确认快照、空库说明及新增回归断言见[CI核查](reviews/round-3-ci-41318724181-repair.md)。依赖既有Repository事务，不改分配、答案或门禁；验收依赖新完整原生运行和PNG。

| 需求 | 当前实现 | 主要验证 | 剩余验收 |
|---|---|---|---|
| 只在 main、保留旧测试 | 直接 main 提交、原93/20保留 | Git history、源码/测试计划完整性 | 最终真实 main SHA 与 compare清单 |
| 完整原文唯一本地模式 | Registry/Audit/内存发现/HTTPS抓取/HTML/Normalizer/Quality/Repository；无阅读降级 | 全文准入、截断/部分/URL/原子回滚/失败刷新/去重；Live10源 | 最终源列表/完整UI与PNG |
| 负责人个人模式特别指示 | personal-full-text 与 audited-full-text 分开，不伪造出版社授权 | importBasis/伪造证据拒绝；官方源真实运行 | Reuters401/AP403/Smithsonian不完整如实舍弃 |
| 所有入口仅当前任务 | ArticleLearningAccess；Reader打开/save/complete均检查 | 历史/收藏/稍后/跨日门禁Domain及UI | 最新全量UI |
| 双正文原子保存 | rawContent物理旧列+structuredBody+证据/哈希同事务 | failure/rollback/no孤儿/结构不一致拒绝 | 最新构建/175测试 |
| 多词典/离线/简明+详情 | Free/Wiktionary/CEDICT，版本缓存，最多两条简明义项、独立完整详情 | 多Provider/缓存/英文节POS/IPA/词形/失败UI | Free真实间歇404与最终截图 |
| 真正连线 | 锚点Canvas、多线、错误重试、两端禁用、Domain拒绝重复 | 像素/布局/旋转/会话恢复/AX等价 | 最新双尺寸及逐图审阅 |
| 阅读器/主题/结构/恢复 | TextKit、原文投影、三主题、大字/横屏、位置/版本恢复 | 十次旋转实际正文/点词；原创HTML结构和版本UI | 最新三主题/双尺寸PNG |
| SPEC §10 FSRS与复习闭环 | FSRS4.5、原句词形/短语遮空、固定语境/明确变体、排程解释 | 向量/非法状态/题组冻结/Again-Hard-Good/重启 | 全量UI；不冒称最新FSRS/分钟步骤 |
| 生词安全/管理/导出 | 安全撤销、明确移除、个人笔记/确认义项、筛选/排序、完整JSON/CSV | 原测试+事务故障/确认义项/原生导出UI | 最新PNG/重启证据 |
| 探索/推荐/额外复习 | 解锁排序卡片、归档重置、全文词汇推荐仅明确加入、独立额外会话 | 无自动入本/无新增周期/无重新锁定/恢复 | 最新主要与失败状态UI |
| 迁移/历史保护 | 冷备份、optional轻量字段、分离历史归档、完整个人旧版本 | 三套旧schema磁盘、原文/学习关系保存及失败回滚 | 当前原生运行对应准确计数 |
| 全状态截图与CI效率 | 原生PNG+元数据+SHA合并、compile-once+4UI组+2设备、fail-fast | 自动选择器完整核对；实际下载原始附件审查 | 同一最终代码完整ZIP/CSV/manifest/xcresult/逐图索引 |

完整 VoiceOver 听读、iOS27/真机/Instruments 仍无通过证据；不能用模拟器按钮存在或静态文档代替。以下保留历史记录，CURRENT与本轮报告优先。

---

# 需求追踪矩阵

> 前半部分保留 Round 1 历史基线与不变量；当前生产功能、Round 2 验证结果和未完成项见文末及 Round 2 开发交付自述。

本矩阵纠正旧版把源码存在、FakeStore与旧CI扩大解释为完成的描述。代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。 历史报告原文保留；本轮适用缺陷回归通过仍不等于整个SPEC §25或后续里程碑交付。

| ID/审核项 | SPEC 原文依据 | 实际实现/范围与依赖 | 测试名称（详见测试计划）/层级 | 本次结果 | 未验证边界/完成标准 |
|---|---|---|---|---|---|
| GOV-001 | §0.1 “本文档是开发代理的主要产品依据” | 不改 SPEC；保留原审查；本次独立读取全部规格 | 文档/代码审查 | 已读，静态检查 | 不等于产品验收 |
| M0-001/002/003 | §3.1 “主导航固定为五项”；§15.1 “SwiftUI” | 保留五 Tab、三 target、27.0产品/26.5兼容 CI | `testFivePrimaryTabsAreVisibleAndSelectable` / UI | 对应代码CI通过 | iOS 27/设备/签名未验证 |
| R2-001/M1-001 | §2.2.1 “因系统明确判定无需执行而略过” | 字符串接口拒绝 deferred；完整 queue reader 生成周期绑定证据；生产不可用抛错 | `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`, `testUnavailableNonemptyAndIncompleteQueuesCannotDeferReview`, `testVerifiedEmptyFixtureQueueSatisfiesReviewOnlyAfterExplicitReading` / Domain+Fake | 对应代码CI通过 | 未接入真实队列；合法空数据仅显式 fixture |
| R2-002 | §2.2 “未完成任务必须保存在本地数据库” | throwing init/validate/Record.domain；原状态归档后保守 blocked | `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations` / Domain；`testSwiftDataStrictDecodeRejectsLegacyDeferredAndRepairArchivesWithoutLosingAssignment` / 内存 SwiftData | 对应代码CI通过 | 未知值/重复/孤立记录保留并报错，需要专门修复 |
| R2-003 | §2.3 “建立周期必须使用数据库事务和幂等约束” | 同一 writer 保存文章/周期；统一 rollback；日期/文章关联/最早 current | `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`, `testSwiftDataRepositoryRejectsMissingArticleMismatchedIDDuplicateDateAndReassignment` / 内存 SwiftData；`testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable` / 磁盘；`testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement` / 内存SwiftData | 对应代码CI通过 | 不保证跨进程或多容器并发；不冒称磁盘满/断电测试 |
| R2-004/M1-002 | §20.1 “恢复未完成任务” | 重开后重新查文章正文/许可/指纹与关联、周期全值、关键偏好 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` / 磁盘 | 对应代码CI通过 | 不是 OS 强制杀进程测试；未逐字段检查全部偏好 |
| R2-005 | §25 “相关单元测试或集成测试通过” | FakeStore 测试改名，补数据库与 UI 断言；不删除失败断言 | `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle` / Fake 与上述真 DB 明确分开 | 对应代码CI通过 | 源码方法数不等于运行数 |
| R2-006/M1-004 | §19.1 “正文指纹”；§19.9 “ageRange”；§21.3 “对每个来源记录许可、署名、缓存和衍生内容权限” | SHA-256/词数/阅读时间计算；主题/缓存/来源和图片许可门禁；年龄段可选；新偏好默认12/6/4 | `testDirectArticleRepositoryRejectsInvalidLicenseCacheImageAndMissingMetadata` / 内存 SwiftData；磁盘重开 | 对应代码CI通过 | 真实来源注册表/授权核验与展示 M3 尚未实现；不伪造授权 |
| R2-007/M2-001/002 | §23.3 “对不可重试错误解释原因和下一步” | 四任务显示原因、禁用未接入操作、诚实说明尚不能恢复学习、重读/存储重开真实动作 | `testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates`, `testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged`, `testStartupRetryRepeatsInitializationAndLoadsApp` / UI；`testUnavailableInProgressRecoveryPreservesCycleArticleAndOtherProgress` / DB | 对应代码CI通过 | 真实阅读/复习导航属后续；无障碍未全验 |
| R2-008 | §2.5 “阅读进度达到90%或以上”；“用户手动确认” | 常规确认/手动确认契约；泛型 completed 拒绝；正文版本绑定 | `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation`, `testProductionContractsRejectReadingCompletionAndUnknownQueue` / Domain+DB | 对应代码CI通过 | 阅读器真实证据 adapter 尚未接入 |
| R2-009/M1-003 | §19.3 “跨日次数”；§18.5 “处理夏令时变化和用户旅行” | ADR-006 日历日期高水位；固定时区；原任务保留 | `testCarryOverCountsSkippedCivilDatesAndNeverRecountsRollback`, `testDSTAndTravelUseCivilDateHighWaterWithoutChangingAssignment`, `testViewModelHonorsFixedStudyTimeZoneAndGregorianDate` | 对应代码CI通过 | 历史旧计数不凭空重算 |
| R2-010 | §0.2 “不得伪造测试” | GitHub公开main线性历史与旧PR状态核对；旧报告中的无效SHA明确纠正 | Git log、GitHub branch/commit/PR API与完整tree SHA比对 / 仓库事实 | 公开SHA与父提交已核对 | PR#1仍closed/unmerged，旧分支保留，不声称曾正式merge |
| R2-011 | §23.6 “文档要求”；§25完成标准 | 所有本轮文档按真实层级/固定代码SHA/本轮run修正 | Actions完整job日志、精确61+8方法清单、xcresult artifact / CI证据 | 代码SHA、实际61+8/0与artifact已核对 | docs提交自身运行分别记录，不预填success；不扩大为真机/全部产品验收 |
| R2-012 | §19.10 “每次模型变更必须定义迁移策略” | 可选列轻量迁移，原store/sidecar冷备份；双历史模型升级测试 | `testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences`, `testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive` / 真实旧磁盘升级 | 对应代码CI通过 | 实机用户库、其他未知中间schema待验证 |
| M3/M4/M5/M6/M7/M9 | §26 对应里程碑 | 真实内容、阅读器、词典、复习算法/题目、通知、AI、IPA | 当前不声明完成 | 未实施 | 后续范围；无fixture冒充 |


## Round 2 开发中追踪（批次 1）

| 目标 | SPEC 原文依据 | 实现 | 测试层级及当前结果 | 未验证边界 |
|---|---|---|---|---|
| 合法内容与导入 | §12、§21.3 内容合规 | ContentRepository、SourceRegistry、ArticleAcquisitionService | Round2Tests 的导入/来源测试，未执行 | 真实网络错误、过期和升级待扩展 |
| 原生阅读与证据 | §2.5、§6、§19.2 | ReaderFeature、InteractiveEnglishText、ReaderProgressService | 已新增保存失败与完成证据内存 SwiftData 测试，未执行 | 磁盘、生命周期、命中 UI 待验证 |
| 查词与生词 | §7.5「默认行为：点击单词后自动加入生词本。」、§9 | CEDICTDictionaryProvider、VocabularyRepository | 幂等、自动添加关闭、安全撤销测试已编写，未执行 | 详细 UI、性能待验证 |
| 两阶段复习 | §10、§19.7–19.8 | ReviewQueueService、ReviewSession/Exercise/Log/State | 真实内存 SwiftData 作答到周期完成测试已编写，未执行 | 磁盘恢复、故障事务待扩展 |
| 设置/探索 | §5、§11 | LearningSettingsView、LiveExploreView | 当前未验证 | 路由封锁、持久化重开待扩展 |

本轮用户明确要求“词汇 Tab”成为可管理生词本，因此优先实现不被探索锁阻断的核心生词本；SPEC 中高级词汇推荐仍未实现，不冒充已交付。排程明确为 lexidawn-basic-1，不宣称实现 FSRS；保留不可变日志和算法版本支持未来升级。

## Round 2 批次 2 验证追踪

以下新增行为以当前用户任务书为范围；历史 Round 1 行保持为当时证据。应用代码fcac01b的run41194434948已实际通过93 XCTest/13 UI，106个方法与日志逐项匹配。后续测试定位/文档提交的运行单独核对。

| ID | SPEC 逐字依据 | 实现与依赖 | 验证及边界 |
|---|---|---|---|
| R2-CONTENT | §21.3“如果许可只允许展示标题、摘要和链接，就不能把全文复制进应用。” | SourceRegistry、ContentRepository、ArticleAcquisitionService；只接受用户本地声明或核验 RFC 指纹；原 URL/ID/正文去重 | Import/HTTP429/timeout/official RFC network tests；CC、IETF 官方条款复核；相应测试在上述固定代码CI通过 |
| R2-ACCESS | §12.7“正文缓存应记录来源许可和缓存期限。” | monotone accessHighWater，读取/保存均校验；到期清正文、保留元数据/进度/词汇；Reader 撤回显示 | expiry 精确边界、离线纯本地读取、时钟回拨、VM 失效撤回测试；无法识别设备从未观察到的历史时间，未宣称安全时钟 |
| R2-READER | §6.3“找不到时回退到文章开头并提示，而不是跳到错误位置。” | 一致 paragraphRange 指纹，唯一锚点，UTF16 offset；2秒节流、退出/后台落盘；证据与周期原子更新 | 内存故障/磁盘重开/版本变化，UI滚动重启核对可见词元位置；未执行真机 Instruments |
| R2-WORD | §6.2“任何可识别的英文单词都应可点” | TextKit glyph hit；标点边界排除；NLP句子；详细页复用英文组件；嵌套最多3层 | token contractions/hyphens/URL/email/code/3500词性能测量；真实 UI 点击、浮窗返回；复杂短语属后续 |
| R2-VOCAB | §7.5“如果词条原本已存在，撤销不得删除原有记录。” | creationToken+revision、软删除、上下文指纹；词典与词条实体分离；中文缓存搜索 | 幂等/旧词撤销/关闭自动添加/保存故障/缓存删除保留，UI查找与手动加入撤销 |
| R2-REVIEW | §10.3“选择结果必须在复习会话创建时固定保存” | 完整 eligible 查询；固定题目/顺序/掩码；senseID配对，实际答案、提示、次数；结果/日志/排程/周期同一save | 正常闭环/阶段门禁/重复提交/最终事务失败/磁盘恢复/缺状态拒绝；基础算法有固定向量，不宣称FSRS |
| R2-HOME | §4.2“任务所属日期，逾期时明确标注。” | 真实hero来源/主题/进度/原日期、任务状态、统计；原生文章库与历史 | 阅读后即时更新；统计取实际阅读/复习完成事件时间，不把原分配日当完成日 |
| R2-EXPLORE | §5.5“探索默认不再推荐已开始或已完成的文章。” | 排除每日指派和探索已开始；保存/完成与路由均门禁；保留历史入口 | opt-out导入在库可见、锁定写入口拒绝、解锁后继续、已分配拒绝重开为探索；UI完整周期解锁 |
| R2-SETTINGS | §11.5“设置必须写入持久化存储，应用重启后仍生效。” | 昵称/年龄/目标/主题/阅读/自动添加/上限/学习时区；阅读器菜单即时保存 | 磁盘重开、UI切换自动添加后重启；通知/AI明确准备中，不假装系统能力启用 |


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。


| 截图审阅补充 | SPEC §24.6：“加载、空状态、错误状态和锁定状态都可通过 VoiceOver 理解。” §24.7：“冷启动、首页加载、文章打开、浮窗查词和词典详情页响应时间。” | 7个gallery UI场景，生产RFC与隔离故障明确区分，原始PNG附件导出；截图不代替完整无障碍/性能验证 | 依赖已运行原生App与真实资源 | CI实际结果和下载图片包以本次交付答复核对，未运行前不宣称通过 |



2026-11-01追加：负责人明确以个人使用方式调整公开完整文章获取规则；旧许可结论不改作授权。修复文章库搜索默认隐藏、滚动后屏外单词的UI定位，保留全部原20 UI方法和断言并增加原始截图元数据。对应下一main提交待CI验证，不声明最终通过。


2026-11-01 · 负责人特别指示的公开官网全文模式：允许个人使用场景下直接尝试11个官网来源（BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian）；旧出版社许可审核不改写为授权。FullTextRightsEvidence.importBasis=owner-directed-personal-use-2026-11-01，grant.scope=personal-full-text，与audited-full-text分开。只请求公开HTTPS页面，固定主机白名单及重定向检查，无登录、验证码处理、浏览器、代理或付费墙绕过。RSS/列表只在内存中发现候选；完整闭合正文子树或明确articleBody、正文长度/段落/原文一致性和数据库事务验证通过后才入库；任何失败不留下候选。Wikinews另按CC BY4.0及2024-12-17创建日期门槛接入。最多3条来源管线并行，首篇原文导入后更新首页，各来源独立失败/退避。新增8个确定性测试及真实网络五来源导入门槛测试，尚未执行，不把配置11源当作11源成功。


Round 3继续：原生小屏截图已逐张检查R3-R02/R3-M06/R3-R08，横屏正文与真实线条可见，最大字号首屏占用问题继续整改。阅读器仅压缩元信息/完成控件，正文仍遵循完整动态字体；已配对两端保留高对比文字/边框并禁用。HTML提取保留嵌套引用和有序列表序号，以原生TextKit样式显示，原文字符不插入生成内容。推荐按兴趣/新鲜度/长度排序且仍过滤已分配与探索中记录。增加明确fixture标记的词典加载/单源失败/全失败/空结果/缓存/离线UI状态，另加空库真实多来源逐个本地阅读截图测试，通过真实阅读确认和空复习流程解锁，不插入完成状态。以上待新SHA运行证据。


新增真实Repository保存故障UI证据：DEBUG Simulator仅在明确round3-storage-vocabulary场景对下一次实际save抛错，验证没有成功状态、无撤销入口，重试成功后在持久生词本出现；Release不包含该配置。CI UI步骤在测试编译成功后独立执行，即使网络单元测试失败仍采集UI与xcresult，整个job仍保留失败结论。当前源码146 XCTest、31 XCUITest，均待对应最终SHA执行。


继续修复公开来源：RSS候选http仅升级为同站https后再抓取，绝不降级HTTPS；添加仅来源ID/计数/诊断码的发现与提取诊断，无候选URL、标题或正文。NASA补充article语义根，仍要求完整闭合和全文验证。Wiktionary按英文节补充原始IPA/词形/词源/例句，例句不作为独立义项，缓存schema升级3；提供同义词真实义项/例句对照页面及独立加载失败重试，不生成词义解释。新增确定性英文节测试。当前源码147单元/31 UI，待新SHA验证。


来源刷新集成：首页展示真实本地完整文章卡片，保留每日原周期；后台恢复、显著时间变化与下拉刷新调用同一来源新鲜度/退避用例。Repository候选仍去重并保护未完成周期。最新源码147 XCTest/31 UI，未宣称全绿。


修复Wikimedia批量发现请求误用只适用于单页的revisions rvlimit/rvdir：恢复info批量发现，Wikinews创建日期另发单页请求；固定revision全文和日期门槛保留。到期正文现在同事务迁出ArticleRecord到历史归档，历史引用/标题/计数仍可恢复但不可阅读推荐；已核验同版本RFC可恢复到原身份，用户学习关系不变。新增到期无partial ArticleRecord与持久刷新退避测试；原到期、时钟回拨和RFC恢复旧测试未删除或改断言。源码149 XCTest/31 UI，待对应新SHA验证。


追加保护：历史不可用归档不回流文章库候选；仅旧到期历史的不可读DTO用于保留旧API契约，所有可见文章仍为完整本地记录。生词来源上下文读取历史元数据，避免迁移后丢标题/署名。SE专项增加冷启动、库搜索、词典异常和保存故障4项，原三项及主31项全量不删减。MediaWiki错误只记录受限诊断码，不记录标题或URL。


VOA改用其官方RSS目录明确公布的As It Is Feed，候选仍仅在内存；没有第三方内容代理。文章库增加停止发现并在离开页取消请求；已经原子入库的全文保留，取消不生成未完成文章。后台恢复/日期变化仍尊重来源退避。SE核心路径优先增加，不删全量测试。


补齐文章发现加载/停止状态与对应原始截图UI测试：明确延迟URLProtocol夹具验证取消后无文章残留；下拉与按钮共用可取消Task，已完整入库数据保留。当前源码149 XCTest/32 UI（原93/20保留），待新SHA执行。


交付基础设施：新增Release构建并验证DEBUG故障/截图夹具标记未进入二进制；新增统一证据汇总job，合并同一workflow/commit全部设备原生PNG，逐张验证SHA-256，输出完整manifest/CSV/INDEX.md和无重绘的原始PNG ZIP。合并脚本已在实际run41270145667小屏14张原始PNG上验证，不借此声称最新应用测试通过；Linux仅验证Python/YAML及真实附件打包。


HTML完整性改进：随附标准HTML5字符引用映射，保留未知引用字面文本，不因合法Unicode实体误丢正文；schema articleBody若实际含HTML则结构化清理，末段一致性单测覆盖。新增两项测试，源码151 XCTest/32 UI，原93/20保留。新版本Release和统一原始证据包均由Actions验证，当前不能标记通过。


语境排序补充Apple公开NaturalLanguage句向量的本机语义相似度：仅在模型可用时参与，缺失时回退原词性/词汇规则；原始义项不改写不生成。排序预计算各义项分数，避免sort比较器重复模型推理。CI在UI回归前立即上传单元日志便于定位真实外网与迁移错误，完整UI测试和最终xcresult上传不变。


继续定位并修复真实UI失败：词典详情入口改为常驻工具栏，避免丰富义项使入口被推至长列表末尾；生词保存错误优先显示，完整句子语境可展开，自动添加状态优先可见。笔记保存成功解除键盘焦点，解决键盘遮挡Tab导致冷启动闭环无法返回今日。加载夹具延迟30秒并按真实标识定位可见状态。macOS Bash3.2空数组与set-u冲突通过始终含原三项的测试选择器数组修复，不删测试。最近已完成7d2be63运行41274185444：151单元/0失败，真实九源25篇；32 UI/4失败，SE7/4失败，大屏为shell空数组失败，均未称全绿。新修改待对应main验证。


继续补齐验收：文章库搜索绑定公开searchFocused并提供完成搜索，保留结果与收藏持久化断言；阅读浮窗继承三主题，补充三主题浮窗截图；新增took/taken及look into、carry out、take into account、play a role in逐项真实UI嵌套查询/返回测试（原创语境夹具与真实本地词典明确区分）。复习反馈展示评分依据、原定日期→下次日期，新增Hard/Good实际作答、重启持久化截图；原Again显示答案截图测试保留。正文提取优先显式正文根，标题作者日期作为独立元数据保留，支持WebPage/Person引用及毫秒日期，不编造作者；新增确定性测试。当前源码152 XCTest/35 UI（旧93/20全保留），新增内容待对应SHA执行；最新已完成151/0的结果不冒用于新增测试。


词典异常展示补齐：全部来源失败/保存失败优先显示及重试，不藏在长义项列表底部；加载期间不将初始空缓存误报为无结果，全部失败与真实空结果区分。无结果时详情入口禁用；缓存和部分来源失败在浮窗首屏说明。此项待最新UI验证。


Free Dictionary真实网络出现间歇404（已通过的book词条也发生），与403/429/断网区别处理：同一官方端点最多3次复核，仍404则返回真实空结果，不伪造释义，不切换来源冒充成功。原Live测试的非空英语noun断言保留，不能以空结果让测试通过。对文章404仍丢弃候选。


新增注入404的Free Dictionary真实Provider路径测试，确认没有编造义项；来源失败截图矩阵追加404丢弃无残留R3-A22。源码153 XCTest/35 UI，原Live非空断言与93/20旧测试保留。


并发与状态补齐：同一发现服务的并发调用加入同一Task并返回相同真实入库结果，取消传播并在入库前再次检查；不再把正在刷新误报成无新文章。新增并发原子导入测试。文章库按业务门禁禁用未解锁文章，收藏不建周期；网络失败与本地读写失败使用相应安全重试，避免把本地问题误导为重新抓网。源码154 XCTest/35 UI，待最新SHA执行。


语境拼写完整性：新题组固定保存sourceContext和contextSnapshotVersion；按原句实际词形（took/taken）出题，整段短语统一遮空。旧题组只回填可安全遮空的语境，答案/提示/尝试/完成/排程不变，不能匹配时用原有独立拼写题。两个新增确定性测试覆盖语法、短语答案不泄露、语境不可被后续源数据改写及旧会话恢复。新增字段为optional轻量迁移，冻结Round2磁盘迁移测试保留。源码156 XCTest/35 UI，待对应SHA验证。


数据失败UI补齐：编辑释义/笔记后清除旧“已保存”，每次保存先取消成功状态，失败保留草稿；词典异步完成不能清掉笔记保存错误。复习提交失败清理上一次正确反馈。新增第三次实际Repository保存单次失败场景，验证先成功→改草稿→失败无旧成功标签→安全重试→重启保留笔记，四张原始PNG截图。源码156 XCTest/36 UI，原93/20全部保留。


已查看SE原始故障截图：重试前数据库错误首屏可见，重试后成功入口因重复的大导航标题和medium高度被推到屏外。词典浮窗/详情/对照和生词详情统一inline导航标题；测试实际滚动到成功撤销入口并额外断言可点击、旧错误消失，仍检查重启后真实词条，不降低断言。


词典数据质量复核：Wiktionary音标和词形按实际词性章节归属，避免把名词/动词不同发音和变形混在每个义项中；不明确归属时不补造。新增record名词/动词独立音标/变形夹具测试，Provider缓存schema升级4。源码157 XCTest/36 UI，既有测试断言不变。


2026-11-01 · 规格复核后的实际整改（运行结果待对应SHA验证）：统一ArticleLearningAccess检查当前最早未完成周期、历史cycleID、收藏/稍后和跨日未建立新周期的入口；Reader打开及save/complete均验证，历史标题元数据不授予正文访问。简明浮窗仅显示前2个原始义项，详细词典独立全屏并按词性分组，快捷朗读与返回路径保留；短语成员查询按类型识别。新增3项门禁/短语确定性测试及2项原生UI测试，连同缓存回归当前161 XCTest/38 XCUITest，旧93/20不删除不降低断言。CI改为编译一次、完整unit/真实网络及Release关卡后共享原始test products，4个穷尽UI分组+SE/大屏专项，自动核对每个方法恰执行一次；新main提交取消旧运行，矩阵实际失败即停止其余任务，失败附件仍上传。静态Python/YAML/bash检查已执行，不把它们当Swift构建通过。上一代码3ce74e4运行41289580393：156单元0失败；新增16 UI 0失败，原20 UI中1项首页文章库入口不可达；SE7/2失败，大屏3/0。入口已常驻导航栏；小屏搜索提供真正结束搜索，待新运行。探索完整呈现、额外复习轮、词汇推荐与生词本高级管理仍继续整改，不能标完成。


2026-11-01 · 生词本与额外复习实装（待对应提交验证）：生词本新增待复习/逾期/近7日/较熟悉筛选及最近添加/到期/字母/复习优先级排序，展示可用音标/词性/最近和下次时间；原全部/单词/短语筛选保留。用户主动导出JSON/CSV包含实际词条、个人释义/笔记、来源上下文、真实词典缓存义项、排程和不可变日志，不上传。额外复习使用purpose=extra及extra|sessionID独立命名空间，不创建DailyStudyCycle，复用实际配对/拼写/事务排程，恢复未完成额外题组且不重复刚完成的未来到期词。purpose新增optional字段，历史required会话不重写。个人中文释义生成复习无需英语外网，其他中文从真实本地词典按句子语境排序；无可靠中文仍阻止出题。拼写优先近期遗忘/较长词形，答案与原句继续固定。新增3个确定性回归及1个原生额外复习重启UI；当前164 XCTest/39 UI，原93/20保留。探索完整呈现和词汇推荐继续实现，不宣称统一完成。


2026-11-01 · 探索和推荐融合实现（新代码待运行）：探索读取完整本地文章，按集中配置的25/20/20/15/10/5/5权重排序，原生主题封面、来源/日期/词数/阅读时长和未开始状态；支持主题筛选、直接收藏/稍后、发现/取消及安全错误重试。首次真正进入Reader即保存inProgress；用户确认重新标记时归档原进度（新增optional archivedAt，原百分比/完成日期保留）而非删除学习历史；每日任务不可重置。词汇Tab保留可管理生词本，并新增高级词汇/短语推荐入口，未完成任务时锁定；候选从实际本地全文词元提取、保留实际词形/偏移、排除已有词，再查询真实词典，没有可靠数据则不展示。仅显式加入写生词；推荐详情及嵌套查词禁用自动加入。新增词形/推荐无自动添加/探索归档确定性测试及3项原生UI场景，当前167 XCTest/42 UI，旧93/20保留。上一提交4b09989的快速关卡发现生词本toolbar少一个闭括号，已静态确认修复；不是CI通过声明。ebd7f44的编译/Release/完整单元关卡已success，后续新提交不借用该结果。


2026-11-01 · 复习义项与拼写变体补齐：用户可在生词详情明确选择中文义项，来源ID、原文中文和原始来源证据独立持久化，清词典缓存不丢用户选择；修改个人释义才切换选择，笔记更新不改义项。新题组优先使用明确选择，已固定题组不被后续修改改写。英美拼写仅从Provider原始释义中明确的Alternative/British/American spelling of关系生成并固定可接受答案，不猜测词形、不把其他时态视为正确。新增2项确定性测试覆盖清缓存、题组不变及明确变体判定。新增均optional字段，旧schema磁盘测试保留。当前169 XCTest/42 UI待新SHA验证。25f7fdb的快速构建关卡发现推荐Model.catch中error同名遮蔽，已更正为self.error；其他同名赋值一并静态检查。


2026-11-01 · UI回归修复：保留原93/20测试及全部断言，查词浮窗显式large初始高度（仍可切medium），生词保存/已有/撤销状态前置，相关短语先于简明义项；导入表单禁用手势关闭以保护草稿，仍提供明确取消。run41295662878为169单元0失败、大屏3/0、full-4 12项中4失败，其他矩阵任务被fail-fast取消，不是全量通过。待下一main原生回归验证。


2026-11-01 · 恢复并提交个人全文版本更新：仅允许解锁后的未指派user-local文章，显式确认完整原文；旧全文/结构/署名保存在新增ArticleContentVersionRecord，旧完成进度归档，未完成位置按唯一原段落恢复且新进度归零。每日已指派文章拒绝更新。新增事务故障回归检查失败不留版本孤儿、不替换当前正文/授权，原周期数量不变。170单元/42 UI源码，新增版本UI与其余截图补充继续恢复，未声明新功能验收通过。
