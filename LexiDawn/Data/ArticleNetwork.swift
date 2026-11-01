import Foundation

actor ArticleFetchService {
    private let session: URLSession
    private var nextRequestAt = Date.distantPast
    init(configuration supplied: URLSessionConfiguration? = nil) {
        let configuration = supplied ?? URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 45
        configuration.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: configuration)
    }
    func fetch(_ url: URL, allowedHost: String) async throws -> Data {
        guard url.scheme == "https", url.host == allowedHost, url.user == nil, url.password == nil else { throw FullTextImportError.transport }
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let delay = max(0, nextRequestAt.timeIntervalSinceNow)
            nextRequestAt = max(Date(), nextRequestAt).addingTimeInterval(1)
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("LexiDawn/0.3 (personal offline reader; https://github.com/whyhaoyu1022-glitch/LexiDawn)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json, application/xml, text/html;q=0.8", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, http.url?.host == allowedHost else { throw FullTextImportError.transport }
                if [429, 503].contains(http.statusCode), attempt < 2 {
                    let delay = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? pow(2, Double(attempt + 1))
                    // Long server backoff is not silently shortened. Let the caller retry later.
                    guard delay <= 30 else { throw FullTextImportError.rateLimited }
                    try await Task.sleep(for: .seconds(max(1, delay))); continue
                }
                guard http.statusCode == 200 else { throw http.statusCode == 429 ? FullTextImportError.rateLimited : FullTextImportError.transport }
                guard data.count <= 4_000_000, !data.isEmpty else { throw FullTextImportError.incomplete }
                return data
            } catch is CancellationError { throw CancellationError() }
            catch let error as FullTextImportError { throw error }
            catch { if attempt == 2 { throw FullTextImportError.transport }; try await Task.sleep(for: .seconds(pow(2, Double(attempt)))) }
        }
        throw FullTextImportError.transport
    }
}

/// These values exist only in memory, before full-text admission. No candidate persistence API exists.
struct ArticleDiscoveryItem: Sendable { let sourceID: String, title: String, url: String, revision: Int? }

enum OfficialArticleAPI {
    static func url(host: String, fields: [String: String]) throws -> URL {
        var components = URLComponents(); components.scheme = "https"; components.host = host; components.path = "/w/api.php"
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw FullTextImportError.transport }; return url
    }
    static func discovery(_ data: Data) throws -> [ArticleDiscoveryItem] {
        struct Response: Decodable { struct Query: Decodable { let pages: [Page] }; struct Page: Decodable { let title: String; let fullurl: String; let lastrevid: Int }; let query: Query }
        return try JSONDecoder().decode(Response.self, from: data).query.pages.map { .init(sourceID: "wikipedia", title: $0.title, url: $0.fullurl, revision: $0.lastrevid) }
    }
}

@MainActor final class ArticleDiscoveryService {
    private let fetcher: ArticleFetchService
    private let content: ContentRepository
    private var refreshing = false
    private var lastSuccess: Date?
    init(content: ContentRepository, fetcher: ArticleFetchService = ArticleFetchService()) { self.content = content; self.fetcher = fetcher }
    func refresh(force: Bool = false, at now: Date = Date()) async throws -> Int {
        guard !refreshing else { return 0 }
        let stored = try content.sourceRefreshState("wikipedia")
        if !force, let success = stored.success ?? lastSuccess, now.timeIntervalSince(success) < 3600 { return 0 }
        if let retry = stored.retryAfter, retry > now { if force { throw FullTextImportError.rateLimited }; return 0 }
        guard ArticleSourceRegistry.enabled("wikipedia") else { throw FullTextImportError.rights }
        refreshing = true; defer { refreshing = false }
        try content.recordSourceRefresh("wikipedia", beginning: true, at: now)
        do {
            let endpoint = try OfficialArticleAPI.url(host: "en.wikipedia.org", fields: ["action": "query", "format": "json", "formatversion": "2", "generator": "categorymembers", "gcmtitle": "Category:Featured_articles", "gcmlimit": "3", "gcmnamespace": "0", "prop": "info", "inprop": "url"])
            let candidates = try OfficialArticleAPI.discovery(await fetcher.fetch(endpoint, allowedHost: "en.wikipedia.org"))
            var count = 0, failures = 0
            for candidate in candidates {
                try Task.checkCancellation()
                guard let revision = candidate.revision else { continue }
                let url = try OfficialArticleAPI.url(host: "en.wikipedia.org", fields: ["action": "parse", "format": "json", "formatversion": "2", "oldid": String(revision), "prop": "text|revid|displaytitle", "disableeditsection": "1", "disabletoc": "1"])
                do {
                    let data = try await fetcher.fetch(url, allowedHost: "en.wikipedia.org")
                    struct Response: Decodable { struct Page: Decodable { let text: String; let revid: Int }; let parse: Page }
                    let page = try JSONDecoder().decode(Response.self, from: data).parse
                    guard page.revid == revision, page.text.contains("mw-parser-output"),
                          !["copyright violation", "non-free content", "additional attribution"].contains(where: page.text.lowercased().contains) else { throw FullTextImportError.rights }
                    let document = try ArticleHTMLExtractor.extract(page.text)
                    let item = FullTextArticleImport(sourceID: candidate.sourceID, canonicalURL: candidate.url, title: candidate.title,
                        author: "English Wikipedia contributors", publishedAt: nil, rawContent: document.text, document: document, topics: ["知识"],
                        rights: ArticleSourceRegistry.wikipediaRights, completeDocument: true, expectedHash: nil, verifiedAt: now)
                    if try content.importFullText(item, at: now) { count += 1 }
                } catch is CancellationError { throw CancellationError() }
                catch { failures += 1 /* Candidate discarded; no URL, title or body in diagnostics. */ }
            }
            if failures > 0 && count == 0 { throw FullTextImportError.incomplete }
            try content.recordSourceRefresh("wikipedia", beginning: false, at: now)
            lastSuccess = now
            return count
        } catch is CancellationError { throw CancellationError() }
        catch {
            let code = (error as? FullTextImportError)?.rawValue ?? FullTextImportError.transport.rawValue
            try content.recordSourceRefresh("wikipedia", beginning: false, errorCode: code, at: now)
            throw (error as? FullTextImportError) ?? .transport
        }
    }
}

/// XMLParser handles CDATA, namespaces, Atom links and entities; RSS descriptions are never bodies.
final class ArticleFeedParser: NSObject, XMLParserDelegate {
    private var items: [ArticleDiscoveryItem] = [], title = "", link = "", field = "", inside = false
    private let sourceID: String
    init(sourceID: String) { self.sourceID = sourceID }
    func parse(_ data: Data) throws -> [ArticleDiscoveryItem] {
        items = []; inside = false; field = ""
        let parser = XMLParser(data: data); parser.delegate = self; parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw FullTextImportError.parsing }; return items
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = name.lowercased()
        if name == "item" || name == "entry" { inside = true; title = ""; link = "" }
        if inside { field = name; if name == "link", attributes["rel"] == nil || attributes["rel"] == "alternate", let href = attributes["href"] { link = href } }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inside { if field == "title" { title += string }; if field == "link" { link += string } } }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { if let string = String(data: CDATABlock, encoding: .utf8) { self.parser(parser, foundCharacters: string) } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "item" || name == "entry" {
            let url = link.trimmingCharacters(in: .whitespacesAndNewlines)
            if ArticleCandidate.isWebURL(url), !title.isBlank { items.append(.init(sourceID: sourceID, title: title, url: url, revision: nil)) }; inside = false
        }; field = ""
    }
}
