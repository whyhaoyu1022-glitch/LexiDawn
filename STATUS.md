# 当前状态

2026-11-21：`d3d17b7` 的[第二次全量 44872453369](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44872453369) 已结束。251/251 项 XCTest、76/77 次原生 UI、Release 及未签名 IPA `0.1.0 (214)` 通过。唯一失败为自有文章导入用例，原始附件显示授权未切换，保存仍禁用，截图覆盖缺 `reader-11`。上一轮失败的嵌套查词在本次全量通过（63.754 秒）。

本批处理导入的原生交互与诊断、跨版本阅读保存、复习准备和旧题组校验、拼写选题、离线搜索结果归属和迁移备份清理。按负责人要求，完成这批变更和宿主检查后仅发起一轮最终全量。预计 254 项 XCTest、77 次原生 UI、Release、IPA 及截图门禁。当前提交的原生结果待本轮验证。[问题与验证记录](docs/reviews/round-4-ci-regression-2026-11-21.md#接手后的问题核对和整改)

修复前的 Round 4 全量原生兼容回归已通过。验证代码为 `4be478e2e778bea4da2095e65a637e5df117f7be`，运行使用 Xcode 26.6 与 iOS 26.5 Simulator。[最终 CI](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858)

| 交付 | 结果 |
|---|---|
| Debug 全目标与 Release Simulator | 通过 |
| XCTest | 236/236，包括 27 项 MDX、15 项文章网络测试和旧库磁盘迁移 |
| XCUITest | iPhone 17 Pro 65/65，iPhone SE 第三代 7/7，iPhone 17 Pro Max 3/3 |
| 截图 | 413 张同构建原生 PNG。138 项截图场景、设备专项及 10 家真实来源的阅读序列通过 |
| IPA | 0.1.0（180），未签名，目标最低 iOS 27.0，包内完整 MDX 已校验 |

[原生截图与索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14037751591) · [未签名 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858/artifacts/14032474473) · [Round 4 交付报告](docs/reviews/round-4-final-delivery.md)

## 待验收

- 独立逐条核对 144 项标准。全部已有通过的候选测试，79 项有直接编号截图。见[需求追踪](docs/requirements-traceability.md)。
- 在 iOS 27 设备签名安装后，核验学习闭环、音频与 VoiceOver 实际听读、数据升级和长文性能。见[安装](docs/signing.md)与[真机检查项](docs/test-plan.md#真机验收)。

2026-11-14 整理文档，并从上述成功运行生成带原图和词典参考的分类截图 ZIP。该批为资料变更，沿用上述构建与测试证据。[截图交付记录](docs/reviews/round-4-final-delivery.md#截图交付)
