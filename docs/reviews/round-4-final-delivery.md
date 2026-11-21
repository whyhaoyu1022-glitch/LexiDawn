# Round 4 交付记录

## 当前真机测试包 · 0.1.0 (215)

`309bbfd0a06b1d461cdc36001399e047167de69f` 的 [iOS CI 44887232103](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103) 于 2026-11-21 17:50（北京时间）成功结束。模拟器验证使用 Xcode 26.6 和 iOS 26.5 Simulator。签名后在 iOS 27 真机执行的结果待记录。

| 验证项 | 实际结果 |
|---|---|
| XCTest | 254/254 通过，包含上一批新增的三个回归及扩展的正文版本验证。 |
| 原生 UI | 67 次主机型执行、SE 第三代 7 次、Pro Max 3 次，共 77/77 通过。此前自有文章导入失败项本次通过，用时 238.351 秒。 |
| 截图与覆盖 | 合并 443 张原生 PNG，138 个定义场景齐全。`reader-11` 已含 `R3-legacy-F08-owned-import-native-reader-iPhone18-1.png`。九家实时来源有完整序列。 |
| Release 与 IPA | Release Simulator 和 arm64 iPhoneOS IPA 打包成功，最低 iOS 27.0。 |

[XCTest 日志](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/job/136795054666) · [导入分片](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/job/136798639899) · [截图覆盖](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/job/136807793162) · [原生图与索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14702136983)

抽看同运行的 `R3-legacy-X01-import-empty-title-validation-iPhone18-1.png` 和 `R3-legacy-F08-owned-import-native-reader-iPhone18-1.png`，确认授权开启后出现空标题校验，保存后的短文能在原生阅读器打开。暖纸色横屏大字截图中另发现下表的月份释义问题。[原始 PNG 与索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14702136983)

**下载和核验。** 从 Actions ZIP 解出 `LexiDawn-unsigned.ipa` 后签名。实际 IPA 为 44,092,298 字节，SHA-256 `77492854013fd35d77c76ac4d6e2633aa64e056b2eb85d017cddc429d6a3bad5`。已重新核对 ZIP、IPA、Info.plist、未签名 arm64 主程序及完整的 `BundledDictionary.mdx`。包内 MDX 为 38,774,534 字节和 203,181 项索引。[IPA 产物](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14699989879) · [打包核验日志](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/job/136795054407) · [安装](../signing.md) · [真机测试](../device-testing.md)

### 真机前的代码复查

复查使用构建 215 的源码、IPA 内词典和同运行截图。复验时记录机型及初始数据。独立的 144 条验收仍按原账本逐条核对。

