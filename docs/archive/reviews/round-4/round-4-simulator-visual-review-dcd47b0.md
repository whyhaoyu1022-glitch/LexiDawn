# Round 4 · dcd47b0 原图与原生界面复核

构建 `dcd47b0c7fa45590a79fb37c3b88ac2939afff89`，iOS 26.5 Simulator。21 张原 HEIC 和三张参考 JPEG 与同构建的 396 张 PNG 均核验文件。364 张来自通过的方法，32 张来自失败的方法；另按含有失败态的画面建立 52 项子集。全部 21 项均有同提交截图可对应。

[CI](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43328170620) · [原生附件与 PNG](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43328170620/artifacts/13997533326)。

| 原图要求 | 本次实际 PNG | 观察 |
|---|---|---|
| P01 | `R4-P01-today-system-portrait-iPhone18-1.png`（passed） | 只保留简短来源、标题自然换行。样本为本地原创。 |
| P02 | `R4-P02-actual-sources-iPhone18-1.png`（passed） | 同一发现任务实际检查 13 个来源，逐源显示成功和失败。 |
| P03 | `R4-P03-inventory-summary-system-portrait-iPhone18-1.png`（passed） | 今日改为一个文章库入口，库存计数为一条原文。 |
| P04 | `R4-P04-library-scopes-system-portrait-iPhone18-1.png`（passed） | 全量和筛选计数、四个范围均可见；导入后的去重及失败恢复方法尚未走完。 |
| P05 | `R4-P05-progress-system-portrait-iPhone18-1.png`（passed） | 显示当前来源、阶段、处理量与停止动作；画面由显式网络延迟夹具触发。 |
| P06 | `R4-P06-title-system-portrait-iPhone18-1.png`（passed） | 首屏完整七行长标题和第一段正文，另有十次旋转和三主题原生截图。 |
| P07 | `R4-P07-cleaned-structure-iPhone18-1.png`（passed） | 播放器提示从原创 HTML 去除，真实 JavaScript 讨论、有序列表及引用仍可见；旧 DW 独立占位有单元回归。 |
| P08 | `R4-P08-preflight-system-portrait-iPhone18-1.png`（passed） | 进入练习前提示缺义项，提供取消、延期、重试和个人补录。 |
| P09 | `R4-P09-restored-system-portrait-iPhone18-1.png`（passed） | 笔记重启恢复且没有强制保存按钮；users 词形另有真实词典单测。 |
| P10 | `R4-P10-real-MDX-connection-system-portrait-iPhone18-1.png`（passed） | 真实 MDX 的 nod 点头在浮窗与连线一致，成功匹配绘制实线。 |
| P11 | `R4-P11-mask-1-system-portrait-iPhone18-1.png`（passed） | 字母掩码与原句对齐，提交独立固定；另有不同掩码的原生截图。 |
| P12 | `R4-P12-complete-system-portrait-iPhone18-1.png`（passed） | 完成和延期数量可见，排程明细收起。 |
| P13 | `R3-X01-iPhone18-1.png`（passed） | 不同主题各用整卡渐变，标题、元数据和两个操作位于卡内。 |
| P14 | `R4-P14-contexts-system-portrait-iPhone18-1.png`（passed） | 一次来源、两条不同原句、无重复链接。 |
| P15 | `R4-P15-recommendation-detail-iPhone18-1.png`（passed） | 推荐直接进入共享的词典详情；阅读器关联词及关闭回原位的链路仍待完整复验。 |
| P16 | `R4-P16-need-detail-system-portrait-iPhone18-1.png`（passed） | need 的 MDX 真实英美 IPA、词性、义项与双语例句。 |
| P17 | `R4-P17-actual-recommendations-iPhone18-1.png`（passed） | 只显示词头、音标和短释义；已验证浏览与明确加入分开。 |
| P18 | `R4-P18-incorrect-system-portrait-iPhone18-1.png`（passed） | 当前题的输入和错误反馈一致，提交独立固定。 |
| P19 | `R4-P19-wrong-correction-system-portrait-iPhone18-1.png`（passed） | 答案和掩码一致，输入错误后仍等待用户亲自纠正并保留 Again。 |
| P20 | `R4-P20-about-system-portrait-iPhone18-1.png`（passed） | 关于显示 Why Haoyu、实际构建信息；设置自动保存另有实拍。 |
| P21 | `R4-P21-mdx-review-gloss-system-portrait-iPhone18-1.png`（passed） | 原词旁的小窗呈现两条含词性的真实 MDX 释义；大字号转屏仍有诊断图。 |

IMG_8884 对照词头、IPA 与名词／动词分组。IMG_8885 对照词形及双语例句。IMG_8886 对照短语、习语与底部操作。三张参考各自复核，屏幕内容以实际 MDX 收录为准。大字号转屏与嵌套返回未通过本次全流程。

对照包 173,401,882 字节，SHA-256 `6bdceaa20df8a3fd92a57a5a97b1b636d1f40f2a322b3f4c0ad7ffd178f11e08`。
