# 词光 LexiDawn

词光是面向个人学习的原生 iPhone 应用。读完整英文文章、点词离线查释义，保存生词和笔记，再按 FSRS 4.5 复习。项目使用 SwiftUI、必要的 UIKit 和 SwiftData。

- **阅读**支持完整原文、收藏、稍后阅读和历史。今日、文章库与探索共享发现进度。
- **查词**使用内置 MDX，阅读器浮层、生词和复习共用词义身份。MDX 成功确认无中文时可补个人释义。发音由 iOS 系统语音提供。
- **复习**包含可保存和恢复的连线与拼写。学习进度、个人词条和笔记保存在设备上，词汇可导出 JSON 或 CSV。

[当前进度和下载](STATUS.md) · [iPhone 安装](docs/signing.md) · [文档索引](docs/README.md)

## 开发

用 Xcode 打开 `LexiDawn.xcodeproj`，选择 `LexiDawn` scheme。生产目标最低 iOS 27.0。当前 CI 使用 Xcode 26.6 和 iOS 26.5 Simulator 做兼容验证，实际设备结果见当前状态。

构建阶段用 Python 3 验证并恢复仓库中的两个 ZIP，生成完整的 `BundledDictionary.mdx`。[词典数据目录](<Dictionary Data/README.md>)

```sh
python3 scripts/ci-test-plan.py verify
python3 scripts/test-bundled-dictionary.py
```

这两条命令分别验证测试分组和词典恢复与读取。[测试计划](docs/test-plan.md) · [产品规格](SPEC.md) · [工程约定](AGENTS.md)
