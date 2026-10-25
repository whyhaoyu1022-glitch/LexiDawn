# 测试计划

| 层级 | 命令/环境 | 覆盖 | 本批次结果 |
|---|---|---|---|
| 语法/包清单 | `swift package dump-package` | manifest 可解析 | 待执行 |
| XCTest | macOS runner `xcodebuild test` | 导航、模型、状态机 | 未运行（当前无 Xcode） |
| UI/无障碍 | iOS Simulator | 规格 §24.6 | 未运行 |
| 设备/安装 | AltServer/AltStore 真机 | M9 | 未运行 |

每个功能切片必须补正常、边界、错误、恢复和安全用例（适用时）。
