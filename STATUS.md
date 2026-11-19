# 当前状态

2026-11-19：本批 CI 已报告的 9 次 UI 失败均已有后续通过的专项记录，新增推荐后台准备与取消 XCTest 通过。修复包括导入焦点与收键盘、推荐长文计算移出主线程、真实网络测试隔离与跨学习日操作，以及旧 medium sheet 测试对原生浮窗的错误拖动。原 21 张反馈图和 3 张词典参考已再次逐张打开。本次请求最终同一 SHA 的全量验证（246 项 XCTest、77 次 UI 执行、Release、截图与 IPA），结果尚未判定。确认启动后按负责人要求暂停，等待反馈。新截图包与 IPA 尚未完成本次交付。查看[专项结果与运行入口](docs/reviews/round-4-device-feedback-2026-11-18.md)。

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
