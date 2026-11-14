# CURRENT · Round 3 最终自动化证据与截图交付 · 2026-11-02

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。

## 提交与范围

通过全量CI的main提交：`b13d6b4e21e425472d059770319d88cd7c50a15e`。Round3起点：`93b4253d5f809d0813508e02d5e6141e8825d37f`。本报告的文档收尾提交是其直接后继，产品/测试/CI文件保持同一blob；准确收尾SHA由main历史与交付回复给出。本次CI结束时间为北京时间2026-11-02 20:09左右，所有运行日期均按北京时间描述。

SPEC §9.2：“支持导出词汇数据为 JSON 或”及下一行“CSV；导出内容应包含词条、释义、来源、复习状态和时间戳。”SPEC §30：“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”本报告以真实job结果和原始附件回填，不用文档代替功能验证。

## 六个模块与产品融合

| 模块 | 已实现及融合 | 本次证据 |
|---|---|---|
| 多源全文 | Registry/Audit、RSS/Atom/API、完整正文提取/整理、SHA/canonical去重、双正文原子入库、离线、失败保留旧版本 | 真实10源29篇；逐源library/body/scrolled/end PNG |
| 多词典 | Wiktionary、Free Dictionary、本地CEDICT；词形/短语、多义项、来源、版本缓存、部分失败、离线 | 两英语Live本次均通过；可靠中文缺失禁止错误出题 |
| 可视化连线 | 英中双列、实际Canvas曲线、错误重试、多线、双端禁用、重复消费保护、恢复 | 匹配、旋转、滚动、AX等价UI及原始PNG |
| 阅读器 | 原生全文、标题/段落/列表/引用、三主题、大字、横屏、点击词、位置/版本恢复 | 主UI及SE/Pro Max均通过，原始横屏正文可见 |
| 学习闭环 | 最多两条简明释义、完整独立详情/嵌套；生词/个人释义/笔记；FSRS4.5、原句词形/整段短语拼写、反馈/下次时间 | 真网络空库闭环、事务、恢复、评分UI与PNG |
| 库/搜索/收藏 | 今日顶部书库入口；分类/来源/标题/排序/收藏/稍后/历史；完成后探索和词汇推荐；JSON/CSV真实导出 | 统一门禁、收藏不建周期、持久化与原生Save/取消均通过 |

最早未完成周期优先，新文章不覆盖旧任务；阅读与复习独立。每日分配原子且同篇不重复，库/历史/收藏/稍后/探索和Reader打开/save/complete共用门禁。没有新文章时显示真实空状态，不每天循环同一篇已分配文章。收藏不会自动创建周期。笔记、个人释义、已选义项、答案、日志和排程均独立于可丢弃缓存。Repository失败回滚且无成功提示；旧schema迁移保留历史数据，无法证明完整的旧文归档不回流推荐。

## 实际测试结果

| 验证 | 本次实际结果 |
|---|---|
| Debug build-for-testing / Release | 成功；Release排除故障/截图fixture标记 |
| 完整XCTest | 186执行，0失败；其中原93保留；Free与Wiktionary真实接口本次均成功，无XCTest跳过 |
| 主UI full-1 / full-2 / full-3 / full-4 | 11/12/13/13执行，均0失败，共49个不同方法 |
| iPhone SE / iPhone Pro Max | 7/3执行，均0失败；属于额外设备复跑，不增加不同方法数 |
| 导出专项 | 生命周期单元1/0、原生导出UI1/0；也在完整套件中再次执行，不重复计入186/49 |
| 截图合并 | 327张编号截图；138项要求无缺失；10源完整逐源证据；无缺失设备证据 |

真实来源日志：`LIVE_FULLTEXT_AUDIT sourceIDs=bbc,dw,guardian,nasa,npr,phys,sciencedaily,voa,wikinews,wikipedia imported=29`。URLProtocol失败、原创解析fixture与生产网络在截图元数据和测试层分开；没有把注入429/断网说成各官网当次真实返回。

| 任务 | 结论 | 原始日志 |
|---|---|---|
| Export diagnostic · one UI method | success | [job 125246739663](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125246739663) |
| Build once, complete unit and network gate | success | [job 125249438952](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125249438952) |
| Native UI · full-1 · iPhone-17-Pro | success | [job 125253788578](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788578) |
| Native UI · small · iPhone-SE-3rd-generation | success | [job 125253788619](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788619) |
| Native UI · full-2 · iPhone-17-Pro | success | [job 125253788642](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788642) |
| Native UI · large · iPhone-17-Pro-Max | success | [job 125253788684](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788684) |
| Native UI · full-3 · iPhone-17-Pro | success | [job 125253788734](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788734) |
| Native UI · full-4 · iPhone-17-Pro | success | [job 125253788770](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125253788770) |
| Combine original PNG evidence and complete index | success | [job 125267114654](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/job/125267114654) |

