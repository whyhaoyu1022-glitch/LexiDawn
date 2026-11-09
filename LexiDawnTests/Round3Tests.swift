import XCTest
import SwiftData
@testable import LexiDawn

private actor CacheRequestProbe: DictionaryProvider {
    private(set) var requests = 0
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        requests += 1
        throw URLError(.notConnectedToInternet)
    }
}

@MainActor final class Round3Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1793534400)
    func testOwnedStructuredOriginalAndDocumentAreAtomicAndCannotDiverge() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let document = try ArticleHTMLExtractor.extract("<h2>Original heading</h2><blockquote><p>Original quotation.</p></blockquote><ol><li>First original list item.</li></ol>")
        let draft = ArticleImportDraft(title: "Explicit structured fixture", body: document.text, source: "Fixture author", rightsConfirmed: true)
        let id = try learning.content.importArticle(draft, document: document, at: now)
        XCTAssertEqual(try learning.content.read(articleID: id, at: now).document, document)
        XCTAssertThrowsError(try learning.content.importArticle(draft, document: .init(blocks: [.init(kind: .paragraph, text: "A replacement excerpt.")]), at: now))
        let failing = ContentRepository(context: ModelContext(app.modelContainer), saveContext: { _ in throw LearningError.invalid("Explicit fixture save fault") })
        let body = "A different complete original document."
        XCTAssertThrowsError(try failing.importArticle(.init(title: "Another explicit fixture", body: body, source: "Fixture author", rightsConfirmed: true), document: ArticleDocumentNormalizer.plainText(body), at: now))
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ArticleRecord>()), 1)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ContentGrantRecord>()), 1)
    }
    func testPersonalOriginalUpdateKeepsVersionRestoresAnchorAndRollsBackSaveFailure() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let dailyID = try learning.content.importArticle(.init(title: "Explicit daily fixture", body: "A complete daily original article.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: dailyID, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        let old = "Original first paragraph.\n\nA unique original second paragraph remains preserved."
        let id = try learning.content.importArticle(.init(title: "Personal original", body: old, source: "Fixture author", rightsConfirmed: true, eligibleForDaily: false), at: now)
        let paragraph = "A unique original second paragraph remains preserved."
        try learning.reader.save(articleID: id, cycleID: nil, position: .init(percent: 0.5, anchor: fingerprint(paragraph), offset: 27), at: now)
        let updated = "A new original introduction.\n\n" + old
        let draft = ArticleImportDraft(title: "Updated original", body: updated, source: "Fixture author", rightsConfirmed: true, eligibleForDaily: false)
        try learning.content.updateOriginal(articleID: id, draft: draft, at: now)
        let article = try learning.openExplore(articleID: id, at: now), position = try learning.reader.position(article: article, cycleID: nil)
        XCTAssertTrue(position.contentChanged); XCTAssertEqual(position.percent, 0)
        XCTAssertEqual(position.offset, (updated as NSString).range(of: paragraph).location)
        let versions = try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleContentVersionRecord>())
        XCTAssertEqual(versions.count, 1); XCTAssertEqual(versions.first?.rawContent, old)
        XCTAssertThrowsError(try learning.content.updateOriginal(articleID: dailyID, draft: draft, at: now))
        let failing = ContentRepository(context: ModelContext(app.modelContainer), saveContext: { _ in throw LearningError.invalid("Explicit version save fault") })
        XCTAssertThrowsError(try failing.updateOriginal(articleID: id, draft: .init(title: "Failed update", body: "A different complete original that must roll back.", source: "Fixture author", rightsConfirmed: true), at: now))
        XCTAssertEqual(try learning.content.read(articleID: id, at: now).body, updated)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ArticleContentVersionRecord>()), 1)
        XCTAssertEqual(try learning.cycles.fetchAll().count, 1)
    }
    private var webBody: String { (1...3).map { "<p>Paragraph \($0) is explicit original fixture writing. Science helps people understand nature and share discoveries. Every sentence in this complete document is preserved for a deterministic parser test, including the final sentence.</p>" }.joined() }
    func testConfirmedDictionaryMeaningIsUsedAndSavedQuestionCannotBeRewritten() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit sense fixture", body: "We book the room.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let entry = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 3, length: 4), sentence: "We book the room."), articleID: id, autoAdd: true, at: now))
        let context = ModelContext(app.modelContainer)
        context.insert(DictionaryEntryRecord(headword: "book", at: now))
        for (key, en, zh) in [("one", "A collection of pages.", "书（明确原创义项夹具）"), ("two", "To reserve a room.", "预订（明确原创义项夹具）")] {
            let fixture = DictionarySenseRecord(senseID: "cedict-reverse-v1|book|" + key, entryID: "cedict-reverse-v1|book", english: en, chinese: zh, sourceLine: "Explicit original fixture; not dictionary content.")
            fixture.partOfSpeech = key == "one" ? "noun" : "verb"; context.insert(fixture)
        }
        try context.save()
        XCTAssertThrowsError(try learning.vocabulary.confirmReviewMeaning(entryID: entry.entryID, sourceSenseID: "two"))
        try learning.dictionary.recordEmptyEligibilityFixture("book", at: now)
        let personal = PersonalDictionarySense(partOfSpeech: "verb", chinese: "预订（明确原创义项夹具）", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: [personal], at: now)
        try learning.vocabulary.confirmReviewMeaning(entryID: entry.entryID, sourceSenseID: personal.dictionarySense(entryID: entry.entryID).id)
        try confirmOriginalReviewFixtures(learning, at: now)
        _ = try learning.dictionary.clearCaches()
        XCTAssertEqual(try learning.vocabulary.find(surface: "book")?.reviewMeaningText, "预订（明确原创义项夹具）")
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        XCTAssertEqual(prepared?.matching.first?.answer, "预订（明确原创义项夹具）")
        try annotateOriginalFixture(learning, entryID: entry.entryID, meaning: "后来修改的个人释义", notes: "", at: now)
        XCTAssertNil(try learning.vocabulary.find(surface: "book")?.reviewMeaningSenseID)
        XCTAssertEqual(try learning.review.session(cycleID: cycle.cycleID)?.matching.first?.answer, prepared?.matching.first?.answer)
    }
    func testSpellingVariantsRequireExplicitSourceRelationAndFreezeIntoQuestion() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit spelling fixture", body: "The colour is clear.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let entry = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "colour", range: NSRange(location: 4, length: 6), sentence: "The colour is clear."), articleID: id, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: entry.entryID, meaning: "颜色（明确个人释义）", notes: "", at: now)
        let sense = DictionarySense(id: "explicit-spelling-fixture", en: "Alternative spelling of color.", zh: "", line: "Explicit original relation fixture, not live dictionary content.", sources: ["Wiktionary"], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/")
        try DictionaryCacheRepository(context: ModelContext(app.modelContainer)).save("colour", senses: [markMDXFixture(sense)], successful: [BundledMDXDictionaryProvider.sourceName], at: now)
        try confirmOriginalReviewFixtures(learning, at: now)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let session = try XCTUnwrap(prepared)
        XCTAssertEqual(session.cloze[0].acceptedAnswers, ["color", "colour"])
        XCTAssertFalse(SpellingAnswerPolicy.accepts("colored", expected: "colour", alternatives: session.cloze[0].acceptedAnswers))
        XCTAssertEqual(SpellingAnswerPolicy.variants(answer: "running", lemma: "run", senses: [sense]), ["running"])
        try learning.review.submit(cycleID: cycle.cycleID, questionID: session.matching[0].id, answer: session.matching[0].senseID, at: now)
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: " COLOR ", at: now))
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewLogRecord>()).first?.grade, "good")
    }
    func testRecommendationCandidatesKeepOriginalInflectedPhraseAndRealOffset() throws {
        let body = "The team carried out an investigation and took into account the evidence."
        let article = ReadableArticle(id: "explicit-original-fixture", title: "Explicit original fixture", source: "Fixture author", body: body, bodyHash: fingerprint(body), topics: ["Science"], minutes: 1, publishedAt: nil, originalURL: nil)
        let candidates = VocabularyRecommendationRules.candidates(in: [article], excluding: ["carry out"])
        XCTAssertFalse(candidates.contains { $0.id == "carry out" })
        let phrase = try XCTUnwrap(candidates.first { $0.id == "take into account" })
        XCTAssertEqual(phrase.surface, "took into account")
        XCTAssertEqual((body as NSString).substring(with: phrase.range), phrase.surface)
        XCTAssertEqual(EnglishTokenizer.lemma("  LOOKED  into  "), "look into")
        XCTAssertTrue(VocabularyRecommendationRules.candidates(in: [article], excluding: [], limit: 0).isEmpty)
    }
    func testExploreResetArchivesOriginalProgressAndCannotResetDailyTask() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let first = try learning.content.importArticle(.init(title: "Explicit daily fixture", body: "A complete original daily article.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let extra = try learning.content.importArticle(.init(title: "Explicit explore fixture", body: "A complete original exploration article.", source: "Fixture author", rightsConfirmed: true, eligibleForDaily: false), at: now)
        XCTAssertThrowsError(try learning.content.resetExploration(articleID: extra, at: now))
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: first, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        try learning.reader.save(articleID: extra, cycleID: nil, position: .init(percent: 0.7, offset: 10), at: now)
        XCTAssertFalse(try learning.content.exploreRecommendations(at: now).contains { $0.id == extra })
        try learning.content.resetExploration(articleID: extra, at: now)
        XCTAssertTrue(try learning.content.exploreRecommendations(at: now).contains { $0.id == extra })
        let archived = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleProgressRecord>()).first { $0.articleID == extra })
        XCTAssertEqual(archived.readingPercent, 0.7); XCTAssertEqual(archived.archivedAt, now)
        XCTAssertThrowsError(try learning.content.resetExploration(articleID: first, at: now))
        let article = try learning.openExplore(articleID: extra, at: now)
        XCTAssertEqual(try learning.reader.position(article: article, cycleID: nil).percent, 0)
        XCTAssertEqual(ArticleRecommendationService.weights.values.reduce(0, +), 100)
    }
    func testVocabularyRecommendationsRequireUnlockAndDoNotAddUntilExplicitAction() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit recommendation fixture", body: "Cooperation and architecture support thoughtful learning.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        var clockDate = now
        let recommendations = learning.recommendationService(clock: { clockDate })
        var received: [RecommendedVocabulary] = []
        do { _ = try await recommendations.discover { received.append($0) }; XCTFail("Recommendations must remain locked") } catch { }
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        let providers = Array(DictionaryAggregator.versions.keys).map { ($0, DictionaryEvidenceProvider(mode: "many", source: $0) as any DictionaryProvider) }
        try learning.dictionary.configureDictionaryEvidence(providers: providers)
        _ = try await recommendations.discover(limit: 2) { received.append($0) }
        XCTAssertEqual(received.count, 2); XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
        let candidate = try XCTUnwrap(received.first).candidate
        _ = try learning.vocabulary.add(token: .init(surface: candidate.lemma, range: NSRange(location: 0, length: candidate.lemma.count), sentence: candidate.sentence), articleID: candidate.articleID, autoAdd: false, explicit: true, at: Date())
        received = []; _ = try await recommendations.discover(limit: 2) { received.append($0) }
        XCTAssertFalse(received.contains { $0.id == candidate.lemma }); XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        clockDate = now.addingTimeInterval(86400)
        do { _ = try await recommendations.discover { _ in }; XCTFail("A new learning day must lock recommendations again") } catch { }
    }
    func testExtraReviewRestoresFixedSessionSchedulesOnceAndNeverChangesDailyCycle() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let articleID = try learning.content.importArticle(.init(title: "Explicit extra review fixture", body: "A book helps readers learn.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected daily cycle") }
        try confirmOriginalReviewFixtures(learning, at: now)
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: articleID, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        let before = try learning.cycles.fetchAll()
        let word = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book helps readers learn."), articleID: articleID, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: word.entryID, meaning: "书（明确个人释义）", notes: "", at: now)
        try confirmOriginalReviewFixtures(learning, at: now)
        let prepared = try await learning.review.prepareExtra(dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let extra = try XCTUnwrap(prepared)
        let recovered = ReviewQueueService(context: ModelContext(app.modelContainer), cycles: learning.cycles, dictionary: learning.dictionary)
        let resumed = try await recovered.prepareExtra(dailyLimit: 99, pairCount: 9, clozeCount: 9, at: now)
        XCTAssertEqual(resumed, extra)
        try recovered.submitExtra(sessionID: extra.id, questionID: extra.matching[0].id, answer: extra.matching[0].senseID, at: now)
        try recovered.submitExtra(sessionID: extra.id, questionID: extra.cloze[0].id, answer: extra.cloze[0].answer, at: now)
        try recovered.submitExtra(sessionID: extra.id, questionID: extra.cloze[0].id, answer: extra.cloze[0].answer, at: now)
        XCTAssertEqual(try learning.cycles.fetchAll(), before)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 1)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).first?.repetitions, 1)
        let next = try await recovered.prepareExtra(dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        XCTAssertNil(next); XCTAssertEqual(try learning.vocabulary.entries().count, 1)
    }
    func testPersonalMeaningReviewNeedsNoEnglishNetworkAndExtraCannotBypassRequiredReview() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit offline review fixture", body: "A book helps.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let addition = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book helps."), articleID: id, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: addition.entryID, meaning: "书（个人）", notes: "", at: now)
        let provider = CacheRequestProbe()
        try learning.dictionary.configureDictionaryEvidence(providers: [("Free Dictionary API", provider), ("Wiktionary", provider)])
        try confirmOriginalReviewFixtures(learning, at: now)
        do { _ = try await learning.review.prepareExtra(dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now); XCTFail("Required review cannot be bypassed") } catch { }
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        XCTAssertEqual(prepared?.matching.first?.answer, "书（个人）")
        let requests = await provider.requests; XCTAssertEqual(requests, 0)
    }
    func testVocabularyQueriesAndExportsKeepChineseNotesSourcesAndSchedule() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit export source", body: "A book uses the Internet.", source: "Fixture author", rightsConfirmed: true), at: now.addingTimeInterval(-10 * 86400))
        let book = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book uses the Internet."), articleID: id, autoAdd: true, at: now.addingTimeInterval(-10 * 86400)))
        _ = try learning.vocabulary.add(token: .init(surface: "Internet", range: NSRange(location: 16, length: 8), sentence: "A book uses the Internet."), articleID: id, autoAdd: true, at: now)
        try annotateOriginalFixture(learning, entryID: book.entryID, meaning: "书，册", notes: "A \"quoted\" note\nwith another line.", at: now)
        let context = ModelContext(app.modelContainer), state = try XCTUnwrap(context.fetch(FetchDescriptor<ReviewStateRecord>()).first { $0.entryID == book.entryID })
        state.dueAt = now.addingTimeInterval(-2 * 86400); try context.save()
        let entries = try learning.vocabulary.entries()
        XCTAssertEqual(VocabularyQuery.apply(entries, search: "册", type: "word", status: .overdue, sort: .alphabet, at: now).map(\.id), [book.entryID])
        XCTAssertEqual(VocabularyQuery.apply(entries, search: "", type: "all", status: .recent, sort: .added, at: now).map(\.lemma), ["internet"])
        let json = try learning.vocabulary.export(.json, at: now)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any]), exported = try XCTUnwrap(payload["entries"] as? [[String: Any]])
        XCTAssertEqual(exported.count, 2)
        let exportedBook = try XCTUnwrap(exported.first { $0["id"] as? String == book.entryID })
        XCTAssertEqual(exportedBook["notes"] as? String, "A \"quoted\" note\nwith another line.")
        XCTAssertNotNil(exportedBook["dueAt"]); XCTAssertNotNil(exportedBook["sourceContexts"])
        let csv = String(decoding: try learning.vocabulary.export(.csv, at: now), as: UTF8.self)
        XCTAssertTrue(csv.contains("\"A \"\"quoted\"\" note\nwith another line.\"")); XCTAssertTrue(csv.contains("nextDueAt"))
        XCTAssertEqual(try learning.vocabulary.entries().count, 2)
    }
    func testVocabularyExportFilesKeepRepositoryBytesAndIsolateCleanup() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let articleID = try learning.content.importArticle(.init(title: "Original export fixture", body: "A book helps.", source: "Fixture author", rightsConfirmed: true), at: now)
        let entry = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book helps."), articleID: articleID, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: entry.entryID, meaning: "书（个人释义）", notes: "Quoted \"note\"\n第二行", at: now)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = VocabularyExportFileService(directory: directory)
        let json = try learning.vocabulary.export(.json, at: now), csv = try learning.vocabulary.export(.csv, at: now)
        let first = try files.prepare(json, format: .json), second = try files.prepare(csv, format: .csv)
        XCTAssertEqual(first.url.lastPathComponent, "LexiDawn-vocabulary.json")
        XCTAssertEqual(second.url.lastPathComponent, "LexiDawn-vocabulary.csv")
        XCTAssertNotEqual(first.url.deletingLastPathComponent(), second.url.deletingLastPathComponent())
        XCTAssertEqual(try Data(contentsOf: first.url), json)
        XCTAssertEqual(try Data(contentsOf: second.url), csv)
        try files.discard(first); try files.discard(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertEqual(try Data(contentsOf: second.url), csv)
        // Reject cleanup outside this service's staging directory.
        let unrelated = directory.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unrelated) }
        let protectedURL = unrelated.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: protectedURL)
        XCTAssertThrowsError(try files.discard(.init(id: UUID(), url: protectedURL)))
        XCTAssertEqual(try String(contentsOf: protectedURL, encoding: .utf8), "keep")
        try files.discard(second)
        XCTAssertEqual(try learning.vocabulary.entries().map(\.id), [entry.entryID])
        XCTAssertEqual(try learning.vocabulary.find(surface: "book")?.notes, "Quoted \"note\"\n第二行")
    }
    func testVocabularyExportCallbackSurvivesPresentationDismissalAndRejectsOldRequest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = VocabularyExportSession(files: VocabularyExportFileService(directory: directory))
        try session.prepare(Data("{\"explicitCallbackFixture\":true}".utf8), format: .json)
        weak var pendingDelegate: VocabularyExportPicker.Coordinator?
        var firstURL: URL?
        do {
            let request = try XCTUnwrap(session.presentation)
            pendingDelegate = request.delegate; firstURL = request.file.url
        }
        let stagedURL = try XCTUnwrap(firstURL)
        session.presentation = nil // Reproduce SwiftUI dismissal before UIKit delegate delivery.
        session.presentationDidDismiss()
        XCTAssertTrue(session.isBusy)
        XCTAssertNotNil(pendingDelegate) // The session, not a test-local request, retains it.
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedURL.path))
        XCTAssertNil(session.notice)
        let callback = try XCTUnwrap(pendingDelegate)
        let target = directory.appendingPathComponent("LexiDawn-vocabulary.json")
        // Explicit delegate fixture, not evidence of a real system save.
        callback.finished(target)
        XCTAssertEqual(session.notice, "已导出 LexiDawn-vocabulary.json")
        XCTAssertFalse(session.isBusy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedURL.path))
        try session.prepare(Data("lemma,meaning\nbook,书".utf8), format: .csv)
        let second = try XCTUnwrap(session.presentation)
        XCTAssertNil(session.notice)
        callback.finished(target)
        XCTAssertEqual(session.presentation?.id, second.id)
        XCTAssertNil(session.notice)
        second.delegate.finished(nil)
        XCTAssertNil(session.presentation)
        XCTAssertNil(session.notice)
        XCTAssertFalse(session.isBusy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.file.url.path))
    }
    func testVocabularyExportStagingFailureDoesNotPresentEmptyFileOrOverwriteData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let blocker = directory.appendingPathComponent("blocked")
        try Data("protected".utf8).write(to: blocker)
        XCTAssertThrowsError(try VocabularyExportFileService(directory: blocker).prepare(Data("{}".utf8), format: .json))
        XCTAssertEqual(try String(contentsOf: blocker, encoding: .utf8), "protected")
        let files = VocabularyExportFileService(directory: directory.appendingPathComponent("empty"))
        XCTAssertThrowsError(try files.prepare(Data(), format: .csv))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.directory.path))
        let retry = try files.prepare(Data("lemma,meaning\nbook,书".utf8), format: .csv)
        XCTAssertEqual(try Data(contentsOf: retry.url), Data("lemma,meaning\nbook,书".utf8))
        try files.discard(retry)
    }
    func testHistoryFavoriteAndLaterCannotBypassCurrentCycleAtReaderBoundary() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let first = try learning.content.importArticle(.init(title: "Explicit first owned article", body: "A complete first original article.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(old, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected first cycle") }
        _ = try await learning.review.prepare(cycleID: old.cycleID, dailyLimit: 12, pairCount: 6, clozeCount: 4, at: now)
        try learning.reader.complete(articleID: first, cycleID: old.cycleID, manualConfirmation: true, at: now)
        let later = now.addingTimeInterval(86400)
        let second = try learning.content.importArticle(.init(title: "Explicit next owned article", body: "A complete second original article.", source: "Fixture author", rightsConfirmed: true), at: later)
        guard case let .cycle(current, _) = try app.cycleService.ensureCurrentCycle(now: later, timeZone: .current, calendar: .current) else { return XCTFail("Expected next cycle") }
        try learning.content.setLibraryFlags(articleID: first, favorite: true, readLater: true)
        XCTAssertThrowsError(try learning.openArticle(articleID: first, cycleID: old.cycleID, at: later))
        XCTAssertThrowsError(try learning.reader.save(articleID: first, cycleID: old.cycleID, position: .init(), at: later))
        XCTAssertThrowsError(try learning.reader.complete(articleID: first, cycleID: old.cycleID, manualConfirmation: true, at: later))
        XCTAssertThrowsError(try learning.openArticle(articleID: first, cycleID: current.cycleID, at: later))
        XCTAssertEqual(try learning.openArticle(articleID: second, cycleID: current.cycleID, at: later).id, second)
        XCTAssertEqual(try learning.cycles.fetchAll().count, 2)
        XCTAssertTrue(try XCTUnwrap(learning.content.library(at: later).first { $0.id == first }).favorite)
        XCTAssertEqual(try learning.cycles.fetch(by: current.cycleID)?.articleTaskStatus, .ready)
    }
    func testDateChangeLocksHistoricalAndExploreRoutesBeforeHomeCreatesNewCycle() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit original gate fixture", body: "A complete owned article for the gate.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        XCTAssertTrue(try learning.explorationAllowed(at: now))
        let tomorrow = now.addingTimeInterval(86400)
        XCTAssertFalse(try learning.explorationAllowed(at: tomorrow))
        XCTAssertThrowsError(try learning.openArticle(articleID: id, cycleID: cycle.cycleID, at: tomorrow))
        XCTAssertEqual(try learning.cycles.fetchAll().count, 1, "Checking a gate cannot fabricate a new daily cycle")
    }
    func testPhraseSourceSpanIncludesFirstWordAcrossHardBreakAndRejectsUnrelatedRepeatedWord() throws {
        let text = "Earlier original sentence. We take\n  into account every result, then inspect the account."
        let source = text as NSString, first = source.range(of: "account"), last = source.range(of: "account", options: .backwards)
        let tapped = EnglishToken(surface: "account", range: first, sentence: "We take into account every result, then inspect the account.")
        let phrase = try XCTUnwrap(EnglishPhraseRecognizer.token(for: "take into account", around: tapped, sourceText: text))
        XCTAssertEqual(phrase.range.location, source.range(of: "take").location)
        XCTAssertEqual(phrase.surface, "take\n  into account"); XCTAssertEqual(EnglishTokenizer.lemma(phrase.surface), "take into account")
        XCTAssertEqual(source.substring(with: phrase.range), phrase.surface)
        XCTAssertNil(EnglishPhraseRecognizer.token(for: "take into account", around: .init(surface: "account", range: last, sentence: tapped.sentence), sourceText: text))
        let definition = "An original definition. We carry out the study.", ns = definition as NSString
        let nested = try XCTUnwrap(EnglishPhraseRecognizer.token(for: "carry out", around: .init(surface: "out", range: ns.range(of: "out"), sentence: "We carry out the study."), sourceText: definition))
        XCTAssertEqual(nested.range.location, ns.range(of: "carry").location)
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit source-position fixture", body: text, source: "Fixture author", rightsConfirmed: true), at: now)
        let model = WordLookupModel(token: .init(surface: "account", range: NSRange(location: NSNotFound, length: 7), sentence: tapped.sentence), articleID: id, autoAdd: true, learning: learning)
        XCTAssertNil(model.phraseLookup("take into account")); XCTAssertNotNil(model.phraseError); XCTAssertNil(model.vocabularyError)
        XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
    }
    func testDictionaryNestedContextKeepsItsRealEvidenceAndCannotMasqueradeAsArticleSentence() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit original source fixture", body: "A book explains science.", source: "Original fixture author", originalURL: "https://fixture.invalid/complete-original", rightsConfirmed: true), at: now)
        let token = EnglishToken(surface: "science", range: NSRange(location: 16, length: 7), sentence: "A book explains science.")
        let original = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now))
        let evidence = "Explicit original dictionary-source evidence fixture; not production dictionary data."
        let nested = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, origin: .dictionary(headword: "book", evidence: evidence), at: now))
        XCTAssertFalse(nested.created); XCTAssertThrowsError(try learning.vocabulary.undo(nested, at: now))
        XCTAssertThrowsError(try learning.vocabulary.add(token: token, articleID: id, autoAdd: true, origin: .dictionary(headword: "book", evidence: ""), at: now))
        let item = try XCTUnwrap(learning.vocabulary.find(surface: "science"))
        XCTAssertEqual(item.id, original.entryID); XCTAssertEqual(item.sourceContexts.count, 2)
        let dictionary = try XCTUnwrap(item.sourceContexts.first { $0.originKind == "dictionary" })
        XCTAssertEqual(dictionary.title, "词典释义：book"); XCTAssertEqual(dictionary.attribution, evidence); XCTAssertNil(dictionary.originalURL)
        XCTAssertEqual(item.sourceContexts.first { $0.originKind == "reader" }?.originalURL, "https://fixture.invalid/complete-original")
        let exported = String(decoding: try learning.vocabulary.export(.json, at: now), as: UTF8.self)
        XCTAssertTrue(exported.contains(evidence)); XCTAssertTrue(exported.contains("dictionary"))
        let context = ModelContext(app.modelContainer)
        let historical = try XCTUnwrap(context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).first { $0.contextKind == "reader" })
        historical.contextKind = nil; try context.save()
        let reloaded = try XCTUnwrap(learning.vocabulary.find(surface: "science"))
        XCTAssertEqual(reloaded.sourceContexts.first { $0.originKind == nil }?.lookupOrigin.kind, "historical")
        XCTAssertEqual(reloaded.sourceContexts.count, 2)
    }
    func testPhraseMembershipAndUndoNeverMistakeExistingPhraseForWord() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit original phrase fixture", body: "We look into the issue.", source: "Fixture author", rightsConfirmed: true), at: now)
        let token = EnglishToken(surface: "look into", range: NSRange(location: 3, length: 9), sentence: "We look into the issue.")
        let addition = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now))
        XCTAssertEqual(try learning.vocabulary.find(surface: token.surface)?.id, addition.entryID)
        let existing = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now))
        XCTAssertFalse(existing.created); XCTAssertThrowsError(try learning.vocabulary.undo(existing, at: now))
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        XCTAssertEqual(try learning.vocabulary.find(surface: token.surface)?.type, "phrase")
    }
    func testContextSpellingKeepsIrregularGrammarAndMasksEntirePhrase() throws {
        let word = ClozeContext.make(lemma: "take", surfaces: ["taken"], sentence: "I took what I had taken.")
        XCTAssertEqual(word.answer, "taken"); XCTAssertEqual(ClozeContext.mask(try XCTUnwrap(word.sentence), answer: word.answer), "I took what I had _____.")
        let phrase = ClozeContext.make(lemma: "play a role in", surfaces: ["played a role in"], sentence: "Careful reviews played a role in learning.")
        XCTAssertEqual(phrase.answer, "played a role in")
        XCTAssertEqual(ClozeContext.mask(try XCTUnwrap(phrase.sentence), answer: phrase.answer), "Careful reviews ______ _ ____ __ learning.")
        XCTAssertNil(ClozeContext.make(lemma: "take", surfaces: ["took"], sentence: "No verified target occurs here.").sentence)
    }
    func testFreshCacheAvoidsProviderRequestsAndOfflineFallbackKeepsRealFetchDate() async throws {
        // Updated owner contract: no online fallback or expiring external source.
        // The real MDX actor owns the parsed-entry cache; identity is bound to its SHA.
        let provider = BundledMDXDictionaryProvider()
        let first = try await provider.lookup("user")
        XCTAssertFalse(first.filter(BilingualMeaningPolicy.trusted).isEmpty)
        for _ in 0..<25 { let cached = try await provider.lookup("user"); XCTAssertEqual(cached, first) }
        let hits = await provider.cacheHits
        XCTAssertGreaterThanOrEqual(hits, 25)
        XCTAssertEqual(Set(first.compactMap(\.sourceRevision)), [BundledMDXDictionaryProvider.sourceVersion])
    }
    func testReviewContextIsFrozenAndLegacyBackfillKeepsAnswerAttemptsAndHint() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit original context fixture", body: "I took a book home.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected real cycle assignment") }
        let addition = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "took", range: NSRange(location: 2, length: 4), sentence: "I took a book home."), articleID: id, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: addition.entryID, meaning: "拿走（明确个人释义）", notes: "", at: now)
        try confirmOriginalReviewFixtures(learning, at: now)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let original = try XCTUnwrap(prepared)
        XCTAssertEqual(original.cloze.first?.answer, "took"); XCTAssertEqual(original.cloze.first?.context, "I took a book home.")
        let context = ModelContext(app.modelContainer), source = try XCTUnwrap(context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).first)
        source.sentence = "This later source change cannot rewrite a saved question."; try context.save()
        XCTAssertEqual(try learning.review.session(cycleID: cycle.cycleID)?.cloze.first?.context, "I took a book home.")
        try learning.review.submit(cycleID: cycle.cycleID, questionID: original.matching[0].id, answer: original.matching[0].senseID, at: now)
        try learning.review.submit(cycleID: cycle.cycleID, questionID: original.cloze[0].id, answer: "wrong", at: now)
        try learning.review.submit(cycleID: cycle.cycleID, questionID: original.cloze[0].id, answer: "", hint: true, at: now)
        let legacyContext = ModelContext(app.modelContainer), legacy = try XCTUnwrap(legacyContext.fetch(FetchDescriptor<ReviewExerciseRecord>()).first { $0.stage == "cloze" })
        legacy.answer = "take"; legacy.prompt = "ta__"; legacy.sourceContext = nil; legacy.contextSnapshotVersion = nil; try legacyContext.save()
        let resumed = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 99, pairCount: 9, clozeCount: 9, at: now)
        let restored = try XCTUnwrap(resumed)
        XCTAssertEqual(restored.cloze[0].answer, "take"); XCTAssertEqual(restored.cloze[0].attempts, 1); XCTAssertTrue(restored.cloze[0].usedHint)
        XCTAssertNil(restored.cloze[0].context); XCTAssertEqual(restored.id, original.id)
    }
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
        var forged = proof; forged.importBasis = nil
        let invalid = FullTextArticleImport(sourceID: "bbc", canonicalURL: "https://www.bbc.com/news/articles/forged-fixture", title: "Invalid proof", author: "Fixture", publishedAt: nil, rawContent: raw, document: item.document, topics: ["test"], rights: forged, completeDocument: true, expectedHash: nil, verifiedAt: now)
        XCTAssertThrowsError(try content.importFullText(invalid, at: now)); XCTAssertEqual(try content.library(at: now).count, 1)
    }
    func testWikinewsLegacyDateCannotUseNewLicense() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content), raw = "Full original text."
        let item = FullTextArticleImport(sourceID: "wikinews", canonicalURL: "https://en.wikinews.org/wiki/Explicit_fixture", title: "Explicit fixture", author: "Wikinews", publishedAt: Date(timeIntervalSince1970: 1700000000), rawContent: raw, document: ArticleDocumentNormalizer.plainText(raw), topics: ["test"], rights: ArticleSourceRegistry.wikinewsRights, completeDocument: true, expectedHash: nil, verifiedAt: now)
        XCTAssertThrowsError(try content.importFullText(item, at: now)); XCTAssertTrue(try content.library().isEmpty)
    }
    func testNestedQuoteAndOrderedListPreserveStructureWithoutChangingText() throws {
        let document = try ArticleHTMLExtractor.extract("<article><blockquote><p>Original quote.</p></blockquote><ol><li><p>First item.</p></li><li>Last item.</li></ol></article>")
        XCTAssertEqual(document.blocks.map(\.text), ["Original quote.", "First item.", "Last item."])
        XCTAssertEqual(document.blocks.map(\.kind), [.quotation, .listItem, .listItem])
        XCTAssertEqual(document.blocks[1].listOrdinal, 1); XCTAssertEqual(document.blocks[2].listOrdinal, 2)
    }
    func testWiktionaryRichFieldsStayWithinEnglishAndExamplesAreNotDefinitions() throws {
        let html = "<h2 id=\"English\">English</h2><h3>Etymology</h3><p>Explicit etymology fixture.</p><h3>Pronunciation</h3><span class=\"IPA\">/bʊk/</span><h3>Noun</h3><p class=\"headword-line\">book (plural books)</p><ol><li>A fixture collection.<ul><li>An explicit fixture example.</li></ul></li></ol><h2 id=\"French\">French</h2><h3>Noun</h3><ol><li>Excluded other language.</li></ol>"
        let senses = try WiktionaryDictionaryProvider.parseEnglishHTML(html)
        XCTAssertEqual(senses.count, 1); XCTAssertEqual(senses.first?.en, "A fixture collection.")
        XCTAssertEqual(senses.first?.ipa, "/bʊk/"); XCTAssertEqual(senses.first?.examples, ["An explicit fixture example."])
        XCTAssertEqual(senses.first?.forms, ["book (plural books)"]); XCTAssertEqual(senses.first?.etymology, "Explicit etymology fixture.")
    }
    func testWiktionaryPronunciationAndInflectionsStayWithTheirPartOfSpeech() throws {
        let html = "<h2 id=\"English\">English</h2><h3>Pronunciation</h3><span class=\"IPA\">/ˈrek.əd/</span><h3>Noun</h3><p class=\"headword-line\">record (plural records)</p><ol><li>An explicit fixture entry in a log.</li></ol><h3>Pronunciation</h3><span class=\"IPA\">/rɪˈkɔːd/</span><h3>Verb</h3><p class=\"headword-line\">record (records, recorded)</p><ol><li>To write an explicit fixture entry.</li></ol>"
        let senses = try WiktionaryDictionaryProvider.parseEnglishHTML(html)
        let noun = try XCTUnwrap(senses.first { $0.partOfSpeech == "noun" }), verb = try XCTUnwrap(senses.first { $0.partOfSpeech == "verb" })
        XCTAssertEqual(noun.ipa, "/ˈrek.əd/"); XCTAssertEqual(verb.ipa, "/rɪˈkɔːd/")
        XCTAssertEqual(noun.forms, ["record (plural records)"]); XCTAssertEqual(verb.forms, ["record (records, recorded)"])
    }
    func testExpiredFullTextMovesToHistoryAndNeverLeavesPartialArticleRecord() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        try content.importFullText(item(), at: now)
        let context = ModelContext(app.modelContainer), article = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        article.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.until(now.addingTimeInterval(1))); try context.save()
        XCTAssertThrowsError(try content.read(articleID: item().articleID, at: now.addingTimeInterval(2)))
        let fresh = ModelContext(app.modelContainer)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<ArticleRecord>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<ArticleHistoryArchiveRecord>()), 1)
        XCTAssertFalse(try content.library(at: now.addingTimeInterval(2))[0].readable)
    }
    func testFailedSourceRefreshPersistsBackoffAndKeepsSuccessfulLocalVersion() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        try content.importFullText(item(), at: now)
        try content.recordSourceRefresh("wikipedia", beginning: false, at: now)
        try content.recordSourceRefresh("wikipedia", beginning: true, at: now.addingTimeInterval(10))
        try content.recordSourceRefresh("wikipedia", beginning: false, errorCode: FullTextImportError.rateLimited.rawValue, at: now.addingTimeInterval(11))
        let restored = ContentRepository(context: ModelContext(app.modelContainer)), state = try restored.sourceRefreshState("wikipedia")
        XCTAssertEqual(state.success, now); XCTAssertEqual(state.retryAfter, now.addingTimeInterval(3611))
        XCTAssertEqual(try restored.read(articleID: item().articleID, at: now.addingTimeInterval(12)).body, item().rawContent)
    }
    func testStandardEntitiesDecodeUnicodeAndUnknownReferenceRemainsLiteral() throws {
        XCTAssertEqual(try ArticleHTMLExtractor.decodeEntities("caf&eacute; &rarr; &NotEqualTilde; &unknownReference;"), "café → ≂̸ &unknownReference;")
    }
    func testSchemaArticleBodyHTMLIsCleanedAndPreservesFinalParagraph() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("bbc"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.bbc.com/news/articles/explicit-fixture", revision: nil)
        let json = try JSONSerialization.data(withJSONObject: ["@type": "NewsArticle", "headline": "Explicit schema fixture", "articleBody": webBody])
        let html = "<html><script type='application/ld+json'>" + String(decoding: json, as: UTF8.self) + "</script></html>"
        let result = try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source)
        XCTAssertEqual(result.document.blocks.count, 3); XCTAssertFalse(result.document.text.contains("<p>")); XCTAssertTrue(result.document.text.hasSuffix("including the final sentence."))
    }
    func testPublisherExplicitBodyExcludesPageHeaderWhilePreservingAuthorAndDateMetadata() throws {
        let source = try XCTUnwrap(ArticleSourceRegistry.personalSource("nasa"))
        let candidate = ArticleDiscoveryItem(sourceID: source.id, title: "Fixture", url: "https://www.nasa.gov/news-release/explicit-fixture/", revision: nil)
        let graph: [String: Any] = ["@graph": [["@type": "WebPage", "name": "Fixture", "datePublished": "2026-10-30T12:00:00.000Z", "author": ["@id": "fixture-person"]], ["@type": "Person", "@id": "fixture-person", "name": "Explicit fixture author"]]]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: graph), as: UTF8.self)
        let html = "<html><script type='application/ld+json'>" + json + "</script><article><header><h1>Page title metadata</h1></header><div class='wp-block-post-content'>" + webBody + "</div></article></html>"
        let result = try ArticleWebPageExtractor.extract(Data(html.utf8), candidate: candidate, source: source)
        XCTAssertEqual(result.author, "Explicit fixture author"); XCTAssertNotNil(result.publishedAt)
        XCTAssertEqual(result.document.blocks.count, 3); XCTAssertFalse(result.document.text.contains("Page title metadata"))
        XCTAssertTrue(result.document.text.hasSuffix("including the final sentence."))
    }
    func testRecommendationUsesPreferencesAndCannotReuseAssignedCandidate() throws {
        let app = try AppDependencies.makeLearningInMemory(), content = try XCTUnwrap(app.learning?.content)
        let prefs = try app.preferencesRepository.load(); prefs.interestTopics = ["科学"]; try app.preferencesRepository.save(prefs)
        let preferred = try content.importArticle(.init(title: "Preferred science", body: "Original science article with preserved full text.", source: "Explicit fixture author", topic: "科学", rightsConfirmed: true), at: now)
        _ = try content.importArticle(.init(title: "Other culture", body: "Another complete original article with different words.", source: "Explicit fixture author", topic: "文化", rightsConfirmed: true), at: now)
        XCTAssertEqual(try content.candidates(excluding: []).first?.id, preferred)
        XCTAssertFalse(try content.candidates(excluding: [preferred]).contains { $0.id == preferred })
    }
    private func item(raw: String = "The original full article begins here.\n\nThe final paragraph is preserved.", complete: Bool = true, hash: String? = nil) -> FullTextArticleImport {
        FullTextArticleImport(sourceID: "wikipedia", canonicalURL: "https://en.wikipedia.org/wiki/Explicit_test_fixture", title: "Isolated original fixture", author: "Test author", publishedAt: nil, rawContent: raw,
            document: ArticleDocumentNormalizer.plainText(raw), topics: ["test"], rights: ArticleSourceRegistry.wikipediaRights,
            completeDocument: complete, expectedHash: hash, verifiedAt: now)
    }
    func testTenThousandRSSCandidatesStayCompleteAndRecordParserClockAndMemory() {
        let data = Data(("<rss><channel>" + (0..<10_000).map { "<item><title>Explicit large feed fixture \($0)</title><link>https://fixture.invalid/articles/\($0)</link><description>Explicit summary must never become a body.</description></item>" }.joined() + "</channel></rss>").utf8)
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            do {
                let candidates = try ArticleFeedParser(sourceID: "explicit-large-feed-fixture").parse(data)
                XCTAssertEqual(candidates.count, 10_000); XCTAssertEqual(candidates.last?.title, "Explicit large feed fixture 9999")
                XCTAssertEqual(candidates.last?.url, "https://fixture.invalid/articles/9999")
            } catch { XCTFail("Original fixture feed must parse completely: \(error)") }
        }
    }
    func testLongOriginalHTMLExtractionRetainsEveryParagraphAndRecordsClockAndMemory() {
        let html = "<article><h2>Explicit original long extraction fixture</h2>" + (0..<1_000).map { "<p>Explicit original paragraph \($0). Complete original sentences remain preserved through extraction, including every paragraph and the final sentence.</p>" }.joined() + "</article>"
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            do {
                let document = try ArticleHTMLExtractor.extract(html)
                XCTAssertEqual(document.blocks.filter { $0.kind == .paragraph }.count, 1_000)
                XCTAssertTrue(document.text.hasSuffix("Explicit original paragraph 999. Complete original sentences remain preserved through extraction, including every paragraph and the final sentence."))
                XCTAssertTrue(ArticleDocumentNormalizer.preservesOriginal(document.text, document: document))
            } catch { XCTFail("Original fixture document must remain complete: \(error)") }
        }
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
    func testUnavailableOrEmptyFreeDictionaryKeepsWiktionaryResultsAndStatus() async throws {
        struct Empty: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { [] } }
        struct Failed: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { throw FullTextImportError.transport } }
        struct Wiki: DictionaryProvider {
            func lookup(_ word: String) async throws -> [DictionarySense] {
                [DictionarySense(id: "explicit-wiki-fixture", en: "Explicit original Wiktionary provider test definition.", zh: "", line: "Explicit fixture, not live data.", partOfSpeech: "noun", sources: ["Wiktionary"])]
            }
        }
        for (isEmpty, free) in [(true, Empty() as any DictionaryProvider), (false, Failed() as any DictionaryProvider)] {
            let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
            try learning.dictionary.configureDictionaryEvidence(providers: [("Free Dictionary API", free), ("Wiktionary", Wiki())])
            XCTAssertFalse(learning.dictionary.onlineEnabled)
            let result = await DictionaryAggregator(providers: [("Free Dictionary API", free), ("Wiktionary", Wiki())]).lookup("book")
            XCTAssertEqual(result.senses.map(\.en), ["Explicit original Wiktionary provider test definition."])
            XCTAssertEqual(result.senses.first?.sources, ["Wiktionary"])
            XCTAssertTrue(result.senses.allSatisfy { $0.zh.isEmpty })
            XCTAssertEqual(result.failed, isEmpty ? [] : ["Free Dictionary API"])
            XCTAssertEqual(result.empty, isEmpty ? ["Free Dictionary API"] : [])
        }
    }
    func testSingleProviderFailureDoesNotDiscardSuccess() async {
        struct Failure: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { throw FullTextImportError.transport } }
        struct Success: DictionaryProvider { func lookup(_ word: String) async throws -> [DictionarySense] { [DictionarySense(id: "fixture", en: "A genuine fixture definition.", zh: "", line: "fixture")] } }
        let result = await DictionaryAggregator(providers: [("failed", Failure()), ("ok", Success())]).lookup("book")
        XCTAssertEqual(result.failed, ["failed"]); XCTAssertEqual(result.senses.count, 1)
    }
    func testBrokenProviderPayloadCannotHideVocabularyExportOrBlockPersonalMeaningReview() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit corrupt-cache fixture", body: "A book helps people learn.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected actual cycle") }
        let word = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book helps people learn."), articleID: id, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: word.entryID, meaning: "书（明确个人释义）", notes: "Personal notes must remain accessible.", at: now)
        let context = ModelContext(app.modelContainer)
        context.insert(DictionaryProviderCacheRecord(lemma: "book", provider: "Free Dictionary API", version: "api-v2-schema-2", data: Data("Damaged disposable fixture payload".utf8), at: now)); try context.save()
        XCTAssertEqual(try learning.vocabulary.find(surface: "book")?.notes, "Personal notes must remain accessible.")
        let exported = String(decoding: try learning.vocabulary.export(.json, at: now), as: UTF8.self)
        XCTAssertTrue(exported.contains("Personal notes must remain accessible."))
        try confirmOriginalReviewFixtures(learning, at: now)
        let preparedValue = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let prepared = try XCTUnwrap(preparedValue)
        XCTAssertEqual(prepared.matching.first?.answer, "书（明确个人释义）"); XCTAssertEqual(prepared.cloze.first?.acceptedAnswers, ["book"])
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
    }
    func testCorruptDisposableProviderCacheDoesNotHideOtherProviderAndCanBeRepaired() throws {
        let app = try AppDependencies.makeLearningInMemory(), context = ModelContext(app.modelContainer)
        let valid = DictionarySense(id: "explicit-valid-cache", en: "Explicit original cache fixture.", zh: "", line: "Explicit fixture", sources: ["Wiktionary"])
        context.insert(DictionaryProviderCacheRecord(lemma: "book", provider: "Wiktionary", version: "bilingual-action-schema-7", data: try JSONEncoder().encode([valid]), at: now))
        context.insert(DictionaryProviderCacheRecord(lemma: "book", provider: "Free Dictionary API", version: "api-v2-schema-2", data: Data("Damaged retired fixture payload".utf8), at: now))
        try context.save()
        let cache = DictionaryCacheRepository(context: context), loaded = try cache.load("book", at: now)
        // Retired providers cannot be promoted to MDX, including valid old rows.
        XCTAssertTrue(loaded.senses.isEmpty); XCTAssertFalse(loaded.complete)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<DictionaryProviderCacheRecord>()), 2)
        let repaired = markMDXFixture(DictionarySense(id: "explicit-repair", en: "Explicit original repair fixture.", zh: "", line: "Explicit fixture"))
        try cache.save("book", senses: [repaired], successful: [BundledMDXDictionaryProvider.sourceName], at: now.addingTimeInterval(1))
        let current = try cache.load("book", at: now.addingTimeInterval(2))
        XCTAssertTrue(current.complete); XCTAssertEqual(current.senses.map(\.id), [repaired.id])
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<DictionaryProviderCacheRecord>()), 3)
    }
    func testVersionedDictionaryCacheDoesNotEraseVocabulary() throws {
        let app = try AppDependencies.makeLearningInMemory(), context = ModelContext(app.modelContainer)
        let cache = DictionaryCacheRepository(context: context)
        let sense = markMDXFixture(DictionarySense(id: "test", en: "A book.", zh: "", line: "Explicit MDX cache-version fixture"))
        try cache.save("book", senses: [sense], successful: [BundledMDXDictionaryProvider.sourceName], at: now)
        XCTAssertEqual(try cache.load("book", at: now).senses.count, 1)
        let row = try XCTUnwrap(context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).first)
        row.sourceVersion = "obsolete"; try context.save()
        XCTAssertTrue(try cache.load("book", at: now).senses.isEmpty)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<DictionaryProviderCacheRecord>()), 1)
    }
    func testNewReviewStateAndFirstAgainPersistLearningWithoutPretendingPriorMastery() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit new-card fixture", body: "A book helps people learn.", source: "Fixture author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected actual cycle") }
        let word = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "book", range: NSRange(location: 2, length: 4), sentence: "A book helps people learn."), articleID: id, autoAdd: true, at: now))
        try annotateOriginalFixture(learning, entryID: word.entryID, meaning: "书（明确个人释义）", notes: "", at: now)
        let initial = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).first)
        XCTAssertEqual(initial.cardState, "new"); XCTAssertEqual(initial.successfulReviews, 0)
        try confirmOriginalReviewFixtures(learning, at: now)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let session = try XCTUnwrap(prepared), matching = try XCTUnwrap(session.matching.first), cloze = try XCTUnwrap(session.cloze.first)
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: matching.id, answer: matching.senseID, at: now))
        XCTAssertFalse(try learning.review.submit(cycleID: cycle.cycleID, questionID: cloze.id, answer: "", reveal: true, at: now))
        XCTAssertFalse(try XCTUnwrap(learning.review.session(cycleID: cycle.cycleID)).cloze[0].completed)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: cloze.id, answer: cloze.answer, at: now))
        let saved = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).first)
        XCTAssertEqual(saved.cardState, "learning"); XCTAssertEqual(saved.againCount, 1); XCTAssertEqual(saved.successfulReviews, 0)
        XCTAssertEqual(saved.repetitions, 1); XCTAssertGreaterThan(saved.dueAt, now)
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
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
            try annotateOriginalFixture(learning, entryID: addition.entryID, meaning: meaning, notes: "", at: now)
        }
        try confirmOriginalReviewFixtures(learning, at: now)
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
