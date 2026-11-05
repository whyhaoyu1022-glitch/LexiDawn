# CURRENT · Round 3 需求追踪与自动化证据

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。

SPEC §17.2原文“不使用透明背景。”及“在 Xcode Asset Catalog 中按目标 SDK 要求配置 AppIcon”；§22.7“不能在未签名或签名无效时上传一个被标记为可安装的产物。”本次依赖官方Xcode真机SDK，验收为真实IPA结构/签名状态/元数据/图标与SHA；用户自行签名安装，不能把构建当真机通过。安装步骤见[签名说明](signing.md)。

## 2026-11-02 已有全量与截图交付证据（历史范围）

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。

SPEC §9.2：“支持导出词汇数据为 JSON 或”及下一行“CSV；导出内容应包含词条、释义、来源、复习状态和时间戳。”§30：“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”原规格、全文补充及负责人个人模式/可选词典指示的区别保持原样，不改产品规则。本次目标仅将通过结果、元数据与原始截图交付落地。

| 模块 | 已实现及融合 | 本次证据 |
|---|---|---|
| 多源全文 | Registry/Audit、RSS/Atom/API、完整正文提取/整理、SHA/canonical去重、双正文原子入库、离线、失败保留旧版本 | 真实10源29篇；逐源library/body/scrolled/end PNG |
| 多词典 | Wiktionary、Free Dictionary、本地CEDICT；词形/短语、多义项、来源、版本缓存、部分失败、离线 | 两英语Live本次均通过；可靠中文缺失禁止错误出题 |
| 可视化连线 | 英中双列、实际Canvas曲线、错误重试、多线、双端禁用、重复消费保护、恢复 | 匹配、旋转、滚动、AX等价UI及原始PNG |
| 阅读器 | 原生全文、标题/段落/列表/引用、三主题、大字、横屏、点击词、位置/版本恢复 | 主UI及SE/Pro Max均通过，原始横屏正文可见 |
| 学习闭环 | 最多两条简明释义、完整独立详情/嵌套；生词/个人释义/笔记；FSRS4.5、原句词形/整段短语拼写、反馈/下次时间 | 真网络空库闭环、事务、恢复、评分UI与PNG |
| 库/搜索/收藏 | 今日顶部书库入口；分类/来源/标题/排序/收藏/稍后/历史；完成后探索和词汇推荐；JSON/CSV真实导出 | 统一门禁、收藏不建周期、持久化与原生Save/取消均通过 |

## Round 2逐项对应

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

## 统一验收依赖

通过代码`b13d6b4e21e425472d059770319d88cd7c50a15e`；[完整结果/限制/手动验证](reviews/round-3-final-delivery-2026-11-02.md)、[逐图索引](../artifacts/round-3/screenshots/INDEX.md)、[覆盖核对](../artifacts/round-3/screenshots/COVERAGE.md)。依赖当前已通过的Repository事务、数据库迁移、业务门禁与测试，不再修改实现。自动化通过与负责人视觉验收分开，不以截图存在替代功能。

全部历史需求的逐字依据和开发过程见[收尾前矩阵](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/b13d6b4e21e425472d059770319d88cd7c50a15e/docs/requirements-traceability.md)，原SPEC与补充文件未改。新的源准入遵循个人模式特别指示，公开可访问不改写为出版社授权。