## 逐图交付和校验

同一代码/运行的327个不同screenshotID、327个编号PNG；iPhone18,1为268张、iPhone14,6为43张、iPhone18,2为16张。所有索引行含规定11字段及SHA256，PNG签名、字节哈希、CSV/manifest一一对应且ZIP CRC检查通过。654个PNG文件由327个编号副本及327个xcresult原始附件路径组成，不能宣传为654个不同状态。

CI原始完整artifact SHA256：`6d61b1414dfa087798ddcb0ccc789bc11dff29b36a51b3b48b666f595236a8d4`，284198112字节。本地逐张校验327个PNG并复跑既有coverage脚本，138项、10源和设备证据无缺失。本轮没有重新渲染、裁剪、重编码或用录像重建原始PNG。原始Simulator横屏PNG使用EXIF方向标记（如8）；保存时保留原始像素和EXIF，查看时请使用支持方向标记的图片查看器，不对PNG重新旋转编码。

仓库索引：`artifacts/round-3/screenshots/manifest.json`、`screenshots.csv`、`INDEX.md`、`COVERAGE.md`。交付ZIP附加本报告、CI证据JSON、校验文件及单元xcresult/log ZIP，保留全部原始PNG。完整UI xcresult及原始附件可从下表各UI artifact下载。GitHub产物原始到期时间为2027-01-31，另提供下载包供长期留存。

| 产物 | 下载 | 用途 |
|---|---|---|
| LexiDawn-round3-full-1-41436291391-1 | [artifact 13141247249](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13141247249) | xcresult、日志与原始UI附件 |
| LexiDawn-round3-small-41436291391-1 | [artifact 13140400869](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13140400869) | xcresult、日志与原始UI附件 |
| LexiDawn-round3-full-3-41436291391-1 | [artifact 13140165071](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13140165071) | xcresult、日志与原始UI附件 |
| LexiDawn-round3-complete-native-package-41436291391-1 | [artifact 13139234028](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13139234028) | 327张编号PNG、manifest/CSV/INDEX/COVERAGE及原始PNG ZIP |
| LexiDawn-round3-full-2-41436291391-1 | [artifact 13139116147](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13139116147) | xcresult、日志与原始UI附件 |
| LexiDawn-round3-full-4-41436291391-1 | [artifact 13138258516](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13138258516) | xcresult、日志与原始UI附件 |
| LexiDawn-compiled-tests-41436291391-1 | [artifact 13138160706](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13138160706) | 原始诊断/编译产物，名称标明范围 |
| LexiDawn-unit-diagnostics-41436291391-1 | [artifact 13137801231](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13137801231) | 原始诊断/编译产物，名称标明范围 |
| LexiDawn-round3-large-41436291391-1 | [artifact 13136813727](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13136813727) | xcresult、日志与原始UI附件 |
| LexiDawn-export-check-41436291391-1 | [artifact 13135914714](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13135914714) | 原始诊断/编译产物，名称标明范围 |

## Round 2整改逐项追踪

| 整改 | 实现 | 自动化证据及边界 |
|---|---|---|
| R2-A01 | 横屏正文、滚动点词与十次旋转 | 主UI、SE/大屏通过；R3-R02 |
| R2-A02 | 实际连接线、两端禁用及重复消费 | 匹配UI/像素断言通过；R3-M06/M08 |
| R2-A03 | 多来源完整原文 | 10源29篇；每源首/中/末截图齐全 |
| R2-A04 | 多英语词典 | Free与Wiktionary Live均通过；失败状态另用明确fixture |
| R2-A05 | FSRS4.5、原句拼写与排程 | 单元/复习UI通过；不称最新FSRS或分钟学习步骤 |
| R2-A06 | 真实空库学习闭环 | 真实网络导入至探索解锁/重启UI通过 |
| R2-A07 | 刷新/离线/日期/后台保护 | 确定性故障/时间测试及UI通过；不承诺供应商永久可用 |
| R2-A08 | 配对/错误/拼写视觉反馈 | 状态UI通过，PNG交负责人视觉验收 |
| R2-A09 | 整页及浮窗三主题 | 三设备主题/横屏证据齐全 |
| R2-A10 | 原文结构与硬换行 | 解析/映射/结构UI通过 |
| R2-A11 | 全局视觉与对比度 | 完整UI通过，最终视觉判断待负责人 |
| R2-A12 | 精简来源与许可收纳 | 阅读器/来源详情PNG齐全，无外部阅读入口 |
| R2-A13 | 评分原因与下次日期 | Again/Hard/Good、重启/排程UI通过 |
| R2-A14 | 旋转/大字/词形/嵌套/键盘/AX | 49主UI与设备专项通过；完整VoiceOver听读未实测 |
| R2-A15 | fixture身份 | manifest逐张标注，Release排除测试场景通过 |
| R2-A16 | CURRENT及历史分离 | 本次统一更新CURRENT与完整结果/下载索引 |
| R2-A17 | 跨会话状态清理/恢复 | 会话、generation及重启测试通过 |
| R2-A18 | Provider/source/schema缓存版本 | 缓存版本/离线/故障测试通过 |
| R2-A19 | 真实长文与性能检查 | 原生滚动/内存/时钟测试通过；无真机60fps/Instruments结论 |
| R2-A20 | 全局细节和异常状态 | 138项覆盖无缺失；最终逐图视觉确认仍保留 |

