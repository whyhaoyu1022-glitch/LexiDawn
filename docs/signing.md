# iPhone 安装与签名

## 准备

- 从[当前状态](../STATUS.md)下载最新未签名 IPA 的 Actions ZIP，解压外层 ZIP，取出 `LexiDawn-unsigned.ipa`。签名工具使用完整 IPA 文件。
- 本应用 IPA 面向 arm64 iPhone，最低 iOS 27.0，Bundle ID 为 `com.lexidawn.app`。版本、提交与哈希以 ZIP 中的 `build-manifest.json` 和 `SHA256SUMS.txt` 为准。
- 从官方下载安装 AltServer。Windows 的依赖、设备连接和 Wi-Fi 同步步骤以官方安装页为准。[macOS](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos) · [Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)

## 使用 AltServer 安装

1. 通过 USB 接上 iPhone，解锁并信任电脑。确认 Finder 或 Windows 的 Apple 设备工具可以识别它。
2. macOS 按住 **Option**、Windows 按住 **Shift**，点击 AltServer 图标。选择 **Sideload .ipa…**，再选择 iPhone 和 IPA。[AltServer 说明](https://faq.altstore.io/release-notes/altserver)
3. 在本机签名界面登录你的 Apple 账户，按提示完成验证。账户、密码与验证码只在本机操作。
4. 如系统提示，在「设置 → 通用 → VPN 与设备管理」信任开发者。进入「设置 → 隐私与安全性 → 开发者模式」启用、重启并确认。[Apple 开发者模式说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
5. 打开词光，在「关于」确认版本和构建。按[真机检查项](test-plan.md#真机验收)记录结果。

以后可在 AltStore Classic 的 My Apps 用加号导入 IPA，或用 Refresh All 续签。个人免费签名通常七天到期，按页面显示的有效期操作。续签时保留 App，使用同一账户及包身份覆盖安装，以保留设备学习数据。[AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore)

## 验证已有 IPA

下载后用外层 ZIP 内的 `SHA256SUMS.txt` 核对 IPA。在仓库根目录运行下列命令，验证 IPA 内包含的完整 MDX。

```sh
python3 scripts/verify-bundled-dictionary.py --ipa /path/to/LexiDawn-unsigned.ipa
```

构建核验检查实际 Info.plist、arm64 Mach-O、图标与签名状态，以及内置 MDX 的大小和 SHA。iOS 26.5 Simulator 结果与 iOS 27 真机安装记录分别保存。
