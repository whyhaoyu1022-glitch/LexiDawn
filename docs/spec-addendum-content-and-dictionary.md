# LexiDawn（词光）产品与技术开发总规格书补充说明一
## 英文文章来源扩展、自动内容获取与词典数据系统

- 版本：1.0
- 状态：已由产品负责人批准
- 生效提交：以本文件进入 `main` 的提交为准
- 关联主文档：`SPEC.md`

---

## 1. 文档优先级与适用范围

### 1.1 优先级

本补充说明经产品负责人批准并提交至 GitHub 后，成为 LexiDawn 的正式产品与技术规范。

**在本文件覆盖的范围内，本补充说明优先级高于原始 `SPEC.md`。** 如有冲突，按以下规则执行：

1. 文章来源选择、来源登记、文章发现、正文获取、正文解析、自然段落整理、文章本地存储及来源展示，优先遵守本补充说明。
2. 词典来源、词典查询、多个来源的结果合并、词典缓存和释义展示，优先遵守本补充说明。
3. 阅读器中来源与版权信息的展示密度，优先遵守本补充说明。
4. 原 `SPEC.md` 中其他未被本文件明确修改的要求继续有效，包括学习周期、阅读进度、生词本、复习状态机、数据安全、隐私、数据库迁移、无障碍、测试和 CI。
5. 本文件不代表允许绕过登录、付费墙、验证码、访问控制或来源明确设置的自动访问限制。不同网站的接入方式可以不同，但产品侧应尽量统一。

本文件重点修订原 `SPEC.md` §7–8 中的词典来源与数据获取、§12–13 中的文章来源与内容获取、§19–20 中的文章/词典数据与缓存，以及 §21.3 中与本文件主题相关的来源处理要求。

### 1.2 修订目的

词光的核心用途是帮助用户持续阅读真实英文文章、点击查词、积累词汇并完成复习。现有文章来源和词典来源过于单一，导致内容数量、题材、时效性和释义质量不足。

本次修订要求：

- 显著增加 BBC、Reuters、AP、The Guardian、NPR、DW、VOA Learning English、NASA、Wikipedia 等真实内容来源。
- 让来源自动发现新文章，减少逐篇手动录入。
- 对可通过相应接口和使用条件取得的完整正文，自动下载、提取并保存至本地数据库。
- 对只能取得标题、摘要或原站链接的来源，也应进入正常内容发现和推荐列表，不应因此完全排除。
- 统一 HTML 正文解析和段落整理，解决硬换行、短行和不自然分段。
- 扩大英语词典来源，提供词性、音标、英文释义、中文释义、例句、短语和词义关系。
- 将冗长的版权技术信息从阅读首屏移走，只保留用户理解来源所需的信息和来源明确要求保留的署名/声明。
- 不破坏现有学习周期、生词本、阅读进度和复习记录。

---

## 2. 文章来源范围与具体来源

### 2.1 第一批优先来源

第一批应优先接入以下来源。来源地址和接口必须在开发时实际请求验证，不能仅凭文档中列出的地址就声称接入成功。

| 来源 | 内容方向 | 首选发现入口 | 正文获取建议 |
|---|---|---|---|
| BBC News | 国际、英国、商业、科技、科学、文化 | BBC RSS | RSS 用于发现标题、摘要、时间和原文链接；正文使用来源允许的访问方式，不能假设 RSS 允许全文复制 |
| Reuters | 国际、商业、科技、政治、社会 | 可用的官方内容入口或授权内容服务 | Reuters Connect/内容 API 需按其服务条件取得访问；未取得相应许可时保留发现元数据和原站链接 |
| AP News | 国际、社会、商业、科技 | AP 官方内容 API 或可用 Feed | 优先使用 AP Media API 等正式接口；按 API 账户和授权范围获取正文 |
| The Guardian | 世界、科技、环境、文化、生活 | Guardian Open Platform | 使用官方 Content API；按 API key 类型、调用额度和使用条款处理 |
| NPR | 美国社会、科学、文化、商业 | NPR 官方 RSS/内容入口 | RSS 用于发现；正文使用明确允许的内容入口 |
| Deutsche Welle（DW） | 国际、欧洲、科技、商业、文化 | DW 英文 RSS | 可从官方 RSS 发现文章；正文按来源实际允许的方式获取 |
| VOA Learning English | 新闻、教育、科学、生活、英语学习 | VOA Learning English RSS | 优先使用 VOA 自制学习内容；按其公开内容说明保留 credit；需区分其中来自新闻机构的第三方内容 |
| NASA | 科学、航天、环境、技术 | NASA API / 官方内容页面 | 优先使用官方 API；逐项保留必要的摄影师/机构署名，并识别第三方内容例外 |
| Wikipedia / Wikinews | 科学、历史、文化、人物、知识 | MediaWiki API / Wikimedia REST API | 使用官方 API，按具体项目和页面许可保留署名及来源链接 |

