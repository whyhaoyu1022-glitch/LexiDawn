# 测试计划

| 层级 | 命令/环境 | 覆盖 | Round 1 结果 |
|---|---|---|---|
| 工程识别 | `xcodebuild -list -project LexiDawn.xcodeproj` | 应用与测试 target/scheme | CI 环境可执行；当前容器无 Xcode，未本地运行 |
| 未签名构建 | `xcodebuild ... -configuration Debug IPHONEOS_DEPLOYMENT_TARGET=26.5 CODE_SIGNING_ALLOWED=NO build`（CI checkout 临时覆盖目标） | 应用产物与 Info.plist | run 40597791954 success；本地容器无 Xcode |
| XCTest | 先用 `-destination generic/platform=iOS Simulator ... build-for-testing`，再在具体 simulator 上 `xcodebuild test` | 状态机、周期幂等、跨日、时区、SwiftData、磁盘重开、候选门禁、首页 ViewModel、失败重试 | run 40597791954 unit step success；25 XCTest 方法在 target 中，artifact 12776278533 |
| UI 测试 | 同一具体 Simulator，`-configuration Debug` | 五入口、无候选首页和禁用未接入任务入口 | run 40597791954：2 tests/0 failures |
| UI/无障碍 | iOS Simulator/真机 | SPEC §24.6 | 未运行 |
| 设备/安装 | AltServer/AltStore 真机 | M9 | 未运行 |

CI 在 runner checkout 中临时把工程内 27.0 deployment target 替换为已批准的 26.5 兼容目标；工程没有独立 `CI` build configuration。workflow 先用 `generic/platform=iOS Simulator` 执行 `build-for-testing` 编译应用和测试 target，编译失败会在创建 simulator 前终止。通过后保留 `xcodebuild -showdestinations` 诊断，但 Xcode 26.6 可能只返回 placeholder，因此以刚创建并由 `simctl` 再次确认存在的具体设备 ID执行 build/test；失败会使 job 失败，不会跳过测试。run 40597791954 已完成并成功，单元/UI 结果包上传为 artifact 12776278533。

CI 固定使用用户批准的 iOS 26.5 兼容目标。工程产品配置仍为 iOS 27.0，兼容构建和测试结果不替代规格目标验收。本地容器没有 Swift/Xcode，因此本轮没有声称本地 iOS 构建、XCTest 或 UI 测试通过。
