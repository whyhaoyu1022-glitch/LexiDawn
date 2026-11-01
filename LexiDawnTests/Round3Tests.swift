import XCTest
import SwiftData
@testable import LexiDawn

@MainActor final class Round3Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1793534400)
    private var webBody: String { (1...3).map { "<p>Paragraph \($0) is explicit original fixture writing. Science helps people understand nature and share discoveries. Every sentence in this complete document is preserved for a deterministic parser test, including the final sentence.</p>" }.joined() }
    func testPersonalSourceInstructionNeverMasqueradesAsPublisherLicense() throws {
        XCTAssertFalse(ArticleSourceRegistry.enabled("bbc")); XCTAssertTrue(ArticleSourceRegistry.canAttempt("bbc"))
        let proof = try XCTUnwrap(ArticleSourceRegistry.evidence(for: "bbc"))
        XCTAssertEqual(proof.importBasis, "owner-directed-personal-use-2026-11-01")
        XCTAssertTrue(proof.license.contains("未声明出版社授权")); XCTAssertNil(ArticleSourceRegistry.evidence(for: "unknown"))
    }
    func testPublisherSubtreeRetainsFinalParagraphAndRejectsPageNavigation() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("nasa"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.nasa.gov/news-release/fixture/", revision: nil)
        let html = "<html><head><meta property='og:title' content='Original title'></head><body><nav>Do not import navigation.</nav><div class='entry-content'>" + webBody + "</div><footer>Do not import footer.</footer></body></html>"
        let result = try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source)
        XCTAssertEqual(result.title, "Original title"); XCTAssertEqual(result.document.blocks.count, 3)
        XCTAssertTrue(result.document.text.hasSuffix("including the final sentence.")); XCTAssertFalse(result.document.text.contains("navigation")); XCTAssertFalse(result.document.text.contains("footer"))
    }
    func testPublisherMissingClosingBodyAndTruncatedPageAreRejected() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("nasa"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.nasa.gov/news-release/fixture/", revision: nil)
        for html in ["<html><div class='entry-content'>" + webBody, "<html><div class='entry-content'><p>Summary only.</p></div></html>", "<html><div class='entry-content'>" + webBody + "</html>"] {
            XCTAssertThrowsError(try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source))
        }
    }
    func testPublisherLoginCaptchaAndPaywallNeverBecomeArticle() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("nasa"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.nasa.gov/news-release/fixture/", revision: nil)
        for marker in ["Verify you are human", "Sign in to continue reading", "Subscribe to continue reading"] {
            let html = "<html><div class='entry-content'>" + webBody + "<p>" + marker + "</p></div></html>"
            XCTAssertThrowsError(try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source))
        }
        let html = "<html><script type='application/ld+json'>{\"@type\":\"NewsArticle\",\"isAccessibleForFree\":false}</script><div class='entry-content'>" + webBody + "</div></html>"
        XCTAssertThrowsError(try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source))
    }
    func testBBCMultipleBodyBlocksKeepEveryParagraphInOrder() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("bbc"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.bbc.com/news/articles/fixture", revision: nil)
        let html = "<html>" + (1...3).map { "<div data-component='text-block'><p>Block \($0). This original fixture paragraph discusses science and education. Reading each full paragraph provides a meaningful context for learning English words and expressions without substituting a summary for the original article.</p></div>" }.joined() + "</html>"
        let result = try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source)
        XCTAssertEqual(result.document.blocks.count, 3); XCTAssertTrue(result.document.blocks[0].text.hasPrefix("Block 1.")); XCTAssertTrue(result.document.blocks[2].text.hasPrefix("Block 3."))
    }
    func testPublisherDiscoveryRejectsExternalAndNonArticleLinks() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("voa"))
        let html = "<html><a href='/a/original/1234567.html'>Original title</a><a href='/a/original/1234567.html'>Duplicate</a><a href='https://evil.invalid/a/leak/123.html'>External</a><a href='/login'>Login</a></html>"
        let items = try ArticleWebPageExtractor.links(Data(html.utf8), source: source)
        XCTAssertEqual(items.count, 1); XCTAssertEqual(items.first?.title, "Original title")
    }
    func testPersonalFullTextImportPersistsExplicitBasisAndRejectsForgedEvidence() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let proof = try XCTUnwrap(ArticleSourceRegistry.evidence(for: "bbc")), raw = "Original complete personal article.\n\nThe final paragraph remains preserved."
        let item = FullTextArticleImport(sourceID: "bbc", canonicalURL: "https://www.bbc.com/news/articles/explicit-fixture", title: "Explicit fixture", author: "Fixture author", publishedAt: nil, rawContent: raw, document: ArticleDocumentNormalizer.plainText(raw), topics: ["test"], rights: proof, completeDocument: true, expectedHash: fingerprint(raw), verifiedAt: now)
        XCTAssertTrue(try content.importFullText(item, at: now)); XCTAssertEqual(try content.read(articleID: item.articleID, at: now).body, raw)
        let record = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleRecord>()).first)
        XCTAssertEqual(try JSONDecoder().decode(FullTextRightsEvidence.self, from: XCTUnwrap(record.fullTextRightsEvidenceData)).importBasis, proof.importBasis)
    }
    func testWikinewsLegacyDateCannotUseNewLicense() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content), raw = "Full original text."
        let item = FullTextArticleImport(sourceID: "wikinews", canonicalURL: "https://en.wikinews.org/wiki/Explicit_fixture", title: "Explicit fixture", author: "Wikinews", publishedAt: Date(timeIntervalSince1970: 1700000000), rawContent: raw, document: ArticleDocumentNormalizer.plainText(raw), topics: ["test"], rights: ArticleSourceRegistry.wikinewsRights, completeDocument: true, expectedHash: nil, verifiedAt: now)
        XCTAssertThrowsError(try content.importFullText(item, at: now)); XCTAssertTrue(try content.library().isEmpty)
    }
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
    func testCompletedMeaningCannotBeConsumedByAnotherQuestion() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(ArticleImportDraft(title: "Own fixture", body: "A book explains science.", source: "Test author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected real saved cycle") }
        for (word, meaning) in [("book", "书（个人释义）"), ("science", "科学（个人释义）")] {
            let addition = try XCTUnwrap(learning.vocabulary.add(token: EnglishToken(surface: word, range: NSRange(location: 0, length: word.count), sentence: "A book explains science."), articleID: id, autoAdd: true, at: now))
            try learning.vocabulary.annotate(entryID: addition.entryID, meaning: meaning, notes: "", at: now)
        }
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 2, pairCount: 2, clozeCount: 2, at: now)
        let questions = try XCTUnwrap(prepared).matching
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: questions[0].id, answer: questions[0].senseID, at: now))
        XCTAssertThrowsError(try learning.review.submit(cycleID: cycle.cycleID, questionID: questions[1].id, answer: questions[0].senseID, at: now))
        XCTAssertEqual(try learning.review.session(cycleID: cycle.cycleID)?.matching.first { $0.id == questions[1].id }?.attempts, 0)
    }
    func testHistoricalRound2DiskSchemaMigratesLearningRelationsAndFullText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store"), articleID = UUID().uuidString
        let raw = "A complete historical article.\n\nIts final paragraph remains preserved."
        let cycle = try DailyStudyCycle(assignedLocalDate: "2026-11-01", assignedTimeZoneID: "Asia/Shanghai", articleID: articleID, createdAtUTC: now, updatedAtUTC: now, assignmentReason: "historical-fixture")
        var entryID = "", sessionID = ""
        do {
            let container = try ModelContainer(for: FrozenRound2Schema.schema, configurations: [ModelConfiguration(url: url)])
            let context = ModelContext(container)
            let article = FrozenRound2Schema.ArticleRecord(articleID: articleID, canonicalURL: "lexidawn-local://article/\(articleID)", originalTitle: "Historical original", sourceID: "user-import", fetchedAt: now, licenseID: "user-declared-local-use", licenseVerified: true, bodyText: raw, bodyHash: fingerprint(raw), contentStatus: "available", createdAt: now, updatedAt: now)
            article.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.persistent); article.sourceAttribution = "Historical local author"; article.fullTextDisplayAllowed = true; article.topicTags = ["test"]
            context.insert(article); context.insert(try FrozenRound2Schema.DailyStudyCycleRecord(cycle: cycle))
            context.insert(FrozenRound2Schema.ContentGrantRecord(articleID: articleID, sourceID: "user-import", bodyHash: fingerprint(raw), scope: "user-local", evidenceURL: "local-user-confirmation", originalURL: nil, acceptedAt: now, eligibleForDaily: true))
            let progress = FrozenRound2Schema.ArticleProgressRecord(articleID: articleID, cycleID: cycle.cycleID, bodyHash: fingerprint(raw), at: now); progress.readingPercent = 0.4; progress.characterOffset = 12; context.insert(progress)
            let entry = FrozenRound2Schema.VocabularyEntryRecord(lemma: "book", surface: "book", type: "word", at: now, from: articleID, token: "historical-token")
            entry.userMeaning = "个人释义"; entry.notes = "保留笔记"; entryID = entry.entryID; context.insert(entry)
            context.insert(FrozenRound2Schema.ReviewStateRecord(entryID: entryID, at: now))
            let session = FrozenRound2Schema.ReviewSessionRecord(cycleID: cycle.cycleID, entries: [entryID], at: now, limit: 12); sessionID = session.sessionID; context.insert(session)
            context.insert(FrozenRound2Schema.ReviewExerciseRecord(sessionID: sessionID, entryID: entryID, stage: "matching", position: 0, prompt: "book", answer: "个人释义", senseID: "user"))
            context.insert(FrozenRound2Schema.ReviewExerciseRecord(sessionID: sessionID, entryID: entryID, stage: "cloze", position: 0, prompt: "bo__", answer: "book", senseID: "user"))
            let preferences = FrozenRound2Schema.UserPreferencesRecord(); preferences.displayName = "Historical reader"; context.insert(preferences)
            try context.save()
        }
        let container = try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url))
        let context = ModelContext(container), content = ContentRepository(context: context)
        try content.migrateRound3(at: now)
        XCTAssertEqual(try content.read(articleID: articleID, at: now).body, raw)
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first?.notes, "保留笔记")
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first?.entryID, entryID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first?.sessionID, sessionID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewExerciseRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewStateRecord>()).first?.algorithmVersion, BasicReviewScheduler.version)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ArticleProgressRecord>()).first?.readingPercent, 0.4)
        XCTAssertEqual(try StudyCycleRepository(context: context).fetchAll().first?.cycleID, cycle.cycleID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserPreferencesRecord>()).first?.displayName, "Historical reader")
        XCTAssertFalse(try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first).isFavorite)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("before-round3").path))
    }
    func testLegacyUnavailableRowIsArchivedWithoutLosingCycleReference() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(ArticleImportDraft(title: "Own historical fixture", body: "Complete historical original.", source: "Test author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let context = ModelContext(app.modelContainer), record = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        record.bodyText = nil; record.structuredBody = nil; record.contentStatus = "unavailable"; try context.save()
        try learning.content.archiveLegacyIncompleteArticles(at: now)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ArticleRecord>()), 0)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ArticleHistoryArchiveRecord>()), 1)
        XCTAssertTrue(try learning.content.library(at: now).isEmpty)
        XCTAssertEqual(try learning.cycles.fetchAll().first?.cycleID, cycle.cycleID)
        XCTAssertEqual(try learning.cycles.fetchAll().first?.articleTaskStatus, .ready)
        XCTAssertThrowsError(try learning.content.read(articleID: id, at: now))
    }
    func testCacheCleanupProtectsFavoritePersonalImportAndVocabularyContext() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        try learning.content.importFullText(item(), at: now)
        try learning.content.setLibraryFlags(articleID: item().articleID, favorite: true)
        XCTAssertEqual(try learning.content.clearUnusedArticleCache(), 0)
        try learning.content.setLibraryFlags(articleID: item().articleID, favorite: false)
        _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: item().articleID, autoAdd: true, at: now)
        XCTAssertEqual(try learning.content.clearUnusedArticleCache(), 0)
        _ = try learning.content.importArticle(ArticleImportDraft(title: "User owned", body: "User owned complete original.", source: "Test author", rightsConfirmed: true), at: now)
        XCTAssertEqual(try learning.content.clearUnusedArticleCache(), 0)
        _ = try learning.dictionary.clearCaches()
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
    }
    func testUnreferencedOfficialCacheIsRemovedAtomicallyWithoutCreatingCycle() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        try learning.content.importFullText(item(), at: now)
        XCTAssertEqual(try learning.content.clearUnusedArticleCache(), 1)
        XCTAssertTrue(try learning.content.library(at: now).isEmpty)
        XCTAssertTrue(try learning.cycles.fetchAll().isEmpty)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ContentGrantRecord>()), 0)
    }

}
