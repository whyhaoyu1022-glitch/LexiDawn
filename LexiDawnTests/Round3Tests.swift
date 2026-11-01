import XCTest
import SwiftData
@testable import LexiDawn

@MainActor final class Round3Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1793534400)
    private func item(raw: String = "The original full article begins here.\n\nThe final paragraph is preserved.", complete: Bool = true, hash: String? = nil) -> FullTextArticleImport {
        FullTextArticleImport(sourceID: "wikipedia", canonicalURL: "https://en.wikipedia.org/wiki/Explicit_test_fixture", title: "Isolated original fixture", author: "Test author", publishedAt: nil, rawContent: raw,
            document: ArticleDocumentNormalizer.plainText(raw), topics: ["test"], rights: ArticleSourceRegistry.wikipediaRights,
            completeDocument: complete, expectedHash: hash, verifiedAt: now)
    }
    func testRSSDescriptionRemainsInMemoryAndCannotBecomeBody() throws {
        let data = Data("<rss><channel><item><title>Fixture &amp; text</title><link>https://example.invalid/a</link><description>Summary only</description></item></channel></rss>".utf8)
        let values = try ArticleFeedParser(sourceID: "disabled-test").parse(data)
        XCTAssertEqual(values.count, 1); XCTAssertEqual(values[0].title, "Fixture & text")
        XCTAssertFalse(ArticleSourceRegistry.enabled(values[0].sourceID))
    }
    func testAtomAlternateLinkAndCDATA() throws {
        let values = try ArticleFeedParser(sourceID: "fixture").parse(Data("<feed xmlns='http://www.w3.org/2005/Atom'><entry><title><![CDATA[A title]]></title><link rel='alternate' href='https://example.invalid/article'/></entry></feed>".utf8))
        XCTAssertEqual(values.first?.url, "https://example.invalid/article")
    }
    func testMalformedFeedFailsAndEmptyFeedHasNoCandidate() throws {
        XCTAssertThrowsError(try ArticleFeedParser(sourceID: "test").parse(Data("<rss>".utf8)))
        XCTAssertEqual(try ArticleFeedParser(sourceID: "test").parse(Data("<rss><channel/></rss>".utf8)).count, 0)
    }
    func testOfficialAPIJSONMapsRevisionWithoutPersistingCandidate() throws {
        let json = #"{"query":{"pages":[{"title":"Fixture","fullurl":"https://en.wikipedia.org/wiki/Fixture","lastrevid":123}]}}"#
        XCTAssertEqual(try OfficialArticleAPI.discovery(Data(json.utf8)).first?.revision, 123)
        XCTAssertThrowsError(try OfficialArticleAPI.discovery(Data("{}".utf8)))
    }
    func testCanonicalURLRetainsSemanticQueryAndRemovesTracking() {
        XCTAssertEqual(ArticleCandidate.normalizeCanonicalURL("HTTPS://Example.COM:443/article/?b=2&utm_source=x&a=1#top"), "https://example.com/article?a=1&b=2")
    }
    func testOriginalSHAIsNotNormalizedOrTruncated() {
        XCTAssertNotEqual(fingerprint("Full article.\n"), fingerprint("Full article."))
        XCTAssertEqual(fingerprint("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func testNormalizerMergesHardLinesAndRetainsParagraphsAndEveryCharacter() {
        let raw = "A hard\nline remains intact.\n\nAnother paragraph.\n- A list item\n> A quotation"
        let document = ArticleDocumentNormalizer.plainText(raw)
        XCTAssertEqual(document.blocks.count, 4)
        XCTAssertEqual(document.blocks[0].text, "A hard line remains intact.")
        XCTAssertEqual(document.blocks[2].kind, .listItem); XCTAssertEqual(document.blocks[3].kind, .quotation)
        XCTAssertTrue(ArticleDocumentNormalizer.preservesOriginal(raw, document: document))
    }
    func testHTMLStructureEntitiesNavigationAndQuotedAngleBrackets() throws {
        let document = try ArticleHTMLExtractor.extract("<nav>Navigation</nav><article><h2>Heading</h2><p title='a > b'>First &amp; final paragraph.</p><blockquote>A quote.</blockquote><ul><li>One</li><li>Two</li></ul></article>")
        XCTAssertEqual(document.blocks.map(\.text), ["Heading", "First & final paragraph.", "A quote.", "One", "Two"])
        XCTAssertEqual(document.blocks.map(\.kind), [.heading, .paragraph, .quotation, .listItem, .listItem])
    }
    func testHTMLMalformedAndUnclosedScriptFailClosed() {
        XCTAssertThrowsError(try ArticleHTMLExtractor.extract("<p title='unterminated>text"))
        XCTAssertThrowsError(try ArticleHTMLExtractor.extract("<script>private data"))
    }
    func testJSONLDRequiresRealArticleBody() throws {
        XCTAssertEqual(try ArticleHTMLExtractor.jsonLD(Data(#"{"@graph":[{"@type":"NewsArticle","articleBody":"Full original text."}]}"#.utf8)), "Full original text.")
        XCTAssertThrowsError(try ArticleHTMLExtractor.jsonLD(Data(#"{"description":"Summary"}"#.utf8)))
    }
    func testRightsAuditHasAllNineCandidatesAndPendingIsDisabled() {
        XCTAssertEqual(ArticleSourceRegistry.audits.count, 9)
        for audit in ArticleSourceRegistry.audits where audit.decision != .approved { XCTAssertFalse(ArticleSourceRegistry.enabled(audit.sourceID)) }
        XCTAssertFalse(ArticleSourceRegistry.enabled("unknown"))
    }
    func testRightsEvidenceMustGrantAllFourPermissions() {
        let proof = FullTextRightsEvidence(id: "unapproved", sourceID: "fixture", termsURL: "https://example.invalid/terms", license: "unknown", attribution: "Fixture", checkedAt: now, acquisitionAllowed: true, persistenceAllowed: true, offlineAllowed: false, displayAllowed: true)
        XCTAssertFalse(proof.valid(sourceID: "fixture", at: now))
    }
    func testURLOnlyEmptyAndPartialBodyNeverPassAdmission() {
        XCTAssertThrowsError(try ArticleQualityValidator.validate(item(raw: ""), at: now))
        XCTAssertThrowsError(try ArticleQualityValidator.validate(item(complete: false), at: now))
        XCTAssertThrowsError(try ArticleQualityValidator.validate(item(raw: "Some preview..."), at: now))
    }
    func testTruncationHashAndPaywallFailWithoutFallback() {
        XCTAssertThrowsError(try ArticleQualityValidator.validate(item(hash: fingerprint("Different full article")), at: now))
        XCTAssertThrowsError(try ArticleQualityValidator.validate(item(raw: "Subscribe to continue reading this story."), at: now))
    }
    func testCompleteOriginalAndStructuredBodyAreAtomicAndDeduplicate() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        XCTAssertTrue(try content.importFullText(item(), at: now)); XCTAssertFalse(try content.importFullText(item(), at: now))
        let records = try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleRecord>())
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.rawContent, item().rawContent); XCTAssertNotNil(record.structuredBody)
        XCTAssertEqual(record.fullTextRightsEvidenceID, item().rights.id)
        XCTAssertEqual(try content.read(articleID: item().articleID, at: now).body, item().rawContent)
    }
    func testFailedTransactionLeavesNeitherBodyNorGrant() throws {
        let app = try AppDependencies.makeLearningInMemory()
        let content = ContentRepository(context: ModelContext(app.modelContainer)) { _ in throw FullTextImportError.storage }
        XCTAssertThrowsError(try content.importFullText(item(), at: now))
        let context = ModelContext(app.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ArticleRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentGrantRecord>()), 0)
    }
    func testInvalidRefreshDoesNotOverwriteLocalFullVersion() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        try content.importFullText(item(), at: now)
        XCTAssertThrowsError(try content.importFullText(item(raw: "Truncated..."), at: now))
        XCTAssertEqual(try content.read(articleID: item().articleID, at: now).body, item().rawContent)
    }
    func testFavoriteAndLaterPersistWithoutCreatingStudyCycle() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        try content.importFullText(item(), at: now)
        try content.setLibraryFlags(articleID: item().articleID, favorite: true, readLater: true)
        let library = try ContentRepository(context: ModelContext(app.modelContainer)).library(at: now)
        XCTAssertEqual(library.first?.favorite, true); XCTAssertEqual(library.first?.readLater, true)
        XCTAssertTrue(try app.cycleRepository.fetchAll().isEmpty)
    }
    func testReaderProjectionPreservesSourceOffsetsAcrossHardWraps() {
        let raw = "First hard\nwrapped sentence.\n\nLast paragraph."
        let projection = ReaderTextProjection(raw: raw)
        XCTAssertTrue(projection.text.contains("hard wrapped"))
        let rawOffset = (raw as NSString).range(of: "Last").location
        let displayed = projection.displayOffset(rawOffset)
        XCTAssertEqual(projection.rawOffset(displayed), rawOffset)
        XCTAssertEqual((projection.text as NSString).substring(with: NSRange(location: displayed, length: 4)), "Last")
    }
    func testComplexFormsAndPhrasesAreEntities() {
        for (surface, lemma) in [("took", "take"), ("taken", "take"), ("looked into", "look into"), ("carried out", "carry out"), ("taking into account", "take into account"), ("played a role in", "play a role in")] { XCTAssertEqual(EnglishTokenizer.lemma(surface), lemma) }
    }
    func testDictionaryMergeKeepsPartsOfSpeechAndAllSourcesDistinct() {
        let a = DictionarySense(id: "a", en: "A financial institution.", zh: "", line: "fixture", partOfSpeech: "noun", sources: ["one"])
        let b = DictionarySense(id: "b", en: a.en, zh: "", line: "fixture", partOfSpeech: "noun", sources: ["two"])
        let c = DictionarySense(id: "c", en: a.en, zh: "", line: "fixture", partOfSpeech: "verb", sources: ["two"])
        let merged = DictionaryAggregator.merge([a, b, c])
        XCTAssertEqual(merged.count, 2); XCTAssertEqual(merged.first { $0.partOfSpeech == "noun" }?.sources, ["one", "two"])
    }
    func testContextRankingUsesRealExistingDefinitions() {
        let river = DictionarySense(id: "z", en: "The land beside a river.", zh: "", line: "fixture", partOfSpeech: "noun")
        let money = DictionarySense(id: "a", en: "A financial institution.", zh: "", line: "fixture", partOfSpeech: "noun")
        XCTAssertEqual(DictionaryAggregator.rank([money, river], context: "We sat beside the river.").first?.id, "z")
    }
    func testEnglishProviderJSONRetainsIPAExamplesAndSource() throws {
        let data = Data(#"[{"word":"book","phonetic":"/bʊk/","license":{"name":"CC BY-SA 3.0","url":"https://creativecommons.org/licenses/by-sa/3.0/"},"meanings":[{"partOfSpeech":"noun","definitions":[{"definition":"A collection of pages.","example":"Read a book.","synonyms":["volume"]}]}]}]"#.utf8)
        let sense = try XCTUnwrap(FreeDictionaryProvider.parse(data).first)
        XCTAssertEqual(sense.ipa, "/bʊk/"); XCTAssertEqual(sense.examples, ["Read a book."]); XCTAssertTrue(sense.zh.isEmpty)
    }
    func testWiktionaryJSONDoesNotInventChinese() throws {
        let data = Data(#"{"en":[{"partOfSpeech":"Verb","definitions":[{"definition":"To <b>reserve</b> a place.","examples":["Please book a seat."]}]}]}"#.utf8)
        let sense = try XCTUnwrap(WiktionaryDictionaryProvider.parse(data).first)
        XCTAssertEqual(sense.en, "To reserve a place."); XCTAssertEqual(sense.partOfSpeech, "verb"); XCTAssertTrue(sense.zh.isEmpty)
    }
    func testSingleProviderFailureDoesNotDiscardSuccess() async {
        struct Failure: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { throw FullTextImportError.transport } }
        struct Success: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { [DictionarySense(id: "fixture", en: "A genuine fixture definition.", zh: "", line: "fixture")] } }
        let result = await DictionaryAggregator(providers: [("failed", Failure()), ("ok", Success())]).lookup("book")
        XCTAssertEqual(result.failed, ["failed"]); XCTAssertEqual(result.senses.count, 1)
    }
    func testVersionedDictionaryCacheDoesNotEraseVocabulary() throws {
        let app = try AppDependencies.makeLearningInMemory(), context = ModelContext(app.modelContainer)
        let cache = DictionaryCacheRepository(context: context)
        try cache.save("book", senses: [DictionarySense(id: "test", en: "A book.", zh: "", line: "English Wiktionary contributors", sources: ["Wiktionary"])], successful: ["Wiktionary"], at: now)
        XCTAssertEqual(try cache.load("book", at: now).senses.count, 1)
        let row = try XCTUnwrap(context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).first)
        row.sourceVersion = "obsolete"; try context.save()
        XCTAssertTrue(try cache.load("book", at: now).senses.isEmpty)
    }
    func testFSRSInitialPublishedVectorsAndForgettingCurve() throws {
        let good = try FSRSScheduler.schedule(stability: nil, difficulty: nil, elapsedDays: 0, grade: .good)
        XCTAssertEqual(good.stability, 3.7145, accuracy: 0.000001); XCTAssertEqual(good.difficulty, 5.1618, accuracy: 0.000001)
        XCTAssertEqual(good.intervalDays, 4)
        XCTAssertEqual(FSRSScheduler.retrievability(elapsedDays: 3.7145, stability: 3.7145), 0.9, accuracy: 0.000001)
        let again = try FSRSScheduler.schedule(stability: nil, difficulty: nil, elapsedDays: 0, grade: .again)
        XCTAssertEqual(again.stability, 0.4872, accuracy: 0.000001); XCTAssertEqual(again.intervalDays, 1)
    }
    func testFSRSLapseCannotIncreaseStabilityAndInvalidStateIsRejected() throws {
        let again = try FSRSScheduler.schedule(stability: 10, difficulty: 5, elapsedDays: 12, grade: .again)
        XCTAssertLessThanOrEqual(again.stability, 10)
        let good = try FSRSScheduler.schedule(stability: 10, difficulty: 5, elapsedDays: 12, grade: .good)
        XCTAssertGreaterThan(good.stability, 10)
        XCTAssertThrowsError(try FSRSScheduler.schedule(stability: .nan, difficulty: 5, elapsedDays: 1, grade: .good))
    }
    func testRound3BackfillIsIdempotentAndKeepsRawArticleAndStudyData() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let id = try content.importArticle(ArticleImportDraft(title: "Own fixture", body: "Full original\ntext.", source: "Test author", rightsConfirmed: true), at: now)
        let context = ModelContext(app.modelContainer), record = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        record.structuredBody = nil; try context.save()
        try content.migrateRound3(at: now); try content.migrateRound3(at: now)
        XCTAssertEqual(try content.read(articleID: id, at: now).body, "Full original\ntext.")
        XCTAssertNotNil(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleRecord>()).first?.structuredBody)
    }
}
