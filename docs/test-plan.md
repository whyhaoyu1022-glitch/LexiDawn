# 测试计划与证据边界

> 前半部分保留 Round 1 历史基线与不变量；当前生产功能、Round 2 验证结果和未完成项见文末及 Round 2 开发交付自述。

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

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。

### Round 2 批次 2 实际验证清单

- 内容：导入确认/URL/控制字符/重复正文/原URL，RFC随附版权与真实词典；HTTP429与超时用依赖注入HTTP客户端，官方RFC成功路径另用真实URLSession。网络测试失败会真实使CI失败，不用fixture冒充联网成功。
- 访问：到期前1毫秒、精确到期、离线本地访问、时钟回拨、旧记录保留、前台已显示正文撤回，以及重新取得同一核验RFC。
- 阅读：保存/明确确认/不满足90%拒绝/手动确认/重复完成、版本锚点唯一、更新失败隔离、磁盘重开、原周期与复习独立。
- 生词：自动关闭、手动加入、安全撤销、已有记录幂等、真正托管修改后的故障、中文缓存搜索及缓存删除不伤实体。
- 复习：实际配对和拼写、先后阶段、已保存题组/每日上限、到期队列/缺状态报错、最后答案事务故障与可重试、日志与排程幂等、跨日新周期。
- UI：保留原8条；新增5条实际运行流程。round2-disk只在DEBUG模拟器显式开启，每个测试用独立UUID磁盘库；通过生产导入/词典/reader/review服务，不与生产库混用。另一个测试从空库真实填写导入表单。滚动恢复同时检查百分比和可见词元UTF16位置，不只检查静态进度数字。截图keepAlways保存在xcresult。
- 性能：XCTest measure测试3504词分词和全部二分命中；不把此微基准当作Instruments/真机帧率证据。VoiceOver仅基础标签与可点击词元实施，最大动态字体/高对比/小屏/横屏/真机完整检查尚未完成。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。


## 2026-10-31 截图验收补充（运行结果待核对）

按用户要求补充7个实际XCUITest场景及数十个keepAlways截图点：正式生产依赖首次启动与RFC8890、真实RFC隔离库的主题/横屏/词条/复习、导入空状态与校验、许可到期、429后退避、跨日和缺失复习状态。P为真实生产内容，S为真实RFC加预置学习状态，F为隔离原创测试文章，X为明确故障注入；旧Round1截图另标历史，不冒充当前生产页面。CI额外导出原始附件PNG和manifest，保留xcresult与原回归；UI步骤超时扩至45分钟容纳截图，不改产品iOS27目标。截图数量、最终SHA、实际成功/失败与下载包在本次交付答复核对，不预填通过。SPEC §24.6原文：“加载、空状态、错误状态和锁定状态都可通过 VoiceOver 理解。”截图辅助审阅，不等于完整VoiceOver验收。


截图首轮547fbde / Actions41199999648已结束：93 XCTest/0；20 UI/3失败。实际下载原始PNG与AX附件，确认Form惰性列表尚未载入禁用保存按钮、overflow菜单没有继承SwiftUI identifier（原生label为“阅读外观”）、主题Picker应匹配原生label且先结束键盘输入。保留三个场景及断言，修正真实控件定位后再次运行；结果不预填成功。


原始图片抽查追加：保留拼写键盘独立截图，同时在答错/提示/显示答案截图前滚动到反馈可见处；来源退避截图也先露出具体错误。只改善拍摄取景，不重绘图片或改变状态机。7a5cd98的运行仍单独保留，后续截图提交自己的最终CI需完成后核对。


0ba4a65 / Actions41201712543：93 XCTest/0，20 UI/1失败，其他19个UI场景通过并已导出90张当前功能截图。实际AX证据显示未知长词已命中并打开查词、词条成功保存；长标题占满medium sheet，List尚未创建下方无结果行。保留无结果断言，先展开/滚动原生浮窗再验证该行与截图。此轮修正只涉及测试可见性，不能将旧失败运行写为通过；最终SHA结果以交付答复为准。