### 2.2 可直接配置的示例入口

以下是可用于第一阶段接入验证的入口：

- BBC News Top Stories：`https://feeds.bbci.co.uk/news/rss.xml`
- BBC World：`https://feeds.bbci.co.uk/news/world/rss.xml`
- BBC Technology：`https://feeds.bbci.co.uk/news/technology/rss.xml`
- BBC Science & Environment：`https://feeds.bbci.co.uk/news/science_and_environment/rss.xml`
- The Guardian Open Platform：`https://open-platform.theguardian.com/documentation/`
- Guardian Content API base：`https://content.guardianapis.com/`
- VOA Learning English RSS 列表：`https://learningenglish.voanews.com/rssfeeds`
- VOA Learning English 内容使用说明：`https://learningenglish.voanews.com/p/6861.html`
- DW Top Stories RSS：`https://rss.dw.com/rdf/rss-en-top`
- DW English All RSS：`https://rss.dw.com/rdf/rss-en-all`
- NASA API 文档：`https://api.nasa.gov/`
- Wikimedia REST API 文档：`https://www.mediawiki.org/wiki/API:REST_API`

Reuters、AP、NPR 等来源的具体 Feed/API 地址、认证方式和内容范围应由开发 AI 在实施时从官方入口核实并记录。不得凭空编造端点或把第三方 RSS 目录当作官方 API。

### 2.3 来源接入方式的实际区别

不同来源不能一律使用同一种抓取方式：

- BBC：优先用 RSS 发现文章。RSS 项目通常提供标题、摘要、发布日期和文章 URL；不能把 RSS 可读取直接等同于完整正文可本地保存。
- Reuters：将 Reuters 纳入正常发现列表；全文获取优先使用官方授权内容服务。Reuters Connect 条款对自动抓取、复制、缓存和再提供有明确限制，未取得相应授权时不能用通用爬虫代替授权接口。
- AP：优先调查 AP 官方 API/内容产品。没有 API 访问权限时仍可保留允许展示的发现信息和原文入口，不得把登录或付费内容当作公开全文。
- The Guardian：优先使用 Open Platform Content API，不应使用爬虫替代 API。Developer key 的调用额度和非商业使用条件、Commercial key 的申请条件必须按官方最新条款核验。
- NPR、DW：优先 RSS/官方内容入口，检查 Feed 正文长度；若只有摘要，保留摘要和原文链接，不得将摘要冒充全文。
- VOA Learning English：其自制 Learning English 内容具有公开的教育/商业再使用说明并要求 credit；页面中来自 AP、Reuters、AFP 等第三方机构的内容、图片和视频不能一概视作 VOA 自制公共领域内容。
- NASA：可使用 NASA 官方 API 和符合条件的公开媒体资源；需要识别第三方版权、商标、肖像和署名例外。
- Wikimedia：使用官方 API；每个项目和文件的许可须按实际页面记录。

**产品要求是尽可能多地发现真实文章，并在适合的路径中提供完整阅读；技术实现必须按来源真实提供的接口和条件工作，不得用“网站能打开”推断可以自动复制、缓存或再发布全文。**

---

## 3. 自动文章发现与刷新流程

### 3.1 统一流程

统一采用：

`来源登记 → 定时/按需发现 → 解析 Feed/API → 文章元数据入库 → 正文获取 → HTML 清理 → 正文结构化 → 质量检查 → 去重 → 本地保存 → 阅读器展示`

用户不需要逐篇复制粘贴 URL 才能看到新文章。

### 3.2 来源配置

