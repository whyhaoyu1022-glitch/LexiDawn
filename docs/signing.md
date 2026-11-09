# LexiDawn 未签名 IPA 与 AltServer 真机安装

Round 4 要求完成完整测试并导出未签名 IPA；打包与测试证据分别报告。未签名包不能直接点开安装；AltServer 会在你的电脑上使用你自己的 Apple 账户签名，再安装到手机。项目和 Actions 不保存你的账户、密码、证书或设备 UDID。

## 打包配置

- 显示名称：`LexiDawn`，Bundle ID：`com.lexidawn.app`，版本：`0.1.0`；build 使用本次打包 workflow 的 run number。
- 真机 `iphoneos` / `arm64` / Release；不是模拟器 `.app`。当前产品及打包最低 iOS 27.0。CI 的 iOS 26.5 仅为兼容验证；Xcode 26.6/SDK26.5 构建不等于 iOS27 真机验收。此前 iOS26.0 IPA 属于历史产物，不适用于当前包。
- `LexiDawn/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`：不透明1024×1024方形源图，使用Xcode资源编译生成各尺寸。不烘焙圆角、不加文字。原概念图在仓库中已截断，见 `assets/AppIcon-design.md`。
- 不带 provisioning profile、证书或代码签名；若链接器产生ad-hoc签名，只在暂存副本移除。打包校验实际Info.plist、arm64/iOS Mach-O、图标、无测试包、ZIP CRC和SHA256；`build-manifest.json`明确signed=false、installedOnDevice=false、testsRerun=false。
- `[ipa-only]`提交只触发 `Unsigned iPhone IPA` 打包任务；原全量CI的构建关卡在此标记下跳过，其余完整测试配置保持。手动打包也可在Actions选择该workflow的Run workflow。

构建必须实际验证 App/IPA 中的完整 BundledDictionary.mdx 与指定 SHA，禁止仅打入分块 ZIP。成功 iOS CI 会触发同一提交的未签名真机 Release 打包，失败不会宣称产物可用。

## 电脑准备

从官方 https://altstore.io/ 下载最新版 **AltServer**。官网将AltStore Classic和AltStore PAL分开，当前使用的是AltServer/Classic路线。

Windows：按官方Windows安装指南安装Apple官网版本的iTunes和iCloud，再安装AltServer，首次以管理员方式启动；系统托盘出现AltServer图标。iCloud的Microsoft Store版本需要官方故障指南中的额外步骤，不混用安装方式。当前官方发布记录指出Windows1.7.4修复了iOS26.4启动崩溃，使用官网当前最新版。

macOS：下载后把AltServer.app拖入Applications并运行，顶部菜单栏出现图标。当前版本不要求旧版Mail插件，不照搬旧教程。

用数据线连接iPhone，解锁手机。在手机点“信任此电脑”，输入锁屏密码；电脑端也确认信任。先确保Finder（Mac）或iTunes（Windows）能识别手机。第一次安装建议保持USB连接。

## 方法一：直接用AltServer签名安装本IPA

1. 下载 `LexiDawn-unsigned.ipa` 到电脑。若从Actions下载的是ZIP，先解压外层artifact ZIP，保留里面的`.ipa`文件；不要把IPA继续解压。
2. Windows按住 **Shift**，再点击系统托盘的AltServer图标；Mac按住 **Option（⌥）**，再点击菜单栏AltServer图标。
3. 选择 **Sideload .ipa…**，选择你的iPhone和下载的`LexiDawn-unsigned.ipa`，按实际对话框顺序操作。
4. 在本机AltServer对话框输入你的Apple账户和密码，按提示处理验证。无需付费开发者会员。不要把密码或验证码发给开发代理，也不要放进GitHub Secrets。
5. 等待签名和传输完成，保持电脑联网、手机解锁并连接USB。AltServer成功通知后，手机桌面应出现 **LexiDawn**。
6. 手机上到“设置 → 通用 → VPN与设备管理”，找到对应Apple账户的开发者项目，按系统提示信任。不同系统中文文字可能稍有变化。
7. 到“设置 → 隐私与安全性 → 开发者模式”，开启并按提示重启、确认。该菜单可能在首次开发签名安装后才出现。
8. 打开LexiDawn开始真机测试。首次重点检查桌面图标、文章发现/本地全文、点词、生词保存、复习、横屏和重启恢复。

免费账户直接通过AltServer侧载的App通常需要每7天重新签名安装。到期前用同一Apple账户、同一个包身份覆盖安装，通常保留应用数据；不要先删除App，删除会移除本地学习数据。签名完成并不等于已经验证本App在你的具体手机上运行成功。

## 方法二：AltStore Classic管理刷新（适合后续持续测试）

1. 电脑AltServer菜单选 **Install AltStore → 你的iPhone**，在电脑输入Apple账户完成安装；按上述步骤信任并开启开发者模式。
2. 把IPA保存到手机“文件”App，打开手机AltStore Classic，在Settings中登录同一Apple账户。
3. 保持AltServer在电脑运行，手机通过USB连接，或两者在可互相发现的同一Wi-Fi。打开My Apps，点“+”导入IPA（也可从文件的分享菜单交给AltStore）。
4. 在My Apps中确认LexiDawn安装与剩余时间，用Refresh All续签。免费账户通常7天到期，同时激活的侧载App数量有限（官方说明为3个，AltStore自身也占用一个位置）。
5. 如需Wi-Fi刷新，Mac Finder勾选“在Wi-Fi上显示此iPhone”；Windows iTunes打开Wi-Fi同步，允许AltServer通过专用网络防火墙。初次连接失败先回到USB。

## 常见问题

- **找不到设备/AltServer**：手机解锁、两端信任、换可传输数据的线，确认Finder/iTunes看得到设备；使用USB排除Wi-Fi隔离。
- **无法验证App/开发者不受信任**：检查VPN与设备管理和开发者模式，保持手机联网；不要尝试直接安装未签名IPA。
- **系统版本不符**：当前包最低 iOS27.0。低于该版本不能只改IPA的MinimumOSVersion文本绕过；需要重新进行兼容构建。
- **免费账户App名额/证书限制**：按AltServer显示的真实错误处理；要移除其他App时先备份其数据，不能为了安装词光随意删数据。
- **7天后打不开**：用同一账户刷新/覆盖重签，保留已有App，不先卸载。
- **Windows新系统安装后闪退**：先更新官方AltServer；官方Windows1.7.4包含iOS26.4签名相关修复。词光自身崩溃则保留设备系统版本、机型和崩溃日志再定位。

## 官方依据（2026-11-05核对）

- 下载：https://altstore.io/
- 直接安装、Shift/Option及7天重装：https://faq.altstore.io/release-notes/altserver
- Windows安装：https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
- macOS安装：https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos
- 刷新/有效期：https://faq.altstore.io/altstore-classic/your-altstore
- 连接与故障：https://faq.altstore.io/altstore-classic/troubleshooting-guide

SPEC §17.2：“不使用透明背景。”、“在 Xcode Asset Catalog 中按目标 SDK 要求配置 AppIcon”；§22.7：“不能在未签名或签名无效时上传一个被标记为可安装的产物。”本次遵循负责人明确的未签名交付指示，包名与manifest都标明unsigned；签名及真实安装留给用户自己的AltServer完成。
