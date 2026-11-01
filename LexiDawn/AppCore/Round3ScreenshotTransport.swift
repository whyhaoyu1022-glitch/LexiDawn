#if DEBUG && targetEnvironment(simulator)
import Foundation

/// Explicit opt-in URLProtocol faults for native UI evidence. Never part of Release or production networking.
final class Round3ScreenshotTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "en.wikipedia.org" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let scenario = ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"] ?? ""
        let mode = scenario.replacingOccurrences(of: "round3-import-", with: "")
        Self.lock.lock(); Self.requests += 1; let count = Self.requests; Self.lock.unlock()
        if mode == "offline" { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let status = mode == "429" ? 429 : mode == "503" ? 503 : mode == "403" ? 403 : mode == "retry" && count == 1 ? 503 : 200
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
    override func stopLoading() { }
    @MainActor static func install(in learning: LearningServices) {
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [Round3ScreenshotTransport.self]
        learning.setDiscoveryForUITesting(ArticleDiscoveryService(content: learning.content, fetcher: ArticleFetchService(configuration: configuration), sourceIDs: ["wikipedia"]))
    }
}
#endif
