# CURRENT · Round 4 v1.1测试计划，尚未实施（2026-11-07）

UI专项42334204472在编译阶段发现新布局夹具DictionarySense参数顺序错误（synonyms必须在forms前），已修正；尚未运行UI，无新截图。继续专项，同时本地迁移旧测试与加强数据恢复。
复习批次0f02c4b167c52c8920032049f8f6fa564eed7f9d的专项42332992118：全部目标编译成功，14新增XCTest执行/0失败。新增8个Round4 UI方法（旧49未删除，共57个），覆盖参考词典首/中/末、小浮层、可靠中文锁定/英英允许补录、个人自动保存/重启、真实连线、揭示纠正、延期预检、设置/关于、书库和来源进度；实际执行/截图尚待本次专项。

批次3：F07/F08/F10/F11/F12/F18/F19/F24的复习/投影实现已写入，累计14新测试待验证。此前42331595559编译/10核心测试通过，不是全量；迁移、旧合同转移与原生截图继续。

批次2：F01–F06/F09/F13–F17/F20–F23相关UI与发现进度已写入，验证未完成；首专项编译缺try已修，复习/截图继续。新增UI合同将迁移原有断言，核心业务/持久化断言不删。

## 2026-11-07最新执行覆盖 · 只使用英中释义

负责人现已授权开始开发，并明确“英英释义是不需要的……如果只有英英释义的话，那么可以视为没有”。本规则高于v1.1：只有真实可靠英中释义才禁用个人释义；英英结果只可作为内部排序/词形元数据，不作为产品释义展示，也不阻止结构化个人英中录入。英文例句、音标、词性仍可保留。复习始终要求明确中文与匹配语境，不能把英英义自动译成答案。

实现批次1：F09/F11/F16/F23的数据/策略与解析基础已写入，Round4Tests新增10方法，未运行；共享详情、复习与自动化仍在开发，不据此关闭任何整项需求。

2026-11-07按负责人新增三张词典参考升级Round 4至v1.1：完整页按词性/编号义项/搭配/双语例句/短语动词分层，Wiktionary、可配置Oxford、Free为可靠优先组并保留字段来源；有可靠英文也禁用用户释义，确认无可靠来源才允许结构化多词性/多义项/例句录入。笔记仍可用，旧个人义无损只读，复习统一sense/版本/来源快照。新增F22–F24、36条验收、T22–T24，当前总计24项/144条/24族；原21图不重排。仅文档，没有Swift/测试/CI/IPA变更或新通过结果。

[主任务书](plans/round-4-development-specification.md) · [词典补充规范](plans/round-4-dictionary-detail-addendum.md) · [新增三图审阅](reviews/round-4-dictionary-reference-audit-2026-11-07.md) · [机器清单](reviews/round-4-feedback-manifest.json)。

| 来源 | 需求与原文依据 | 范围/依赖 | 验收 | 测试/证据状态 |
|---|---|---|---|---|
| R01–R03 | F22：“尽量仿照这些截图的样式设计”“尽量包含最多的信息” | 共享完整页、丰富结构、加入/导航/无障碍；依赖真实字段与F23 | A22-01–12 | T22；planned，原生首中末/失败截图待实现 |
| 11月7日指令 | F23：“对于具有可靠来源的，禁用用户释义功能”“录入词性、例句” | 可靠融合/资格/结构化个人义/自动保存/迁移/导出；Oxford条件配置 | A23-01–12 | T23；planned，策略/事务/UI/真实来源分层 |
| 11月7日指令 | F24：“确保这些修改和复习功能可以正确匹配” | 稳定sense/快照、条件化预检、两类来源题组、Again/幂等/门禁 | A24-01–12 | T24；planned，两条完整E2E及失败/恢复 |

原F08/F09/F10/F15/F16的实现与验收已在主任务书和机器清单同步更新：可靠仅英文禁止补个人义；未知失败不当无结果；笔记保存与释义资格分开。原108条编号保留，加36条为144条；T01–T24是测试族，不代表已有24个新测试方法。旧186 XCTest/49主UI及设备专项仍需保留核心断言并按批准新合同迁移。

必须新增：Repository直接拒绝可靠词写个人义、可靠结果到达与autosave竞态、仅英文可靠词无中文不得出题、无来源多词性个人词例句闭环、个人→可靠新题资格切换/旧题冻结、清缓存不解除已知可靠锁定、导出恢复和失败迁移。真实网络、URLProtocol故障、解析fixture和布局fixture分别报告。专用验证先于最终完整CI；此文档提交不启动测试。详细状态矩阵和截图清单见补充规范第5–8节。

## 2026-11-06初版测试计划（历史规划，冲突以v1.1为准）

## 2026-11-06 · Round 4首次真机21图研究与任务书（计划完成，尚未实现）

