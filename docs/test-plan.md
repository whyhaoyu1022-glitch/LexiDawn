# 测试计划与证据边界

代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。

本地没有Swift/Xcode，未运行iOS测试。以下列名用例在上述对应SHA的真实日志中通过；61是XCTest汇总，包含领域、FakeStore、内存、磁盘和升级测试，不是61个数据库测试。两条旧schema升级属于磁盘测试子集，不重复相加。基线25+2不作为新代码证明。

| 测试层级 | 实际测试对象 | 主要测试名 | 结果/未验证边界 |
|---|---|---|---|
| Domain | 值模型及证据验证 | `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`, `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations`, `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation` | Actions通过；adapter fixture不是真实队列 |
| FakeStore/VM | 服务幂等与失败操作重试 | `testFakeStoreSameDayProvisioningIsIdempotent`, `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle`, `testViewModelWithFakeStoreRetriesOriginalBlockedUpdate` | 不证明 SwiftData rollback |
| 内存 SwiftData | 真实 ModelContext 对象变化、注入提交前错误、rollback、重试 | `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`, `testSwiftDataUpdateFailureDoesNotLeakIntoLaterPreferenceSave`, `testSwiftDataArticleAndPreferenceFailuresRollBackManagedChanges`, `testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement` | 故障发生在真实托管变更后/save 前；不是模拟磁盘满 |
| 真实磁盘 SwiftData 保存故障 | `allowsSave: false` 数据库 | `testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable` | 保存确实调用 SwiftData；不等于断电/磁盘满实机测试 |
| 磁盘容器重开 | 两个作用域释放容器/Repository后重开同一路径 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` | 重开后重新读 ArticleRecord，比较全部周期值和列明偏好；不是进程被杀的测试 |
| 旧 schema 升级 | c13906a 和 b894bda 冻结存储字段生成旧磁盘库，再用新模型打开 | `testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences`, `testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive` | 两条真实升级在上述CI通过；不以同模型重开冒充升级 |
| 启动失败 | 损坏库错误、备份/原字节保留、factory重试 | `testFailedStoreOpenRetainsOriginalBytesAndPreUpgradeBackup`, `testStartupRetryReopensWithoutDeletingStore` | 不声称覆盖所有迁移错误 |
| XCUITest | 真正运行 app 的显式隔离 fixture、disabled 点击与重新读取、四任务原因/历史恢复/启动失败 | `testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates`, `testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged`, `testHistoricalInProgressBecomesExplainedBlockedWithoutChangingArticle`, `testStartupFailureHasRealRetryAndNeverPretendsDataLoaded`, `testStartupRetryRepeatsInitializationAndLoadsApp`, `testAppUsesFullSizeWindowOnModernCISimulator` | 8个UI用例在上述CI通过；Release不编译fixture；非生产内容端到端 |

workflow 保留三个 target 的 build-for-testing 和分别执行的 unit/UI test，不跳过 target；测试命令启用 pipefail，经 tee 保存完整日志并上传 xcresult/log artifact。Debug/Release iOS 27.0 产品配置保留，CI checkout 临时使用获批准 iOS 26.5。

仍需真机、签名 IPA、iOS 27 产品工具链、VoiceOver、最大动态字体、深色模式、性能、跨进程竞争、真实网络文章来源/阅读器/复习模块接入测试。逐项完整源码清单、实际执行证据及历史失败见 [整改报告](reviews/round-1-second-remediation-report-2026-10-31.md)。

UI定位回归：固定iPhone17Pro，实际断言窗口至少375×667，产物plist必须包含原生UILaunchScreen/scene；显式today-scroll按方向定位，无进展保存截图与层级并使测试失败。去掉固定6次下滑，未去掉业务断言；单用例失败即停止无意义后续动作，其他用例正常执行，UI步骤20分钟上限，超时仍失败。正常Wait for idle/AX快照是XCTest同步行为，旧数百次固定滑动不是验收要求。

新增复习结果回归使用真实内存SwiftData，先验证旧时间/新终态快照可构造成结构合法的domain对象，再直接调用Repository断言拒绝，重新fetch必须与原值完全一致；同时验证精确重试和最终完成时间。成功UI用例保留5张原生PNG附件，非生成图，来源、尺寸和SHA-256见整改报告。
