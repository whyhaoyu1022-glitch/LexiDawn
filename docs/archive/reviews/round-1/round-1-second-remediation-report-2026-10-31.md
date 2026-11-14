# LexiDawn 第一轮第二次整改报告 — 2026-10-31

## 1. 整改概览

本轮从 GitHub 最新 main `b894bdacadbee3a52073f6c300ab043c7e43caa8` 独立重新读取全部 SPEC、AGENTS、README/ROADMAP/STATUS、架构/决策/追踪/测试计划/CHANGELOG、两份独立审核、旧整改报告、所有 Swift 源码、测试和工程/workflow 后开始修改。不采信旧报告自述作为完成证据。

范围是 Round 1 领域不变量、Repository/SwiftData、恢复/升级、Today UI、测试真实性与文档证据。不开发 M3–M9 的整套阅读器、词典或复习算法。生产 candidate provider 仍为空，生产 review queue adapter 不存在即抛错，reader capability 默认不可用。明确 fixture 从不冒充真实文章/来源/许可。

### 真实 Git 操作

- 起始公开 SHA：[b894bdacadbee3a52073f6c300ab043c7e43caa8](https://github.com/whyhaoyu1022-glitch/LexiDawn/commit/b894bdacadbee3a52073f6c300ab043c7e43caa8)。
- 本地普通 git push 因没有命令行认证失败，未把本地 checkpoint SHA 写成已推送。随后使用已连接 GitHub 的 create_tree/create_commit/update_ref，以已核对 HEAD 为父提交、`force=false` 和 expected_sha 快进 main。首次树 SHA 与本地树完全相同。
- 本轮公开代码提交：`0d0dd8dc940ffe309de5bc48be3d00d6cbbdbb31` → `7758aa49b99ffaa04c6acefd26cc879e7bf9fb42` → `1104143c2a5905431905dded8418420ba8f83005` → `459b89dbd60a7c1f51499768899cc8c54d6ff710` → `2c9733075e444791c612fafb9f44d97809c291ed` → `9eb6adbb205f3ef8016cd84e4b92ea6f2ca16d76` → `d5ee6112211e574a6d9e44b860f88952dd9503d8` → `a40fe00248fb4d5ea01c6dbcd894abe8f8a899e6` → `468028e484ae5bbfbcb940131455386dfd0c3b04` → `57eb1f5f78b90913d23887b300d5df8d58ae988f` → `007df816758207551cef44d5a45fd8557ae80f7d` → `7ff799870643acb39d3653905ecc1b6ff2acb7fa` → `b1c76345e265e7d70d5e54a04050672ae6deb069` → `0db7d2c6eaec77e6a56ad4c8e8e6ff21784e4eeb` → `d61ea28aff3838a3ec6e2cb988cad1ba6e8decdd` → `41096f3426dbb2e134b41b5b025b3ddaeec856c3` → `4705e41fc2dd398c3b676c0498e48a01251ed5c0` → `024de16eab89e3b799f1292261a6be982db453af` → `309afe81aecfbfd84e5a9f52251c59f8e32c0575`。
- 最终应用代码 SHA：[`309afe81aecfbfd84e5a9f52251c59f8e32c0575`](https://github.com/whyhaoyu1022-glitch/LexiDawn/commit/309afe81aecfbfd84e5a9f52251c59f8e32c0575)。匹配的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**；XCTest61/0、XCUITest8/0，非旧绿色运行。
- 本报告自身的 docs commit 不自引用无法预知的 SHA；精确提交以本文件 GitHub History/最终交付说明为准。代码 SHA 与文档提交分别记录。
- PR #1 实查 closed、merged=false。没有关闭/合并任何 PR；保留 `round1-daily-cycle`，没有尝试删除。没有 force push 或重写远端历史。
- 三份既有审核/整改报告逐字节与起始 SHA 比较一致，没有覆盖。本报告是在原 `docs/reviews/` 新增的文件。

### 关键文件

- `LexiDawn/Domain/DailyTasks/DailyTasks.swift`
- `LexiDawn/Data/PersistenceModels.swift`
- `LexiDawn/Data/Repositories.swift`
- `LexiDawn/AppCore/DependencyContainer.swift`
- `LexiDawn/Features/Today/TodayFeature.swift`
- `LexiDawn/LexiDawnApp.swift`
- `LexiDawnTests/LexiDawnTests.swift`
- `LexiDawnTests/MigrationFixtures.swift`
- `LexiDawnUITests/LexiDawnUITests.swift`
- `.github/workflows/ios-ci.yml`
- `LexiDawn.xcodeproj/project.pbxproj`

## 2. R2-001 至 R2-012 整改矩阵

本节先记录修复与边界；是否通过以第4、5节对应SHA的实际日志为准。每项修改文件/关键符号另见下表，精确代码位置见§10。

| 编号 | 原问题与根因 | 实际整改 | 关键测试/层级 | 结果与残余边界 |
|---|---|---|---|---|
| R2-001 / P0 | 状态枚举把任意 deferred 当完成，非空字符串等同系统判断 | 通用更新一律拒绝 deferred；ReviewQueueEvidence 私有构造、由完整 eligible queue reader 读取生成并绑定 cycle/时间/版本；三个复习状态一次解析；生产 unavailable reader 抛错 | `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`, `testUnavailableNonemptyAndIncompleteQueuesCannotDeferReview`, `testEmptyQueueProofCannotBeReplayedForAnotherCycle`, `testVerifiedEmptyFixtureQueueSatisfiesReviewOnlyAfterExplicitReading` / Domain+Fake | 本轮适用缺陷已修复，相关回归在最终代码CI通过（§5）；未接入真实队列，合法空集合仅显式 fixture |
| R2-002 / P1 | 只保护 update，init/Record.domain 不校验组合 | throwing init+validate，状态 private(set)，proof/原因/时间/current 统一校验；已知非法历史先完整归档再 blocked；未知状态拒绝且保留 | `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations`, `testSwiftDataStrictDecodeRejectsLegacyDeferredAndRepairArchivesWithoutLosingAssignment`, `testUnknownPersistedStateRecoveryFailsAndRetainsOriginalRecord` / Domain+内存DB | 本轮适用缺陷已修复，相关回归在最终代码CI通过；未知损坏/重复指派不自动删改，需专门人工核对 |
| R2-003 / P1 | 两阶段 fallback、普通保存不回滚、关系可绕过 | 禁非原子 store，统一 RepositoryWriter，autosave=false，所有失败 rollback；创建同一次 save；普通保存检查文章/日期/ID/终态/current | `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`, `testSwiftDataUpdateFailureDoesNotLeakIntoLaterPreferenceSave`, `testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable`, `testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement` / 内存+磁盘 | 本轮适用缺陷已修复，相关回归在最终代码CI通过；提交前故障注入不冒称磁盘故障；只读磁盘测试是真正 save 错误；跨进程竞争无保证 |
| R2-004 / P1 | 重开后未重新读正文/关联/状态 | 第二容器新建所有 Repository；重查两个 ArticleRecord，比较完整 domain 周期及关键偏好；保留一个已完成和一个 carry-over 未完成周期 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` / 磁盘 | 本轮适用缺陷已修复，相关回归在最终代码CI通过；不是强制杀进程测试，不声称全部偏好字段逐个验过 |
| R2-005 / P1 | 测试名称/文档夸大 Fake 能力 | 原 Fake 测试明确改名；invalidCandidate 改真 SwiftData 并断言文章/周期皆空；单 current 测试先拒绝新周期、完成旧周期后新建 | 61 个 XCTest 源码方法与 8 个 UI 方法，见完整清单；实际数量见日志 | 全部61 XCTest/8 UI真实执行0失败；不以数量当证明，不删除失败target/关键断言 |
| R2-006 / P1 | Candidate 无元数据，许可/缓存可绕过 | Candidate 计算 SHA-256、英文词数、200词/分钟估算；主题必须提供；缓存权限/期限、来源署名、图片 URL/许可/署名校验；ageRange 可选 | `testDirectArticleRepositoryRejectsInvalidLicenseCacheImageAndMissingMetadata`, `testDiskContainerReopenRestoresCycleArticleAndPreferences` / DB | 本轮适用缺陷已修复，相关回归在最终代码CI通过；许可来源可信度仍依赖 M3 的来源注册表/授权核验，生产不注入假授权 |
| R2-007 / P1 | blocked/failed 无原因/假称可恢复，UI 没测禁用 | 四任务显示原因，四入口始终 disabled，说明“当前尚不能恢复学习”；真实重新读取/存储重开；旧 inProgress 转 blocked 并保留指派/证据 | `testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged`, `testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates`, `testStartupRetryRepeatsInitializationAndLoadsApp`, `testUnavailableInProgressRecoveryPreservesCycleArticleAndOtherProgress` / UI+DB | 本轮适用缺陷已修复，相关回归在最终代码CI通过；不声称尚未接入的学习功能现已能恢复 |
| R2-008 / P1 | 直接 article completed 无阅读/确认依据 | 通用 completed 拒绝；ReadingCompletionEvidence 绑定文章/内容SHA/进度/确认/时间；常规>=90%，手动确认允许低进度；默认无 reader 禁操作 | `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation`, `testProductionContractsRejectReadingCompletionAndUnknownQueue` / Domain+DB | 契约已修复且回归通过；未实现阅读器的真实进度采集，不能声称阅读功能交付 |
| R2-009 / P2 | carry-over 依赖打开次数，时区边界不足 | ADR-006 选择经过的 civil study dates，高水位不回退/重计；Gregorian日期差不按秒除86400；Today应用固定时区 | `testCarryOverCountsSkippedCivilDatesAndNeverRecountsRollback`, `testDSTAndTravelUseCivilDateHighWaterWithoutChangingAssignment`, `testViewModelHonorsFixedStudyTimeZoneAndGregorianDate` / Domain/Fake/VM+DB | 本轮适用缺陷已修复，相关回归在最终代码CI通过；规格有歧义已记录，历史计数保留不凭空重算 |
| R2-010 / P1 | 旧报告引用不可解析SHA、误述整合 | 不沿用ab70b5a；核对公开一父提交链、PR closed/unmerged；本次只引用插件实际返回且 main 接受的SHA | Git log / GitHub API / tree comparison | 历史原文按用户要求保留，本报告明确纠正，不把复制内容当PR merged |
| R2-011 / P1 | 旧CI代表新代码、测试层级夸大 | STATUS/README/架构/追踪/测试/日志/CHANGELOG重写准确边界；逐次记SHA/run；CI日志与xcresult上传 | 真实 Actions jobs/logs/artifacts，见 §5 | 代码、文档与本轮61+8/0证据已核对；文档提交自身运行另查，不自引用假定SHA |
| R2-012 / P1 | 同schema重开被当迁移，schemaVersion未实施流程 | 冻结c13906a与b894bda旧存储字段，旧模型建磁盘库后新模型打开；可选字段轻量升级；升级前store/WAL/SHM冷备份；失败不删库 | `testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences`, `testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive`, `testFailedStoreOpenRetainsOriginalBytesAndPreUpgradeBackup` / 旧磁盘升级 | 两条旧磁盘升级及损坏库保留原字节测试在最终CI通过；不虚称覆盖所有中间schema或真实设备用户库 |

### 逐项文件与关键位置映射

精确行号与固定代码SHA链接见§10；测试全名与层级见§4和追踪矩阵。

| 编号 | 实际修改文件/关键符号 |
|---|---|
| R2-001 | DailyTasks.swift：TaskStatus、DailyStudyCycle.update/resolveEmptyReview、ReviewQueueEvidence.evaluate；PersistenceModels.swift：Record.domain；Repositories.swift：upsert/validateCollection；LexiDawnTests.swift：deferred/queue回归 |
| R2-002 | DailyTasks.swift：throwing init/validate；PersistenceModels.swift：domain/repairKnownLegacyState/CycleRecoveryArchive；Repositories.swift：recoverLegacyRecords；LexiDawnTests.swift：构造/解码/修复测试 |
| R2-003 | DailyTasks.swift：AtomicCycleCreationStore/DailyCycleService；Repositories.swift：RepositoryWriter、upsert/normalizeCurrent、Article/PreferencesRepository；LexiDawnTests.swift：内存故障、只读磁盘、重试/关联测试 |
| R2-004 | LexiDawnTests.swift：testDiskContainerReopenRestoresCycleArticleAndPreferences；Repositories.swift：全新context fetch；PersistenceModels.swift：Article字段 |
| R2-005 | LexiDawnTests.swift、LexiDawnUITests.swift、docs/test-plan.md、requirements-traceability.md：分层测试和真实结果 |
| R2-006 | DailyTasks.swift：ArticleCandidate/ArticleCachePermission；PersistenceModels.swift：ArticleRecord/UserPreferencesRecord；Repositories.swift：文章写入门禁/validateStoredMetadata |
| R2-007 | TodayFeature.swift：TaskStatusRow/actionButtons/retry；LexiDawnApp.swift：AppStartup/StorageUnavailableView；LexiDawnUITests.swift：禁用/原因/恢复；project.pbxproj：原生窗口配置 |
| R2-008 | DailyTasks.swift：ReadingCompletionEvidence、completeReading、DailyCycleService.completeReading；Repositories.swift：实际正文版本关联校验；LexiDawnTests.swift：确认/进度/不可用契约 |
| R2-009 | DailyTasks.swift：markCarryOver/studyDate；TodayFeature.swift：load时区；decisions.md：ADR-006；LexiDawnTests.swift：跨多日/DST/旅行/回拨 |
| R2-010 | 本报告§1/§2历史纠正、STATUS.md、CHANGELOG.md、daily日志；旧报告按要求保留 |
| R2-011 | README/STATUS/CHANGELOG、architecture/test-plan/requirements-traceability/decisions/daily及本报告；ios-ci.yml：toolchain/日志/plist门禁 |
| R2-012 | AppCore/DependencyContainer.swift：openPersistentStore/backupBeforeUpgrade；PersistenceModels.swift：可选新增列；MigrationFixtures.swift：两版冻结旧schema；LexiDawnTests.swift：旧磁盘升级/失败保留 |

### R2-001 证据来源与周期完成

1. `TaskStatus.isSatisfied(for:)` 不再把 deferred 当作独立完成依据；周期判断验证结构化结果。
2. `DailyStudyCycle.update` 拒绝所有 task 的 deferred/completed，文章 deferred 给明确错误；不能通过“test”“no-review-items”或中文系统理由伪造。
3. `ReviewQueueEvidence.evaluate` 查询 reader，必须是完整可复习集合，包含近期新词，且真正为空；非空、不完整、无版本、不可用都拒绝。构造器私有，业务字符串不产生证据。
4. 证据只适用于原周期；重复同结果不改变完成时间；不同周期不可重放。空队列同时解析 review/matching/cloze，无部分 deferred 造成的不一致。
5. M5 正常/部分复习契约也保留：`ReviewSessionResult` 只能从 `ReviewSessionReading` 读取固定已保存会话，验证非空题目、唯一ID、已答集合与题组关系、相同会话进度单调。没有 adapter 时服务抛错，不能传任意状态代替答题结果。
6. 生产 review queue 不存在，不因数据库没有复习模型就假定“没有应复习词条”。本轮不声称真实空队列业务已接入。

### R2-002 历史记录恢复细节

`Record.domain()` 不再只转换 raw enum，而是调用领域统一校验。已知旧无凭据终态通过 `repairKnownLegacyState` 保存 `CycleRecoveryArchive`：原 ID、文章、日期/时区、四状态/四原因、创建/更新/完成时间、carry-over高水位、指派/完成原因、current与旧凭据均保留。正常合法状态不重新写入；恢复事务任一校验/保存失败则整体 rollback。

无依据 completed 不冒称真实阅读/答题完成，也不直接删掉用户进度：旧值在记录审计快照和升级前数据库中保留，工作状态变为原因明确的 blocked。文章/日期/时区/正文不换新。未知 enum、损坏凭据、非法日期或重复/孤立关联不静默改成 ready；显式报错并保留原库。本轮尚无这些未知损坏情况的自动合并/人工修复 UI，列入残余边界。

### R2-003 原子性、失败与并发范围

- 生产服务要求 AtomicCycleCreationStore；不存在先写文章再写周期的 fallback。
- Writer 关闭 autosave，在真实托管对象变更后只调用一次save；失败rollback并传播、弃用失败context。所有文章/周期/偏好写入口共享相同策略。真实只读磁盘save测试进一步证明，rollback并不保证同context中不存在注册幽灵对象：因此每个写操作使用独立ModelContext，失败后永久丢弃；每次公开查询用新context，不复用失败缓存。
- 创建检查 cycle.articleID == candidate.id；普通保存必须已有文章；新周期仅 ready，旧未完成周期存在时拒绝新指派。相同ID不同文章快照拒绝覆盖，同日/同文章分配拒绝；不同ID/URL但相同正文也按SHA-256拒绝（旧hash缺失时从原正文计算）。
- current 总是最早未完成周期，而不是最后保存的那个。历史多个未完成周期保留，只派生唯一current。
- 已保存周期身份不可变、UTC更新时间/跨日计数不能回退；延迟恢复的有效结果保留源事件时间，updatedAt仍取高水位，completedAt取最后一项有效结果时间；终态凭据不能被换掉，完成时间不能被重写。
- 支持单个应用容器、MainActor串行写入口；不同context顺序调用有独立测试。没有声称多容器/跨进程竞争受数据库唯一索引保护，当前没有独立extension/后台写进程。新增这种写源前必须增加共享协调器或数据库约束及竞争回归。
- Preferences编辑先捕获完整detached快照并回滚编辑context，再在专属事务context应用；保存后重新load，不能跨await悬置托管编辑。复制字段经静态清单核对无遗漏。注入提交前错误测试和真正只读磁盘save测试分开统计。

### R2-004 重开断言的实际范围

第二个容器重新创建 Repository 后比较完整 `[DailyStudyCycle]` 值，覆盖cycleID/articleID、四状态/原因、reading/review凭据、原分配日期/时区、created/updated/completedAtUTC、completionReason、isCurrent、carryOverCount/lastCarryOverLocalDate/assignmentReason。重新读取每条 ArticleRecord，检查ID关联、正文、哈希、词数、估算时间、主题、许可和缓存权限，并比较重新构造的Candidate全部字段。

偏好逐项验证displayName、ageRange、timeZonePolicy、fixedTimeZoneID、autoAddOnWordTap、dailyReviewLimit、阅读通知开关、readerTheme、两组提醒时分及matching/cloze数量。没有声称覆盖全部偏好字段或模拟OS强杀进程。两周期分别已完成和未完成，明确断言未完成仍current且carry-over保留。

### R2-005 六个原测试的真实性审查

| 原测试名称 | 当前精确名称 | 实际层级与补强范围 |
|---|---|---|
| testInvalidCandidateCannotCreateCycleOrArticle | `testInvalidCandidateCannotCreateSwiftDataCycleOrArticle` | 已由只操作内存Store改为真实内存SwiftData，明确断言文章和周期均未写入 |
| testRetryingFailedRepositoryWriteCanSucceedWithoutDuplicateCycle | `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle` | 诚实标注FakeStore；真正数据库故障另由AtomicCreateInjectedSaveFailure和ReadOnlyDiskStore完整名称用例证明，不借此例声称DB重试 |
| testTodayViewModelRetryRepeatsFailedWrite | `testViewModelWithFakeStoreRetriesOriginalBlockedUpdate` | 真VM+FakeStore写失败，验证重试原命令；另加`testViewModelReadRetryDoesNotReplayPendingFakeStoreWrite`，不冒充磁盘失败 |
| testRepositoryMaintainsSingleCurrentCycle | `testSwiftDataRepositoryRejectsNewCycleUntilOldCompletesAndMaintainsCurrent` | 真实内存SwiftData；先拒绝旧周期未完成时新建，再完成旧周期后新建；另测历史多个current保留周期并归一最早 |
| testSameDayProvisioningIsIdempotent | `testFakeStoreSameDayProvisioningIsIdempotent` | 原例只是FakeStore；真实内存库另测`testSameContainerSeparateContextsObserveSequentialProvisioningWithoutDuplicates`和原子重试；不夸大为并发/跨进程 |
| testDateRollbackDoesNotIncreaseCarryOverCount | `testFakeStoreDateRollbackDoesNotIncreaseCarryOverCount` | 原例为FakeStore；另测领域多日/DST/旅行高水位与真实库clock rollback恢复，不冒称真机改时区测试 |

此前通过字符串test将复习deferred的helper已经改为明确的阅读凭据和显式完整空队列fixture。删除的是错误的业务假设，没有删除失败target或降低合法/非法路径断言。数据库、UI和迁移新增断言按各自真实能力记录，完整方法名见§4。

### R2-006 字段与许可语义

正文SHA-256从UTF-8计算，不由外部随意提供；英文词数估算保留撇号和连字符，阅读时长按200词/分钟向上取整，至少1分钟。主题来自候选，空列表拒绝而不是默认空实现。词数/时长是估算，不宣称语言学精确计数或个性化速度。

许可核验必须同时提供licenseID、sourceAttribution、独立的fullTextDisplayAllowed及明确的全文缓存permission（persistent或until），过期不允许新写入。图片需HTTP(S)URL、imageLicenseVerified、imageLicenseID及imageAttribution。contentStatus通过枚举限定available/partial/unavailable，只有available且非空英文正文可建立必做周期。ArticleRepository单独调用也执行相同门禁；没有用production假新闻或虚构授权补候选。

旧文章缺少新增缓存许可字段时保留原数据，绝不自行填“永久许可”。当前UI不展示正文；未来阅读器接入必须重新核验旧快照权利和期限。

### R2-008 阅读契约

常规finishButton/endConfirmation需progress为有限0–1且>=0.9；manualConfirmation明确表达主动手动确认，低进度可完成，覆盖短文章/进度恢复不准确/有意快速完成，不要求点击任何生词。凭据绑定文章ID、64位正文哈希、确认时间；Repository还核对实际文章版本。只打开文章或通用update不产生凭据。默认reader capability=false，因此未接入时无生产完成操作。

### R2-010 历史纠正

此前报告的ab70b5a不能从已获取公开Git对象解析；本轮再次GET GitHub commits/ab70b5a实际返回422，message为“No commit found for SHA: ab70b5a”，不能当作GitHub已存在的整合SHA。可核对的`c291c225273774df59a28e3bd9c784550253682c`父提交为`7e4c7a4ea79a93a34862abd9241ed2122a9bbd2e`，是一父普通提交。本轮不声称此前曾完成某次GitHub正式merge，不把PR字段中预生成的merge_commit_sha解释成merged。用户要求旧报告不覆盖，因此以新报告纠正其证据。

## 3. 超出审核报告的新发现

| 新发现 | 影响 | 实际处理/边界 |
|---|---|---|
| 新偏好默认20词/5连线/5拼写，规格默认12/6/4；字号18/行距1.2与建议19/1.45–1.65不符 | 初始行为偏差 | 新默认改12/6/4、19/1.5；历史保存值不重置 |
| Today未使用已保存fixedTimeZoneID | 日期归属可能跟随错误时区 | ViewModel读取统一偏好，fixed合法时区计算日期；新增VM+DB测试 |
| Calendar可能非Gregorian，日期字符串与领域Gregorian校验不一致 | 年份/日期键不稳定 | 学习日期统一Gregorian且使用所选时区；Buddhist日历回归 |
| 已完成周期的内容哈希恢复时未与ArticleRecord比较 | 结构正确凭据可能关联错正文版本 | 读/写Repository均核对哈希 |
| 相同Article ID的upsert可替换已指派正文 | 内容锚点/历史进度可能损坏 | 完整快照幂等重试；冲突快照拒绝，不无条件覆盖 |
| SwiftData真实save失败后rollback仍留注册幽灵对象 | hasChanges=false不能证明同context查询干净 | 真磁盘测试保留原断言；写context隔离、失败弃用、新context读取，并增强可写重试/已有周期更新失败验证 |
| CI工具链探测awk提前exit造成Broken pipe | xcodebuild异常退出134，测试根本未运行 | 改为完整消费输入，保留pipefail；不是容错吞掉错误 |
| 已保存复习事件被重试时刻替换 | 幂等请求可能改写完成时间/误报冲突 | 读取源recordedAt，重复结果保持完成时间；专门服务层测试 |
| 旧CI父目录缺失后CoreData512自恢复 | 日志噪声、环境路径风险 | 打开生产存储前先建父目录；已核对最终日志未见旧512 |
| UI测试固定上滑8次、每次读取前固定下滑6次，无滚动进展仍继续 | 单个blocked/failed用例192次上滑、36次下滑；整组UI长达10–12分钟 | 改指定today-scroll、按目标方向定位；到边界/无进展立即失败并附截图/AX层级，所有可见/禁用/真实点击/状态断言保留 |
| 现代iPhone17Pro上的AX窗口却为320×480 | 文章按钮Y604.67不可见，多次滑动位置不变；缺少原生launch/scene配置 | App Debug/Release补标准Info.plist生成开关，CI验证产物；新增现代窗口尺寸XCUITest。原生窗口断言已在最终CI通过，最终PNG尺寸1206×2622 |
| ViewModel读失败重试可能重放先前pending写 | “重新读取”可能意外更新状态 | 仅saveFailed重放写，其余状态真实重读；新增FakeStore VM测试检查保存尝试数和状态 |
| 非有限日期/缓存期限及carry-over加法溢出 | 非法历史输入可能通过比较或触发Int陷阱 | finite门禁、日期长度/计数高水位一致性、addingReportingOverflow；失败保持原计数 |
| Article恢复仅验证enum，可能接受错误正文版本或负统计值 | 完成凭据与实际正文不一致 | validateStoredMetadata统一拒绝非法日期/统计/内容状态/正文指纹，旧nil权利和hash不补假值 |
| 复习源事件时间可回退；复习已完成但文章未完成时可由直接Repository替换复习终态结果 | 可能改写复习完成依据并影响最终完成时间 | Domain拒绝旧recordedAt；Repository同时保持事件单调和复习终态结果完全相同；真实内存SwiftData测试先构造结构合法对象再调用save，防止仅因构造错误而虚假通过 |

未发现即可保证没有其他bug不是合理结论。本轮继续记录跨进程竞争、未知损坏人工恢复、真实模块adapter及设备验收边界，见§8。

## 4. 测试证据

### 4.1 本地实际执行

- `git clone`、`git log/show/rev-parse`、完整源码/文档阅读。
- `git diff --check`：通过。
- Python解析workflow YAML及scheme XML：确认两个TestableReference均skipped=NO，项目6处target Debug/Release deployment值27.0；新增MigrationFixtures被纳入测试Sources。
- 三份旧报告与起始SHA逐字节比较一致。
- 本地工具探测：无swift、xcodebuild、gh；没有运行iOS构建、XCTest、SwiftData或XCUITest。

### 4.2 层级与故障模型

1. FakeStore：服务分配/幂等/时间规则，及VM pending操作重试，不证明数据库事务。
2. 内存SwiftData：真实ModelContainer/ModelContext、插入/托管对象修改、save前注入错误、rollback/retry、独立context重读；故障hook不冒称磁盘满。
3. 磁盘SwiftData：相同模型重开和allowsSave=false真实SwiftData保存异常；覆盖原子新建、已有周期更新和偏好更新，失败后从相同Repository新context读取与重开后原库检查，恢复可写后重试成功。
4. 旧磁盘schema升级：由冻结旧模型建库，释放作用域后新模型打开，验证文章、周期、偏好、状态和升级前备份。不同于同模型重开。
5. XCUITest：运行真实app，以DEBUG+simulator显式测试环境创建隔离内存fixture；禁用按钮坐标点击、重新读取和四任务状态/原因、旧inProgress说明、存储重试。不是生产真实文章来源端到端测试。

### 4.3 XCTest源码清单（运行数量以CI为准）

- `testDesignTokensUseFourPointGrid`
- `testRootTabViewCanBeConstructed`
- `testFirstCycleUsesCandidateAndStoresArticleAssociation`
- `testFakeStoreSameDayProvisioningIsIdempotent`
- `testNoCandidateDoesNotCreatePlaceholderCycle`
- `testCompletedCycleSameDayDoesNotCreateAnotherCycle`
- `testOldIncompleteCycleWinsAfterDateChanges`
- `testRepeatedRefreshDoesNotIncreaseCarryOverCount`
- `testArticleAndReviewRemainIndependent`
- `testLegalAndIllegalStateTransitionsAreExplicit`
- `testVerifiedEmptyFixtureQueueSatisfiesReviewOnlyAfterExplicitReading`
- `testArticleCannotBeDeferred`
- `testDeferredReviewCannotCompleteCycleWhenArticleIsIncomplete`
- `testBlockedAndFailedNeverCountAsCompleted`
- `testCrossTimeZoneKeepsAssignedArticleAndDate`
- `testFakeStoreDateRollbackDoesNotIncreaseCarryOverCount`
- `testTodayStartDoesNotPersistUnavailableInProgressState`
- `testSwiftDataCycleAndPreferencesSurviveRepositoryRebuild`
- `testDiskContainerReopenRestoresCycleArticleAndPreferences`
- `testSwiftDataRepositoryRejectsNewCycleUntilOldCompletesAndMaintainsCurrent`
- `testInvalidCandidateCannotCreateSwiftDataCycleOrArticle`
- `testArticleRepositoryRejectsNormalizedDuplicateCanonicalURL`
- `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle`
- `testViewModelWithFakeStoreRetriesOriginalBlockedUpdate`
- `testTodayViewModelShowsNoCandidateAndFixtureCycleState`
- `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`
- `testUnavailableNonemptyAndIncompleteQueuesCannotDeferReview`
- `testEmptyQueueProofCannotBeReplayedForAnotherCycle`
- `testProductionContractsRejectReadingCompletionAndUnknownQueue`
- `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation`
- `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations`
- `testSwiftDataStrictDecodeRejectsLegacyDeferredAndRepairArchivesWithoutLosingAssignment`
- `testUnknownPersistedStateRecoveryFailsAndRetainsOriginalRecord`
- `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`
- `testSwiftDataUpdateFailureDoesNotLeakIntoLaterPreferenceSave`
- `testSwiftDataArticleAndPreferenceFailuresRollBackManagedChanges`
- `testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable`
- `testSwiftDataRepositoryRejectsMissingArticleMismatchedIDDuplicateDateAndReassignment`
- `testDirectArticleRepositoryRejectsInvalidLicenseCacheImageAndMissingMetadata`
- `testCarryOverCountsSkippedCivilDatesAndNeverRecountsRollback`
- `testDSTAndTravelUseCivilDateHighWaterWithoutChangingAssignment`
- `testUnavailableInProgressRecoveryPreservesCycleArticleAndOtherProgress`
- `testStartupRetryReopensWithoutDeletingStore`
- `testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences`
- `testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive`
- `testFailedStoreOpenRetainsOriginalBytesAndPreUpgradeBackup`
- `testPartialReadingReviewAndMatchingProgressSurviveMultipleDaysWithoutNewAssignment`
- `testSavedReviewSessionResultRejectsInvalidAnswersAndCannotRegressOrMixEmptyQueue`
- `testSameContainerSeparateContextsObserveSequentialProvisioningWithoutDuplicates`
- `testViewModelHonorsFixedStudyTimeZoneAndGregorianDate`
- `testSavedReviewSessionRepeatedServiceReadPreservesCompletionTimestamp`
- `testSwiftDataHistoryMultipleCurrentFlagsResolveToEarliestWithoutDeletingCycles`
- `testPersistedMalformedQueueProofAndCompletionMetadataCannotBypassValidation`
- `testDelayedEvidenceAfterCarryOverPreservesEventTimeAndUpdateHighWater`
- `testPersistedInvalidArticleStatusAndFingerprintAreErrorsWithoutDeletingBody`
- `testArticleRepositoryRejectsIdenticalBodyAcrossDifferentIDsAndURLs`
- `testPreferenceSaveRejectsInvalidValuesAndLoadRejectsUnknownVersionWithoutReset`
- `testReadOnlyExistingCycleUpdateFailureDoesNotLeakAndWritableRetrySucceeds`
- `testClockRollbackDoesNotPreventSafeInProgressRecoveryOrLoseAssignment`
- `testViewModelReadRetryDoesNotReplayPendingFakeStoreWrite`
- `testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement`

### 4.4 XCUITest源码清单

- `testAppUsesFullSizeWindowOnModernCISimulator`
- `testFivePrimaryTabsAreVisibleAndSelectable`
- `testTodayShowsHonestEmptyStateWhenNoArticleProviderIsConnected`
- `testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates`
- `testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged`
- `testHistoricalInProgressBecomesExplainedBlockedWithoutChangingArticle`
- `testStartupFailureHasRealRetryAndNeverPretendsDataLoaded`
- `testStartupRetryRepeatsInitializationAndLoadsApp`

## 5. CI 证据

### 5.1 基线（不是本次整改结果）

- SHA b894bdacadbee3a52073f6c300ab043c7e43caa8，run [40706618129](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40706618129)，success。
- 实际job122880356941日志：XCTest25/0，UI2/0。artifact12823774520。
- 有CoreData512/父目录缺失/沙箱拒绝后recovery成功、multiple destinations、Node/punycode警告；不能描述为完全无错误。

### 5.2 本轮实际运行

| GitHub SHA | Run | 实际结论 | XCTest/UI执行 | 原因与后续 |
|---|---|---|---|---|
| 0d0dd8dc940ffe309de5bc48be3d00d6cbbdbb31 | [41164317564](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164317564) | failure | app编译失败，测试均未执行 | MainActor协议默认参数构造错误；后续代码修复 |
| 7758aa49b99ffaa04c6acefd26cc879e7bf9fb42 | [41164403744](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164403744) | failure | app编译失败，测试均未执行 | Swift复合allSatisfy表达式type-check超时；拆解为switch |
| 1104143c2a5905431905dded8418420ba8f83005 | [41164496857](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164496857) | failure | app build成功，test build失败，测试均未运行 | 旧schema fixture补@testable import |
| 459b89dbd60a7c1f51499768899cc8c54d6ff710 | [41164705881](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164705881) | failure | 工具链探测失败，测试均未运行 | awk提前关闭管道导致xcodebuild Broken pipe/exit134，已修复 |
| 2c9733075e444791c612fafb9f44d97809c291ed | [41164807243](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164807243) | failure | XCTest 53/1 failure；UI未执行 | readonly失败后同context幽灵对象断言失败，后续隔离context修复 |
| 9eb6adbb205f3ef8016cd84e4b92ea6f2ca16d76 | [41164982359](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41164982359) | failure | XCTest 55/1 failure；UI未执行 | 同一readonly幽灵对象断言；两条真实旧schema升级及磁盘重开已实际通过，不扩大为整轮通过 |
| d5ee6112211e574a6d9e44b860f88952dd9503d8 | [41165126166](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41165126166) | failure | XCTest56/1 failure；UI未执行 | 同一readonly断言，保留失败证据 |
| a40fe00248fb4d5ea01c6dbcd894abe8f8a899e6 | [41165403856](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41165403856) | failure | XCTest57/1 failure；UI未执行 | 同一readonly断言，保留失败证据 |
| 468028e484ae5bbfbcb940131455386dfd0c3b04 | [41165752358](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41165752358) | success | XCTest58/0；UI6/0，759.3秒 | 隔离context后原真实磁盘断言通过；UI仍有无效重复滑动，不能证明更严格坐标点击断言 |
| 57eb1f5f78b90913d23887b300d5df8d58ae988f | [41165851835](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41165851835) | success | XCTest59/0；UI6/0，665.5秒 | 回拨恢复通过；不能当最终更严格UI版本证明 |
| 007df816758207551cef44d5a45fd8557ae80f7d | [41165940802](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41165940802) | failure | XCTest59/0；UI6个用例、12个断言失败 | 更严格可见性断言揭示旧UI导航无进展；保留断言排查 |
| 7ff799870643acb39d3653905ecc1b6ff2acb7fa | [41166034117](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41166034117) | failure | XCTest59/0；UI7个用例、12个断言失败，651.467秒 | 启动成功重试UI通过；两个禁用入口用例可见性失败。artifact13029591495实际下载解析 |
| b1c76345e265e7d70d5e54a04050672ae6deb069 | [41166795095](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41166795095) | failure | XCTest60/0；UI7个用例、12个断言失败，613.205秒 | 新VM读重试回归通过；旧UI定位同因失败 |
| 0db7d2c6eaec77e6a56ad4c8e8e6ff21784e4eeb | [41167194120](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41167194120) | failure | XCTest60/0；UI7个用例、12个断言失败，798.917秒 | 时间/溢出回归通过；旧UI同两用例可见性失败 |
| d61ea28aff3838a3ec6e2cb988cad1ba6e8decdd | [41167569542](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41167569542) | failure | XCTest60/0；UI7个用例、12个断言失败，738.784秒 | 文章元数据/指纹回归通过；旧UI同两用例可见性失败 |
| 41096f3426dbb2e134b41b5b025b3ddaeec856c3 | [41168562880](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41168562880) | success | XCTest60/0；UI8/0，369.915秒 | 原生plist、现代窗口尺寸及全部严格UI断言通过；artifact13030870033 |
| 4705e41fc2dd398c3b676c0498e48a01251ed5c0 | [41169162143](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41169162143) | success | XCTest60/0；UI8/0，345.950秒 | 补强四任务通用completed拒绝断言通过；artifact13031225084实际下载，未含图像附件 |
| 024de16eab89e3b799f1292261a6be982db453af | [41170273715](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170273715) | success | XCTest60/0；UI8/0，363.348秒 | 5张原始PNG已实际下载并验证附件映射；artifact13031261844；不是最终61测试版本的替代证据 |
| 309afe81aecfbfd84e5a9f52251c59f8e32c0575 | [41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) | **success** | **XCTest61/0；UI8/0，321.466秒** | 包含新增真实内存SwiftData的旧时间/终态替换回归；全部原断言与截图采集保留；artifact13031277540 |

最终代码运行已结束并核对完整job日志，job [124448014754](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/job/124448014754)；两组均输出TEST SUCCEEDED，XCTest61个用例/0失败，XCUITest8个用例/0失败，无跳过记录。本文§4的61+8个精确方法名与运行日志逐一比对。

- artifact：[13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)，名称 `LexiDawn-xcresults-41170754181`，大小4521946字节，包含unit/UI xcresult及完整文本日志。
- 实测UI用例合计321.466秒；UI步骤383秒，模拟器选择/冷启动步骤168秒，整个job766秒。计时包含范围不同，不混写。
- 旧7ff7998运行UI用例651.467秒；4705e41修复后345.950秒且整组仅3次定向上滑/0次下滑，用例由7增加到8；最终版本另以上述实测记录。不同runner的计时有波动，不承诺恒定运行时间。
- 原生Info.plist检查、现代窗口尺寸回归通过；没有为了优化耗时删除可见/禁用/坐标点击或状态断言。
- 文档在代码验证后单独提交；本报告不预填该docs commit自身尚未知的SHA或结果。精确最终main及其Actions在交付说明另列。

workflow核查：保留Debug/Release，app/unit/UI三target，scheme两个测试均启用；产品27.0，CI checkout临时26.5，指定simulator ID。构建测试失败真实传递；只有showdestinations诊断容错保留。unit/UI经tee保存日志并用set -euo pipefail保留退出码，上传xcresult与log。没有删target、skip测试或用旧绿色运行证明新代码。旧run的readonly失败断言保留，修复写context复用而非降低断言。

iOS26.5兼容模拟器通过也不代表iOS27、真机、Release签名IPA、VoiceOver、动态字体、深色模式或全部产品要求通过。

### 5.3 用户指出的两次UI失败与耗时调查

已独立读取run41165940802、41166034117的job日志，并实际下载后者artifact13029591495（unit/UI完整xcresult及log，167560852字节）。两次单元均59/0；失败集中在两个UI用例的12个可见性断言，不能将其描述成数据库回归失败或忽略为“正常慢”。

run41166034117的blocked/failed用例326.724秒、ready用例137.268秒；单个blocked/failed用例192上滑+36下滑。XCTest的Wait for idle、取AX快照本身是正常同步日志，但固定动作、目标无进展仍继续不是必要流程。旧helper既不检查方向，也不检查是否滑到底，还每次状态检查先固定6次下滑；失败后仍继续执行，放大耗时。未发现业务代码因此产生无限学习循环的证据。

实际xcresult ActionDeviceRecord为iPhone17Pro（iPhone18,1）、iOS26.5；AX应用/scroll frame为320×480，文章按钮Y604.67，反复滑动位置未变。工程缺少原生UILaunchScreen和UIApplicationSceneManifest生成设置。按Apple标准补齐两项开关，新增产物plist和实际现代窗口尺寸门禁。UI helper改用唯一标识滚动容器、按方向滚动、无进展立即失败并保存诊断；测试仍实际点击disabled控件并重读全部任务状态。UI步骤上限20分钟，达到上限仍是失败，不吞错。共享derivedData目录减少重复构建工作，未减少测试target或业务断言。4705e41的实际UI日志整组仅3次定向上滑、0次下滑，UI用例345.950秒；目标无进展的固定数百次动作已消除。原生窗口断言和全部可见/禁用/实际点击/状态断言通过。最终含截图附件的运行41170754181也已通过，实际截图与来源记录见§5.5。

### 5.4 已核验的故障证据解释

run41164982359日志中，旧schema两条测试分别passed；55个单元测试共1失败，失败点是只读save后的Article同context查询非空。NSCocoaErrorDomain259/SQLite26来自故意损坏数据库测试，513来自真实只读save测试；这类预期错误日志不是新的生产异常，也不能被一概删除或称作无错误。该运行和最终代码完整日志均未再出现旧512父目录错误。

框架/runner警告包含AppIntents metadata skipped（没有AppIntents依赖）、已签名测试framework未strip、Node20/punycode/url.parse弃用提示。最终代码日志也核对了这些warning，并有multiple matching destinations提示；未称日志完全无错误。预期CoreData259/SQLite26和只读save513分别归属故障用例；最终日志未再出现旧512父目录错误。

### 5.5 真实运行截图交付

用户请求运行截图后，在既有8个UI测试内增加5个keepAlways附件，没有新增占位测试或降低断言。最终截图实际来自本节列明代码309afe81、run41170754181、artifact13031277540中的LexiDawn-ui.xcresult；名称由真实ActionTestAttachment的payloadRef映射复核。5张均为原始PNG，1206×2622像素；提取后的每个文件与解压后的附件payload逐字节相同，CRC和SHA-256核验通过，没有重绘、裁剪、改状态栏或生成图片。

| 实际附件名称 | 场景和边界 | 原始字节数 | SHA-256 |
|---|---|---:|---|
| today-empty-native-window | 今日空状态；当前未接入文章来源时的真实界面 | 282711 | `8cb973887e14095dbd49870482b2f40598b0eaf6d6a4e5683284e495ae096cad` |
| today-ready-isolated-fixture | 待开始；显式隔离测试文章，非真实内容或授权 | 684083 | `b21436bbfeba50f0f10f6198482aa0d694611571d0028d8ec9005a57091761cf` |
| today-blocked-isolated-fixture | 被阻塞；四任务原因与禁用入口，显式测试场景 | 811425 | `b03b7b9df0b31298e61d7293a6c32388c4035de5f44e0aeaeb529c305fd12c97` |
| today-failed-isolated-fixture | 执行失败；显式测试场景 | 818820 | `78eef439753a4ff317f658d51e7e8c49ddc166febe5d1fdbee9b986b38756219` |
| storage-unavailable-isolated-fixture | 存储不可用；显式factory失败测试场景 | 161036 | `4f0a96e9581588a30f762eece41d69350e9022b5d70b408a326e09f176612288` |

空状态与当前未接入文章provider时的界面一致；ready/blocked/failed/storageFailure为显式DEBUG模拟器隔离fixture，文章和许可不是生产真实内容，失败由测试注入。画面证明当前SwiftUI实际运行效果，不证明阅读器/复习已经接入，也不是iOS27或真实iPhone截图。截图原文件与说明/manifest打包交付给用户；不将二进制图像或私人交付链接提交到公开仓库，审核者可从上述Actions artifact中的同名附件核对。

## 6. 数据安全与迁移

- 新增Data/String字段为可选，不删旧列，不新增会把冲突旧记录强行upsert合并的唯一约束。历史偏好默认存储值保留，新建偏好使用新默认。
- 打开原default store之前保留一次冷启动备份，包含store/WAL/SHM；先复制到唯一staging目录，成功后rename到固定before-r2目录，不覆盖既有备份。无活动外部写进程是当前保障前提。
- 旧模型来自可核验SHA，MigrationFixtures冻结旧存储字段；本轮使用SwiftData自动轻量迁移，没有把UserPreferences.schemaVersion说成物理store版本迁移器。
- 结构升级与语义恢复分开：旧无依据终态原值在archive/backup保存，转换为解释明确的blocked；未知状态/孤立记录/重复指派保留并报错，绝不删除或重新指定文章。
- 事务失败rollback并丢弃写context，读取也用新context，重试不复用失败对象。不把保存失败返回成功。
- 损坏库打开错误测试保留原字节与备份，没有删库fallback。实际升级、备份可读性及错误路径已在上述最终代码CI测试通过，证据范围限于冻结的两版旧模型和受控模拟器环境。

## 7. 文档与架构变更

STATUS与README区分源码实施、旧基线结果和本次运行；CHANGELOG记录范围与限制；architecture记录证据来源、同步unit-of-work及并发边界；decisions新增ADR004–010解释完成契约、历史修复、carry-over歧义和迁移；requirements-traceability按规格/实现/测试层级/结果/未验边界记录；test-plan不再把FakeStore等同真数据库；daily记录每次真实编译失败与修复。本文件在docs/reviews新增，旧三报告不修改。

## 8. 未解决与未验证事项

- 本轮适用代码的61 XCTest/8 UI回归均已通过，R2逐项修复和证据已交付；仍需独立审核复验。下列验证缺口保留，**不宣称整个SPEC或所有最终验收条件均已完成**。
- 真正的文章来源、许可核验注册表、阅读器进度/确认adapter、复习队列与已保存会话adapter属后续模块，生产不可用即拒绝，不伪造结果。
- 跨进程/多容器同时写入、真实断电/磁盘满、OS强制杀进程、真实用户设备旧库未实测。当前串行主actor保障不能扩大解释。
- 未识别状态、重复历史日期/指派、孤立周期保留并解释错误；尚无安全自动合并/人工数据修复UI。这些需要专门核对原始数据，不可直接删除解阻塞。
- 许可字段验证是数据契约，不能从任意licenseID字符串推断外部授权真实有效；M3 adapter必须核对来源登记表。旧正文无缓存权利证据不补假许可。
- iOS27产品工具链、真实iPhone、无障碍/最大动态字体/深色模式/性能、签名IPA均未验证。

## 9. 最终自检

| 自检项 | 当前证据/结论 |
|---|---|
| SPEC最高依据/未擅自改规则 | SPEC未修改；完成确认/空队列/旧任务保留均以§2/§19/§30为依据 |
| 任意字符串deferred绕过 | 领域拒绝，构造/解码/Repository同约束；最终代码相关回归通过，见§5 |
| 所有输入不变量 | throwing init、validate、Record.domain、Repository关系/身份校验；未知损坏不放行 |
| 原子创建与rollback | 单writer、无fallback、注入及只读磁盘测试；不虚称跨进程 |
| 磁盘重开文章与偏好 | 第二容器真读ArticleRecord；测试范围明确 |
| 旧schema | 双历史模型真实升级、备份可读性与打开失败保留原库实际通过；不冒充同模型重开 |
| UI解释和恢复真实 | 未接入disabled、原因、尚不能恢复学习；重读/重开执行真实操作 |
| 测试不降级 | 没有删target/跳过失败测试；Fake改名并补真DB/UI |
| CI/SHA准确 | 仅实际GitHub接受SHA；每次失败如实列；最终代码61+8/0和artifact已核验；docs提交自身另查 |
| 保留报告/分支/PR真实状态 | 三旧报告逐字节不变；旧分支保留；PR#1 closed/unmerged |
| AGENTS文档/日志要求 | 本批同步文档与矩阵，引用SPEC原文；本地无Xcode如实说明 |
| 是否现在能宣布完整通过 | 本轮适用整改自动回归通过，可按固定SHA/报告复核；独立验收未执行，整产品/iOS27/真机等边界未完成，不宣布全部最终标准通过 |

### 对用户18项最终条件的逐条核对

| 条件 | 本轮证据与状态 |
|---|---|
| 1 任意deferred领域绕过 | 已修复；四任务/五类任意理由拒绝且原值不变，合法/非空/不可用队列、构造和解码回归通过 |
| 2 所有输入和恢复入口状态不变量 | 已修复适用入口；throwing init/validate/Record.domain/Repository统一检查，非法已知历史审计后blocked；未知损坏保留报错 |
| 3 真实SwiftData失败和rollback | 通过内存托管变更故障注入及只读磁盘真实save错误；丢弃失败context；真实已有周期和偏好失败/可写重试通过 |
| 4 文章与周期关联 | 创建单次save；缺文章/错ID/重复日期/重复指派均拒绝；失败后文章/周期无残留 |
| 5 重复创建/分配/current | 同容器MainActor支持边界内通过；跨context顺序测试，最早未完成唯一current；不声称跨进程锁 |
| 6 磁盘重开文章/周期/偏好 | 通过；第二容器真读正文/许可/关联、全周期值、列明偏好和carry-over未完成周期 |
| 7 本轮适用规格字段 | 指纹/词数/时长/主题/许可/缓存/图片与ageRange已实现并回归；生产来源核验属M3未接入，不补假授权 |
| 8 旧schema迁移 | 两个明确支持的历史磁盘schema实际升级、备份可读与打开失败原字节保留通过；未知中间schema/真机旧库未验 |
| 9 未接入功能不伪造进度 | 默认reader/queue/session不可用即拒绝；四按钮disabled和实际点击后状态不变通过 |
| 10 blocked/failed真实行为 | 四任务原因、尚不能恢复学习、真实重读与存储重开均有UI断言；无假完成 |
| 11 核心合法/非法回归 | 61 XCTest/8 UI、0失败，包括本轮新增旧源时间和终态凭据替换；不是整套未来产品端到端验收 |
| 12 测试名与断言匹配 | 六个点名原测试逐项审查/改名；真实数据库、FakeStore和VM分层，69个精确方法与日志逐一一致 |
| 13 需求追踪矩阵真实 | 已按SPEC/实现/完整测试名/层级/实际代码run/未验边界更新；未将后续里程碑标记完成 |
| 14 CI不跳过/不吞失败 | 三target、两testable均保留；测试pipefail、完整xcresult/log，历史失败如实列明；仅诊断命令容错 |
| 15 当前代码真实测试可核验 | 309afe81对应run41170754181 success，61+8/0，artifact13031277540；不使用旧代码绿色代替 |
| 16 文档/SHA/运行链接 | 公开main父链/tree与GitHub核对，ab70b5a API422明确纠正；代码run与后续docs提交分开，不自引用未知SHA |
| 17 原报告/旧分支保留 | 三旧报告逐字节等于起始版本；round1-daily-cycle仍c13906a；PR#1仍closed/unmerged |
| 18 新严重缺陷/数据风险 | 已对本轮链路审查并修复发现的额外问题，支持范围内无已知遗留P0/P1；回归不等于绝对无bug证明。§8未验边界及独立验收仍保留 |

## 10. 关键代码索引

以下链接固定到实际公开代码SHA `309afe81aecfbfd84e5a9f52251c59f8e32c0575`，行号由该版本源码生成。

- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:4](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L4) — `enum TaskStatus:`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:173](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L173) — `func validate(at`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:249](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L249) — `struct DailyStudyCycle`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:331](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L331) — `func validate()`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:387](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L387) — `func recordReviewProgress`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:411](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L411) — `func completeReading`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:426](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L426) — `func resolveEmptyReview`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:451](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L451) — `func finishEvidenceMutation`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:505](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L505) — `func markCarryOver`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:563](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L563) — `final class DailyCycleService`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:677](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L677) — `func recordReviewSession`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:710](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L710) — `struct ReadingCompletionEvidence`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:752](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L752) — `struct ReviewQueueEvidence`
- [LexiDawn/Domain/DailyTasks/DailyTasks.swift:780](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L780) — `struct ReviewSessionResult`
- [LexiDawn/Data/Repositories.swift:7](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L7) — `final class RepositoryWriter`
- [LexiDawn/Data/Repositories.swift:83](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L83) — `func save(cycle:`
- [LexiDawn/Data/Repositories.swift:96](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L96) — `private func upsert`
- [LexiDawn/Data/Repositories.swift:142](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L142) — `func recoverLegacyRecords`
- [LexiDawn/Data/Repositories.swift:160](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L160) — `private func validateCollection`
- [LexiDawn/Data/Repositories.swift:202](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L202) — `static func insertOrValidate`
- [LexiDawn/Data/Repositories.swift:241](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L241) — `func validateStoredMetadata`
- [LexiDawn/Data/Repositories.swift:271](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/Repositories.swift#L271) — `final class PreferencesRepository`
- [LexiDawn/Data/PersistenceModels.swift:163](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/PersistenceModels.swift#L163) — `func domain()`
- [LexiDawn/Data/PersistenceModels.swift:311](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/PersistenceModels.swift#L311) — `struct CycleRecoveryArchive`
- [LexiDawn/Data/PersistenceModels.swift:345](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Data/PersistenceModels.swift#L345) — `func repairKnownLegacyState`
- [LexiDawn/AppCore/DependencyContainer.swift:42](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/AppCore/DependencyContainer.swift#L42) — `func openPersistentStore`
- [LexiDawn/AppCore/DependencyContainer.swift:48](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/AppCore/DependencyContainer.swift#L48) — `func backupBeforeUpgrade`
- [LexiDawn/Features/Today/TodayFeature.swift:40](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Features/Today/TodayFeature.swift#L40) — `func load()`
- [LexiDawn/Features/Today/TodayFeature.swift:72](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Features/Today/TodayFeature.swift#L72) — `func retry()`
- [LexiDawn/Features/Today/TodayFeature.swift:219](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Features/Today/TodayFeature.swift#L219) — `func actionButtons`
- [LexiDawn/Features/Today/TodayFeature.swift:271](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/Features/Today/TodayFeature.swift#L271) — `private struct TaskStatusRow`
- [LexiDawn/LexiDawnApp.swift:19](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawn/LexiDawnApp.swift#L19) — `final class AppStartup`
- [LexiDawnUITests/LexiDawnUITests.swift:9](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnUITests/LexiDawnUITests.swift#L9) — `func testAppUsesFullSize`
- [LexiDawnUITests/LexiDawnUITests.swift:127](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnUITests/LexiDawnUITests.swift#L127) — `private func reveal`
- [LexiDawnUITests/LexiDawnUITests.swift:174](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnUITests/LexiDawnUITests.swift#L174) — `private func positioningFailure`
- [LexiDawnTests/MigrationFixtures.swift:7](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnTests/MigrationFixtures.swift#L7) — `enum LegacyRound1Schema`
- [LexiDawnTests/MigrationFixtures.swift:202](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnTests/MigrationFixtures.swift#L202) — `enum LegacyRemediatedSchema`
- [LexiDawnTests/LexiDawnTests.swift:1226](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309afe81aecfbfd84e5a9f52251c59f8e32c0575/LexiDawnTests/LexiDawnTests.swift#L1226) — `func testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement`
