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
    func fetch(_ url: URL, allowedHost: String) async throws -> Data { try await fetch(url, allowedHosts: [allowedHost]) }
    func fetch(_ url: URL, allowedHosts: Set<String>) async throws -> Data {
        guard url.scheme == "https", allowedHosts.contains(url.host ?? ""), url.user == nil, url.password == nil else { throw FullTextImportError.transport }
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let delay = max(0, nextRequestAt.timeIntervalSinceNow)
            nextRequestAt = max(Date(), nextRequestAt).addingTimeInterval(1)
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("LexiDawn/0.3 (personal offline reader; https://github.com/whyhaoyu1022-glitch/LexiDawn)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json, application/xml, text/html;q=0.8", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request, delegate: ArticleRedirectGuard(hosts: allowedHosts))
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse, allowedHosts.contains(http.url?.host ?? "") else { throw FullTextImportError.transport }
                if (http.statusCode == 429 || (500...599).contains(http.statusCode)), attempt < 2 {
                    let delay = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? pow(2, Double(attempt + 1))
                    // Long server backoff is not silently shortened. Let the caller retry later.
                    guard delay <= 30 else { throw FullTextImportError.rateLimited }
                    try await Task.sleep(for: .seconds(max(1, delay))); continue
                }
                guard http.statusCode == 200 else {
                    let sourceID = ArticleSourceRegistry.personalSources.first { $0.hosts.contains(url.host ?? "") }?.id ?? (url.host ?? "unknown")
                    print("ARTICLE_HTTP_DIAGNOSTIC sourceID=\(sourceID) status=\(http.statusCode) attempt=\(attempt + 1)")
                    throw http.statusCode == 429 ? FullTextImportError.rateLimited : FullTextImportError.transport
                }
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
struct ArticleDiscoveryItem: Sendable { let sourceID: String, title: String, url: String, revision: Int?; var createdAt: Date? = nil }

enum OfficialArticleAPI {
    static func url(host: String, fields: [String: String]) throws -> URL {
        var components = URLComponents(); components.scheme = "https"; components.host = host; components.path = "/w/api.php"
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw FullTextImportError.transport }; return url
    }
    static func discovery(_ data: Data, sourceID: String = "wikipedia") throws -> [ArticleDiscoveryItem] {
        struct Response: Decodable { struct Query: Decodable { let pages: [Page] }; struct Page: Decodable { let title: String; let fullurl: String; let lastrevid: Int; let revisions: [Revision]?; struct Revision: Decodable { let timestamp: String } }; let query: Query }
        return try JSONDecoder().decode(Response.self, from: data).query.pages.map { .init(sourceID: sourceID, title: $0.title, url: $0.fullurl, revision: $0.lastrevid, createdAt: $0.revisions?.first.flatMap { ISO8601DateFormatter().date(from: $0.timestamp) }) }
    }
}

