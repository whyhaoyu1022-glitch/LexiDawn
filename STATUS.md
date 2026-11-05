# CURRENT · Round 3全量已通过；首次未签名真机IPA已导出（2026-11-05）

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
