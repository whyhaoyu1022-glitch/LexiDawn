# Round 4 交付报告

验证代码为 `4be478e2e778bea4da2095e65a637e5df117f7be`。[全量运行 43420154858](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858) 成功。原生测试使用 Xcode 26.6、iOS 26.5 Simulator。对应的未签名 IPA 目标最低 iOS 27.0，尚未在真机签名安装和验收。

## 已实现范围

| 范围 | 交付内容 |
|---|---|
| 今日、文章库和探索 | 实际来源进度与结果、可读库存与筛选、独立收藏/稍后、全文准入与主题卡 |
| 阅读器 | 长标题、自然正文、旧文展示投影、主题/方向/字号、点词小浮层和关闭后原位恢复 |
| 词典和生词 | 内置 MDX、原生完整详情、系统语音、离线查词、结构化个人义和修订、笔记、推荐与导出 |
| 复习和设置 | 预检、可视连线、冻结掩码、揭示后纠正、Again 与幂等 FSRS，自动保存和恢复 |

[24 项需求与 144 条追踪](../requirements-traceability.md) · [实现改动清单](https://github.com/whyhaoyu1022-glitch/LexiDawn/compare/30311f806d587453c601a0a44bf5cc8a6c338ec4...4be478e2e778bea4da2095e65a637e5df117f7be)

## 实际测试

| 检查 | 结果 |
|---|---|
| Debug 全目标、Release Simulator | 通过。Release 核验旧词典网络端点与调试场景标记未进入成品。 |
| XCTest | 236/236。含 27 项 MDX、15 项文章网络测试及真实磁盘迁移。 |
| XCUITest | iPhone 17 Pro 65/65，iPhone SE 第三代 7/7，iPhone 17 Pro Max 3/3。 |
| 截图覆盖 | 138/138 个已定义场景、设备专项、10 家真实来源的筛选/正文/滚动/末页。 |

已在同构建跑过历史 Round 3 映射和重开测试。原文件、结构数据、哈希、用户生词与笔记、周期、当前及历史复习关系按实际迁移断言核验。事务失败留原有效状态及备份，旧外部词义历史保留。使用当前 MDX 重新预检的旧无效题另存原快照。[迁移与事务设计](../architecture.md#层与事务) · [逐方法日志产物](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14033683983)

基线 `30311f8` 的 208 个 XCTest 和 57 个主设备 XCUITest 方法全部保留。通过构建增加了 28 个 XCTest 和 8 个主设备 XCUITest，设备专项是其中部分方法的重复验证。

## 截图交付

- **分类对照包**为 `LexiDawn-Round4-Final-Screenshots.zip`，随交付消息提供。合并通过测试的 413 张原生 PNG、21 张反馈原 HEIC 和 3 张词典参考 JPEG。解压打开 `INDEX.html` 按功能浏览，`FEEDBACK.html` 逐项对照，`DICTIONARY-REFERENCES.html` 对照实际 MDX 的首、中、末段及三主题。运行图和原件保留原始字节，反馈另附可在浏览器查看的 JPEG 预览。
- **GitHub 产物**保留[413 张原始运行图及索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14037751591)和[原生附件](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14037456653)。清单区分真实 MDX、真实来源、明确的测试夹具和故障注入。
- **原件及对照**见[上传原件复核](round-4-original-image-recheck-2026-11-11.md)与[整改对照表](round-4-image-remediation-matrix.md)。本次参考首、中、末段的真实 MDX 图分别提取且哈希不同。上一构建的视觉观察可从[历史对照](round-4-simulator-visual-review-1859403.md)追溯。

分类 ZIP 大小 163,920,373 字节，SHA-256 `46d1ae9b6336d6afdeb70d0eb115974dd5e9e0adc797ef34ec4d150be43cbf08`。包含 458 个核验过的图片条目（含 21 张原图预览），通过原始 SHA、PNG/JPEG 格式、ZIP CRC 与索引链接校验。

## IPA 与内置词典

[未签名 IPA 0.1.0（180）](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14032474473)，arm64 / iPhoneOS / 最低 iOS 27.0。IPA 43,935,410 字节，SHA-256 `5611df617771100804133aa1333936873c014e4d93f5b26abb023cdf19bc7b5d`。打包任务核验实际 Info.plist、图标、架构、无签名状态和包内词典。

`BundledDictionary.mdx` 从仓库两份原包按 manifest 恢复。构建检查实际 App Bundle 及 IPA，MDX 文件均为 38,774,534 字节，SHA-256 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。宿主扫描核验了 203,181 个索引记录（含别名）、块校验、内部目标、环路与 UTF-8。[词典分包与格式](<../../Dictionary Data/README.md>) · [宿主记录](../../artifacts/round-4/mdx-host-verification.json) · [签名安装](../signing.md)

## 验收边界

144 条标准属于 24 个测试族。每条都有关联的通过候选方法，79 条有直接编号截图。逐条独立核对与 iOS 27 真机验收仍待执行。系统语音测试验证调用及状态，音质、完整 VoiceOver 听读和长文真机性能需在设备实测。[逐项运行证据](round-4-native-evidence-4be478e.json) · [真机验收操作](../test-plan.md#真机验收)
