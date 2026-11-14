# Round 3 · 导出安全区域与专项CI（41423920944）

负责人要求优先单独验证导出，能用后再跑全量；若仍无法解决，可不再为这个次要功能反复耗费全量CI。本次按此新指示实施专项先行，不把功能删掉或声明已通过。

## 已核查的事实

main `80ffd4446b665968eac2101ad51c74f9e8b6a829` 的[运行41423920944](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41423920944)：Debug/Release、185单元/0失败，Free真实book本次也通过；主full-2 12/0、full-3 13/0；SE/大屏job成功。full-4 13/1失败，full-1取消，合并核查时尚未完成，不能声称全量通过。

这次失败已经不是文件名：日志中 `vocabulary-export-filename` 精确为 `LexiDawn-vocabulary.json`。随后点击cancel-vocabulary-export，XCTest记录 `Computed hit point {-1, -1} after scrolling to visible`；失败AX给出的按钮frame为x352/y27/宽34/高20.3，位于状态栏区域，系统文件窗口因此没有消失，10秒等待超时。

前几次修改对文件名传递及系统控件的判断不够充分。本次使用日志中的实际点击点和布局frame定位，不把新超时继续归咎于文件名。原始[full-4 artifact 13133286113](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41423920944/artifacts/13133286113)可用于复核；本次直接核对了保留于job日志的AX和事件，没有冒称本地Simulator执行。

## 产品修复

导出使用单一UIKit父容器，标题/真实文件名和取消按钮约束到父控制器safeAreaLayoutGuide。原生文档选择器按addChild/didMove方式嵌入，位于头部下面，不再由SwiftUI VStack与原生远端控制器混合决定头部全局原点。取消按钮至少44pt高、60pt宽，动态字体支持，未硬编码状态栏高度或用坐标点击绕过问题。

原文件内容、原子暂存、按请求清理、实际保存回调和过期请求保护保留。原导出UI新增取消按钮真实可点击和44pt高度断言，仍检查取消后窗口消失、没有成功提示、JSON/CSV实际Save及回调，不删失败断言。

公开API依据：[Apple addChild](https://developer.apple.com/documentation/uikit/uiviewcontroller/addchild(_:))、[Apple didMove](https://developer.apple.com/documentation/uikit/uiviewcontroller/didmove(toparent:))。SPEC §9.2原文“支持导出词汇数据为 JSON 或”及下一行“CSV；导出内容应包含词条、释义、来源、复习状态和时间戳。”本次只调整既有导出呈现和验证，不涉及数据模型或学习规则。

## 专项CI：先一项，成功才全量

现有iOS CI增加export-check前置job。带 `[export-only]` 的main push或手动Run workflow选择scope=export时，先只执行 `testVocabularyStatusSortConfirmedMeaningAndNativeExportDialogs` 一个UI方法；不会先跑单元、真实外网、Release或其他UI。编译测试target是执行该原生UI的必要准备，不等于执行其余测试。

- 专项失败或取消：全量build-and-test和下游UI/合并不运行。
- 专项成功：自动开始原有Debug/Release、185单元、49主UI、SE/大屏及138状态证据验证。
- 普通push或scope=full：export-check跳过，原完整验证照常运行。
- 专项保留独立原始PNG、AX、构建/UI日志及xcresult，artifact名LexiDawn-export-check-runID-attempt；上传有上限重试，最终失败仍红。专项产物不混作完整截图包。

未设置永久跳过导出，也未把专项绿色称作全量通过。若本次专项仍因平台问题失败，先基于该单项证据判断是否按负责人授权停止继续修复；不自动反复跑全量。

## 验证及剩余

本地Linux无Xcode。静态检查了YAML、单selector、依赖条件（success/skipped才进入full）、Python/Shell、49方法穷尽分组和旧93/20文件保留；不能将其称作原生通过。本次专项仍待新main运行。完成独立工作后按持续授权结束对话，不轮询CI；专项通过后的全量可能因runner排队相差十几分钟，按真实状态记录。
