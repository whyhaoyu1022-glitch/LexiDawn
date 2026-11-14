# 2026-11-11 · Round 4 原图与原生复验

本批依据负责人“逐张图片，逐张原图进行对照”和“美观、简洁、实用”的指示。P02/P05 显示每个来源的实际检查或入库结果。P03 保留原始标题，展示时修正 ScienceDaily 重复编码的撇号。P07 按结构保留标题、引用、列表和有用图注，旧 DW 固定播放器提示按完整独立段落处理，阅读进度仍定位原正文。P10/P16/P17 词形与语境参与可靠义项排序。P14 将同来源上下文归组，保留各句。P15/F22 的共享阅读布局收起已保存个人义项的编辑控件。P21 在参考胶囊内分别提供返回与关闭，退出后检查原文词位置。

提交 `524d1ad` 的[原生运行](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236272)已通过 Debug 全目标和 Release Simulator 构建。235 项 XCTest 全部通过，包括 27 项真实词典/边界测试和 15 项文章网络测试。大屏 3/3 通过，小屏 3/7 通过。小屏四处失败涉及搜索空状态、实时文章词义资格、已完成连线滚动与保存重试。当前源码 236 项 XCTest、63 项 XCUITest，以上运行数字对应前一提交。

独立核验的[未签名 IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43034236319/artifacts/13863316237)为 0.1.0(29)，arm64、最低 iOS 27.0，文件 43,822,877 字节。实际包内 MDX 为 38,774,534 字节，指定 SHA-256 一致。原生 UI 在 iOS 26.5 Simulator 运行。

详见[持续交付记录](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/6054b03932e036ab3205488ed9e5af60fa7495fa/docs/reviews/round-4-final-delivery.md)。
