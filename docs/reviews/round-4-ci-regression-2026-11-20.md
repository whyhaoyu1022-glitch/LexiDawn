# 2026-11-20 全量 CI 后的专项修复

负责人要求：先修复已报告的失败，只跑受影响专项；全部通过后再提交一次全量 CI，确认触发后停下，由负责人反馈结果。

## 已完成的全量运行

提交 `86593be52aff9e2b169c35e000366a788b9a5340`，[运行 44542739409](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44542739409)。Xcode 26.6、iOS 26.5 Simulator 兼容环境，不是 iOS 27 真机结果。

- 全部目标编译、Release、246/246 XCTest 和未签名 IPA 构建通过。
- UI 共 74/77 次执行通过，失败 3 次，均在 iPhone 17 Pro。SE 7/7、Pro Max 3/3、生产首启通过。
- 截图汇总缺 `dictionary-07/10/17`、`vocabulary-review-03/06/08/09`；这是实测失败，不能将产物标记为最终通过包。

| 失败方法 | 日志与实际录屏 | 本批处理 |
|---|---|---|
| `testRound2SettingsPersistAndDisabledAutoAddRequiresManualAdd` | 行 318 等不到撤销。F32 及失败前录屏仍显示“查词中”，加入按钮禁用。 | 等待真实启用且可命中后再手动加入；完成查询后再次检查没有自动加入，保留写入成功和安全撤销断言。 |
| `testGalleryRealRFCVocabularySearchNotesAndRemove` | 行 537 报搜索框没有键盘焦点。原生搜索激活时字段移入导航栏。 | 原生搜索绑定显式焦点及展示状态；测试待键盘出现再输入，并断言实际搜索值。后续笔记、删除和取消流程保留。 |
| `testComplexFormsAndFourContextPhrasesUseNestedLookupAndReturn` | 行 808 在第二个词形 taken 等不到详情启用，录屏仍在查词中。 | 先处理排序重复编码；服务测试通过但界面仍失败。后续实际日志发现浮窗重建引发请求取消/重启，继续修复所有权并以原生 UI 验证。 |

两个原始诊断 ZIP 已下载并校验 SHA-256，再读取对应原生录屏和附件：

| 产物 | SHA-256 |
|---|---|
| `14543816562` · full-2 | `0a7eb42b661fa8eabe7fdb427ae995f873af176e1666aeca6eae6151a5181ef4` |
| `14543042477` · full-4 | `f2b63e649130791945f0c63ab8dfcdc0829c73d890df55b43a9a0328568f07b9` |

## 修改与验证边界

- 词典排序以 actor 独占系统 NLEmbedding，最多缓存 256 条截断至 1200 字符的本地派生向量。保留余弦距离、原有词汇和语法权重、MDX 义项与排序标识。向量不写入用户数据库，也不是词典来源。
- 不改变 MDX 文件或解析版本，不更换中文释义来源，不删库或迁移用户学习数据。
- 新增 2 项 XCTest：系统余弦距离对照/缓存边界；真实 MDX 的 took、taken、look、carry、account、role 连续查询与语境身份，保留逐次实际耗时附件。系统句向量不可用时明确记录词汇排序降级，不能伪称进行了原生距离对照。
- 专项再运行现有 `testContextRankingUsesRealExistingDefinitions`，共 3 项 XCTest。UI 只选择表中 3 个失败方法，分别隔离分组。全量 67 个主设备方法和两个设备专项保持完整。
- 专项、全量和最终交付结果待实际执行后分别登记。目前尚未宣称这些修复通过验证。

## 专项运行

`0f6b86df0eef076e5009121a13edcff5d1b438df`：[44564141854](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44564141854)。仅选择 3 个相关 XCTest 和 3 个失败 UI 方法。macOS runner 已分配，开始全部目标编译；测试结果待执行。此前检查 main 的运行队列时没有其他旧运行占用；排队不计作测试通过。

专项 XCTest 已完成：3/3 通过。真实 MDX 连续查询用例总耗时 7.145 秒；附件的单次查询记录为 took 4.758 秒（包含首次初始化）、taken 0.802 秒、look 0.420 秒、carry 0.393 秒、account 0.211 秒、role 0.345 秒。

同一附件明确记录该 Simulator 未安装系统英文句向量模型，因此此次通过的是语义模型不可用的降级路径、确定性余弦/容量检查与真实 MDX 查询；不能宣称进行了系统原生余弦距离对照，也不能仅用向量重算解释之前 UI 的 15 秒超时。仍需完成 UI 专项并检查查词展示的生命周期。诊断产物 `14552087944` 的 SHA-256 为 `4220210a108f31be59a2c179fe87d28d5b2e5d438288fe378f7ac9b29ab0c02d`。

## 浮窗生命周期继续修复

