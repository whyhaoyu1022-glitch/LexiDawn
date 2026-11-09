import XCTest
@testable import LexiDawn

private final class Round3FaultURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@MainActor final class Round3NetworkTests: XCTestCase {
    override func tearDown() { Round3FaultURLProtocol.handler = nil; super.tearDown() }
    private func client(status: Int = 200, data: Data = Data("{}".utf8)) -> ArticleFetchService {
        Round3FaultURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json", "Retry-After": "0"])!, data)
        }
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [Round3FaultURLProtocol.self]
        return ArticleFetchService(configuration: configuration)
    }
    func testInjectedSuccessfulTransportReturnsExactBytesWithoutDiskCache() async throws {
        let bytes = Data("Full response fixture".utf8)
        let result = try await client(data: bytes).fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid")
        XCTAssertEqual(result, bytes)
    }
    func testInjected403IsDiscardedWithGenericError() async {
        do { _ = try await client(status: 403).fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid"); XCTFail("403 must fail") }
        catch { XCTAssertEqual(error.localizedDescription, FullTextImportError.transport.localizedDescription); XCTAssertFalse(error.localizedDescription.contains("fixture.invalid")) }
    }
    func testInjectedDictionary404IsARevalidatedEmptyResultNotFabricatedDefinition() async throws {
        let fetcher = client(status: 404)
        var requests: [URLRequest] = []
        Round3FaultURLProtocol.handler = { request in
            requests.append(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!, Data("Explicit unknown-word fixture".utf8))
        }
        let provider = FreeDictionaryProvider(fetcher: fetcher)
        let result = try await provider.lookup("explicit-unknown-fixture")
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(requests.count, 3)
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Cache-Control"))
        XCTAssertTrue(requests.dropFirst().allSatisfy { $0.value(forHTTPHeaderField: "Cache-Control") == "no-cache, max-age=0" && $0.value(forHTTPHeaderField: "Pragma") == "no-cache" })
        XCTAssertEqual(Set(requests.compactMap(\.url)).count, 1)
    }
    func testInjectedDictionaryNegativeCacheRevalidationReturnsOnlyRealResponseDefinitions() async throws {
        let fetcher = client()
        var requests: [URLRequest] = []
        let response = Data(#"[{"word":"book","meanings":[{"partOfSpeech":"noun","definitions":[{"definition":"Explicit original provider fixture definition."}]}]}]"#.utf8)
        Round3FaultURLProtocol.handler = { request in
            requests.append(request)
            let revalidated = request.value(forHTTPHeaderField: "Cache-Control") == "no-cache, max-age=0" && request.value(forHTTPHeaderField: "Pragma") == "no-cache"
            return (HTTPURLResponse(url: request.url!, statusCode: revalidated ? 200 : 404, httpVersion: "HTTP/1.1", headerFields: nil)!, revalidated ? response : Data("Explicit cached-negative fixture".utf8))
        }
        let senses = try await FreeDictionaryProvider(fetcher: fetcher).lookup("book")
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(Set(requests.compactMap(\.url)).count, 1)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.dictionaryapi.dev/api/v2/entries/en/book")
        XCTAssertEqual(senses.map(\.en), ["Explicit original provider fixture definition."])
        XCTAssertEqual(senses.first?.partOfSpeech, "noun")
        XCTAssertEqual(senses.first?.sources, ["Free Dictionary API"])
    }
    func testCancelledDictionaryLookupDoesNotStartRequestsOrReturnEmptySuccess() async {
        let fetcher = client()
        var count = 0
        Round3FaultURLProtocol.handler = { request in
            count += 1
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!, Data("Explicit fixture".utf8))
        }
        let task = Task { try await FreeDictionaryProvider(fetcher: fetcher).lookup("book") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation cannot become an empty successful lookup") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(count, 0)
    }
    func testConcurrentRefreshJoinsOneOperationAndReportsSameCommittedImport() async throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        Round3FaultURLProtocol.handler = { request in
            let action = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "action" }?.value
            let object: [String: Any] = action == "query" ? ["query": ["pages": [["title": "Explicit concurrent fixture", "fullurl": "https://en.wikipedia.org/wiki/Explicit_concurrent_fixture", "lastrevid": 1]]]] : ["parse": ["revid": 1, "text": "<div class='mw-parser-output'><p>Complete original fixture writing for a concurrent import test.</p><p>The final paragraph remains preserved.</p></div>"]]
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, try JSONSerialization.data(withJSONObject: object))
        }
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [Round3FaultURLProtocol.self]
        let service = ArticleDiscoveryService(content: content, fetcher: ArticleFetchService(configuration: configuration), sourceIDs: ["wikipedia"])
        async let first = service.refresh(force: true)
        async let second = service.refresh(force: true)
        let values = try await (first, second)
        XCTAssertEqual(values.0, 1); XCTAssertEqual(values.1, 1)
        XCTAssertEqual(try content.library().count, 1)
    }
    func testInjected429RetryIsBoundedAndStillFails() async {
        let transport = client(status: 429)
        do { _ = try await transport.fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid"); XCTFail("429 must not return success") }
        catch { XCTAssertEqual(error as? FullTextImportError, .rateLimited) }
    }
    func testDisallowedHostDoesNotStartNetwork() async {
        do { _ = try await client().fetch(URL(string: "https://private.invalid/api")!, allowedHost: "fixture.invalid"); XCTFail("Host mismatch must fail") }
        catch { XCTAssertEqual(error as? FullTextImportError, .transport) }
    }
    func testCancelledRequestNeverBecomesSuccessfulImport() async {
        let transport = client()
        let task = Task { try Task.checkCancellation(); return try await transport.fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled task must throw") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testInjectedEveryConfiguredSourceDiscardsTransportAndMalformedDiscoveryWithoutResidue() async throws {
        let ids = ["wikipedia", "wikinews"] + ArticleSourceRegistry.personalSources.map(\.id)
        for id in ids {
            for (status, bytes) in [(403, Data("Forbidden explicit fixture".utf8)), (404, Data("Missing explicit fixture".utf8)), (200, Data("<rss><channel><item>Explicit malformed fixture".utf8))] {
                let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
                let service = ArticleDiscoveryService(content: content, fetcher: client(status: status, data: bytes), sourceIDs: [id])
                do { let count = try await service.refresh(force: true); XCTAssertEqual(count, 0); if status != 200 { XCTFail("Injected transport fault must not claim success: \(id) / \(status)") } }
                catch { XCTAssertEqual(error.localizedDescription, "无法导入完整文章，未添加到本地文章库。") }
                XCTAssertTrue(try content.library().isEmpty, "Rejected source must not leave any visible candidate: " + id)
                XCTAssertTrue(try app.articleRepository.allArticleIDs().isEmpty, "Rejected source must not create ArticleRecord: " + id)
            }
            // A genuine empty official discovery response is not a partially imported article.
            let empty = ["wikipedia", "wikinews"].contains(id) ? Data(#"{"query":{"pages":[]}}"#.utf8) : Data("<html><body></body></html>".utf8)
            let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
            let service = ArticleDiscoveryService(content: content, fetcher: client(data: empty), sourceIDs: [id])
            let count = try await service.refresh(force: true)
            XCTAssertEqual(count, 0); XCTAssertTrue(try app.articleRepository.allArticleIDs().isEmpty)
        }
    }
    func testInjected503AndTimeoutRemainFailuresAfterBoundedRetry() async {
        let unavailable = client(status: 503)
        do { _ = try await unavailable.fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid"); XCTFail("503 must never become success") }
        catch { XCTAssertEqual(error as? FullTextImportError, .transport) }
        let timeout = client()
        Round3FaultURLProtocol.handler = { _ in throw URLError(.timedOut) }
        do { _ = try await timeout.fetch(URL(string: "https://fixture.invalid/api")!, allowedHost: "fixture.invalid"); XCTFail("Timeout must never become success") }
        catch { XCTAssertEqual(error as? FullTextImportError, .transport) }
    }
    // These tests use real external services, separately named from injected/fixture tests.
    func testLivePublisherAdaptersImportAtLeastFiveCompleteSources() async throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let count = try await ArticleDiscoveryService(content: content).refresh(force: true)
        let rows = try content.library(), sources = Set(rows.map(\.sourceID))
        print("LIVE_FULLTEXT_AUDIT sourceIDs=\(sources.sorted().joined(separator: ",")) imported=\(count)")
        XCTAssertEqual(rows.count, count)
        XCTAssertGreaterThanOrEqual(sources.count, 5, "Five real complete source imports are required; blocked candidates cannot be counted")
        for row in rows {
            let article = try content.read(articleID: row.id, at: Date())
            XCTAssertFalse(article.body.isBlank); XCTAssertTrue(ArticleDocumentNormalizer.preservesOriginal(article.body, document: try XCTUnwrap(article.document)))
        }
    }
    func testLiveFreeDictionaryEnglishDefinition() async throws {
        // Historical selector retained; obsolete online probe migrated to real bundled MDX.
        let senses = try await BundledMDXDictionaryProvider().lookup("book")
        XCTAssertTrue(senses.contains { $0.partOfSpeech == "noun" && BilingualMeaningPolicy.trusted($0) && !$0.en.isBlank })
        XCTAssertTrue(senses.allSatisfy { $0.sources == [BundledMDXDictionaryProvider.sourceName] && $0.audioURL == nil })
    }
    func testLiveWiktionaryEnglishDefinition() async throws {
        // Historical selector retained; the only current dictionary is the local MDX.
        let senses = try await BundledMDXDictionaryProvider().lookup("take off")
        XCTAssertFalse(senses.filter(BilingualMeaningPolicy.trusted).isEmpty)
        XCTAssertTrue(senses.allSatisfy { $0.lexicalHeadword == "take off" && $0.sectionKind == "phrasalVerb" })
        XCTAssertEqual(Set(senses.compactMap(\.sourceRevision)), [BundledMDXDictionaryProvider.sourceVersion])
    }
    func testLiveWikipediaDiscoveryImportsCompleteOriginalIntoEmptyDatabase() async throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let count = try await ArticleDiscoveryService(content: content, sourceIDs: ["wikipedia"]).refresh(force: true)
        XCTAssertGreaterThan(count, 0)
        let rows = try content.library()
        XCTAssertTrue(rows.allSatisfy(\.readable)); XCTAssertEqual(rows.count, count)
        for row in rows {
            let article = try content.read(articleID: row.id, at: Date())
            XCTAssertFalse(article.body.isBlank); XCTAssertNotNil(article.document)
            XCTAssertTrue(ArticleDocumentNormalizer.preservesOriginal(article.body, document: try XCTUnwrap(article.document)))
        }
    }
}
