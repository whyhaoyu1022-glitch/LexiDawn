# 测试计划与证据边界

本地无 Swift/Xcode，`git diff --check` 仅是空白差异检查，不能证明编译或运行成功。本次新增测试执行结果待对应提交 Actions。基线 b894bda 的 run 40706618129 实测 25 XCTest/2 XCUITest、0 failures，不是新代码证据。

| 测试层级 | 实际测试对象 | 主要测试名 | 结果/未验证边界 |
|---|---|---|---|
| Domain | 值模型及证据验证 | `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`, `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations`, `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation` | 新代码未本地运行；adapter fixture 不是真实队列 |
| FakeStore/VM | 服务幂等与失败操作重试 | `testFakeStoreSameDayProvisioningIsIdempotent`, `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle`, `testViewModelWithFakeStoreRetriesOriginalBlockedUpdate` | 不证明 SwiftData rollback |
| 内存 SwiftData | 真实 ModelContext 对象变化、注入提交前错误、rollback、重试 | `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`, `testSwiftDataUpdateFailureDoesNotLeakIntoLaterPreferenceSave`, `testSwiftDataArticleAndPreferenceFailuresRollBackManagedChanges` | 故障发生在真实托管变更后/save 前；不是模拟磁盘满 |
| 真实磁盘 SwiftData 保存故障 | `allowsSave: false` 数据库 | `testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable` | 保存确实调用 SwiftData；不等于断电/磁盘满实机测试 |
| 磁盘容器重开 | 两个作用域释放容器/Repository后重开同一路径 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` | 重开后重新读 ArticleRecord，比较全部周期值和列明偏好；不是进程被杀的测试 |
| 旧 schema 升级 | c13906a 和 b894bda 冻结存储字段生成旧磁盘库，再用新模型打开 | `testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences`, `testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive` | 真实升级路径待 CI；不以同模型重开冒充升级 |
| 启动失败 | 损坏库错误、备份/原字节保留、factory重试 | `testFailedStoreOpenRetainsOriginalBytesAndPreUpgradeBackup`, `testStartupRetryReopensWithoutDeletingStore` | 不声称覆盖所有迁移错误 |
| XCUITest | 真正运行 app 的显式隔离 fixture、disabled 点击与重新读取、四任务原因/历史恢复/启动失败 | `testUnavailableButtonsAreDisabledAndReloadDoesNotChangeReadyStates`, `testBlockedAndFailedReasonsExplainUnavailableRecoveryAndRemainUnchanged`, `testHistoricalInProgressBecomesExplainedBlockedWithoutChangingArticle`, `testStartupFailureHasRealRetryAndNeverPretendsDataLoaded` | Release 不编译 fixture；尚未本地运行 |

workflow 保留三个 target 的 build-for-testing 和分别执行的 unit/UI test，不跳过 target；测试命令启用 pipefail，经 tee 保存完整日志并上传 xcresult/log artifact。Debug/Release iOS 27.0 产品配置保留，CI checkout 临时使用获批准 iOS 26.5。

仍需真机、签名 IPA、iOS 27 产品工具链、VoiceOver、最大动态字体、深色模式、性能、跨进程竞争、真实网络文章来源/阅读器/复习模块接入测试。逐项源码清单和本轮实际执行证据将在整改报告列明。