建立统一的 `ArticleSourceConfig`，至少包含：

- `id`
- `name`
- `websiteURL`
- `feedURLs`
- `apiEndpoint`（可空）
- `categories`
- `discoveryMethod`（RSS、Atom、API、Sitemap、HTML）
- `contentMethod`（API 正文、Feed 正文、HTML 正文、原站阅读）
- `fullTextStorageAllowed`
- `refreshInterval`
- `enabled`
- `lastSyncAt`
- `lastETag`
- `lastModified`
- `lastError`

来源配置应集中维护，不得把来源 URL 和解析逻辑散落在多个 View 中。

### 3.3 RSS/Atom 解析

使用稳定的 XMLParser 或经过审查的轻量解析器处理 RSS/Atom。每条内容提取：

- 标题
- 原文 URL
- GUID
- 发布日期
- 作者（如 Feed 提供）
- 摘要
- 分类
- 更新日期
- 图片 URL（如有，另行确认展示要求）

将解析结果统一映射为 `ArticleDiscoveryItem`，并保存来源 ID。

Feed 只提供摘要时，必须将其标记为摘要，不能将其误标记为完整正文。

### 3.4 自动刷新

- App 启动时检查来源是否需要刷新。
- 用户进入今日或探索页面时检查缓存新鲜度。
- 支持手动刷新。
- 可以使用 iOS BackgroundTasks 做尽力而为的后台刷新，但不能假设系统会按固定分钟运行。
- 常规新闻可按 30–60 分钟作为刷新目标；长篇/专题内容可按 3–12 小时刷新。
- 使用 ETag、If-Modified-Since、Last-Modified 和 HTTP 304 降低重复下载。
- 对 429、503、超时和网络错误进行有上限的指数退避，并遵守服务端 Retry-After。
- 对来源级别设置并发上限和请求间隔。
- 单篇失败不能导致整个 Feed 或候选池丢失。

### 3.5 发现与正文获取分离

发现阶段只需要取得标题、摘要、时间、来源和 URL。

正文阶段单独判断是否有可用的正文接口和相应的本地保存方式。若可获取完整正文，则自动下载并进入本地阅读链路；若只能取得摘要，则在 UI 中显示“摘要/原站阅读”，不能伪装成全文。

---

## 4. 正文获取、HTML 解析与清理

### 4.1 请求实现

使用 `URLSession` 和独立的网络层：

- 设置合理的 User-Agent、Accept 和 Accept-Language。
- 设置连接/资源超时。
- 校验 HTTP 状态码和 Content-Type。
- 检查最终跳转 URL。
- 对响应体设置大小上限。
- 正确处理 UTF-8 和网页声明的字符编码。
- 记录请求状态、响应时间和可重试错误。
- 不在日志中打印完整文章正文、Cookie、API key 或授权头。

不得绕过登录、付费墙、验证码、访问控制或来源明确禁止的自动访问方式。

### 4.2 正文提取优先级

按以下顺序处理：

1. 来源官方 API 返回的结构化文章正文。
2. Feed 中明确提供且允许使用的完整内容字段。
3. 页面 JSON-LD / 结构化数据，例如 `NewsArticle.articleBody`。
4. HTML 语义结构中的 `article`、`main`、`h1`、`h2`、`p`、`blockquote`、`ul`、`ol`。
5. 通用正文提取算法，例如 Readability 思路或经审查的 Swift HTML 解析工具。

可以评估 SwiftSoup 等 HTML 解析工具；不得仅用一组正则表达式处理复杂 HTML，也不得引入未经审查的大型 UI 框架。

### 4.3 清理无关网页内容

提取正文时过滤：

- 网站导航、页眉、页脚
- 广告和赞助卡片
- Cookie 提示
- 分享按钮
- 推荐阅读和热门文章
- 评论区
- 订阅/登录引导
- 重复标题和重复摘要
- 浮动工具栏
- 无关菜单和页面脚本

不得误删正文中的引用、图片说明、列表、表格、标题、作者署名、修正声明或文章内链接。

### 4.4 正文完整性检查

提取后检查：

- 标题存在且合理。
- 正文非空且长度合理。
- 正文主要语言为英语。
- 不是登录页、验证码页或错误页。
- 不是仅有导航/广告的页面。
- 不存在明显乱码。
- 没有大段重复内容。
- 没有明显截断。
- 正文词数和预计阅读时间合理。

