# 词光 LexiDawn

个人使用的原生 iOS 英语阅读、词典与间隔复习应用。产品行为以 [SPEC.md](SPEC.md) 为准，当前仍处于 M0 验收阶段。

## 开发环境

工程使用 SwiftUI 和原生 Xcode 项目，不引入第三方 UI 框架。应用 target 的 bundle identifier 是 `com.lexidawn.app`，版本为 `0.1.0 (1)`，常规 Debug/Release 产品配置的最低系统版本为 iOS 27.0。CI 在 runner checkout 中临时把该目标替换为已批准的 iOS 26.5 兼容目标，再使用 Debug 配置构建和测试；工程中没有独立的 `CI` build configuration。兼容构建不替代 iOS 27.0 规格验收。

## 构建与测试

```sh
xcodebuild -list -project LexiDawn.xcodeproj
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 先使用 `build-for-testing` 和 `generic/platform=iOS Simulator` 编译应用及测试 target；这一步失败时不会启动具体 simulator。编译通过后才创建并校验具体 iOS Simulator，保留 `xcodebuild -showdestinations` 诊断后使用该设备 ID 执行单元测试和 UI 测试，并上传 `.xcresult` 结果包。workflow 只在 `main` push 和面向 `main` 的 pull request 上触发。当前开发容器没有 Xcode，不能把本地命令结果写成 iOS 验收证据。

## 交付边界

模拟器/未签名构建与可安装签名 IPA 分开记录。Windows + AltServer/AltStore 路径和免费 Apple ID 限制见 [docs/signing.md](docs/signing.md)。


## Round 1 第二次整改状态

代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。

已实施领域证据、严格状态恢复、隔离事务上下文、真实磁盘故障/重开、两版旧schema升级和UI禁用/错误/启动恢复回归。UI长循环已排查，补齐原生启动配置并改为有界定向定位；未减少业务断言。CI固定iPhone17Pro/iOS26.5，共享derivedData，保留完整日志与xcresult。

生产候选与阅读/复习模块仍未接入，fixture不作为真实内容或授权来源；兼容模拟器结果不等于iOS27、真机、IPA或完整产品验收。准确边界见 [STATUS.md](STATUS.md)、[测试计划](docs/test-plan.md) 和 [本轮整改报告](docs/reviews/round-1-second-remediation-report-2026-10-31.md)。后续文档提交的Actions与上述代码运行分别记录。
