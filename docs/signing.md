# Windows、AltServer 与签名边界

本项目目标是先在 GitHub Actions macOS runner 完成模拟器测试和未签名构建。免费 Apple ID 的个人签名能力、有效期、设备数量和 AltStore/AltServer 兼容性必须以当前官方工具和实际安装结果验证；免费 Apple ID 不等同于 Apple Developer Program 会员。当前仓库没有证书、私钥、provisioning profile 或已安装 IPA 证据，因此未声称存在可安装 IPA。M9 需在有 macOS runner、Apple ID 和真实设备的条件下分别记录：构建产物、签名状态、安装结果和失败原因。
