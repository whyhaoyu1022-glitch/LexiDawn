import Foundation

struct ArticleSourceEligibilityAudit: Codable, Sendable {
    enum Decision: String, Codable, Sendable { case pending, disabled, approved }
    let sourceID: String, name: String, evidenceURLs: [String], conclusion: String
    let decision: Decision
    let checkedAt: String
}

enum ArticleSourceRegistry {
    /// Pending is the default. A feed's availability never grants storage rights.
    static let audits: [ArticleSourceEligibilityAudit] = [
        .init(sourceID: "bbc", name: "BBC News", evidenceURLs: ["https://www.bbc.co.uk/usingthebbc/terms/"], conclusion: "官方条款在审查网络中受限；RSS不证明全文储存权，未取得许可。", decision: .pending, checkedAt: "2026-11-01"),
        .init(sourceID: "reuters", name: "Reuters", evidenceURLs: ["https://www.reutersconnect.com/general-terms"], conclusion: "§8.2限制复制、抓取与缓存；没有账户内容合同。", decision: .disabled, checkedAt: "2026-11-01"),
        .init(sourceID: "ap", name: "AP News", evidenceURLs: ["https://www.ap.org/terms-and-conditions/"], conclusion: "网站个人打印许可不等于App全文数据库授权；未配置授权API。", decision: .disabled, checkedAt: "2026-11-01"),
        .init(sourceID: "guardian", name: "The Guardian", evidenceURLs: ["https://open-platform.theguardian.com/access/", "https://www.theguardian.com/open-platform/terms-and-conditions"], conclusion: "需要API key；§5要求24小时替换或删除，未取得满足本地长期离线需求的许可。", decision: .disabled, checkedAt: "2026-11-01"),
        .init(sourceID: "npr", name: "NPR", evidenceURLs: ["https://www.npr.org/about-npr/179876898/terms-of-use"], conclusion: "官方条款读取受限，未核实完整正文持久化/离线权利。", decision: .pending, checkedAt: "2026-11-01"),
        .init(sourceID: "dw", name: "Deutsche Welle", evidenceURLs: ["https://amp.dw.com/en/benefit-from-smart-content-made-in-germany/a-19470839", "https://b2b.dw.com/page/dw-terms-conditions"], conclusion: "合作Feed需要许可；没有本App全文离线授权。", decision: .pending, checkedAt: "2026-11-01"),
        .init(sourceID: "voa", name: "VOA Learning English", evidenceURLs: ["https://learningenglish.voanews.com/p/6861.html", "https://learningenglish.voanews.com/p/6021.html"], conclusion: "仅VOA独家制作文本可复用；AP/Reuters/AFP例外，尚无可靠逐篇独家权利证明适配器。", decision: .pending, checkedAt: "2026-11-01"),
        .init(sourceID: "nasa", name: "NASA", evidenceURLs: ["https://www.nasa.gov/nasa-brand-center/", "https://sti.nasa.gov/disclaimers/"], conclusion: "NASA自制内容与第三方例外必须逐篇区分；通用媒体指引不作所有新闻全文授权。", decision: .pending, checkedAt: "2026-11-01"),
        .init(sourceID: "wikipedia", name: "Wikipedia / Wikinews", evidenceURLs: ["https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use"], conclusion: "§7允许按具体项目许可复用全文，保留署名和许可；仅启用英文Wikipedia文字API，Wikinews待单独项目许可核对。", decision: .approved, checkedAt: "2026-11-01")
    ]
    static func enabled(_ id: String) -> Bool { audits.contains { $0.sourceID == id && $0.decision == .approved } }
    static let wikipediaRights = FullTextRightsEvidence(id: "wikipedia-text-cc-by-sa-4-2026-11-01", sourceID: "wikipedia",
        termsURL: "https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use", license: "CC BY-SA 4.0",
        attribution: "English Wikipedia contributors · CC BY-SA 4.0 · Layout only; original text preserved. https://creativecommons.org/licenses/by-sa/4.0/",
        checkedAt: Date(timeIntervalSince1970: 1793491200), acquisitionAllowed: true, persistenceAllowed: true, offlineAllowed: true, displayAllowed: true)
}
