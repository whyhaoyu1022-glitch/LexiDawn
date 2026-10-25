# 当前状态

- 当前里程碑：M0（进行中，等待 macOS runner 验收）
- 已完成需求：GOV-001；M0-001、M0-002、M0-003、ENG-M0-XCODE、ENG-M0-DESIGN、ENG-M0-TEST、ENG-M0-CI 已实现待验收
- 未完成需求：M0-004、M0-005（规格中未映射）；M1–M9 全部未开始
- 阻塞项：当前容器无 Xcode/macOS，无法本地运行 iOS 构建或设备验收；用户已明确批准 CI 使用 iOS 26.5 兼容目标，工程产品配置仍保持 iOS 27.0。
- 最近代码修复 commit SHA：a069ee5cbc372b21dc6e9ec8d471fc0ed5f9afec
- 最近 CI workflow commit SHA：2f2fb6ba5d3228433a84547a73c85e4bc8d86e1b
- 最近失败 Actions：run 40183884530，job 121140467210；构建已通过，测试因未指定具体模拟器失败：Tests must be run on a concrete device。
- 修复：CI 现在动态选择并启动可用 iOS Simulator，使用 -destination id=... 执行单元测试和 UI 测试。
- 最近一次本地测试：未运行；容器没有 swift/Xcode。
- 下一批目标：检查新的 Actions 构建、具体模拟器测试和测试报告；若仍失败，按新的真实日志继续修复。
