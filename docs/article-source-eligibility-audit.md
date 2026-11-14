# 文章来源审查与实测结果

源码登记 13 个公开正文尝试来源。导入时保存来源级依据，区分经审核的文章来源资格、负责人个人使用路径和用户自有原文。原站访问、抓取结果与准入记录分别判断。[来源登记](../LexiDawn/Domain/Learning/PublisherSources.swift) · [完整原文规则](spec-addendum-content-and-dictionary.md)

## Round 4 已观察结果

[最终运行 43420154858](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43420154858) 针对以下十家都有实际来源筛选、首屏正文、滚动和阅读末段截图。

| 取得完整阅读证据 | 实际获取方式 |
|---|---|
| BBC News、The Guardian、NPR、DW、VOA Learning English | 公开 Feed 发现并提取对应网站正文 |
| NASA、ScienceDaily、Phys.org | 公开 Feed 发现并提取对应网站正文 |
| Wikipedia、Wikinews | 官方入口取完整内容，保留修订和归因 |

Reuters、AP News、Smithsonian Magazine 在源码登记中，本轮没有完整的逐源阅读截图序列。随附 RFC 8890 是独立的本地示例，不纳入十家实时来源。各来源可用性会变化。运行故障测试另用明确注入的超时、限流、解析及写入错误，采用真实网页时会注明。

## 历史来源审查

各站点的来源调查、当时的条款页面和实测失败保存在[整理前审查记录](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/6054b03932e036ab3205488ed9e5af60fa7495fa/docs/article-source-eligibility-audit.md)。早期 pending/disabled 结论适用于对应日期和审查路径。当前准入请结合源码和本轮实际结果。
