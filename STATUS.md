# 当前状态

2026-11-21：e0f6bbf 已通过全部目标编译，正在专项验证连续词形/短语的原生 UI 等待修复。同时逐张查看 e0dea57 三主题横屏大字原始截图，发现浮窗词头/音标截断，不能用控件边界通过替代视觉验收。已补修换行、浮窗字号与滚动，并增加对应断言，待两项受影响 UI 专项验证。全部专项通过后才提交最终全量并暂停；当前没有新全量或新包通过结论。[最新记录](docs/reviews/round-4-ci-regression-2026-11-21.md)。

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
