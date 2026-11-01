#if DEBUG && targetEnvironment(simulator)
import Foundation

private actor DictionaryComparisonEvidenceProbe {
    static let shared = DictionaryComparisonEvidenceProbe()
    private var attempts: [String: Int] = [:]
    func firstAttempt(source: String) -> Bool { attempts[source, default: 0] += 1; return attempts[source] == 1 }
}
struct DictionaryEvidenceProvider: DictionaryProvider {
    let mode: String, source: String
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        if mode.hasPrefix("comparison-"), headword == "network" {
            if mode == "comparison-loading" { try await Task.sleep(for: .seconds(30)) }
            if mode == "comparison-empty" { return [] }
            if mode == "comparison-failed" { throw URLError(.notConnectedToInternet) }
            if mode == "comparison-retry", await DictionaryComparisonEvidenceProbe.shared.firstAttempt(source: source) { throw URLError(.notConnectedToInternet) }
            return [DictionarySense(id: source + "|explicit-network", en: "Explicit original comparison fixture: connected elements in a system.", zh: "", line: "Explicit original comparison fixture; not production dictionary data.", partOfSpeech: "noun", examples: ["Explicit fixture: a small network connects these rooms."], sources: [source], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/")]
        }
        if mode == "loading" { try await Task.sleep(for: .seconds(30)) }
        if ["all-failed", "offline", "single-failed"].contains(mode) && (mode != "single-failed" || source == "Wiktionary") { throw URLError(.notConnectedToInternet) }
        if mode == "empty" { return [] }
        if mode == "many" {
            return (1...6).map { index in DictionarySense(id: source + "|explicit-many-\(index)", en: "Explicit original definition number \(index) for the dictionary presentation test.", zh: "", line: "Explicit original fixture; not production dictionary content.", partOfSpeech: index <= 3 ? "noun" : "verb", ipa: "/ˈɪntənet/", sources: [source], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/") }
        }
        return Self.senses(source: source)
    }
    static func senses(source: String) -> [DictionarySense] {
        [DictionarySense(id: source + "|explicit-evidence", en: "An interconnected system of networks.", zh: "", line: "Explicit original dictionary UI fixture; not production dictionary data.", partOfSpeech: "noun", ipa: "/ˈɪntənet/", examples: ["Explicit fixture: the Internet connects networks."], synonyms: ["network"], sources: [source], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/")]
    }
    @MainActor static func install(mode: String, learning: LearningServices) throws {
        let names = Array(DictionaryAggregator.versions.keys).sorted()
        let cached = ["offline", "cache"].contains(mode) ? names.flatMap { senses(source: $0) } : []
        try learning.dictionary.configureDictionaryEvidence(providers: names.map { ($0, DictionaryEvidenceProvider(mode: mode, source: $0)) }, cachedSenses: cached, stale: mode == "offline")
    }
}

/// Explicit opt-in URLProtocol faults for native UI evidence. Never part of Release or production networking.
final class Round3ScreenshotTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var requests = 0
    private let stateLock = NSLock()
    private var stopped = false
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "en.wikipedia.org" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"] == "round3-import-loading" {
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in self?.deliver() }
        } else { deliver() }
    }
    private func deliver() {
        stateLock.lock(); let active = !stopped; stateLock.unlock(); guard active else { return }
        let scenario = ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"] ?? ""
        let mode = scenario.replacingOccurrences(of: "round3-import-", with: "")
        Self.lock.lock(); Self.requests += 1; let count = Self.requests; Self.lock.unlock()
        if mode == "offline" { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let status = mode == "429" ? 429 : mode == "503" ? 503 : mode == "403" ? 403 : mode == "404" ? 404 : mode == "retry" && count == 1 ? 503 : 200
        let action = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value
        let payload: [String: Any]
        if action == "query" {
            let pages: [[String: Any]] = mode == "empty" ? [] : [["title": "Explicit fixture article (not production)", "fullurl": "https://en.wikipedia.org/wiki/LexiDawn_explicit_test_fixture", "lastrevid": 1]]
            payload = ["query": ["pages": pages]]
        } else {
            let body: String
            switch mode {
            case "rights": body = "<div class='mw-parser-output'><p>Copyright violation warning. This candidate must be discarded.</p></div>"
            case "parse": body = "<div class='mw-parser-output'><p title='unterminated>Incomplete markup"
            case "truncated": body = "<div class='mw-parser-output'><p>This is only a preview...</p></div>"
            case "summary": body = "<div><p>Summary only, without a full document receipt.</p></div>"
            default: body = "<div class='mw-parser-output'><h2>Explicit original test fixture</h2><p>A book explains science and helps people learn. This complete article is original test writing, never production content.</p><p>The final paragraph remains fully preserved in the local database.</p></div>"
            }
            payload = ["parse": ["text": body, "revid": 1]]
        }
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json", "Retry-After": "0"]), let data = try? JSONSerialization.data(withJSONObject: payload) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { stateLock.lock(); stopped = true; stateLock.unlock() }
    @MainActor static func install(in learning: LearningServices, content: ContentRepository? = nil) {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [Round3ScreenshotTransport.self]
        learning.setDiscoveryForUITesting(ArticleDiscoveryService(content: content ?? learning.content, fetcher: ArticleFetchService(configuration: configuration), sourceIDs: ["wikipedia"]))
    }
}
#endif
