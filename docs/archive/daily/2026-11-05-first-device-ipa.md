# 首次真机IPA导出记录

## 2026-11-05 · 首次真机未签名IPA打包（构建结果待原生任务）

负责人授权仅导出未签名IPA，不重跑全量。核查发现原概念PNG IDAT截断/无IEND，保留原文件，按SPEC原品牌方向重建1024不透明AppIcon并接入资源编译；显示名称保持LexiDawn。新增独立iphoneos/arm64 Release打包及实际包校验，最低系统在命令中覆盖为26.0，项目原27.0目标不改；如低版本API不兼容必须由真实编译报错，不伪改IPA绕过。打包提交用[ipa-only]跳过原全量构建/测试，只产出unsigned包、manifest/SHA/日志及AltServer安装指南。Swift业务和全部旧测试不修改；尚未签名、尚未安装、构建结果待本次任务。

静态已执行：原概念图字节/PNG分块核查，新图1024RGB/完整解压/CRC验证，pbx资源引用、独立工作流门禁、Bash/Python/YAML语法。未运行XCTest、XCUITest、模拟器或签名；原生打包结果待当前main任务。按负责人明确授权在打包命令覆盖最低系统，并避免触发全量。

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。