`0f6b86d` 的短语 UI 再次失败（69.454 秒）：关闭 took 后点击 taken，词头的 AX 查询超时。该轮仍使用原来的 `StateObject` 外部输入。已下载原生诊断 `14552214923` 并查看实际录屏，SHA-256 `637362976abc02653d6c0cf9734defde32211d89a1c509b1b4847d21eb83d0fb`；录屏仍显示加载浮窗。因此仅有服务层测试通过或向量优化不足以关闭本项。

阅读器的选择状态已经持有 `WordLookupModel`。浮窗改为 `ObservedObject` 接收当前模型，并在三处入口按请求 ID 隔离视图生命周期，移除未使用的内部建模初始化方法。关闭时只取消对应模型。词头的无障碍值仅在原文词形不同于显示词头时说明原文，便于核验和辅助阅读。

原失败方法增加两轮六词/短语查询，每轮都要求原词形与当前词头对应、加载完成、无资源错误、详情返回仍为同一原词形；关闭旧浮窗确实消失后再进入下一个词。第一轮原截图 ID 保留，第二轮使用 `-repeat` 独立 ID。这是每轮必须通过的连续性检查，不是失败后的整项重试；原 15 秒就绪等待上限保留。

真实 MDX 单元用例还改为实际自动加入并核对最终持久词头集合与每次结果身份一致。下一轮继续验证该用例和相关排序测试、手动加入、连续查词；保留正在执行的上一轮搜索任务，避免为此中断其他独立验证。生命周期修复结果待实际运行。

生命周期修复提交为 `b3335a6e9b9adb7032a33b9ae18c1b99744f4fd1`，[专项运行 44569752811](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44569752811)。全部目标已编译，专项结果待执行。上一轮搜索方法已完整通过（87.171 秒），包含后续笔记自动保存、删除确认与取消、最终删除及截图采集；其实际运行仍为 `0f6b86d` / 44564141854，不能改记为新提交的结果。


`b3335a6` 结果：全部目标编译、3/3 相关 XCTest 通过，包含真实 MDX 查询和自动加入（7.502 秒）；手动加入 UI 再次通过（96.743 秒）。连续查词仍在第一次循环的 taken 失败（82.511 秒），因此不能宣称模型所有权修改已解决本项。原生诊断 `14555061671` 已下载并校验 SHA-256 `5ea49da89e8bb4c3478add073c27ff625fbdd75879f2a51888049e57cf4375ed`，录屏末尾仍为加载浮窗。

下一轮仅运行连续查词 UI。阅读器将无障碍隐藏限制在正文，而非包括浮窗宿主的整页；正常原生弹层负责自身模态无障碍行为。增加仅包含请求 UUID、阶段和加载/结果布尔状态的 OSLog，CI 保留日志；失败时额外导出真实完整 AX 层级和截图。没有记录查词文本或文章内容。两轮十二次查询、原十五秒时限、原始截图及详情返回断言均保留。此项仍待运行验证，不使用服务测试通过代替界面验收。

当前限定 UI 专项：`41183dc2698916b936dd2841c8b87dbfea86c120`，[44710496861](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44710496861)。只选择连续查词方法，结果待运行；其余已通过的方法本轮不重复执行。

## 请求取消竞态与浮窗 AX 同步

`41183dc` / 44710496861 编译通过，UI 仍失败（198.903 秒）。本轮已实际完成 took、taken、look into、carry out，并分别进入/返回前两组短语详情；失败转移到 account 的浮窗就绪断言，不能计作两轮通过。产物 `14617487704` SHA-256 `52999610063cd917522c4f81200a3f426b8159911b28d3ddb19b60c10073e3d4` 已下载校验。完整 AX 与失败原图明确显示 take into account、短语、考虑到；顾及及可用详情按钮。

生命周期记录显示此请求 09:36:03.849Z 开始，09:36:04.346Z 发布，09:36:04.448Z 完成；UI 在 09:36:04.996Z 对尚未稳定定位的全页词头取 label，最终断言超时。日志还记录同一请求在弹层初次显示时短暂出现/消失/再出现，原 onDisappear 立即取消，在旧 Task 尚未开始时排入第二个 Task，两次 query-began 后一次取消。不能用增大超时掩盖此竞态。

修复：三处浮窗均由 presenting selection 的 Binding 处理真正关闭或替换时的取消；页面离开也取消所属请求，浮窗临时重建只记日志。排队任务开始前核验取消标记及 job UUID，旧任务不得进入 lookup 改写新 generation。两轮 UI 将元素查询限定在 compact-word-card，先核验元素存在，再取 label，并在同一十五秒内同时要求正确词头和详情可用，未增加等待上限。

