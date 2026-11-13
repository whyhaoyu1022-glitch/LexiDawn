# Round 4 · 1859403 原图与模拟器画面对照

在 iOS 26.5 Simulator 的同一构建中逐一打开了上传的 21 张原图与对应运行画面，并对照三张词典参考图。原图、参考图与 375 张原生 PNG 的字节和 SHA-256 已验证。364 张来自通过的方法，11 张来自失败的方法；ZIP 的失败目录另外包含通过方法中有意验证的错误状态。

[全量运行 43409540624](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43409540624) · [原生 PNG 与索引](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43409540624/artifacts/14031552586)。

| 编号 | 原件 | 同构建原生 PNG | 实际观察 |
|---|---|---|---|
| P01 | `IMG_8854.heic` | `R4-P01-today-system-portrait-iPhone18-1.png` (passed) | 今日卡只留来源和任务信息，原图划掉的长技术说明已移除。样本为本地原创文章。 |
| P02 | `IMG_8857.heic` | `R4-P02-actual-sources-iPhone18-1.png` (failed) | 发现入口使用明确动词，显示真实 13 个来源检查和 30 篇完整导入。截图拍摄在 BBC 后续筛选失败前。来源测试仅完成 Wikipedia、Wikinews 的首、中、末。 |
| P03 | `IMG_8858.heic` | `R4-P03-inventory-summary-system-portrait-iPhone18-1.png` (passed) | 今日改成带总量的单个书库入口，屏幕下方不再逐篇重复库存。 |
| P04 | `IMG_8859.heic` | `R4-P04-library-scopes-system-portrait-iPhone18-1.png` (passed) | 总量和筛选量可见，四个范围在同一行。搜索命中、空结果、收藏和稍后持久化有独立截图。 |
| P05 | `IMG_8860.heic` | `R4-P05-progress-system-portrait-iPhone18-1.png` (passed) | 显示正在处理的来源、阶段、来源计数与停止动作。此帧使用明确注入的延迟网络。 |
| P06 | `IMG_8862.heic` | `R4-P06-title-system-portrait-iPhone18-1.png` (passed) | 长标题自然排成多行，作者与来源在标题下，正文仍可滚动。 |
| P07 | `IMG_8863.heic` | `R4-P07-cleaned-structure-iPhone18-1.png` (passed) | 引用、编号列表与正常段落清楚。讨论 JavaScript 的正文保留。另有旧 DW 播放器定向截图。 |
| P08 | `IMG_8864.heic` | `R4-P08-preflight-system-portrait-iPhone18-1.png` (passed) | 未进练习即给出失败原因与取消、延期、重试、个人补录入口。本帧为无中文可补录状态。 |
| P09 | `IMG_8866.heic` | `R4-P09-restored-system-portrait-iPhone18-1.png` (passed) | 自动保存的个人笔记在重启后显示，页面无强制保存按钮。users 原形与 user 词头由另项测试覆盖。 |
| P10 | `IMG_8867.heic` | `R4-P10-real-MDX-connection-system-portrait-iPhone18-1.png` (passed) | 可见词头与中文之间的实际曲线，数字和勾标明关联。真实 MDX 浮窗与同一语境的答案一致。 |
| P11 | `IMG_8869.heic` | `R4-P11-mask-1-system-portrait-iPhone18-1.png` (passed) | 当前掩码位于词中，固定提交区可见。其他位置和重启不变需配套截图及数据测试。 |
| P12 | `IMG_8870.heic` | `R4-P12-complete-system-portrait-iPhone18-1.png` (passed) | 完成和延期数量在主区域，逐词排程位于可折叠的复习记录。 |
| P13 | `IMG_8872.heic` | `R3-X01-iPhone18-1.png` (passed) | 每篇文章使用独立整张渐变卡，标题与操作同卡，主题有不同色彩。此帧为个人原文。 |
| P14 | `IMG_8873.heic` | `R4-P14-contexts-system-portrait-iPhone18-1.png` (passed) | 同一来源只出现一次，两条原句仍独立可读，无重复 URL。 |
| P15 | `IMG_8875.heic` | `R4-P15-recommendation-detail-iPhone18-1.png` (passed) | 生词与查词使用共享原生详情，直接展示词头、IPA 和编号义项。关联词导航及关闭回原文有独立截图。 |
| P16 | `IMG_8876.heic` | `R4-P16-need-detail-system-portrait-iPhone18-1.png` (passed) | need 显示来自内置 MDX 的 IPA、明确词性、真实中文及成对例句。 |
| P17 | `IMG_8878.heic` | `R4-P17-actual-recommendations-iPhone18-1.png` (passed) | 卡片显示词头、IPA、简短中文。截图上方仍有其他推荐的短时查词提示，浏览与加入由测试分别核验。 |
| P18 | `IMG_8879.heic` | `R4-P18-incorrect-system-portrait-iPhone18-1.png` (passed) | 当前题的错误提示与当前输入对应，底部操作独立，画面无上题成功提示。 |
| P19 | `IMG_8880.heic` | `R4-P19-wrong-correction-system-portrait-iPhone18-1.png` (passed) | 揭示后保留原题，错误输入仍在，Again 提示可见；另有亲自纠正后换题的截图。 |
| P20 | `IMG_8881.heic` | `R4-P20-about-system-portrait-iPhone18-1.png` (passed) | 关于页实际显示 Why Haoyu、0.1.0、当前模拟器构建号。自动保存画面另有索引。 |
| P21 | `IMG_8883.heic` | `R4-P21-mdx-review-gloss-system-portrait-iPhone18-1.png` (passed) | 浮窗靠近词并保留原文，两条中文释义有词性、真实 IPA、已加入状态和详情箭头。关闭恢复原词偏移有独立截图。 |

## 三张词典参考

| 参考 | 同构建实拍 | 观察 |
|---|---|---|
| IMG_8884 | `R4-F22-real-top-system-portrait-iPhone18-1.png` | 衬线词头、英美 IPA、发音按钮、A/B 词性和编号义项可见，英文例句与中译逐条排列。 |
| IMG_8885 | `R4-F22-real-middle-system-portrait-iPhone18-1.png` | 文件与首屏字节相同。词性标题已在首屏可点击，旧截图步骤因此没有滚动。三主题也有相同现象。新的复验将先把动词标题置于上半区，并确认词头已滚出。 |
| IMG_8886 | `R4-F22-real-phrases-system-portrait-iPhone18-1.png` | 能看到后续义项、双语例句、单独的短语动词区和不遮正文的底部操作。三主题末段截图另有实际内置来源与底部控件。 |

全量结果为 236/236 XCTest、70/75 XCUITest。138 个历史截图状态和设备专项齐全；逐源门禁只完成两家来源，要求至少五家，故仍失败。未签名 IPA 0.1.0（176）已独立核验，目标最低 iOS 27.0，实际原生测试为 iOS 26.5 Simulator。