## 手动验证步骤

1. 干净本地库发现全文，打开首/中/末；离线重开。失败候选不得留下卡片或记录。
2. 未完成任务时从书库、历史、收藏、稍后和探索尝试其他文章；均应受门禁。跨日先续接最早未完成周期。
3. 阅读器十次旋转、滚动和点词，检查小/大屏、三主题、大字、返回位置及来源详情。
4. 点词简明释义最多两条，独立详情含全部义项和来源；嵌套返回。模拟单Provider失败/离线时保留可用真实结果。
5. 生词选义、笔记、重启、搜索筛选、清缓存及确认移除；JSON/CSV原生取消不得提示成功，实际Save后才提示成功。
6. 连线错误重试、实线、多线、双端禁用，原句拼写、显示答案及Again/Hard/Good；重启保留答案与下次时间。
7. 全部必做任务完成才解锁探索；收藏不建每日周期，推荐仅主动加入，额外复习不重新锁定探索。
8. 更新未指派个人全文，旧版本保留；每日已指派文章拒绝更新。写入失败不得显示成功或替换原内容。

## 未完成验收与已知限制

- 当前证据来自已批准Xcode26.6（17F113）/iOS26.5兼容Simulator。项目目标仍为iOS27；真机、iOS27、完整VoiceOver听读和Instruments没有通过证据。
- 327张逐图编号PNG完整交付；自动覆盖检查不等于负责人视觉验收。本轮只人工抽查8张（R3-M06两设备、R3-R02小屏、V14/V16/V17、S01、A10），确认可见连线、横屏正文、原生窗口/真实完成反馈与通用失败提示。小屏横屏底部浮动Tab会覆盖视口下缘部分卡片，需滚动查看；按负责人冻结代码要求保留供视觉评审，本轮未修改。
- 外部来源与词典可能波动。本次10源29篇成功；Reuters/AP/Smithsonian历史未成功，不纳入10源。Free本次真实成功，仍按已批准可选来源策略显示不可用，而不伪造释义。
- 个人使用指令与出版社授权分别记录，不把公开可访问写成出版社授权。失败候选丢弃；无摘要/URL/WebView或原站阅读降级。
- FSRS为固定参数4.5实现，不声称最新版本或Anki分钟学习步骤；多进程并发写入不在当前单应用支持范围。
- 本次不新增功能，不改Swift、测试、项目、数据资源、工作流或脚本，不改写已有main历史。收尾文档/证据集中一次提交，使用[skip ci]避免对同一产品代码重新运行全量。

## 从Round 3起点到通过CI提交的完整修改文件

共76个路径。以GitHub两棵完整tree（均非truncated）逐blob比较生成，含新增、修改和删除；以下范围截止通过CI的应用提交，本次纯文档/索引收尾文件另见本次提交diff。

