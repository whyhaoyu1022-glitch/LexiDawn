# 测试计划

| 层级 | 命令/环境 | 覆盖 | 本批次结果 |
|---|---|---|---|
| 工程识别 | `xcodebuild -list -project LexiDawn.xcodeproj` | 应用与测试 target/scheme | 已在 Actions 构建阶段识别 |
| 未签名构建 | `xcodebuild ... IPHONEOS_DEPLOYMENT_TARGET=26.5 CODE_SIGNING_ALLOWED=NO build` | 应用产物与 Info.plist | 最新失败 run 中已通过 |
| XCTest | 具体 iOS Simulator 的 `xcodebuild test` | 4 pt 间距 token、导航可构造 | 修复具体 destination 后等待新 Actions |
| UI 测试 | 同一具体 Simulator 的 `LexiDawnUITests` | 启动、五入口定位与选择 | 修复具体 destination 后等待新 Actions |
| UI/无障碍 | iOS Simulator/真机 | SPEC §24.6 | 未运行 |
| 设备/安装 | AltServer/AltStore 真机 | M9 | 未运行 |

CI 固定使用用户批准的 iOS 26.5 兼容目标。workflow 会从 `xcrun simctl list devices available -j` 动态选择可用 iPhone Simulator，执行 boot/bootstatus，然后把 `-destination id=<具体设备>` 传给 `xcodebuild test`。未签名 26.5 兼容构建和测试结果不替代规格要求的 iOS 27.0 产品配置验收。

本地容器没有 Swift/Xcode，因此本批次没有声称本地 iOS 测试通过。CI 构建或测试失败时 workflow 必须失败；被跳过的测试不能作为通过证据。