追加 2 项真实 MDX XCTest：排队后立即取消/重启不得覆盖新结果或重复加入；选择替换取消旧任务，相同选择不取消，关闭后已解析结果保留且仅浏览不加词。与原真实 MDX 连续查询共 3 项专项，再跑唯一剩余 UI 方法。源码总计 250 个 XCTest，原有 67 个 UI 方法完整保留。下一轮结果待实际执行。

请求所有权修复提交 `f1241c7391b1488d98b47247f7a8659d6a7c5e3b`，[专项 44713380139](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44713380139)，仅选择上述 3 项 XCTest 与连续查词 UI；结果待执行。

### 隔离的 Simulator 启动故障

`f1241c7` 的全部目标编译通过，但 136210468089 作业在启动 Simulator 失败，3 项 XCTest 未执行。日志为首次 bootstatus 等待 360 秒超时，随后 simctl list 诊断也超时；原脚本把 list 与 shutdown 放在同一 try，导致未执行 shutdown，第二次 boot 返回 149。不能把本轮未执行的 XCTest 记为通过，也不能把 runner 启动失败归因于业务断言。

启动控制拆为可测试的脚本：诊断失败也必须独立尝试关闭本作业创建的临时设备；boot 命令返回非零仍以 bootstatus 成功作为唯一就绪证据，最多两次，最终失败保留退出错误。本地 4/4 Python 故障控制测试通过，覆盖正常、已启动、诊断超时仍关闭、两次就绪失败；这不是实际 Simulator 启动验收。

下轮 `[lookup-unit-only] [round4-fix-ui] [lookup-lifecycle]` 只运行未执行的 3 项 XCTest，并保留独立执行中的 f1241c7 UI 作业，避免重跑同一份 Swift 代码的界面测试。该限定仅适用于专项；`[round4-final]` 始终恢复全部 UI 与严格完成门禁。没有清空用户数据库，也没有取消这项仍有用的 UI 验证。

启动恢复与 XCTest 限定运行提交 `dfe65abb1488fa6bde991a449da2e4b6194d8d87`，[44715663269](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44715663269)。与 f1241c7 的 App、XCTest、UI 测试及 Xcode 工程目录完全相同（git diff 核对），仅 CI、启动脚本与记录有变动。f1241c7 的 UI 因此保留，不重复启动；两个原生专项结果均待实际执行。

`dfe65ab` / 44715663269 已成功：全部目标编译，实际 Simulator 启动、3/3 XCTest 专项通过。原 f1241c7 连续查词 UI 仍在独立运行；尚不能宣称该方法或最终全量通过。

专项 XCTest 实际耗时：排队取消后重启 3.082 秒；selection 取消边界 2.926 秒；真实 MDX 六词/短语自动加入 4.769 秒；3 项总计 10.778 秒，零失败。启动脚本第一轮实际就绪。四项本地 Python 控制流用例与原生 XCTest 分开记账。

### 完整详情的返回按钮与模态无障碍范围

保留中的 f1241c7 UI 已结束失败（244.228 秒），本次查词和首个短语详情成功，失败在进入 look into 详情后全页按 label 查找“返回查词”按钮（原行 838）。原生完整 AX 与失败 PNG 均有正确完整详情和可见返回按钮，同时仍暴露底层今日/阅读页面。诊断产物 `14620066756` SHA-256 `327d42c97d6fe83fd4367074ce9dd109fa28c5f034e77c4564ce70cda4756980` 已实际下载、校验、查看；本轮的 info 生命周期文件仅有表头，不能伪称从中读到了查询时间。

