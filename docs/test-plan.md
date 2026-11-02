# CURRENT · Round 3 验证计划与事实

负责人批准Free Dictionary为可选不稳定来源：空/失败时明确提示，保留Wiktionary及可用缓存；仅该真实可用性探测的外部不可用可XCTSkip并单独报告，解析错误和非空noun断言仍严格验证，Wiktionary真实联网仍强制。最新41420744836编译通过，184测试/2失败（Free三次404、推荐测试跨日时钟）；本次同时统一测试时钟并增加次日重新锁定断言。源码185/49、138截图状态，待新CI。 [授权范围、证据与规格依据](reviews/round-3-optional-free-dictionary-41420744836.md)。

当前源码 **185 XCTest / 49 XCUITest**，包含原 93 / 20。完整主 UI 自动发现并分为 4 组，每个方法恰好一次；SE 专项 7，大屏专项 3。源码数量不是运行通过数量。对应 SHA、实际失败与重跑结果以 [STATUS](../STATUS.md) 和 [本轮开发记录](reviews/round-3-development-delivery.md) 为准。

最近运行41318724181已核验180单元/0失败、大屏3/0；SE7/1，另有两个主UI失败，取消部分不能计入通过。本次强化冷启动键盘打开时保存必须可点击、成功后关闭键盘、退出重进读回释义；重置先取消再确认，禁止误开阅读器/编辑页。原Round2空库断言保持。详见[核查报告](reviews/round-3-ci-41318724181-repair.md)；新源码尚未原生运行。

## 分层验证

| 层级 | 覆盖 | 证据边界 |
|---|---|---|
| 原 93 XCTest | 周期证据/分配/唯一性/旧迁移/事务/撤销/阅读/复习/统计/偏好 | 文件与断言保留，不以删除旧测试解决兼容问题 |
| Round3 确定性 | RSS/Atom/API、URL/SHA、HTML/JSON-LD/实体/结构、全文准入/拒绝/原子回滚/去重、缓存版本/Provider 合并/词形/语境、FSRS 向量、语境拼写/变体、独立额外复习、跨入口/跨日门禁、探索/推荐/导出/确认义项、全文版本保留 | 使用真实 SwiftData/Domain；原创解析数据明确为 fixture |
| URLProtocol 故障 | 每个配置来源的 403/404/不合格发现/空发现无文章残留；公共抓取的 429/503/超时/取消/主机拒绝；并发加入同一发现事务 | 注入结果不冒称真实官网当次返回该故障 |
| Live 外网 | >=5 个实际完整来源入库、Wikipedia 空库完整导入、Free Dictionary 和 Wiktionary 真实 noun 英文释义 | 非空断言保留；服务不通会失败，不用 mock/其他 Provider 代替 |
| 磁盘迁移 | 两版既有旧 schema、冻结 Round2 schema、关系/旧题/进度/词条/日志和全文保留；损坏库备份/重试/真实只读保存故障 | 同模型重开不能冒充迁移；未知 schema 不清库 |
| 原生 UI | 原20 + 新29：真冷启动闭环、10次旋转正文/点词、真实线像素/双端禁用、全尺寸主题大字、词典/文章失败/保存失败、搜索收藏历史、额外复习、推荐、确认义项与导出、结构/版本变化恢复 | fixture 与生产网络标明；完整 VoiceOver 听读仍待实测 |

## 截图和产物

`XCUIScreen.main.screenshot()` 原始 PNG 和 JSON 元数据使用 keepAlways 附件，必须保留 screenshotID、featureID、screenName、state、device、orientation、theme、testName、fixtureOrProduction、fileName、notes。`export-round3-evidence.py` 仅复制真实附件，`merge-round3-evidence.py` 逐张验证 SHA，并生成 manifest/CSV/INDEX.md/原始 ZIP。最终必须来自同一代码运行；不混入旧运行截图或录像重建帧。空 manifest 不能作为交付。

阅读器、连线、词典、库、导入失败、生词/笔记、Again/Hard/Good、锁定/解锁等状态由独立 captureID 对应；新增结构/版本 R10–13、库 L06/L10–12、生词 V10–12/V14–15 补充主要状态。最终覆盖和逐张文件名应从实际产物索引核查，不凭写了截图调用就认定存在。

