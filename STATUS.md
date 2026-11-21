# 当前状态

**iPhone 真机测试包 `0.1.0 (215)` 已就绪。** 构建对应 `309bbfd0a06b1d461cdc36001399e047167de69f`，面向 arm64 iPhone，最低 iOS 27.0，需在本机签名。下载 Actions 产物后，解压外层 ZIP，取出 `LexiDawn-unsigned.ipa`。[下载构建 215](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14699989879) · [签名安装](docs/signing.md) · [真机测试清单](docs/device-testing.md)

## 最近一次全量验证

2026-11-21，全量 `44887232103` 成功。工具链为 Xcode 26.6，原生测试使用 iOS 26.5 Simulator。自有文章导入用例已完整通过，短文阅读 `reader-11` 已补齐。[完整运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103) · [交付记录](docs/reviews/round-4-final-delivery.md)

| 检查 | 结果 |
|---|---|
| XCTest | 254/254 通过 |
| XCUITest | iPhone 17 Pro 67/67，iPhone SE 第三代 7/7，iPhone 17 Pro Max 3/3 |
| Release 与 IPA | 两项通过。IPA 字节、架构、最低系统及完整离线 MDX 均已复核 |
| 截图 | 443 张原生 PNG，138/138 个定义场景，九家实时来源有完整阅读序列 |

[本次原生截图和索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14702136983) · [原始运行附件](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44887232103/artifacts/14701863330)

## 待验收

- 在 iOS 27 真机上记录签名安装、旧数据覆盖升级、离线阅读查词、复习恢复、VoiceOver 与长文表现。[真机测试清单](docs/device-testing.md)
- 完成 144 条独立验收。历史图证和候选测试按原 SHA 查阅，独立结论继续写入现有账本。[需求追踪](docs/requirements-traceability.md)
- 后续工程复验包含月份词形、同句同形词排序、旧词形的 CSV 日志及部分保存后的个人义项草稿恢复。[代码复查](docs/reviews/round-4-final-delivery.md#真机前的代码复查)

此前的失败、专项及旧版下载请从[交付与审查索引](docs/reviews/README.md)按提交查询。