如果正文提取失败，保留文章元数据和原文 URL，并标记失败原因。不能将空正文或几十个词的摘要标记成完整文章。

---

## 5. 英文文章自然排版

### 5.1 原始内容与展示结构分离

不得将原始网页中的每个换行直接当成自然段落，也不得粗暴删除所有换行。

需要将正文转换为结构化内容块：

- 标题
- 小标题
- 自然段落
- 引用
- 有序/无序列表
- 图片说明（如允许展示）
- 正文内链接

建议模型：

```swift
struct ArticleDocument {
    let title: String
    let blocks: [ArticleBlock]
}

enum ArticleBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case quotation(String)
    case list(items: [String], ordered: Bool)
    case caption(String)
}
```

### 5.2 换行整理

- 合并同一段落中仅由网页列宽或纯文本固定行宽造成的硬换行。
- 保留真正的空行和段落分隔。
- 保留标题与正文之间的结构关系。
- 保留列表项目，不得将列表拼成一个长段落。
- 保留引用块与图片说明。
- 对无法可靠判断的结构保留原始段落边界，不得擅自改写文章内容。
- 原始正文与展示结构分别保存，以便重新解析或回溯。

### 5.3 阅读器 UI

- 正文默认约 18–20 pt，动态字体可缩放。
- 行距约 1.4–1.6 倍。
- 段落间距约 10–16 pt。
- 大屏限制最大阅读宽度。
- 标题、正文、引用和列表具有清晰层级。
- 浅色、深色、暖纸色主题必须作用于整个阅读页面，包括导航区、文章信息区、工具栏、浮层和正文，不能只给正文换肤。
- 减少正文顶部大块留白。
- 来源/版权说明不得挤占首屏正文。

---

## 6. 本地文章数据库与去重

### 6.1 本地优先

继续使用现有 SwiftData 和 Repository 架构，不得无必要地推倒现有数据模型。

文章记录至少需要：

- 稳定 ID
- sourceID
- canonicalURL
- title
- author
- publishedAt
- fetchedAt
- summary
- rawContent（仅在允许保存时）
- structuredBody
- bodyHash
- wordCount
- estimatedReadMinutes
- topicTags
- contentStatus（fullText / summary / originalLink / unavailable）
- extractionVersion
- lastError

正文允许本地保存时，应持久化到本机，使用户可以离线阅读。

只允许保存元数据或摘要的来源，不能将其正文状态标记为 fullText。

### 6.2 三层去重

1. URL 去重：规范化 host、path、末尾斜杠和追踪参数，优先使用 canonical URL。
2. 正文指纹：对实际取得的正文计算 SHA-256。
3. 标题/事件相似度：识别同一新闻的重复报道，降低重复推荐。

每日文章一经分配，不得再次作为新文章分配。已经开始/完成的探索文章应保留历史，但默认不重复推荐。

### 6.3 数据安全

- 正文更新失败不能覆盖已有有效正文。
- 缓存清理不得删除阅读进度、生词本、复习记录或周期状态。
- 数据库迁移必须有版本号和测试。
- 写入失败不得显示保存成功。
- 文章正文更新后，阅读进度应尽可能通过稳定段落锚点恢复。
- 网络失败时仍可阅读本地已保存文章。

---

## 7. 文章推荐和每日任务

### 7.1 主题

至少支持：

- 世界新闻
- 科技
- 科学
- 商业
- 社会
- 文化
- 环境
- 教育
- 历史
- 健康与生活

优先使用来源自带分类；必要时再使用规则分类或 AI 辅助。

### 7.2 文章评分

根据以下因素评分：

- 来源质量
- 发布时间
- 用户兴趣
- 词汇难度
- 正文完整度
- 文章长度
- 主题多样性
- 是否重复报道同一事件
- 用户是否已经读过

1,200–2,500 词可作为长文推荐区间，但短新闻也可以进入探索列表，不应硬性排除。

### 7.3 学习周期不变量