负责人上传21张不同批注HEIC，已逐张完整查看，并对7张密集/手写/黑字区域另行放大；按原文件名建立R4-P01–P21、R4-F01–F21、108个验收点和21个测试族。新增约1000行Round4任务书、逐图审阅及哈希清单，涵盖UI精简/渐变卡/小浮层、词典可靠性和词形、复习预检/延期/纠正/串题、自动保存、关于页、旧数据迁移、截图与统一验收。新批注冲突优先于旧SPEC，原版权/学习证据和数据保护保持。仅修改文档/索引，没有修复功能、运行测试或导出新IPA；本次文档提交使用[skip ci]。

[完整任务书](plans/round-4-development-specification.md) · [逐图审阅](reviews/round-4-first-device-21-image-audit-2026-11-06.md) · [机器清单](reviews/round-4-feedback-manifest.json)。F编号为强制整改，A编号为逐条验收，T编号为测试族；以下是计划，不是已运行测试结果。

| 原图ID | 文件 | 需求 | 验收数 | 测试族 | 当前状态 |
|---|---|---|---|---|---|
| R4-P01 | IMG_8854.heic | R4-F01 | 5 | R4-T01 | planned |
| R4-P02 | IMG_8857.heic | R4-F02 | 5 | R4-T02 | planned |
| R4-P03 | IMG_8858.heic | R4-F03 | 5 | R4-T03 | planned |
| R4-P04 | IMG_8859.heic | R4-F04 | 5 | R4-T04 | planned |
| R4-P05 | IMG_8860.heic | R4-F05 | 5 | R4-T05 | planned |
| R4-P06 | IMG_8862.heic | R4-F06 | 5 | R4-T06 | planned |
| R4-P07 | IMG_8863.heic | R4-F07 | 5 | R4-T07 | planned |
| R4-P08 | IMG_8864.heic | R4-F08 | 5 | R4-T08 | planned |
| R4-P09 | IMG_8866.heic | R4-F09 | 6 | R4-T09 | planned |
| R4-P10 | IMG_8867.heic | R4-F10 | 5 | R4-T10 | planned |
| R4-P11 | IMG_8869.heic | R4-F11 | 5 | R4-T11 | planned |
| R4-P12 | IMG_8870.heic | R4-F12 | 5 | R4-T12 | planned |
| R4-P13 | IMG_8872.heic | R4-F13 | 5 | R4-T13 | planned |
| R4-P14 | IMG_8873.heic | R4-F14 | 5 | R4-T14 | planned |
| R4-P15 | IMG_8875.heic | R4-F15 | 5 | R4-T15 | planned |
| R4-P16 | IMG_8876.heic | R4-F16 | 6 | R4-T16 | planned |
| R4-P17 | IMG_8878.heic | R4-F17 | 5 | R4-T17 | planned |
| R4-P18 | IMG_8879.heic | R4-F18 | 5 | R4-T18 | planned |
| R4-P19 | IMG_8880.heic | R4-F19 | 5 | R4-T19 | planned |
| R4-P20 | IMG_8881.heic | R4-F20 | 5 | R4-T20 | planned |
| R4-P21 | IMG_8883.heic | R4-F21 | 6 | R4-T21 | planned |

本轮沿用现有测试和数据安全要求；批准改变交互的旧UI断言必须迁移到对应F/A新合同，不能删除持久化、失败和业务门禁断言。最终验收仍需实际实现、真实CI、原始截图和负责人真机复验。

## Round 3历史证据（不得冒充Round 4通过）

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。

SPEC §17.2原文“不使用透明背景。”及“在 Xcode Asset Catalog 中按目标 SDK 要求配置 AppIcon”；§22.7“不能在未签名或签名无效时上传一个被标记为可安装的产物。”本次依赖官方Xcode真机SDK，验收为真实IPA结构/签名状态/元数据/图标与SHA；用户自行签名安装，不能把构建当真机通过。安装步骤见[签名说明](signing.md)。

## 2026-11-02 已有全量与截图交付证据（历史范围）

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。

| 验证 | 本次实际结果 |
|---|---|
| Debug build-for-testing / Release | 成功；Release排除故障/截图fixture标记 |
| 完整XCTest | 186执行，0失败；其中原93保留；Free与Wiktionary真实接口本次均成功，无XCTest跳过 |
| 主UI full-1 / full-2 / full-3 / full-4 | 11/12/13/13执行，均0失败，共49个不同方法 |
| iPhone SE / iPhone Pro Max | 7/3执行，均0失败；属于额外设备复跑，不增加不同方法数 |
| 导出专项 | 生命周期单元1/0、原生导出UI1/0；也在完整套件中再次执行，不重复计入186/49 |
| 截图合并 | 327张编号截图；138项要求无缺失；10源完整逐源证据；无缺失设备证据 |

## 测试层与证据边界

