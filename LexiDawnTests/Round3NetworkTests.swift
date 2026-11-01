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
    // These tests use real external services, separately named from injected/fixture tests.
    func testLiveFreeDictionaryEnglishDefinition() async throws {
        let senses = try await FreeDictionaryProvider().lookup("book")
        XCTAssertTrue(senses.contains { $0.partOfSpeech == "noun" && !$0.en.isBlank })
    }
    func testLiveWiktionaryEnglishDefinition() async throws {
        let senses = try await WiktionaryDictionaryProvider().lookup("book")
        XCTAssertTrue(senses.contains { $0.partOfSpeech == "noun" && !$0.en.isBlank })
    }
    func testLiveWikipediaDiscoveryImportsCompleteOriginalIntoEmptyDatabase() async throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let count = try await ArticleDiscoveryService(content: content).refresh(force: true)
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