- 先检查是否有未完成的旧周期。
- 有旧周期时必须继续旧周期，不得因新文章到来而覆盖。
- 无旧周期时才分配新的每日文章。
- 分配必须原子化。
- 文章阅读完成与复习完成保持独立。
- 不得将预取候选计为已分配或已完成。
- 不得因抓取失败、无网络或缓存清理而伪造完成状态。
- 现有周期、生词本、复习和跨日逻辑必须完整回归。

---

## 8. 词典来源扩展

### 8.1 第一批词典来源

| 来源 | 主要用途 | 接入方式 |
|---|---|---|
| Wiktionary | 词性、定义、词形、发音、词源和用法 | MediaWiki API / Wiktionary 可用的结构化接口 |
| Free Dictionary API | 英文释义、音标、例句、发音数据 | JSON API |
| Open English WordNet | 同义词集、上下位关系、反义/词义关系 | 下载并解析官方版本数据 |
| CC-CEDICT | 中文对应词补充 | 保留现有本地索引 |
| Merriam-Webster | 权威释义、音频、同义词、反义词和词源 | 官方 Dictionary API，按其 key、配额及非商业/商业条款使用 |
| Cambridge / Oxford | 高质量词典参考 | 正式 API、授权渠道或原站入口；不把商业网页直接批量复制为本地词库 |

参考入口：

- Wiktionary API：`https://en.wiktionary.org/w/api.php`
- Wikimedia REST API：`https://www.mediawiki.org/wiki/API:REST_API`
- Free Dictionary API：`https://api.dictionaryapi.dev/api/v2/entries/en/{word}`
- Open English WordNet：`https://en-word.net/downloads`
- CC-CEDICT 下载：`https://cc-cedict.org/editor/editor.php?handler=Download`
- Merriam-Webster API：`https://www.dictionaryapi.com/`

Merriam-Webster 官方免费 API 当前说明为非商业用途、每个 reference 每日不超过 1,000 次、最多两个 reference works；若应用用途或规模不满足，应申请相应商业方案。API key 不得硬编码进客户端或公开仓库。

### 8.2 统一词典模型

每个词条支持：

- lemma
- surfaceForm
- IPA / phonetics
- pronunciation audio URL（如有）
- partOfSpeech
- English definitions
- Chinese translations
- usage labels
- examples
- phrases
- synonyms
- antonyms
- word forms
- etymology（如有）
- sourceID
- sourceVersion
- confidence
- fetchedAt
- expiresAt（如适用）

不同词性、不同词源和不同 sense 必须分开保存，不能把所有释义拼成一个字符串。

### 8.3 多词典聚合

实现 `DictionaryProvider` 协议和 `DictionaryAggregator`：

1. 用户点击英文单词或短语。
2. 识别表面词形、lemma 和当前句子。
3. 先查本地缓存。
4. 缓存缺少重要字段时并行或按优先级请求可用词典。
5. 解析不同来源的数据结构。
6. 合并相同词性和重复义项。
7. 保留每条义项的来源。
8. 按当前句子词性和上下文排序。
9. 返回最相关义项与其他常见义项。
10. 将允许缓存的结果保存到本地。

单个来源失败不能导致整个查词流程失败。已有本地结果必须立即可用。

### 8.4 语境义

排序优先考虑：

1. 当前句子的语法词性。
2. 当前短语和固定搭配。
3. 当前段落和文章主题。
4. 词典义项的常见程度。
5. 其他低频义项。

可以先采用确定性规则，后续再增加 AI 辅助排序。AI 只能排序和解释真实存在的词典义项，不得编造词典原文。

没有可靠中文对应词时，应明确显示“暂无可靠中文释义”，允许用户填写个人释义；不能为了让复习流程继续而编造答案。

### 8.5 缓存

- 按 lemma、language、providerID、sourceVersion 建立缓存。
- 有明确缓存期限的来源遵守其期限。
- 静态开放词典数据记录数据版本和许可证。
- 来源版本更新后可重建索引或刷新缓存。
- 缓存清理不删除用户生词本和个人笔记。
- 离线时展示已有数据，并明确标注可能不是最新版本。

---

## 9. 来源信息与阅读界面

阅读首屏只显示用户需要的信息：

- 文章标题
- 来源名称
- 作者（如有）
- 发布时间
- 阅读进度
- 原文入口