- 保留原93 XCTest和20 XCUITest，不删除或弱化断言；当前不同方法186/49。导出专项及设备复跑不重复计数。
- 确定性单元包含RSS/Atom/API、HTML/JSON-LD/正文完整性/去重/事务、门禁/跨日、词典聚合/词形/短语/缓存版本、FSRS/固定语境/可靠中文、导出迟到回调、旧schema磁盘迁移和失败回滚。
- 真实网络层含完整文章导入、空库冷启动和两个英语词典；本次10源29篇、Free及Wiktionary均成功。Free仍为已批准可选来源，未来不可用的skip必须单独报告，本次没有XCTest跳过。
- URLProtocol故障和原创解析fixture验证空/失败/超时/429/503/重复等分支，不冒称每个官网当次返回所有故障。UI元数据逐张保留fixtureOrProduction。
- 4个主UI分组恰好覆盖全部49方法，SE7和大屏3额外执行；真实Save、取消、重启、长文、十次旋转、大字、三主题、AX等价、嵌套、键盘、异常与重试均在现有套件中。
- Release构建验证故障/截图fixture被排除。性能测试不作真机60fps或完整VoiceOver听读结论。

## 原始截图与xcresult

327个唯一截图ID，138项状态无缺失，10源完整逐源证据；具体文件见[INDEX](../artifacts/round-3/screenshots/INDEX.md)、[manifest](../artifacts/round-3/screenshots/manifest.json)、[CSV](../artifacts/round-3/screenshots/screenshots.csv)、[COVERAGE](../artifacts/round-3/screenshots/COVERAGE.md)。654个ZIP内PNG文件含编号副本及xcresult原始附件副本，不是654个不同状态。

PNG签名、逐张SHA256、ZIP CRC及CSV/manifest对应均已核对。可复核命令：

```sh
python3 scripts/verify-round3-coverage.py artifacts/round-3/screenshots/manifest.json --report /tmp/round3-coverage.md
python3 scripts/ci-test-plan.py verify
```

[完整原始artifact与每个xcresult入口、手动复核步骤、设备/视觉限制](reviews/round-3-final-delivery-2026-11-02.md)。本次只验证文档和产物，不重新执行Swift/Xcode，不将静态检查冒称新增原生运行。历史详细用例依据见[收尾前测试计划](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/b13d6b4e21e425472d059770319d88cd7c50a15e/docs/test-plan.md)。


## Round 4 · 历史兼容与草稿保护（待专项原生验证）

上一提交 dbb3ca580fe65e7a94ce967b3d04b19ba530c155 的专项42334485159已完成所有目标编译及14新增XCTest（0失败），UI仍在执行，尚无新截图可检视。继续实现，无全量通过声明。

本批加入从规划基线c52dd2e精确冻结的17实体Round3磁盘schema测试；升级前独立before-round4备份；词形归一保留别名ID、原笔记/释义、上下文、旧题/日志与导出，不直接删除碰撞行，失败回滚。未确认反向索引的未完旧题原样归档再预检，已完成记录不改。个人/设置草稿原子落盘，冲突需明确恢复/保留，旧版本存档；例句与译文合并保持对应。

可靠英中优先中文维基英语区，缺失/不可用时补查英文维基明确标注中文的翻译表，严格按英语语言区/词性/单表隔离，不翻译英英原文；新schema-7缓存。Free英英仅元数据，界面明确无英中；无Oxford凭据仍未配置。真实接口本轮尚待网络集成验证。

旧186单元方法保留；指定复习夹具明确补入原创、已确认POS/中文/例句，并保留原业务断言；揭示答案的旧断言按负责人P19改为先未完成/0日志，纠正后原Again断言继续。新核心累计21方法，待执行；旧49 UI合同迁移、全异常截图/逐图审阅、全量回归继续进行。


## Round 4 · 首轮原生UI反馈修正（待复跑）

专项42334485159的8 UI执行：4通过/4失败，导出29张真实PNG（含4诊断），不是验收通过。通过来源进度取消、连线/恢复/纠正Again、预检/全延期、10次旋转与3主题；失败为可靠中文fixture在弹层未出现、键盘遮挡后测试滚动失效、设置测试误触听写系统界面。已查看9张实际图（4失败+标题/横屏/多线/纠正/设置），其余继续逐图；原图SHA256均核验。浮窗请求改由稳定model拥有并在离开时取消，网络加载期间不提前显示无结果；个人无结果压缩为短提示；设置增加原生键盘完成/交互收起，UI滚动限定内容区域并保留失败层级。新增端到端model/Provider/cache确定性测试，核心累计22。

兼容批次b474adc40cc4c187f1a1588e57061ce97bc06c68的42336167201在VocabularyRepository大表达式类型检查编译失败，已拆分typed map/搜索字段，未执行该批单元。17实体真实磁盘升级/别名/归档等仍待执行。继续专项，旧测试迁移与截图完善并行，未全量完成。
