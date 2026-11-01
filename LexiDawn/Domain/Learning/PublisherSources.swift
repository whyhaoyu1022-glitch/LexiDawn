import Foundation

struct PublisherArticleSource: Sendable {
    enum Discovery: Sendable { case feed, links }
    let id: String, name: String, discoveryURL: String
    let discovery: Discovery
    let hosts: Set<String>
    /// Exact class/id/data attribute tokens identifying the article body, not the surrounding page.
    let bodyMarkers: [String]
    let articlePathPattern: String
    let topics: [String]
}

extension ArticleSourceRegistry {
    /// Explicit owner instruction in this conversation, 2026-11-01. Separate from publisher rights audits.
    static let personalSources: [PublisherArticleSource] = [
        .init(id: "bbc", name: "BBC News", discoveryURL: "https://feeds.bbci.co.uk/news/world/rss.xml", discovery: .feed,
              hosts: ["www.bbc.com", "www.bbc.co.uk", "bbc.com", "bbc.co.uk"], bodyMarkers: ["text-block"], articlePathPattern: #"/news/(articles/|[a-z-]+-\d)"#, topics: ["新闻", "世界"]),
        .init(id: "reuters", name: "Reuters", discoveryURL: "https://www.reuters.com/world/", discovery: .links,
              hosts: ["www.reuters.com", "reuters.com"], bodyMarkers: ["article-body", "ArticleBody"], articlePathPattern: #"/(world|business|technology|science|sustainability)/.+-\d{4}-\d{2}-\d{2}/"#, topics: ["新闻", "世界"]),
        .init(id: "ap", name: "AP News", discoveryURL: "https://apnews.com/hub/world-news", discovery: .links,
              hosts: ["apnews.com", "www.apnews.com"], bodyMarkers: ["RichTextStoryBody"], articlePathPattern: #"/article/[a-z0-9-]+"#, topics: ["新闻", "世界"]),
        .init(id: "guardian", name: "The Guardian", discoveryURL: "https://www.theguardian.com/world/rss", discovery: .feed,
              hosts: ["www.theguardian.com", "theguardian.com"], bodyMarkers: ["article-body-commercial-selector", "articleBody", "body"], articlePathPattern: #"/\w+/\d{4}/[a-z]{3}/\d{2}/"#, topics: ["新闻", "世界"]),
        .init(id: "npr", name: "NPR", discoveryURL: "https://feeds.npr.org/1001/rss.xml", discovery: .feed,
              hosts: ["www.npr.org", "npr.org"], bodyMarkers: ["storytext"], articlePathPattern: #"/\d{4}/\d{2}/\d{2}/"#, topics: ["新闻", "文化"]),
        .init(id: "dw", name: "Deutsche Welle", discoveryURL: "https://rss.dw.com/rdf/rss-en-all", discovery: .feed,
              hosts: ["www.dw.com", "dw.com", "amp.dw.com"], bodyMarkers: ["longText", "rich-text", "RichText"], articlePathPattern: #"/en/.+/a-\d+"#, topics: ["新闻", "世界"]),
        .init(id: "voa", name: "VOA Learning English", discoveryURL: "https://learningenglish.voanews.com/api/zkm-ql-vomx-tpej-rqi", discovery: .feed,
              hosts: ["learningenglish.voanews.com", "www.learningenglish.voanews.com"], bodyMarkers: ["wsw", "body-container"], articlePathPattern: #"/a/.+/\d+\.html"#, topics: ["英语学习", "文化"]),
        .init(id: "nasa", name: "NASA", discoveryURL: "https://www.nasa.gov/news-release/feed/", discovery: .feed,
              hosts: ["www.nasa.gov", "nasa.gov", "science.nasa.gov"], bodyMarkers: ["entry-content", "article-body"], articlePathPattern: #"/(news-release|missions|science-research|general)/"#, topics: ["科学", "太空"]),
        .init(id: "sciencedaily", name: "ScienceDaily", discoveryURL: "https://www.sciencedaily.com/rss/top/science.xml", discovery: .feed,
              hosts: ["www.sciencedaily.com", "sciencedaily.com"], bodyMarkers: ["story_text"], articlePathPattern: #"/releases/\d{4}/\d{2}/"#, topics: ["科学"]),
        .init(id: "phys", name: "Phys.org", discoveryURL: "https://phys.org/rss-feed/", discovery: .feed,
              hosts: ["phys.org", "www.phys.org"], bodyMarkers: ["article-main"], articlePathPattern: #"/news/\d{4}-\d{2}-"#, topics: ["科学", "科技"]),
        .init(id: "smithsonian", name: "Smithsonian Magazine", discoveryURL: "https://www.smithsonianmag.com/rss/latest_articles/", discovery: .feed,
              hosts: ["www.smithsonianmag.com", "smithsonianmag.com"], bodyMarkers: ["article-body", "article-text"], articlePathPattern: #"/(science-nature|history|smart-news|arts-culture|travel)/.+-\d+/"#, topics: ["文化", "科学"])
    ]
    static func personalSource(_ id: String) -> PublisherArticleSource? { personalSources.first { $0.id == id } }
    static func canAttempt(_ id: String) -> Bool { enabled(id) || id == "wikinews" || personalSource(id) != nil }
    static func name(_ id: String) -> String {
        personalSource(id)?.name ?? (id == "wikipedia" ? "Wikipedia" : id == "wikinews" ? "Wikinews" : id == SourceRegistry.rfc.id ? SourceRegistry.rfc.name : id)
    }
    static func evidence(for id: String) -> FullTextRightsEvidence? {
        if id == "wikipedia" { return wikipediaRights }
        if id == "wikinews" { return wikinewsRights }
        guard let source = personalSource(id), let host = source.hosts.sorted().first else { return nil }
        return FullTextRightsEvidence(id: "owner-personal-instruction-2026-11-01-" + id, sourceID: id,
            termsURL: "https://" + host + "/", license: "个人使用指示；未声明出版社授权",
            attribution: source.name + " · 原作者及原始版权归属保留 · 按负责人个人使用指示本地导入",
            checkedAt: Date(timeIntervalSince1970: 1793491200), acquisitionAllowed: true, persistenceAllowed: true, offlineAllowed: true, displayAllowed: true,
            importBasis: "owner-directed-personal-use-2026-11-01")
    }
    static let wikinewsRights = FullTextRightsEvidence(id: "wikinews-post-2024-12-16-cc-by-4", sourceID: "wikinews",
        termsURL: "https://en.wikinews.org/wiki/Wikinews:Copyright", license: "CC BY 4.0",
        attribution: "Wikinews contributors · CC BY 4.0 · Original text preserved. https://creativecommons.org/licenses/by/4.0/",
        checkedAt: Date(timeIntervalSince1970: 1793491200), acquisitionAllowed: true, persistenceAllowed: true, offlineAllowed: true, displayAllowed: true)
}
