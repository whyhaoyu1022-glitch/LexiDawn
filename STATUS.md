# CURRENT · Round 4正在开发：英中词典核心已写入，待专项原生验证（2026-11-07）

复习批次0f02c4b167c52c8920032049f8f6fa564eed7f9d的专项42332992118：全部目标编译成功，14新增XCTest执行/0失败。新增8个Round4 UI方法（旧49未删除，共57个），覆盖参考词典首/中/末、小浮层、可靠中文锁定/英英允许补录、个人自动保存/重启、真实连线、揭示纠正、延期预检、设置/关于、书库和来源进度；实际执行/截图尚待本次专项。

前一UI提交c70ff02836b3bc493e28c8e7115afa26c55cfbaa的专项42331595559：全部目标编译成功，Round4Tests 10执行/0失败；不是全量通过。继续实现共享可靠英中/结构化个人义resolver、原子冻结义项/掩码、类型化预检、统一入口弹窗/立即补录、单词延期与全组明确确认。延期证据保留原始非空选择，不计答对或更新FSRS，和真空队列区分。显示答案仅持久化揭示事实，亲自纠正后才完成且仍Again；反馈按questionID隔离、默认完成页收起逐词日志。短词不凑拼写题，有明确省略证据。

复习批次新增代码/14测试待新专项，原21项与新增3项整体仍未完成验收。

实现批次2已写入：参考图层级的统一完整英中词典、锚定小浮层、滚动完整标题、结构化个人编辑/笔记草稿和自动保存、设置自动保存/关于、首页精简、探索/推荐渐变卡、书库可见收藏/稍后与数量、真实并行来源进度。均待原生验证，复习/迁移/全量回归与截图仍在继续。首专项42330605998在编译阶段发现throws map缺try，已修正；尚无通过结果。

最新指令：英英释义视为没有可用释义，只有可靠英中才禁用个人释义。首批实现资格策略、中文维基解析、结构化个人义/独立笔记、可靠证据持久化和随机掩码；新增10个确定性测试。当前未编译/运行，无新CI通过或截图；UI与复习集成继续进行。

以下为此前规划记录，冲突按最新指令覆盖：

2026-11-07按负责人新增三张词典参考升级Round 4至v1.1：完整页按词性/编号义项/搭配/双语例句/短语动词分层，Wiktionary、可配置Oxford、Free为可靠优先组并保留字段来源；有可靠英文也禁用用户释义，确认无可靠来源才允许结构化多词性/多义项/例句录入。笔记仍可用，旧个人义无损只读，复习统一sense/版本/来源快照。新增F22–F24、36条验收、T22–T24，当前总计24项/144条/24族；原21图不重排。仅文档，没有Swift/测试/CI/IPA变更或新通过结果。

- [主任务书](docs/plans/round-4-development-specification.md)
- [词典详细页补充规范](docs/plans/round-4-dictionary-detail-addendum.md)
- [原21图审阅](docs/reviews/round-4-first-device-21-image-audit-2026-11-06.md) / [新增三图审阅](docs/reviews/round-4-dictionary-reference-audit-2026-11-07.md)
- [机器清单](docs/reviews/round-4-feedback-manifest.json)

## Round 3与首IPA历史状态（2026-11-05及以前）

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。

## 2026-11-02 已有全量与截图交付证据（历史范围）

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。

通过CI的main代码：`b13d6b4e21e425472d059770319d88cd7c50a15e`。本次为一次纯文档/证据收尾提交；没有改变已通过的Swift、测试、CI或数据文件，没有重写历史。

## 已核验结果

| 验证 | 本次实际结果 |
|---|---|
| Debug build-for-testing / Release | 成功；Release排除故障/截图fixture标记 |
| 完整XCTest | 186执行，0失败；其中原93保留；Free与Wiktionary真实接口本次均成功，无XCTest跳过 |
| 主UI full-1 / full-2 / full-3 / full-4 | 11/12/13/13执行，均0失败，共49个不同方法 |
| iPhone SE / iPhone Pro Max | 7/3执行，均0失败；属于额外设备复跑，不增加不同方法数 |
| 导出专项 | 生命周期单元1/0、原生导出UI1/0；也在完整套件中再次执行，不重复计入186/49 |
| 截图合并 | 327张编号截图；138项要求无缺失；10源完整逐源证据；无缺失设备证据 |

[全量运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) · [完整交付报告](docs/reviews/round-3-final-delivery-2026-11-02.md) · [逐图索引](artifacts/round-3/screenshots/INDEX.md) · [覆盖核对](artifacts/round-3/screenshots/COVERAGE.md) · [完整PNG artifact](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13139234028)。全部原始PNG与xcresult下载入口在报告内。

## 当前范围与限制

| 模块 | 已实现及融合 | 本次证据 |
|---|---|---|
| 多源全文 | Registry/Audit、RSS/Atom/API、完整正文提取/整理、SHA/canonical去重、双正文原子入库、离线、失败保留旧版本 | 真实10源29篇；逐源library/body/scrolled/end PNG |
| 多词典 | Wiktionary、Free Dictionary、本地CEDICT；词形/短语、多义项、来源、版本缓存、部分失败、离线 | 两英语Live本次均通过；可靠中文缺失禁止错误出题 |
| 可视化连线 | 英中双列、实际Canvas曲线、错误重试、多线、双端禁用、重复消费保护、恢复 | 匹配、旋转、滚动、AX等价UI及原始PNG |
| 阅读器 | 原生全文、标题/段落/列表/引用、三主题、大字、横屏、点击词、位置/版本恢复 | 主UI及SE/Pro Max均通过，原始横屏正文可见 |
| 学习闭环 | 最多两条简明释义、完整独立详情/嵌套；生词/个人释义/笔记；FSRS4.5、原句词形/整段短语拼写、反馈/下次时间 | 真网络空库闭环、事务、恢复、评分UI与PNG |
| 库/搜索/收藏 | 今日顶部书库入口；分类/来源/标题/排序/收藏/稍后/历史；完成后探索和词汇推荐；JSON/CSV真实导出 | 统一门禁、收藏不建周期、持久化与原生Save/取消均通过 |

未完成验收为负责人逐图视觉确认、完整VoiceOver听读、真机/iOS27及Instruments；没有把兼容模拟器或测试绿色标成这些项目已通过。外部来源持续可用性无法保证；Free本次成功但仍保留不可用处理。20项Round2整改实现、自动化结果、手动步骤及76路径完整修改清单见报告。

## 历史

专项41432723597为生命周期单元成功、UI启动超时；此前41429945732为实际Save反馈失败。这些历史失败经修复后，本次专项和全量均通过。历史CURRENT全文保留在[通过CI时的STATUS](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/b13d6b4e21e425472d059770319d88cd7c50a15e/STATUS.md)，不混作当前结果。