| 风险 | 当前行为 | 后续验证 |
|---|---|---|
| P1 · 月份 `August` 误取形容词 | 同运行原图 `R4-popup-max-type-scrolled-paper-iPhone18-1.png` 中，原文 `August 2020` 的点词浮窗显示小写 `august` 和形容词义。直接读取 IPA 内 MDX 并追踪内部词条链接，确认 `August`、`august` 各自存在并分别提供月份与形容词义。应用对 `May` 有专门保留逻辑，`August` 则被转为小写。[原生图产物](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14702136983) · [标准化代码](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309bbfd0a06b1d461cdc36001399e047167de69f/LexiDawn/Domain/Learning/LearningRules.swift#L54-L76) | 在 RFC 开头点 `August 2020`，记录词头和首义。后续覆盖月份、普通形容词和前后词形，以及已有生词和义项关联。 |
| P1 · 旧词形 CSV 导出 | 历史别名词形的日志在数据库和 JSON 导出中保留。CSV 的 `reviewLogsJSON` 仅筛当前词条 ID，会遗漏同一主词条的历史别名日志。[导出代码](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309bbfd0a06b1d461cdc36001399e047167de69f/LexiDawn/Data/VocabularyRepository.swift#L285-L303) | 用有别名合并与旧复习日志的旧库，分别导出 JSON、CSV，对照事件 ID 与时间。需要留旧词形历史时用 JSON。 |
| P1 · 个人义项与笔记部分保存 | 笔记保存成功、个人义项随后校验或写入失败时，草稿仍记录两步保存前的基线。重开会把正常保留的失败草稿提示为版本冲突。[草稿保存](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309bbfd0a06b1d461cdc36001399e047167de69f/LexiDawn/Features/Learning/VocabularyFeature.swift#L237-L310) | 用测试词条验证笔记已存而义项待恢复，后续为部分成功补回归，保留独立笔记保存规则。 |
| P1 · 同一句多次出现同形词 | 义项排序以原句的首个同形词决定语法词性。点中同句后面的同形词时，有可能继续使用前一个位置的词性。[排序](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309bbfd0a06b1d461cdc36001399e047167de69f/LexiDawn/Data/DictionaryAggregation.swift#L252-L304) · [查词入口](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/309bbfd0a06b1d461cdc36001399e047167de69f/LexiDawn/Data/VocabularyRepository.swift#L645-L686) | 在 `I book early so I can read the book later.` 中分别点两个 `book`，记录实际词头，以及单词命中时的动词和名词首义。文章主题和常见程度的排序需求也仍待专门的验收样例。 |

本轮保持构建 `309bbfd` 的设备测试基线，整理下载、签名、测试与证据入口。后续改动以真机复现和独立验收证据安排。

## 历史参考 · 构建 0.1.0 (180)

这一节及下列历史记录对应修复前 `4be478e`。后续设备反馈见 [2026-11-18 反馈记录](round-4-device-feedback-2026-11-18.md)，回归与修复过程见 [2026-11-21 CI 续修记录](round-4-ci-regression-2026-11-21.md)。

验证代码为 `4be478e2e778bea4da2095e65a637e5df117f7be`。[全量运行 43420154858](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858) 成功。原生测试使用 Xcode 26.6、iOS 26.5 Simulator。对应的未签名 IPA 目标最低 iOS 27.0，尚未在真机签名安装和验收。

### 当时实现范围

| 范围 | 交付内容 |
|---|---|
| 今日、文章库和探索 | 实际来源进度与结果、可读库存与筛选、独立收藏/稍后、全文准入与主题卡 |
| 阅读器 | 长标题、自然正文、旧文展示投影、主题/方向/字号、点词小浮层和关闭后原位恢复 |
| 词典和生词 | 内置 MDX、原生完整详情、系统语音、离线查词、结构化个人义和修订、笔记、推荐与导出 |
| 复习和设置 | 预检、可视连线、冻结掩码、揭示后纠正、Again 与幂等 FSRS，自动保存和恢复 |

[24 项需求与 144 条追踪](../requirements-traceability.md) · [实现改动清单](https://github.com/whyhaoyu1022-glitch/LexiDawn/compare/30311f806d587453c601a0a44bf5cc8a6c338ec4...4be478e2e778bea4da2095e65a637e5df117f7be)

### 当时测试

| 检查 | 结果 |
|---|---|
| Debug 全目标、Release Simulator | 通过。Release 核验旧词典网络端点与调试场景标记未进入成品。 |
| XCTest | 236/236。含 27 项 MDX、15 项文章网络测试及真实磁盘迁移。 |
| XCUITest | iPhone 17 Pro 65/65，iPhone SE 第三代 7/7，iPhone 17 Pro Max 3/3。 |
| 截图覆盖 | 138/138 个已定义场景、设备专项、10 家真实来源的筛选/正文/滚动/末页。 |

已在同构建跑过历史 Round 3 映射和重开测试。原文件、结构数据、哈希、用户生词与笔记、周期、当前及历史复习关系按实际迁移断言核验。事务失败留原有效状态及备份，旧外部词义历史保留。使用当前 MDX 重新预检的旧无效题另存原快照。[迁移与事务设计](../architecture.md#层与事务) · [逐方法日志产物](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14033683983)

基线 `30311f8` 的 208 个 XCTest 和 57 个主设备 XCUITest 方法全部保留。通过构建增加了 28 个 XCTest 和 8 个主设备 XCUITest，设备专项是其中部分方法的重复验证。

### 截图交付

- **分类对照包**为 `LexiDawn-Round4-Final-Screenshots.zip`，随交付消息提供。合并通过测试的 413 张原生 PNG、21 张反馈原 HEIC 和 3 张词典参考 JPEG。解压打开 `INDEX.html` 按功能浏览，`FEEDBACK.html` 逐项对照，`DICTIONARY-REFERENCES.html` 对照实际 MDX 的首、中、末段及三主题。运行图和原件保留原始字节，反馈另附可在浏览器查看的 JPEG 预览。
- **GitHub 产物**保留[413 张原始运行图及索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14037751591)和[原生附件](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14037456653)。清单区分真实 MDX、真实来源、明确的测试夹具和故障注入。
- **原件及对照**见[上传原件复核](round-4-original-image-recheck-2026-11-11.md)与[整改对照表](round-4-image-remediation-matrix.md)。本次参考首、中、末段的真实 MDX 图分别提取且哈希不同。上一构建的视觉观察可从[历史对照](round-4-simulator-visual-review-1859403.md)追溯。

分类 ZIP 大小 163,920,373 字节，SHA-256 `46d1ae9b6336d6afdeb70d0eb115974dd5e9e0adc797ef34ec4d150be43cbf08`。包含 458 个核验过的图片条目（含 21 张原图预览），通过原始 SHA、PNG/JPEG 格式、ZIP CRC 与索引链接校验。

### IPA 与内置词典

[未签名 IPA 0.1.0（180）](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14032474473)，arm64 / iPhoneOS / 最低 iOS 27.0。IPA 43,935,410 字节，SHA-256 `5611df617771100804133aa1333936873c014e4d93f5b26abb023cdf19bc7b5d`。打包任务核验实际 Info.plist、图标、架构、无签名状态和包内词典。

`BundledDictionary.mdx` 从仓库两份原包按 manifest 恢复。构建检查实际 App Bundle 及 IPA，MDX 文件均为 38,774,534 字节，SHA-256 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。宿主扫描核验了 203,181 个索引记录（含别名）、块校验、内部目标、环路与 UTF-8。[词典分包与格式](<../../Dictionary Data/README.md>) · [宿主记录](../../artifacts/round-4/mdx-host-verification.json) · [签名安装](../signing.md)

### 验收边界

144 条标准属于 24 个测试族。每条都有关联的通过候选方法，79 条有直接编号截图。逐条独立核对与 iOS 27 真机验收仍待执行。系统语音测试验证调用及状态，音质、完整 VoiceOver 听读和长文真机性能需在设备实测。[逐项运行证据](round-4-native-evidence-4be478e.json) · [真机验收操作](../device-testing.md)
