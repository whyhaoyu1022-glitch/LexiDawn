# 需求与证据追踪

每条需求以 P（反馈图）、F（功能）、A（验收项）和 T（测试族）为稳定编号。F01–F21 对应 21 张原图，F22–F24 对应三张词典参考和功能补充。

| 要查的数据 | 权威入口 |
|---|---|
| 功能、原图、原始批注与 144 条标准 | [反馈清单](reviews/round-4-feedback-manifest.json)、[Round 4 产品范围](plans/round-4-development-specification.md) |
| 每条验收的实现在何处、如何测试、是否独立通过 | [验收账本](reviews/round-4-acceptance-status.json) |
| 哪些候选测试实际通过、哪些 PNG 直接对应编号 | [4be478e 原生证据](reviews/round-4-native-evidence-4be478e.json) |
| 当前整体构建与下载 | [STATUS](../STATUS.md)、[交付报告](reviews/round-4-final-delivery.md) |

代码 **4be478e** 的兼容测试证据覆盖全部 24 个测试族。144 条均有候选方法通过，其中 79 条有直接编号截图。独立逐条验收仍开放。截图关联描述已有画面，手动检查结论将逐条写入验收账本。

| 功能 | 依据 | 测试族 | 条款数 | 有直接截图 |
|---|---|---|---:|---:|
| R4-F01 · 今日任务卡 | R4-P01 · IMG_8854.heic | R4-T01 | 5 | 2 |
| R4-F02 · 多来源文章发现 | R4-P02 · IMG_8857.heic | R4-T02 | 5 | 1 |
| R4-F03 · 今日库存与标题 | R4-P03 · IMG_8858.heic | R4-T03 | 5 | 2 |
| R4-F04 · 书库与筛选 | R4-P04 · IMG_8859.heic | R4-T04 | 5 | 3 |
| R4-F05 · 真实发现进度 | R4-P05 · IMG_8860.heic | R4-T05 | 5 | 4 |
| R4-F06 · 阅读标题 | R4-P06 · IMG_8862.heic | R4-T06 | 5 | 3 |
| R4-F07 · 正文结构 | R4-P07 · IMG_8863.heic | R4-T07 | 5 | 3 |
| R4-F08 · 复习预检 | R4-P08 · IMG_8864.heic | R4-T08 | 5 | 4 |
| R4-F09 · 词形与自动保存 | R4-P09 · IMG_8866.heic | R4-T09 | 6 | 3 |
| R4-F10 · 连线与语境 | R4-P10 · IMG_8867.heic | R4-T10 | 5 | 1 |
| R4-F11 · 稳定拼写掩码 | R4-P11 · IMG_8869.heic | R4-T11 | 5 | 2 |
| R4-F12 · 复习完成页 | R4-P12 · IMG_8870.heic | R4-T12 | 5 | 4 |
| R4-F13 · 探索卡片 | R4-P13 · IMG_8872.heic | R4-T13 | 5 | 3 |
| R4-F14 · 词汇上下文 | R4-P14 · IMG_8873.heic | R4-T14 | 5 | 3 |
| R4-F15 · 统一词典详情 | R4-P15 · IMG_8875.heic | R4-T15 | 5 | 2 |
| R4-F16 · 唯一 MDX 来源 | R4-P16 · IMG_8876.heic | R4-T16 | 6 | 4 |
| R4-F17 · 词汇推荐 | R4-P17 · IMG_8878.heic | R4-T17 | 5 | 4 |
| R4-F18 · 按题反馈 | R4-P18 · IMG_8879.heic | R4-T18 | 5 | 4 |
| R4-F19 · 揭示后纠正 | R4-P19 · IMG_8880.heic | R4-T19 | 5 | 3 |
| R4-F20 · 设置和关于 | R4-P20 · IMG_8881.heic | R4-T20 | 5 | 2 |
| R4-F21 · 阅读查词浮层 | R4-P21 · IMG_8883.heic | R4-T21 | 6 | 3 |
| R4-F22 · 完整详情排版 | R4-R01–R03 | R4-T22 | 12 | 8 |
| R4-F23 · 结构化个人词典 | R4-R01–R03 | R4-T23 | 12 | 7 |
| R4-F24 · 词义与复习闭环 | R4-R01–R03 | R4-T24 | 12 | 4 |

后续验收从账本定位具体条款，再核对实际运行、原图和对应代码。记录构建、设备、环境、判断依据与结论。测试未覆盖的实机操作按[测试计划](test-plan.md#真机验收)补证。历史编号与先前结果见[旧追踪表](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/6054b03932e036ab3205488ed9e5af60fa7495fa/docs/requirements-traceability.md)。