完整的来源详情、许可链接和技术信息放在二级详情页面。

不得为了展示版权技术资料而在阅读器顶部占用大面积空间。

如果来源明确要求正文随附特定声明或署名，应保留该要求；其余技术元数据不应挤占正文。

---

## 10. 建议技术模块

文章系统：

```text
ArticleSourceRegistry
    ↓
ArticleDiscoveryService
    ├── RSSParser
    ├── AtomParser
    ├── OfficialAPIAdapter
    └── SitemapDiscovery
    ↓
ArticleFetchService
    ↓
ArticleHTMLExtractor
    ↓
ArticleDocumentNormalizer
    ↓
ArticleQualityValidator
    ↓
ArticleRepository (SwiftData)
    ↓
DailyArticleAssignmentService
    ↓
ReaderView
```

词典系统：

```text
InteractiveEnglishText
    ↓
WordTokenizer
    ↓
DictionaryAggregator
    ├── LocalDictionaryProvider
    ├── WiktionaryProvider
    ├── FreeDictionaryProvider
    ├── OpenEnglishWordNetProvider
    └── CCEDICTProvider
    ↓
DictionaryCache (SwiftData)
    ↓
WordLookupSheet / DictionaryDetailView
```

复用现有 ContentRepository、VocabularyRepository、ReaderProgressService、LearningServices 和每日学习状态机。不得在 View 中直接发起所有网络请求或直接操作数据库。

---

## 11. 验收标准

本补充说明对应功能完成时，至少满足：

1. 多个真实来源可以自动发现新文章。
2. BBC、Reuters、AP、The Guardian 等主流来源出现在正常内容发现/推荐体系中；不能把“不能全文缓存”当作完全排除来源的理由。
3. 至少两个可实际使用的来源完成自动正文获取、提取和本地持久化的完整链路；具体来源必须有真实成功证据，不能只用 mock。
4. 只能提供摘要/原站链接的来源，正确显示对应模式，不伪装成全文。
5. HTML 提取能够过滤导航、广告、Cookie、推荐模块和无关内容。
6. 自然段落、标题、列表和引用结构正确。
7. 已保存正文可离线阅读，重启后仍存在。
8. 同一文章不会重复保存或重复分配。
9. 抓取失败、超时和限流不会破坏现有文章和学习数据。
10. 每日周期、旧任务续接、阅读进度、生词本和复习状态不受影响。
11. 至少两个词典来源能提供真实查询结果；其中一个应提供结构化英语释义/词性，不能只依赖中文反向索引。
12. 查词结果保留来源、词性、释义和可用的音标/例句。
13. 词典结果缓存有效，断网时已有结果可查看。
14. 同一词多义不会被错误合并；语境义排序可测试、可解释。
15. 阅读器不再展示大段版权技术说明。
16. 阅读器自然换行，深色/浅色/暖纸色全页一致。
17. 横屏下正文真实可见、可滚动、可点击，不能只断言某个按钮存在。
18. 所有新功能都有正常、空、加载、失败、重试和离线状态。
19. 新增单元测试、Repository/网络集成测试和 UI 自动化。
20. 原有回归测试不得通过删除或弱化断言来“通过”。
21. GitHub Actions 必须针对最终应用代码提交执行成功；运行中的 CI 不得冒充通过。

---

## 12. 重要原则

本次修改的核心是：**扩大真实内容，简化内容接入，让词光真正成为每天有文章可读、每个词都能查的英语学习 App。**

- 文章来源应尽可能丰富，优先主流媒体和优质杂志/科普网站。
- 内容发现与全文存储分开；不支持全文存储的来源也可以正常推荐。
- 对可通过相应方式取得的正文自动提取、整理并保存本地。
- 词典从单一来源升级为多来源聚合。
- 阅读器排版以自然英文阅读为标准，而不是照搬网页固定行宽。
- 版权和来源信息必须准确，但不应占用用户大量阅读空间。
- 不得绕过网站访问控制、付费墙、验证码或明确禁止的自动访问方式。
- 保留全部旧学习数据与状态机不变量。
- 真实功能、真实数据、真实运行、真实截图才算交付。

**本补充说明在文章来源、词典、内容获取、正文展示和相关缓存范围内优先于原 `SPEC.md`。**
