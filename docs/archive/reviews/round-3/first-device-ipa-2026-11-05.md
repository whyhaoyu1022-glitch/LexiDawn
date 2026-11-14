# 首次真机未签名IPA交付 · 2026-11-05

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。


## 下载

[原始打包artifact](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248/artifacts/13413974126)含IPA、构建日志、build-manifest.json、SHA256SUMS及INSTALL-AltServer.md。外层artifact ZIP解压后取`LexiDawn-unsigned.ipa`，不要继续解压IPA。产物到期时间2027-02-03，请下载留存。

## 图标与范围

原概念文件的IDAT实际截断且无IEND；按用户适配授权保留原件，内置imagegen按SPEC原品牌方向重建书/金色日出/深蓝背景，1024RGB AppIcon已接入Xcode资源编译。主图及完整提示见[处理记录](../../../../assets/AppIcon-design.md)。保持LexiDawn显示名称及Bundle ID com.lexidawn.app。

所有Swift业务和既有测试均未修改；本次不声称运行了全量回归。此前通过的186单元/49主UI结果仍属于b13d6b4，不能冒充本次真机安装通过。SDK实际支持26.0最低目标，命令级覆盖不改SPEC原27.0目标。

## 未签名状态与真机边界

本IPA是真实iPhoneOS arm64 Release，不是模拟器包。没有embedded.mobileprovision、_CodeSignature和主可执行文件LC_CODE_SIGNATURE；只能交给用户本机AltServer签名后安装。尚未获取用户机型、系统、Apple账户或实际安装/运行证据，manifest如实标明未安装。手机至少iOS26.0。

构建有既有两处PBX重复组成员警告、无AppIntents元数据提示及iPad方向/全屏声明警告；均非构建错误，本次不为消除警告改动业务或重新全量。IPA未显式设置方向数组；Apple UIKit官方说明缺省时iPhone支持除倒置竖屏以外方向、iPad支持全部方向：https://developer.apple.com/documentation/uikit/uiapplication/supportedinterfaceorientations(for:) 。实际手机布局和旋转仍在第一次测试中确认。

## 安装与保护数据

[完整AltServer步骤](../../../signing.md)：Windows Shift或Mac Option点击AltServer → Sideload .ipa… → 选择本IPA/手机 → 用户在自己的电脑输入Apple账户 → 签名安装 → 手机信任开发者及开启开发者模式。免费账户通常7天重签；用同账户覆盖安装，不先删除App，避免删除本地学习数据。也可安装AltStore Classic，通过My Apps/+导入并Refresh All。

本次源码提交39c5f7056644972ca0030a1cb041400a08d52c3c；后续仅结果文档回填用[skip ci]，不重新打包或重跑测试。可下载的IPA和manifest均锁定上述构建提交。
