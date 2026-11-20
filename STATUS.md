# 当前状态

2026-11-20：全量 44542739409 中 246/246 XCTest、Release、IPA 和 74/77 次 UI 通过。搜索、手动加入已分别完成后续专项；取消/重启、选择所有权和真实 MDX 连续查询在 dfe65ab / 44715663269 中 3/3 通过，启动故障控制 4/4 通过。连续查词 UI 仍未通过；现针对原生正文词语在模态覆盖时仍暴露的问题修复 UIKit 容器，新增原生 XCTest 已通过（1.179 秒），但 UI 首次查词仍阻塞。继续限定同一 UI，采集真实线程堆栈和持久请求日志定位；没有进入全量。全部专项通过后才提交最终全量并停下。当前没有新全量通过或新包交付结论。[完整记录](docs/reviews/round-4-ci-regression-2026-11-20.md)。

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
