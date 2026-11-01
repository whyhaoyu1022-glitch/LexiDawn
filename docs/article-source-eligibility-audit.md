# ArticleSourceEligibilityAudit · 2026-11-01

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
| Wikipedia / Wikinews | https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use §7；https://www.mediawiki.org/wiki/API:Parsing_wikitext | 英文Wikipedia文字按CC BY-SA 4.0复制、保存、离线展示；API按固定revision取得整页，不使用extract intro/summary接口 | 保留contributors、页面出处、CC许可和导入声明；拒绝版权冲突/额外署名警告。非文字媒体不导入；Wikinews未启用 | 仅Wikipedia文字适配器启用；实际网络成功以独立Live测试日志为准 |

RFC 8890是保留的既有完整原文来源，使用固定指纹、IETF TLP 5 §3(c)(i)和全文版权声明，不算上述九候选中的新增新闻来源。用户本地导入使用本地明确声明，不能替代供应商合同或证明任意网页授权。

当前不能宣称已达到至少五个新来源，也不能宣称所有九源完成实时正常/空Feed/超时/429/503验证。未核实来源完全禁用，不提供摘要、URL、候选卡片或外部阅读。


2026-11-01 · 负责人特别指示的公开官网全文模式：允许个人使用场景下直接尝试11个官网来源（BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian）；旧出版社许可审核不改写为授权。FullTextRightsEvidence.importBasis=owner-directed-personal-use-2026-11-01，grant.scope=personal-full-text，与audited-full-text分开。只请求公开HTTPS页面，固定主机白名单及重定向检查，无登录、验证码处理、浏览器、代理或付费墙绕过。RSS/列表只在内存中发现候选；完整闭合正文子树或明确articleBody、正文长度/段落/原文一致性和数据库事务验证通过后才入库；任何失败不留下候选。Wikinews另按CC BY4.0及2024-12-17创建日期门槛接入。最多3条来源管线并行，首篇原文导入后更新首页，各来源独立失败/退避。新增8个确定性测试及真实网络五来源导入门槛测试，尚未执行，不把配置11源当作11源成功。