@MainActor final class ArticleDiscoveryService {
    private let fetcher: ArticleFetchService
    private let content: ContentRepository
    private let sourceIDs: [String]
    private var refreshing = false
    init(content: ContentRepository, fetcher: ArticleFetchService = ArticleFetchService(), sourceIDs: [String]? = nil) {
        self.content = content; self.fetcher = fetcher
        self.sourceIDs = sourceIDs ?? (["wikipedia", "wikinews"] + ArticleSourceRegistry.personalSources.map(\.id))
    }
    private struct Outcome: Sendable { let sourceID: String, count: Int, succeeded: Bool, error: FullTextImportError? }
    func refresh(force: Bool = false, at now: Date = Date(), onImport: (@MainActor () -> Void)? = nil) async throws -> Int {
        guard !refreshing else { return 0 }
        refreshing = true; defer { refreshing = false }
        let ids = sourceIDs.filter(ArticleSourceRegistry.canAttempt)
        var total = 0, successes = 0, failures: [FullTextImportError] = []
        // At most three source pipelines run concurrently. One source cannot suppress another.
        try await withThrowingTaskGroup(of: Outcome.self) { group in
            var next = 0
            func enqueue(_ id: String) { group.addTask { @MainActor [self] in
                try await refreshSource(id, force: force, at: now, onImport: onImport)
            } }
            while next < min(3, ids.count) { enqueue(ids[next]); next += 1 }
            while let outcome = try await group.next() {
                total += outcome.count; if outcome.succeeded { successes += 1 }
                if let error = outcome.error { failures.append(error) }
                print("ARTICLE_SOURCE_RESULT sourceID=\(outcome.sourceID) imported=\(outcome.count) status=\(outcome.error?.rawValue ?? (outcome.succeeded ? "success" : "fresh-or-backoff"))")
                if next < ids.count { enqueue(ids[next]); next += 1 }
            }
        }
        if total == 0 && successes == 0, let error = failures.first { throw error }
        return total
    }
    private func refreshSource(_ id: String, force: Bool, at now: Date, onImport: (@MainActor () -> Void)?) async throws -> Outcome {
        do {
            let stored = try content.sourceRefreshState(id)
            if !force, let success = stored.success, now.timeIntervalSince(success) < 3600 { return Outcome(sourceID: id, count: 0, succeeded: false, error: nil) }
            if let retry = stored.retryAfter, retry > now { return Outcome(sourceID: id, count: 0, succeeded: false, error: force ? .rateLimited : nil) }
            try content.recordSourceRefresh(id, beginning: true, at: now)
            let count: Int
            if id == "wikipedia" || id == "wikinews" { count = try await importWikimedia(id, at: now, onImport: onImport) }
            else if let source = ArticleSourceRegistry.personalSource(id) { count = try await importPublisher(source, at: now, onImport: onImport) }
            else { throw FullTextImportError.rights }
            try content.recordSourceRefresh(id, beginning: false, at: now)
            return Outcome(sourceID: id, count: count, succeeded: true, error: nil)
        } catch is CancellationError { throw CancellationError() }
        catch {
            let code = (error as? FullTextImportError) ?? .transport
            try content.recordSourceRefresh(id, beginning: false, errorCode: code.rawValue, at: now)
            return Outcome(sourceID: id, count: 0, succeeded: false, error: code)
        }
    }
    private func importWikimedia(_ id: String, at now: Date, onImport: (@MainActor () -> Void)?) async throws -> Int {
        let host = id == "wikinews" ? "en.wikinews.org" : "en.wikipedia.org"
        // Revisions rvlimit/rvdir are single-page parameters; a category generator is multi-page.
        var fields = ["action": "query", "format": "json", "formatversion": "2", "generator": "categorymembers", "gcmtitle": id == "wikinews" ? "Category:Published" : "Category:Featured_articles", "gcmlimit": "3", "gcmnamespace": "0", "prop": "info", "inprop": "url"]
        if id == "wikinews" { fields["gcmsort"] = "timestamp"; fields["gcmdir"] = "desc" }
        let endpoint = try OfficialArticleAPI.url(host: host, fields: fields)
        let candidates = try OfficialArticleAPI.discovery(await fetcher.fetch(endpoint, allowedHost: host), sourceID: id)
        var count = 0, failures = 0
        for candidate in candidates {
            try Task.checkCancellation()
            do {
                guard let revision = candidate.revision, let rights = ArticleSourceRegistry.evidence(for: id) else { throw FullTextImportError.incomplete }
                var createdAt = candidate.createdAt
                if id == "wikinews" {
                    let createdURL = try OfficialArticleAPI.url(host: host, fields: ["action": "query", "format": "json", "formatversion": "2", "titles": candidate.title, "prop": "revisions", "rvprop": "timestamp", "rvlimit": "1", "rvdir": "newer"])
                    struct Creation: Decodable { struct Query: Decodable { struct Page: Decodable { struct Revision: Decodable { let timestamp: String }; let revisions: [Revision] }; let pages: [Page] }; let query: Query }
                    let response = try JSONDecoder().decode(Creation.self, from: await fetcher.fetch(createdURL, allowedHost: host))
                    createdAt = response.query.pages.first?.revisions.first.flatMap { ISO8601DateFormatter().date(from: $0.timestamp) }
                    guard let createdAt, createdAt >= Date(timeIntervalSince1970: 1734393600) else { throw FullTextImportError.rights }
                }
                let url = try OfficialArticleAPI.url(host: host, fields: ["action": "parse", "format": "json", "formatversion": "2", "oldid": String(revision), "prop": "text|revid|displaytitle", "disableeditsection": "1", "disabletoc": "1"])
                let data = try await fetcher.fetch(url, allowedHost: host)
                struct Response: Decodable { struct Page: Decodable { let text: String; let revid: Int }; let parse: Page }
                let page = try JSONDecoder().decode(Response.self, from: data).parse
                guard page.revid == revision, page.text.contains("mw-parser-output"), !["copyright violation", "non-free content", "additional attribution"].contains(where: page.text.lowercased().contains) else { throw FullTextImportError.rights }
                let document = try ArticleHTMLExtractor.extract(page.text)
                let item = FullTextArticleImport(sourceID: id, canonicalURL: candidate.url, title: candidate.title, author: ArticleSourceRegistry.name(id) + " contributors", publishedAt: createdAt,
                    rawContent: document.text, document: document, topics: id == "wikinews" ? ["新闻"] : ["知识"], rights: rights, completeDocument: true, expectedHash: nil, verifiedAt: now)
                if try content.importFullText(item, at: now) { count += 1; onImport?() }
            } catch is CancellationError { throw CancellationError() }
            catch { failures += 1 }
        }
        if failures > 0 && count == 0 { throw FullTextImportError.incomplete }
        return count
    }
    private func importPublisher(_ source: PublisherArticleSource, at now: Date, onImport: (@MainActor () -> Void)?) async throws -> Int {
        guard let endpoint = URL(string: source.discoveryURL), let host = endpoint.host, let rights = ArticleSourceRegistry.evidence(for: source.id) else { throw FullTextImportError.transport }
        let data = try await fetcher.fetch(endpoint, allowedHosts: source.hosts.union([host]))
        let candidates: [ArticleDiscoveryItem]
        switch source.discovery {
        case .feed: candidates = try ArticleFeedParser(sourceID: source.id).parse(data)
        case .links: candidates = try ArticleWebPageExtractor.links(data, source: source)
        }
        var count = 0, failures = 0
        let eligible = candidates.compactMap { candidate -> ArticleDiscoveryItem? in
            guard var components = URLComponents(string: candidate.url) else { return nil }
            if components.scheme == "http" { components.scheme = "https" }
            guard let url = components.url, ArticleWebPageExtractor.accepts(url, source: source) else { return nil }
            return ArticleDiscoveryItem(sourceID: candidate.sourceID, title: candidate.title, url: url.absoluteString, revision: candidate.revision)
        }
        print("ARTICLE_DISCOVERY_DIAGNOSTIC sourceID=\(source.id) candidates=\(candidates.count) eligible=\(eligible.count)")
        for candidate in eligible.prefix(3) {
            try Task.checkCancellation()
            do {
                guard let url = URL(string: candidate.url) else { throw FullTextImportError.transport }
                let bytes = try await fetcher.fetch(url, allowedHosts: source.hosts)
                let result = try ArticleWebPageExtractor.extract(bytes, candidate: candidate, source: source)
                let item = FullTextArticleImport(sourceID: source.id, canonicalURL: result.canonicalURL, title: result.title, author: result.author, publishedAt: result.publishedAt,
                    rawContent: result.document.text, document: result.document, topics: source.topics, rights: rights, completeDocument: true, expectedHash: nil, verifiedAt: now)
                if try content.importFullText(item, at: now) { count += 1; onImport?() }
            } catch is CancellationError { throw CancellationError() }
            catch { failures += 1 }
        }
        if failures > 0 && count == 0 { throw FullTextImportError.incomplete }
        return count
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

private final class ArticleRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let hosts: Set<String>
    init(hosts: Set<String>) { self.hosts = hosts }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let permitted = request.url.map { $0.scheme == "https" && hosts.contains($0.host ?? "") && $0.user == nil && $0.password == nil } ?? false
        completionHandler(permitted ? request : nil)
    }
}
