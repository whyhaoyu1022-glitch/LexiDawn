# 需求追踪矩阵

本矩阵纠正旧版把源码存在、FakeStore 与旧 CI 结果扩大解释为完成的描述。所有本次改动尚待当前提交 CI；未通过 SPEC §25 的完整完成标准。历史报告保留原文。

| ID/审核项 | SPEC 原文依据 | 实际实现/范围与依赖 | 测试名称（详见测试计划）/层级 | 本次结果 | 未验证边界/完成标准 |
|---|---|---|---|---|---|
| GOV-001 | §0.1 “本文档是开发代理的主要产品依据” | 不改 SPEC；保留原审查；本次独立读取全部规格 | 文档/代码审查 | 已读，静态检查 | 不等于产品验收 |
| M0-001/002/003 | §3.1 “主导航固定为五项”；§15.1 “SwiftUI” | 保留五 Tab、三 target、27.0产品/26.5兼容 CI | `testFivePrimaryTabsAreVisibleAndSelectable` / UI | 待本次 CI | iOS 27/设备/签名未验证 |
| R2-001/M1-001 | §2.2.1 “因系统明确判定无需执行而略过” | 字符串接口拒绝 deferred；完整 queue reader 生成周期绑定证据；生产不可用抛错 | `testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation`, `testUnavailableNonemptyAndIncompleteQueuesCannotDeferReview`, `testVerifiedEmptyFixtureQueueSatisfiesReviewOnlyAfterExplicitReading` / Domain+Fake | 待本次 CI | 未接入真实队列；合法空数据仅显式 fixture |
| R2-002 | §2.2 “未完成任务必须保存在本地数据库” | throwing init/validate/Record.domain；原状态归档后保守 blocked | `testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations` / Domain；`testSwiftDataStrictDecodeRejectsLegacyDeferredAndRepairArchivesWithoutLosingAssignment` / 内存 SwiftData | 待本次 CI | 未知值/重复/孤立记录保留并报错，需要专门修复 |
| R2-003 | §2.3 “建立周期必须使用数据库事务和幂等约束” | 同一 writer 保存文章/周期；统一 rollback；日期/文章关联/最早 current | `testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent`, `testSwiftDataRepositoryRejectsMissingArticleMismatchedIDDuplicateDateAndReassignment` / 内存 SwiftData；`testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable` / 磁盘 | 待本次 CI | 不保证跨进程或多容器并发；不冒称磁盘满/断电测试 |
| R2-004/M1-002 | §20.1 “恢复未完成任务” | 重开后重新查文章正文/许可/指纹与关联、周期全值、关键偏好 | `testDiskContainerReopenRestoresCycleArticleAndPreferences` / 磁盘 | 待本次 CI | 不是 OS 强制杀进程测试；未逐字段检查全部偏好 |
| R2-005 | §25 “相关单元测试或集成测试通过” | FakeStore 测试改名，补数据库与 UI 断言；不删除失败断言 | `testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle` / Fake 与上述真 DB 明确分开 | 待本次 CI | 源码方法数不等于运行数 |
| R2-006/M1-004 | §19.1 “正文指纹”；§19.9 “ageRange”；§21.3 “对每个来源记录许可、署名、缓存和衍生内容权限” | SHA-256/词数/阅读时间计算；主题/缓存/来源和图片许可门禁；年龄段可选；新偏好默认12/6/4 | `testDirectArticleRepositoryRejectsInvalidLicenseCacheImageAndMissingMetadata` / 内存 SwiftData；磁盘重开 | 待本次 CI | 真实来源注册表/授权核验与展示 M3 尚未实现；不伪造授权 |
| R2-007/M2-001/002 | §23.3 “对不可重试错误解释原因和下一步” | 四任务显示原因、禁用未接入操作、诚实说明尚不能恢复学习、重读/存储重开真实动作 | 6 个 XCUITest；`testUnavailableInProgressRecoveryPreservesCycleArticleAndOtherProgress` / DB | 待本次 CI | 真实阅读/复习导航属后续；无障碍未全验 |
| R2-008 | §2.5 “阅读进度达到90%或以上”；“用户手动确认” | 常规确认/手动确认契约；泛型 completed 拒绝；正文版本绑定 | `testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation`, `testProductionContractsRejectReadingCompletionAndUnknownQueue` / Domain+DB | 待本次 CI | 阅读器真实证据 adapter 尚未接入 |
| R2-009/M1-003 | §19.3 “跨日次数”；§18.5 “处理夏令时变化和用户旅行” | ADR-006 日历日期高水位；固定时区；原任务保留 | `testCarryOverCountsSkippedCivilDatesAndNeverRecountsRollback`, `testDSTAndTravelUseCivilDateHighWaterWithoutChangingAssignment`, `testViewModelHonorsFixedStudyTimeZoneAndGregorianDate` | 待本次 CI | 历史旧计数不凭空重算 |
| R2-010/011 | §0.2 “不得伪造测试”；§23.6 文档要求 | GitHub/真实日志核对；新报告纠正不存在 SHA/旧CI扩大声明 | Git/Actions API，基线 40706618129 的25+2仅代表旧代码 | 已核对基线；新 CI 待查 | 不把closed PR当merged |
| R2-012 | §19.10 “每次模型变更必须定义迁移策略” | 可选列轻量迁移，原store/sidecar冷备份；双历史模型升级测试 | 两个 `testLegacy*DiskSchema*` / 真实旧磁盘升级 | 待本次 CI | 实机用户库、其他未知中间schema待验证 |
| M3/M4/M5/M6/M7/M9 | §26 对应里程碑 | 真实内容、阅读器、词典、复习算法/题目、通知、AI、IPA | 当前不声明完成 | 未实施 | 后续范围；无fixture冒充 |