CI 一次编译所有 Debug 测试产物，Release 另检 fixture 排除；所有单元/真实网络通过后共享原始 test products。4 主分组 + 2 设备专项保留全部方法，分组失败后 fail-fast 取消其余任务，新 main 取消旧运行。失败日志/xcresult/已产生截图仍上传。iOS27 产品目标保持；Actions 使用已批准 Xcode26.6/iOS26.5 兼容模拟器，不等于真机/iOS27/Instruments 验收。

以下是历史时间顺序记录，仅用于追溯；旧“待运行”或测试计数不表示当前状态。

---

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



2026-11-01 · 负责人特别指示的公开官网全文模式：允许个人使用场景下直接尝试11个官网来源（BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian）；旧出版社许可审核不改写为授权。FullTextRightsEvidence.importBasis=owner-directed-personal-use-2026-11-01，grant.scope=personal-full-text，与audited-full-text分开。只请求公开HTTPS页面，固定主机白名单及重定向检查，无登录、验证码处理、浏览器、代理或付费墙绕过。RSS/列表只在内存中发现候选；完整闭合正文子树或明确articleBody、正文长度/段落/原文一致性和数据库事务验证通过后才入库；任何失败不留下候选。Wikinews另按CC BY4.0及2024-12-17创建日期门槛接入。最多3条来源管线并行，首篇原文导入后更新首页，各来源独立失败/退避。新增8个确定性测试及真实网络五来源导入门槛测试，尚未执行，不把配置11源当作11源成功。


Round 3继续：原生小屏截图已逐张检查R3-R02/R3-M06/R3-R08，横屏正文与真实线条可见，最大字号首屏占用问题继续整改。阅读器仅压缩元信息/完成控件，正文仍遵循完整动态字体；已配对两端保留高对比文字/边框并禁用。HTML提取保留嵌套引用和有序列表序号，以原生TextKit样式显示，原文字符不插入生成内容。推荐按兴趣/新鲜度/长度排序且仍过滤已分配与探索中记录。增加明确fixture标记的词典加载/单源失败/全失败/空结果/缓存/离线UI状态，另加空库真实多来源逐个本地阅读截图测试，通过真实阅读确认和空复习流程解锁，不插入完成状态。以上待新SHA运行证据。


证据更正：4bd1976 的运行41271935072原135单元中有1个真实Free Dictionary网络请求失败，旧93单元及新增确定性测试通过，主UI未执行；两个设备专项任务success。未以重试/跳过测试掩盖错误，网络服务增加500–599有界重试及仅sourceID/status诊断，待新提交验证。新增嵌套引用/有序列表与推荐实际候选选择测试；当前源码146单元、30 UI（含原93/20），不能当作执行通过数量。


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


补齐截图覆盖：今日原文卡片优先每源一篇，全部仍来自本地完整库；真实多源UI返回今日采集R3-S01。连线全部完成后可展开查看已保存全部连接，进入拼写不删除线条证据；新增M08全部双端禁用/实线和M11滚动后锚点实线PNG断言，主用例数量不变。新增截图仍待当前代码运行。


验收补强：134项状态→实际PNG检查与逐源首/中/末、SE/大屏主题横屏检查加入最终合并关卡，缺图会失败但仍上传已有证据/COVERAGE.md；不把截图调用数当真实产物数。补充生词搜索无结果V13、嵌套短语返回D62–65。损坏可丢弃Provider缓存不能阻断生词读取/导出或可靠个人释义复习，新增真实SwiftData回归；数据库fetch错误仍抛出。当前175 XCTest/48主UI清单，新增待当前代码执行。


本次继续整改（结果待新代码运行）：747d7c3 / Actions41314198717 的Debug/Release、175 XCTest/0失败；UI full-3为13/1失败，其他组取消，整次失败。原始AX附件显示同义词入口被父DisclosureGroup标识覆盖，改为独立展开按钮与独立选项，中文义项选择同样隔离，旧断言保留。新增词典/阅读/历史未知语境类型与真实来源证据，nullable列保留旧数据；完整短语原始位置核验及独立错误状态；新卡new、首次Again为learning、既有复习失败为relearning；大RSS/长HTML时钟内存测量。源码180 XCTest/49主UI，旧93/20不变，新增D66/D67及134项PNG覆盖要求，均待本次实际验证，不标完成。
