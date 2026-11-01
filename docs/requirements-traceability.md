# CURRENT · Round 3追踪

| 需求与逐字依据 | 实现 | 依赖与证据 | 当前边界 |
|---|---|---|---|
| v1.1 E：“rawContent 和 structuredBody 必须原子写入” | ArticleQualityValidator、FullTextRepository、ArticleDocument | 来源权利证据；事务失败、缺正文、截断、双正文/去重测试 | 新测试运行结果单独核对，不能用fixture冒充真网络 |
| v1.1 D：“不得将候选写入磁盘缓存” | 内存ArticleDiscoveryItem、ephemeral HTTP、未入库不进UI | RSS/Atom/API解析及LiveWikipedia测试 | 其余候选禁用，不展示摘要或外链 |
| v1.1 G：“不提供原站阅读按钮、外部 URL 跳转或 WebView” | Reader/Library/Vocabulary移除文章Link | 原生阅读器；canonical仅出处文本 | 许可/词典来源链接不是文章阅读入口 |
| SPEC §10.1：“FSRS…或经审查的等价间隔复习实现” | 独立FSRS 4.5 DSR、固定参数与不可变日志 | 初始向量、R(S)=0.9、遗忘/非法状态及旧闭环 | 不宣称最新FSRS/Anki分钟步骤或个性优化器 |
| SPEC §10.5：“已配对的条目应保持可见” | MatchingBoard双列随机、Canvas、双端禁用 | 真实线像素/旋转UI、重复消费事务 | 多设备/完整VO仍待执行 |
| SPEC §19.10：“数据迁移与一致性” | 冷备份、可选列回填、历史归档 | FrozenRound2Schema磁盘升级及既有两版旧schema | 损坏/未知schema失败保留，不自动清库 |
| 用户功能六：收藏不创建周期 | 标题/分类/来源/时间、收藏/稍后/历史 | 独立标记写入与无周期断言 | 完整UI截图矩阵仍待运行 |

原93 XCTest/20 UI保留；Round2-A01至A20逐项状态见[Round 3记录](reviews/round-3-development-delivery.md)。以下为历史基线。

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
