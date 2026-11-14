# 变更记录

## 2026-11-14 · 文档与截图交付

- 精简当前规格、架构、测试和交付入口。旧报告按轮次归档，原规格修订可从 Git 历史查阅。
- 汇合同一成功构建的 413 张原生图、21 张原反馈和 3 张词典参考，新增分类浏览和逐项对照。见 [Round 4 交付报告](docs/reviews/round-4-final-delivery.md)。

## 2026-11-13 · Round 4 完整回归

- 内置唯一 MDX，阅读器小浮层、完整词典详情、离线搜索、生词与复习共用义项。新增系统发音、个人词典资格校验和版本化自动保存。
- 文章发现展示真实来源和进度。改进书库数量、收藏与稍后阅读、标题检索、探索卡片、长标题及正文排版。
- 统一复习预检，保留连线、拼写掩码、揭示后亲自纠正、延期和幂等排程。补齐旧库映射、失败恢复与用户数据保护。
- iOS 26.5 Simulator 的全量验证和 iOS 27.0 目标的未签名 IPA 记录于[交付报告](docs/reviews/round-4-final-delivery.md)。

## 以往轮次

| 轮次 | 变更 | 记录 |
|---|---|---|
| Round 3 | 多来源完整原文、FSRS 4.5、原生连线、数据导出和全屏阅读体验 | [自动化交付](docs/archive/reviews/round-3/round-3-final-delivery-2026-11-02.md) |
| Round 2 | 真实学习服务、全文阅读、查词、生词及复习的首个端到端实现 | [开发交付](docs/archive/reviews/round-2/round-2-development-delivery.md) |
| Round 1 | 原生工程、学习周期状态机、存储与恢复契约 | [验收与整改记录](docs/archive/README.md#round-1) |

更细的每批变更见 [Git 提交历史](https://github.com/whyhaoyu1022-glitch/LexiDawn/commits/main/)。
