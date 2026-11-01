# Round 3 · CI 41326351407 导出修复核查

核查代码 main `0126709082265a3b2648b502772df889488c4b9f`，[运行41326351407](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41326351407) 整体失败。本次新代码尚未原生运行，不作通过声明。

## 已核验结果

- Debug/Release成功，180 XCTest/0失败；真实10源29篇完整文章导入。
- SE7/0，大屏3/0。主full-4为13/1失败；唯一已发现的断言失败是 `testVocabularyStatusSortConfirmedMeaningAndNativeExportDialogs` 第一次JSON导出找不到文件名。
- 前次嵌套关闭、嵌套来源语境、阅读外观、重置取消/确认已经分别通过；full-2已输出12/0，但job因fail-fast取消，不能称整组关卡成功。
- 其他主组被取消，不能将其未执行方法算作通过；截图合并仍因缺少状态失败，134项要求保留。

## 现场与诊断边界

[原始full-4 artifact 13092665953](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41326351407/artifacts/13092665953)：失败AX `014CCA42-02F4-4277-B976-EB5FC8DFDDD1.txt` 显示原生文件控制器、Browse/Save和On My iPhone，但没有文件名控件。录像 `18C87990-135C-43C4-88BB-C3675A7A5780.mp4` 显示导出后白屏；录像帧仅用于诊断，不能作为交付PNG。原断言失败在文件名出现前，并非之前的Cancel定位分支。

日志不足以将故障唯一归因于SwiftUI或系统文件服务。旧链路在菜单动作中同时改变可选FileDocument、格式与呈现状态，本次消除这一可变文档传递路径，保留真实文件名断言并重新跑原生流程，不用延时/空控件掩盖问题。

## 实际修改

1. `VocabularyExportFileService` 先取得Repository真实JSON/CSV快照，在每次独立UUID临时目录中原子写入准确扩展名文件，只有写入成功才返回导出请求；空数据和磁盘错误直接抛出。
2. 使用公开 `UIDocumentPickerViewController(forExporting:asCopy:)` 接收已经存在的不可变文件，并显示扩展名；不需要可选FileDocument状态。取消/完成后由sheet关闭清理本次目录；系统复制的用户目标文件不清理，不修改学习库。失败不显示成功。
3. 清理校验UUID及暂存根目录，只清理本次请求，重复清理安全；不允许误删其他目录。应用被系统强杀留下的文件属于系统临时目录，不能冒称已经执行取消清理。
4. UI保留原JSON/CSV文件名断言及两种原生截图，先断言系统文件导航栏存在；取消手势只作用于现场观察到的文件导航栏，随后还必须断言其消失，不能因为背景生词本仍在AX中而误判关闭成功。
5. 新增两项确定性XCTest：真实Repository JSON/CSV字节与暂存文件逐字节一致、独立目录和清理/重试/核心数据保留；写入失败/空内容不返回文件，保护既有文件并安全重试。原93单元与20UI不修改。本次源码182 XCTest/49 UI（新增测试尚未执行）。

## SPEC依据、范围与验收

SPEC §9.2逐字原文：“支持导出词汇数据为 JSON 或”及下一行“CSV；导出内容应包含词条、释义、来源、复习状态和时间戳。” §30：“**缓存清理不伤核心数据**：普通清理不删除生词本、复习日志和任务状态。”及“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”

范围只涉及现有导出文件交接及清理、对应回归，不改变数据库schema、复习答案、学习门禁或来源策略。Repository仍提供真实快照，文件Service管理暂存，原生UI只负责用户选择保存位置。

公开API依据：[Apple导出/复制初始化方法](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(forexporting:ascopy:))、[Apple文档选择器与扩展名/Delegate](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller)。不使用私有API。

本地Linux无Swift/Xcode，只执行静态差异、Python/YAML/Shell与方法完整分组检查。新182单元、49主UI、SE7/大屏3及完整PNG/CSV/manifest/xcresult必须由新main CI复验。仅剩CI运行时按负责人持续授权停止，不轮询等待、不提前宣称完整验收。
