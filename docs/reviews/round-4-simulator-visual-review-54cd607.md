# Round 4 · 54cd607 原生截图复核

本次复核使用同一提交的 [Simulator 原始截图](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43233166087/artifacts/13961012885) 和 [21 张原图的逐项复核](round-4-original-image-recheck-2026-11-11.md)。255 张 PNG 的 SHA 与图片格式均核验。190 张来自通过的方法，65 张来自失败的方法。对照包保留 21 张 HEIC、三张 JPEG、255 张原始 PNG、失败子集及逐图索引。对照包 SHA-256 为 `9d8e9ce6e3dccfe98ea4efb5b0e870170ed6bb56c491ffc881bb5d1c7761798a`。

| 范围 | 实际观察 | 当前整改 |
|---|---|---|
| P02、P04、P05 | `R4-P02-actual-sources` 显示 13 个实际来源均已处理，有导入、连接失败和无法获取完整原文三类结果。`R3-legacy-round2-unreachable-testGalleryRealRFCLicenseExpiryBackoffAndOverdue` 中备用技术文档已展开，官方刷新可见，旧测试没有取得可点击按钮。 | RFC 保持次级入口，展开后作为独立列表按钮；回归从当前筛选查找可触达的阅读入口。无结果使用一个完整的辅助功能元素。 |
| P10 | `R3-M05` 可见绿线与紫色虚线，`R3-M06` 的两条线在转屏后仍对齐。两组为显式个人数据夹具；后续展开三条连接的像素断言失败。 | 像素抽样取左右按钮实际间隙，覆盖多个线色。作答同时核验当前右侧选项与义项，个人义项显式标记。已追加真实 MDX 浮窗与连线的原生回归。 |
| P14 | `R4-P14-contexts` 显示一份来源和两句不同原文，方法通过。 | 同源语境归组已有本次真实截图。 |
| P15、F22 | `R4-F22-real-top` 有真实词头、英美 IPA、名词／动词及配对双语例句。`R4-diagnostic-testActualBundledMDXDetailAndSystemPronunciation` 实际显示 `nod off`，测试在辅助功能中同时发现下层 `nod`，退出恢复步骤未执行。 | 详情呈现时隐藏下层辅助功能，保留原文语境短语入口和返回操作。 |
| P21 | `R4-diagnostic-testActualMDXReferenceLayoutThreeThemesLandscapeAndAccessibilityFont` 的超大字号浮窗落在屏幕底部，可见中文义项，但关闭和详情按钮区域未显示。 | 点击位于屏幕下半部时向上展开。释义区独立滚动，操作栏保持可达；原生测试显式断言详情按钮可点击。 |

这些图片属于 `54cd607`。本次改动的实际结果需要新提交的原生运行。上一版最新运行仍缺 46 个界面场景、8 个设备场景；当前验收状态以逐项清单为准。