进一步限定模态无障碍语义：浮窗及完整详情使用 SwiftUI isModal trait，完整详情含底部控制条的 contain 容器；详情显示时遮挡的阅读正文退出 AX 树。返回、关闭和控制条添加稳定 accessibilityIdentifier。专项依旧两轮完整查询，新增验证详情期间 reader-body 不在 AX 树，按当前详情控制条定位真实按钮，保留 hittable、点击和返回后原词形断言。没有坐标点击或跳过返回流程。原生 API 依据：[Apple isModal](https://developer.apple.com/documentation/swiftui/accessibilitytraits/ismodal)。

下一轮仅运行此剩余 UI，已通过的 3 项 XCTest 不重复运行；不改变词义来源、业务规则或数据结构。结果待实际运行。

检查共享滚动测试时，发现模态容器标识必须与原 dictionary-detail-scroll 分离，避免同一 ScrollView 被覆盖标识。完整详情使用外层 ZStack 承载模态分组，原生 ScrollView 保留原标识；连续查词专项新增原滚动区仍存在的断言。本修正随 UI 专项提交，不增加测试范围。

模态/返回专项代码最终为 `0217670ce76110c82af2a8430d08382596b95670`，[44718192194](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44718192194)。它取代尚未执行 UI 的 e3a66b8 范围，仍只运行连续查词方法；结果待运行。

`0217670` / 44718192194 全目标编译成功，UI 失败 64.442 秒。失败层级显示当前 compact-word-card 是带模态语义的 Alert，take、MDX 中文、撤销及详情按钮均已就绪；测试限定 otherElements，实际未找到这个 Alert。因此修正定位为 descendants(.any) + 稳定 ID，保留原十五秒内词头、详情可用、原词形断言。其他已有浮窗测试本来就使用这种与角色无关的 ID 定位；本轮仅此新专项仍限定了错误类型。控制条也按 ID 定位容器。此为实际元素类型变化的测试适配，不跳过任何业务验收。原生产代码不再修改。诊断产物 `14620838564` SHA-256 `3b338c385ed521c99e432c04ff6702b796584d0a76c20c138159adf598596f13`。


## UIKit 正文容器与模态无障碍范围

da3d81e / [44720208229](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44720208229) 编译通过，UI 仍在第二次 taken 浮窗就绪查询失败（134.977 秒）。失败时 AX 明确有 take、原文 taken 和已启用的详情按钮；背景仍暴露整篇原生词语元素。GitHub 产物 14622975061 为 97,580,719 字节，服务记录 SHA-256 95afff2f22323e3a7a3a9f00b32018c996237beb56011e83560cf37fdc01584c。本地执行环境断开，未在本地重新下载并视觉检查该轮 PNG；诊断使用实际作业日志的完整 AX，不伪称重新查看截图。

原生 EnglishTextContainer 自己维护 accessibilityElements，原 SwiftUI 隐藏未阻止它在 layout 回调继续暴露和刷新词语。进一步修复由 UIView 原生 accessibilityElementsHidden 控制遮挡状态，覆盖期间清空暴露数组、停止重建，保留内部词语身份供关闭后恢复。旧词语的 accessibilityActivate 和无障碍滚动也拒绝在覆盖期间执行。仅控制无障碍内容，不改变文章可视布局、查词数据或阅读位置。阅读器把 selection、完整详情和来源页覆盖状态传到原生容器，去掉附在 popover 宿主上的冗余 SwiftUI 隐藏。

新增 XCTest testCoveredReaderRejectsRetainedNativeWordActionsAndRestoresPosition：使用真实 UIKit/TextKit 容器和生成的词语元素，验证正常激活、覆盖时旧元素拒绝激活且不滚动、恢复同一元素身份与位置。它是原生无障碍回归，不能冒充 MDX 解析验证。源码总计 251 个 XCTest。下一轮 [reader-accessibility] 只执行此新 XCTest 与原剩余连续查词 UI；已经通过的三个查询/取消 XCTest不重复运行。

UI 继续执行两轮全部查词和详情返回；遮挡验证针对刚点击的真实文章词语，不把不可聚焦的空容器是否保留为实现验收。已存在的原生滚动区、词形、中文、错误、关闭、返回及就绪断言均保留。结果待实际执行。

原生正文覆盖修复提交 `97c1f83cf5614ed7e6dc7e9391a15cbbc59e5bd2`，[专项 44723268404](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44723268404)。通过仓库连接直接提交 main，随后按不可变提交逐文件回读核对 11 个文件完全一致；全目标编译通过，原生 XCTest 和 UI 结果待执行。本地环境不可用未阻止远端代码、编译及专项继续。

97c1f83 / 44723268404：全部目标编译通过，原生 UIKit 用例 testCoveredReaderRejectsRetainedNativeWordActionsAndRestoresPosition 已实际执行并通过（1.179 秒、零失败）。真实 Simulator 启动成功。连续查词 UI 在独立 runner 准备中，仍待实际结果。


### 实际线程堆栈诊断

97c1f83 的 UI 失败 195.643 秒，首次 took 仍显示加载。完整 AX 已没有文章 word-*，原生屏蔽确认生效；但 App idle 通知未及时返回，不能宣称该修复解决了剩余查词阻塞。UI 产物 14623782534，GitHub 记录 SHA-256 5b10cb0cb485cda543b78336053c06639d55f15903380d148a11331a1c193a41；本地环境仍不可用，该轮 PNG 未独立重新下载查看。

下一轮限定同一 UI，启用只读 macOS sample 对实际 Simulator App 进程取样，保留主线程与词典/NaturalLanguage/AttributeGraph 相关栈。采样仅诊断标记时运行，最多五个时点、每次三秒；没有改变原断言或等待上限。请求 UUID/阶段日志提高为持久 notice，不含文章或查词文本。全量提交不带诊断标记，不运行取样。已经通过的原生 UIKit 用例和三项 MDX/取消专项不重复执行。此步骤用于确定阻塞位置，不能预先算修复通过。