| 路径 | 变化 |
|---|---|
| `.github/workflows/ci-supersession.yml` | added |
| `.github/workflows/ios-ci.yml` | modified |
| `CHANGELOG.md` | modified |
| `LexiDawn.xcodeproj/project.pbxproj` | modified |
| `LexiDawn/AppCore/DependencyContainer.swift` | modified |
| `LexiDawn/AppCore/LearningServices.swift` | modified |
| `LexiDawn/AppCore/Round3ScreenshotTransport.swift` | added |
| `LexiDawn/Data/ArticleHistoryArchive.swift` | added |
| `LexiDawn/Data/ArticleNetwork.swift` | added |
| `LexiDawn/Data/ContentRepository.swift` | modified |
| `LexiDawn/Data/DictionaryAggregation.swift` | added |
| `LexiDawn/Data/FullTextRepository.swift` | added |
| `LexiDawn/Data/LearningModels.swift` | modified |
| `LexiDawn/Data/PersistenceModels.swift` | modified |
| `LexiDawn/Data/ReaderRepository.swift` | modified |
| `LexiDawn/Data/Repositories.swift` | modified |
| `LexiDawn/Data/ReviewRepository.swift` | modified |
| `LexiDawn/Data/VocabularyRecommendations.swift` | added |
| `LexiDawn/Data/VocabularyRepository.swift` | modified |
| `LexiDawn/DesignSystem/DesignTokens.swift` | modified |
| `LexiDawn/Domain/DailyTasks/DailyTasks.swift` | modified |
| `LexiDawn/Domain/Learning/ArticleDocument.swift` | added |
| `LexiDawn/Domain/Learning/ArticleHTMLExtractor.swift` | added |
| `LexiDawn/Domain/Learning/ArticleSources.swift` | added |
| `LexiDawn/Domain/Learning/ArticleWebPageExtractor.swift` | added |
| `LexiDawn/Domain/Learning/ClozeContext.swift` | added |
| `LexiDawn/Domain/Learning/EnglishPhraseRecognizer.swift` | added |
| `LexiDawn/Domain/Learning/FSRSScheduler.swift` | added |
| `LexiDawn/Domain/Learning/LearningRules.swift` | modified |
| `LexiDawn/Domain/Learning/PublisherSources.swift` | added |
| `LexiDawn/Domain/Learning/ReaderTextProjection.swift` | added |
| `LexiDawn/Features/Learning/ArticleLibraryFeature.swift` | added |
| `LexiDawn/Features/Learning/InteractiveEnglishText.swift` | modified |
| `LexiDawn/Features/Learning/LearningHome.swift` | modified |
| `LexiDawn/Features/Learning/MatchingBoard.swift` | added |
| `LexiDawn/Features/Learning/ReaderFeature.swift` | modified |
| `LexiDawn/Features/Learning/ReviewFeature.swift` | modified |
| `LexiDawn/Features/Learning/SettingsFeature.swift` | modified |
| `LexiDawn/Features/Learning/SourceLicensesView.swift` | added |
| `LexiDawn/Features/Learning/VocabularyFeature.swift` | modified |
| `LexiDawn/Features/Learning/VocabularyRecommendationFeature.swift` | added |
| `LexiDawn/LexiDawnApp.swift` | modified |
| `LexiDawn/Resources/CONTENT-LICENSES.txt` | modified |
| `LexiDawn/Resources/html-entities.json` | added |
| `LexiDawnTests/Round2MigrationSchema.swift` | added |
| `LexiDawnTests/Round3NetworkTests.swift` | added |
| `LexiDawnTests/Round3Tests.swift` | added |
| `LexiDawnUITests/LexiDawnUITests.swift` | modified |
| `LexiDawnUITests/Round3UITests.swift` | added |
| `README.md` | modified |
| `STATUS.md` | modified |
| `artifacts/round-3/screenshots/coverage-requirements.json` | added |
| `artifacts/round-3/screenshots/manifest.json` | added |
| `artifacts/round-3/screenshots/screenshots.csv` | added |
| `docs/architecture.md` | modified |
| `docs/article-source-eligibility-audit.md` | added |
| `docs/daily/2026-11-01-round-3.md` | added |
| `docs/requirements-traceability.md` | modified |
| `docs/reviews/round-3-ci-41318724181-repair.md` | added |
| `docs/reviews/round-3-ci-41323390776-repair.md` | added |
| `docs/reviews/round-3-ci-41326351407-repair.md` | added |
| `docs/reviews/round-3-ci-41357763875-repair.md` | added |
| `docs/reviews/round-3-ci-41361046807-repair.md` | added |
| `docs/reviews/round-3-development-delivery.md` | added |
| `docs/reviews/round-3-export-focused-41423920944.md` | added |
| `docs/reviews/round-3-export-launch-isolation-41432723597.md` | added |
| `docs/reviews/round-3-export-lifetime-41429945732.md` | added |
| `docs/reviews/round-3-optional-free-dictionary-41420744836.md` | added |
| `docs/test-plan.md` | modified |
| `scripts/ci-cancel-obsolete.py` | added |
| `scripts/ci-prepare.sh` | added |
| `scripts/ci-simulator.sh` | added |
| `scripts/ci-test-plan.py` | added |
| `scripts/export-round3-evidence.py` | added |
| `scripts/merge-round3-evidence.py` | added |
| `scripts/verify-round3-coverage.py` | added |

