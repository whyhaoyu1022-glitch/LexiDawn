> **2026-11-09 负责人规则覆盖：唯一词典来源为 App 内置 MDX。** 两个 ZIP 只在构建阶段由仓库 merge.py 恢复并验证；运行时原生 C 读取压缩索引与记录块，由 Swift Actor 查询，系统 libxml2 提取词义，AVSpeechSynthesizer 发音。不需要 MDD、词典图片、在线音频，不支持用户导入词典，不向任何在线词典查询。只有 MDX 成功确认无中文或无词条，才允许结构化个人义项；资源/解析故障不等于查无词条。历史外部缓存及个人数据保留，外部缓存不再参与展示或新题。下文旧多 Provider、CC-CEDICT、在线回退及未知失败可补义规则均属历史，已被本段取代。文章来源规则不变。实现及测试尚在进行，不能据此关闭 144 项验收。

# 词光 LexiDawn

**CURRENT · Round 4正在开发：英中词典、阅读与UI批次已写入，原生验证/复习集成/截图验收未完成。**

[Round 4详细任务书](docs/plans/round-4-development-specification.md) · [21图逐张审阅](docs/reviews/round-4-first-device-21-image-audit-2026-11-06.md) · [CURRENT状态](STATUS.md)。原21图独立编号；新增[词典详细页补充规范](docs/plans/round-4-dictionary-detail-addendum.md)及[三图审阅](docs/reviews/round-4-dictionary-reference-audit-2026-11-07.md)，当前合计144条验收、24个测试族。可靠来源词禁用用户释义，无可靠来源才支持结构化个人词；两类词与复习统一合同。本次只提交计划文档。

## Round 3历史交付与现有产品说明

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。 [完整交付报告](docs/reviews/round-3-final-delivery-2026-11-02.md)。

原生 iOS 英文全文阅读、查词、生词管理和间隔复习应用。使用 SwiftUI、SwiftData、Domain、Service 和 Repository，不依赖网页阅读器或大型 UI 框架。

**Round 3历史结果 · 全量自动化通过，截图包已交付；后续真机反馈见Round 4。**

本次真实通过结果与完整下载入口见[交付报告](docs/reviews/round-3-final-delivery-2026-11-02.md)；历史失败保留在Actions与Git历史中。

## 使用入口与任务融合

- **今日**：继续最早未完成周期，明确区分阅读、连线和拼写状态。新文章不会覆盖旧周期；已指派文章不重复分配。顶部书库图标进入“文章库与历史”，导入按钮粘贴个人完整原文。
- **文章库与历史**：发现完整文章、标题搜索、来源/分类筛选、时间排序、收藏、稍后阅读和历史。标记收藏不会创建每日周期。任务完成前，所有库、历史、收藏及稍后入口均只能打开当前任务文章；Reader 打开和进度写入再次执行同一门禁。
- **探索**：完成当前学习日全部必做任务后解锁。完整本地文章按兴趣等因素排序，支持分类、收藏、稍后和发现；打开即记录开始。重新标记为未开始需确认，原进度归档。每日文章不能重置。
- **阅读器**：全文离线阅读、标题/段落/引用/列表、词级点击、位置恢复、横竖屏、动态字体、浅色/深色/暖纸色。查词浮窗展示最多两条原始简明释义，工具栏词典进入含全部原始义项的独立详情，支持有限深度嵌套查词。
- **词汇**：生词本搜索、类型/复习状态筛选、排序、个人释义/笔记、明确选择词典中文义项、确认移除、JSON/CSV 导出。上方“高级词汇与短语推荐”在完成任务后开放，从真实本地全文提取并查询词典，只有主动加入才写入生词本。
- **复习**：真实双列连线与持久化拼写。拼写固定原句实际词形，遮住整词或整段短语；没有可靠中文答案时阻止生成。FSRS 4.5 保存排程、反馈和下次时间；额外复习使用独立会话，不新增每日周期或重新锁定探索。
- **个人原文更新**：解锁后可在库中更新未指派的个人原文，必须重新确认完整原文。旧全文与署名保留；新正文按唯一原段落恢复位置，无法定位时回到开头。每日已指派原文禁止更新。

## 内容与词典

按负责人 2026-11-01 的特别指示，个人模式尝试公开官网完整正文。BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian 加上 Wikipedia/Wikinews 共 13 个候选适配器；可尝试不代表成功或出版社授权。登录、验证码、付费墙、403 和不完整正文均丢弃，无摘要、URL 或浏览器降级。实际已验证来源与许可调查分别记录在 [来源审查](docs/article-source-eligibility-audit.md)。

唯一词典来源为 App 内置 MDX。构建阶段恢复并校验完整文件，原生 C 引擎与 Swift Actor 离线查询，系统 libxml2 解析 HTML，AVSpeechSynthesizer 负责系统发音。不需要 MDD、图片或在线音频，不支持导入其他词典，没有在线回退。MDX 成功确认没有中文释义时，允许创建结构化个人词条；引擎故障不冒充查无此词。旧外部缓存保留历史，但不再用于展示和新题。

## 构建和验证

产品 Debug/Release 目标保持 iOS 27.0；当前 Actions 在 checkout 中临时采用已批准的 iOS 26.5 兼容环境与 Xcode 26.6，不能替代 iOS 27 或真机验收。本地开发容器没有 Swift/Xcode/Simulator，原生运行证据来自 Actions。

```sh
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
python3 scripts/ci-test-plan.py verify
```

CI 一次编译所有测试，完整单元/真实网络/Release 关卡通过后，4 个穷尽 UI 分组与 SE/大屏专项共享相同编译产物；新 main 提交取消旧运行，任一分组失败取消其余分组。失败日志、原生截图和 xcresult 仍保留。完整 PNG 包由同一次运行合并并核验 SHA，含 manifest、CSV 和逐张索引。尚未完成的最终证据不以历史绿色运行代替。

规范：[SPEC](SPEC.md)、[补充规范](docs/spec-addendum-content-and-dictionary.md)、[本轮计划](docs/plans/round-3-development-plan.md)、[需求追踪](docs/requirements-traceability.md)、[测试计划](docs/test-plan.md)、[架构](docs/architecture.md)。Round 2 历史结果保留在原始独立审核和交付报告中，不作为当前提交结果。


## Round 3截图下载

[完整原生截图artifact](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391/artifacts/13139234028)；[327张逐图编号与文件名](artifacts/round-3/screenshots/INDEX.md)；[138项覆盖核对](artifacts/round-3/screenshots/COVERAGE.md)。该产物属于上述已通过代码，后续仅文档提交不会改变其来源。
