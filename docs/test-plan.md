# 测试计划

| 层级 | 命令/环境 | 覆盖 | 本批次结果 |
|---|---|---|---|
| 工程识别 | `xcodebuild -list -project LexiDawn.xcodeproj` | 应用与测试 target/scheme | 等待 macOS Actions |
| 未签名构建 | `xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` | 应用产物与 Info.plist | 等待新的 Actions |
| XCTest | 同一 scheme 的 `xcodebuild test` | 4 pt 间距 token、导航可构造 | 等待新的 Actions |
| UI 测试 | `xcodebuild test` 中的 `LexiDawnUITests` | 启动、五入口定位与选择 | 等待新的 Actions |
| UI/无障碍 | iOS Simulator/真机 | SPEC §24.6 | 未运行 |
| 设备/安装 | AltServer/AltStore 真机 | M9 | 未运行 |

本地容器没有 Swift/Xcode，因此本批次没有声称本地 iOS 测试通过。CI 构建或测试失败时 workflow 必须失败；被跳过的测试不能作为通过证据。
