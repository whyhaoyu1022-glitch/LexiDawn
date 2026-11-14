# 导出专项41432723597：启动失败与设备隔离

对应main `8c21befea90f22885f446b6bea4dd02078306843`，[运行41432723597](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41432723597)，[原始job日志](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41432723597/job/125235002755)。核查依据为GitHub job日志，不冒称Linux本地运行Simulator。

## 实际结果

- build-for-testing成功。
- 新增testVocabularyExportCallbackSurvivesPresentationDismissalAndRejectsOldRequest通过，1单元/0失败，0.025秒。证明注入的迟到回调、展示关闭、旧请求及取消状态保护；这是确定性回调夹具，不能替代真实系统Save证据。
- 原导出UI失败，1 UI/1失败，146.049秒。失败在Round3UITests.swift:19的launch()：`Timed out while launching application via Xcode.` 尚未进入导出页，没有执行本次真实取消/Save验证。
- 全量构建/单元、其他UI和最终截图合并均跳过，专项失败门禁有效。没有把排队、未运行或窗口消失记作成功。

## 本次修复及边界

原专项连续在同一设备运行app-hosted单元和UI；完整回归原本在不同job中隔离设备。本次只把专项也隔离：读取并保存单元设备JSON状态，Booted则正常shutdown，Shutdown则继续；未知或缺失设备必须报错。随后调用既有ci-simulator.sh创建、boot并等待全新具体UUID的iPhone 17 Pro，下一UI步骤通过GITHUB_ENV使用新UUID，继续复用同一份编译产物。

状态JSON与原有日志/xcresult/原始附件一起上传（主上传及重试均包含）。没有盲目忽略shutdown错误、卸载应用、清除全部设备、跳过启动失败或自动重跑失败UI。没有增加测试等待时间，也没有修改任何Swift、数据库、业务规则、旧测试或断言。

这是针对可观察的连续测试环境复用做的隔离整改。日志不足以唯一证明启动超时由设备复用引起，必须等新专项验证；若仍超时，新的原始日志和设备状态继续如实报告。不能声明之前的真实Save问题已经通过。

SPEC §9.2原文“支持导出词汇数据为 JSON 或”及下一行“CSV；导出内容应包含词条、释义、来源、复习状态和时间戳。”SPEC §30：“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”本次范围为现有导出验收的CI环境隔离，依赖既有模拟器脚本与共享xctestrun；验收仍要求真实文件名、44pt取消、取消无成功、JSON/CSV实际Save和完成反馈全通过。

## 已完成的本地检查

YAML解析、全部专项shell块bash -n、Python脚本AST、专项先单元后隔离再UI的顺序、仅两个only-testing选择器及全量成功依赖检查通过。使用临时命令替身执行实际隔离shell，验证Booted正常关闭并创建新设备、Shutdown直接创建、未知状态失败、设备缺失失败四分支；这些是工作流控制检查，不是CoreSimulator实测。ci-test-plan.py verify确认49主UI完整分组（11/12/13/13），SE7/大屏3。

源码186 XCTest/49 XCUITest、138截图要求保持。原93/20文件及本次全部Swift测试未改。新原生结果、完整截图包和统一验收仍待完成；本次使用[export-only]提交，仍先专项，两项成功才全量，失败即阻断。
