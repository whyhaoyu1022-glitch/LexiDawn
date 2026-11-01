# CURRENT · ArticleSourceEligibilityAudit · 2026-11-01

负责人特别指示允许个人使用场景尝试公开官网完整正文。实现把 `owner-directed-personal-use-2026-11-01` / `personal-full-text` 与出版社授权的 `audited-full-text` 分开；用户指令不是出版社许可。**当前运行会尝试下述公开官网，下面历史许可表的 pending/disabled 仅指未经审核授权模式，不代表个人模式没有尝试。** 登录/验证码/付费墙/403 不绕过，不提供摘要或原站阅读。

## 真实运行结果

代码 `d37b9aa65aebd6bc010de57294ee243c1a95d825` 的 [Actions 41295662878](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41295662878) 真实来源测试通过，10 源共 29 篇通过 Repository 全文准入；后续 `c96015a` 的第一次运行真实文章测试也通过，Free Dictionary 单独失败，整次不算通过。

| 官方来源适配器 | 运行准入方式 | 已观察真实结果 |
|---|---|---|
| BBC News | 公开官方 Feed → 同站完整正文根 | 成功导入；BBC 多 body-block 按原序保留 |
| Reuters | 公开官网文章发现 | HTTP 401，候选舍弃 |
| AP News | 公开官网文章发现 | HTTP 403，候选舍弃 |
| The Guardian | 官方 Feed → 同站正文根 | 成功导入 |
| NPR | 官方 Feed → 同站正文根 | 成功导入 |
| DW | 官方 Feed → 同站正文根 | 成功导入 |
| VOA Learning English | 官方 As It Is Feed → 同站正文根 | 成功导入；不冒称第三方内容已授权 |
| NASA | 官方 Feed → 同站语义正文根 | 成功导入；不下载图片/商标 |
| Wikipedia | 官方 category/API → 固定 revision 全文 | 成功导入；CC BY-SA 4.0 署名及出处 |
| Wikinews | 官方 category/API → 固定 revision 全文 | 成功导入；创建日期至少 2024-12-17，按 CC BY 4.0 |
| ScienceDaily | 官方 Feed → 同站正文根 | 成功导入 |
| Phys.org | 官方 Feed → 同站正文根 | 成功导入 |
| Smithsonian | 公开官网发现及正文提取 | 当次不完整，未导入 |

共 13 个可尝试适配器，10 个实际成功来源；RFC 8890 保留既有核验全文但不计入上述新增来源。单次成功不是持续可用保证；失败只保存来源级错误/时间/诊断码，不保存失败候选 URL、标题、摘要或正文。实际启用名单由 Registry 与明确 importBasis 决定，不通过改许可表伪造授权。

## 九候选的许可模式调查（历史结论保留）

本表区分官方条款调查、明确权利与真实端到端请求。来源可访问不等于有权离线复制；默认 pending/disabled。这里只记录来源级入口，不记录失败候选的标题、网址、摘要或正文。

| 来源 | 官方证据与接口 | 全文取得 / 本地保存 / 离线 / App展示 | 缓存、署名和例外 | 结论 |
|---|---|---|---|---|
| BBC News | https://www.bbc.co.uk/usingthebbc/terms/ ；官方RSS用于调查 | 未核实全部权利；官方条款读取受限，不采用镜像作授权依据 | 未取得本App全文授权；RSS可读不等于可复制全文 | pending，禁用；无候选入库或展示 |
| Reuters | https://www.reutersconnect.com/general-terms ；Reuters Connect | §8.2限制复制、抓取、缓存；合同可改变范围，但本任务没有合同 | 不能把个人访问、预览或RSS当成离线App许可 | disabled |
| AP News | https://www.ap.org/terms-and-conditions/ ；AP官方内容产品 | 网站个人打印许可不能证明本地App全文数据库权利；无授权API凭据 | AP及供稿人保留权利 | disabled |
| The Guardian | https://open-platform.theguardian.com/access/ ；https://www.theguardian.com/open-platform/terms-and-conditions | API可提供article text，但需要注册key；本任务未取得满足长期离线的授权 | §5要求每24小时替换或删除；开发key配额受限；不得把网站访问当API授权 | disabled |
| NPR | https://www.npr.org/about-npr/179876898/terms-of-use | 官方页面本次读取受限；未确认四项完整权利 | 不能用转载站条款、摘要Feed或链接替代官方许可 | pending，禁用 |
| DW | https://amp.dw.com/en/benefit-from-smart-content-made-in-germany/a-19470839 ；https://b2b.dw.com/page/dw-terms-conditions | 官方合作内容/RSS有相应条款，但没有本App长期离线全文授权 | 合作内容盒/链接不符合本产品唯一本地全文模式 | pending，禁用 |
| VOA Learning English | https://learningenglish.voanews.com/p/6861.html ；https://learningenglish.voanews.com/p/6021.html | VOA独家制作文本可复用；不能概括为全部页面 | 必须credit；AP/Reuters/AFP等供稿例外。尚无可靠的逐篇独家文本权利证明适配器 | pending，禁用 |
| NASA | https://www.nasa.gov/nasa-brand-center/ ；https://sti.nasa.gov/disclaimers/ | NASA自制材料通常可复制分发，但第三方版权例外必须逐篇识别；STI文件许可不能泛化为全部新闻 | 保留NASA署名，不暗示背书；图片、商标、肖像和第三方文字分别审查 | pending，禁用 |
| Wikipedia / Wikinews | https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use §7；https://www.mediawiki.org/wiki/API:Parsing_wikitext | 英文Wikipedia文字按CC BY-SA 4.0复制、保存、离线展示；API按固定revision取得整页，不使用extract intro/summary接口 | 保留contributors、页面出处、CC许可和导入声明；拒绝版权冲突/额外署名警告。非文字媒体不导入；Wikinews 新许可另受创建日期门槛限制 | Wikipedia/Wikinews 文字可按各自许可及门槛准入；实际网络结果见上表 |

RFC 8890是保留的既有完整原文来源，使用固定指纹、IETF TLP 5 §3(c)(i)和全文版权声明，不算上述九候选中的新增新闻来源。用户本地导入使用本地明确声明，不能替代供应商合同或证明任意网页授权。

各来源的空 Feed、解析错误、超时、断网、429/503、重复数据和拒绝入库使用共享抓取/解析/Repository 的确定性故障测试；不能称为每家官网实际主动返回过所有故障。真实外网成功、URLProtocol 故障和原创解析 fixture 分开记录。

实现：`ArticleSourceRegistry`、`ArticleSourceEligibilityAudit`、`PublisherArticleSource`、`ArticleWebPageExtractor`、`ArticleDiscoveryService`、`ContentRepository.importFullText`。候选只在内存中处理，完整正文与结构、哈希、来源证据在同一事务保存。原文权限/完整性不足、提取失败或数据库失败统一丢弃，已有有效版本不被刷新错误覆盖。
