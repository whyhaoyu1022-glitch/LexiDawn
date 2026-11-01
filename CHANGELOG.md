# Round 3 开发中 · 2026-11-01

按用户任务书及补充规范v1.1推进完整全文唯一准入、原生阅读器、词典与复习；新增源码和确定性测试待CI。未宣称产品验收完成。见STATUS顶部CURRENT。

# Changelog

## Round 1 第二次整改 — 2026-10-31

- 引入完成/空队列证据与所有入口不变量校验；严格区分模块不可用与队列为空。
- 所有 Repository 写入统一 rollback；原子创建、关联/重复/身份保护及最早 current。
- 文章指纹、词数、估算时长、主题/来源/缓存与图片许可；可选年龄段和规格默认偏好。
- 历史 schema 升级前备份、已知非法状态审计归档、启动重试与任务原因说明。
- 补充真实 SwiftData、只读磁盘故障、磁盘重开、两版历史升级及 XCUITest；本轮最终代码61 XCTest/8 UI、0失败，具体SHA/run见下。
- 修正此前把 FakeStore/源码数量扩大为持久化证明的文档。旧审查/整改报告保留，纠正说明见本轮新报告。
- 修复真实save失败后rollback仍有context幽灵对象、VM读重试误重放写、固定时区/非Gregorian日期、时间非有限值/计数溢出及正文指纹恢复漏洞。
- 修复UI固定重复滚动与原生launch/scene配置缺失；新增窗口尺寸断言、滚动无进展失败诊断，保留可见/disabled/实际点击和状态断言。

本轮代码验证：代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。 产品27.0/CI26.5不变；不代表真机或全部SPEC完成。

历史条目按日期保留。2026-10-28条目曾把blocked称作“可恢复”，当前真实学习模块仍未接入，只能重读/重开存储；旧运行不能证明本次代码，历史证据纠正见新报告。


## Round 1 整改 — 2026-10-28

- 修复必做文章 deferred 绕过周期完成规则的问题；新增周期级 `completionReason`，完成时间只在所有真实条件满足时写入。
- Repository 维护唯一 `isCurrent`、同一本地日期幂等、规范化 canonicalURL 去重，并在同一 ModelContext 保存文章和周期；失败时回滚。
- ArticleRecord/ArticleCandidate 补齐展示标题、难度、图片署名、许可、正文和内容状态；候选进入周期前执行字段和许可门禁。
- 首页未接入的阅读/复习入口改为禁用并明确说明，不再写入无法完成的 `inProgress`；遗留进行中状态启动时转为可恢复的 blocked。
- 保存失败重试保留写操作上下文；新增时区回拨、非法候选、磁盘重开、唯一当前周期和失败重试回归测试。
- ModelContainer 初始化失败显示存储不可用页面，不清空或覆盖本地数据。
- CI 保持 Debug/Release 工程配置和 iOS 27.0 产品目标，workflow 只在 main push/PR 触发；runner checkout 临时使用 iOS 26.5 兼容目标，先在 simulator 启动前执行 `build-for-testing`，再运行 unit/UI tests 并上传 xcresult。

验证状态：当前容器没有 Xcode/Swift；本地只完成静态 diff 检查。最终 main run 40597791954 success，对应 SHA `874b3626c00a745767e9d95fbd2cf4c09abf3ca0`；UI 2 tests/0 failures，unit step success，xcresult artifact 已保存。

## Round 1 — 2026-10-26

- 新增每日学习周期领域模型和 `TaskStatus` 状态迁移，区分 locked、ready、inProgress、completed、deferred、blocked、failed。
- 新增跨日任务保留、最早未完成周期优先、同日幂等、文章去重和无候选结果规则。
- 新增 SwiftData 的文章、每日周期和用户偏好模型，以及周期、文章和偏好 Repository。
- 应用启动时创建共享持久化容器；偏好默认值符合 06:20/21:20 和自动加入生词本规则。
- 今日首页改为读取 Repository 的真实周期，显示状态、原始分配日期、逾期、空状态和重试操作。
- 新增领域、状态迁移、跨日/时区、SwiftData 恢复与首页 ViewModel 测试；保留原有导航测试。
- CI 目的地选择改为以 `xcodebuild -showdestinations` 为准，找不到 scheme 接受的 concrete iOS Simulator 时明确失败。
- CI 在 runner checkout 中临时应用 iOS 26.5 兼容目标；常规 Debug/Release 产品配置仍为 iOS 27.0。

已知限制：本地容器没有 Xcode；真实文章 provider、阅读器、复习题目、通知和真实设备验收属于后续轮次。run 40597791954 已通过；真实设备和 iOS 27 产品目标仍未验证。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](docs/reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。


## 2026-10-31 截图验收补充（运行结果待核对）

按用户要求补充7个实际XCUITest场景及数十个keepAlways截图点：正式生产依赖首次启动与RFC8890、真实RFC隔离库的主题/横屏/词条/复习、导入空状态与校验、许可到期、429后退避、跨日和缺失复习状态。P为真实生产内容，S为真实RFC加预置学习状态，F为隔离原创测试文章，X为明确故障注入；旧Round1截图另标历史，不冒充当前生产页面。CI额外导出原始附件PNG和manifest，保留xcresult与原回归；UI步骤超时扩至45分钟容纳截图，不改产品iOS27目标。截图数量、最终SHA、实际成功/失败与下载包在本次交付答复核对，不预填通过。SPEC §24.6原文：“加载、空状态、错误状态和锁定状态都可通过 VoiceOver 理解。”截图辅助审阅，不等于完整VoiceOver验收。


截图首轮547fbde / Actions41199999648已结束：93 XCTest/0；20 UI/3失败。实际下载原始PNG与AX附件，确认Form惰性列表尚未载入禁用保存按钮、overflow菜单没有继承SwiftUI identifier（原生label为“阅读外观”）、主题Picker应匹配原生label且先结束键盘输入。保留三个场景及断言，修正真实控件定位后再次运行；结果不预填成功。


原始图片抽查追加：保留拼写键盘独立截图，同时在答错/提示/显示答案截图前滚动到反馈可见处；来源退避截图也先露出具体错误。只改善拍摄取景，不重绘图片或改变状态机。7a5cd98的运行仍单独保留，后续截图提交自己的最终CI需完成后核对。


0ba4a65 / Actions41201712543：93 XCTest/0，20 UI/1失败，其他19个UI场景通过并已导出90张当前功能截图。实际AX证据显示未知长词已命中并打开查词、词条成功保存；长标题占满medium sheet，List尚未创建下方无结果行。保留无结果断言，先展开/滚动原生浮窗再验证该行与截图。此轮修正只涉及测试可见性，不能将旧失败运行写为通过；最终SHA结果以交付答复为准。



2026-11-01追加：负责人明确以个人使用方式调整公开完整文章获取规则；旧许可结论不改作授权。修复文章库搜索默认隐藏、滚动后屏外单词的UI定位，保留全部原20 UI方法和断言并增加原始截图元数据。对应下一main提交待CI验证，不声明最终通过。


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
