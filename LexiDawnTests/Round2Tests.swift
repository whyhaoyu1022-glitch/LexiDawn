import XCTest
import SwiftData
import UIKit
@testable import LexiDawn

@MainActor final class Round2Tests: XCTestCase {
    private let now = Date()
    private func setup(body: String = "Reading helps people learn. A book can open a new world.") throws -> (AppDependencies, String, DailyStudyCycle) {
        let app = try AppDependencies.makeLearningInMemory()
        let learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(ArticleImportDraft(title: "Owned test article", body: body, source: "Explicit isolated test author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { throw LearningError.invalid("Expected imported article") }
        return (app, id, cycle)
    }
    func testUserImportPersistsRealBodyGrantAndDoesNotReplaceIncompleteCycle() throws {
        let (app, id, cycle) = try setup()
        let learning = try XCTUnwrap(app.learning)
        let article = try learning.content.read(articleID: id, at: now)
        XCTAssertEqual(article.body, "Reading helps people learn. A book can open a new world.")
        XCTAssertEqual(article.bodyHash, fingerprint(article.body))
        _ = try learning.content.importArticle(ArticleImportDraft(title: "Second", body: "Another original article for later reading.", source: "Author", rightsConfirmed: true), at: now)
        guard case let .cycle(restored, created) = try app.cycleService.ensureCurrentCycle(now: now.addingTimeInterval(172800), timeZone: .current, calendar: .current) else { return XCTFail() }
        XCTAssertFalse(created); XCTAssertEqual(restored.cycleID, cycle.cycleID); XCTAssertEqual(restored.articleID, id)
        let grant = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<ContentGrantRecord>()).first { $0.articleID == id })
        XCTAssertEqual(grant.scope, "user-local"); XCTAssertNotEqual(grant.evidenceURL, "public-domain")
    }
    func testImportRejectsUnconfirmedInvalidURLControlCharactersAndDuplicateBody() throws {
        let (app, _, _) = try setup(); let learning = try XCTUnwrap(app.learning)
        for draft in [ArticleImportDraft(title: "T", body: "An English article", source: "Author"),
                      ArticleImportDraft(title: "T", body: "An English article", source: "Author", originalURL: "javascript:alert(1)", rightsConfirmed: true),
                      ArticleImportDraft(title: "T", body: "An English\u{0000}article", source: "Author", rightsConfirmed: true)] {
            XCTAssertThrowsError(try learning.content.importArticle(draft, at: now))
        }
        XCTAssertThrowsError(try learning.content.importArticle(ArticleImportDraft(title: "Duplicate", body: "Reading helps people learn. A book can open a new world.", source: "Author", rightsConfirmed: true), at: now))
        XCTAssertEqual(try app.articleRepository.allArticleIDs().count, 1)
    }
    func testReaderProgressAndCompletionUseSavedEvidenceAndRemainIndependentOfReview() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        XCTAssertThrowsError(try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: false, at: now))
        try learning.reader.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.45, offset: 15), at: now)
        let article = try learning.content.read(articleID: id, at: now)
        XCTAssertEqual(try learning.reader.position(article: article, cycleID: cycle.cycleID).percent, 0.45)
        XCTAssertEqual(try learning.reader.position(article: article, cycleID: cycle.cycleID).offset, 15)
        XCTAssertThrowsError(try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: false, at: now))
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        let completed = try XCTUnwrap(app.cycleRepository.fetch(by: cycle.cycleID))
        XCTAssertEqual(completed.readingEvidence?.progress, 0.45); XCTAssertEqual(completed.articleTaskStatus, .completed)
        XCTAssertFalse(completed.isComplete)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: now.addingTimeInterval(50))
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID), completed)
    }
    func testReaderFailedTransactionDoesNotLeakProgressOrCycleAndRetrySucceeds() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let failing = ReaderProgressService(context: ModelContext(app.modelContainer), content: learning.content, cycles: app.cycleRepository) { _ in throw LearningError.invalid("injected save failure") }
        XCTAssertThrowsError(try failing.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.5, offset: 10), at: now))
        XCTAssertTrue(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleProgressRecord>()).isEmpty)
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .ready)
        try learning.reader.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.5, offset: 10), at: now)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleProgressRecord>()).count, 1)
    }
    func testTokensHandleContractionsPossessivesHyphensAndExcludeURLsEmailCodeNumbers() {
        let text = "Don’t, it’s researchers’ state-of-the-art long-term carry out look into New York. 中英 word123 https://host.test/secret email@host.test `hidden` ```code``` 123."
        let tokens = EnglishTokenizer.tokens(in: text)
        XCTAssertEqual(tokens.map(\.surface), ["Don’t", "it’s", "researchers’", "state-of-the-art", "long-term", "carry", "out", "look", "into", "New", "York"])
        for token in tokens { XCTAssertEqual(EnglishTokenizer.token(at: token.range.location, tokens: tokens), token) }
        XCTAssertNil(EnglishTokenizer.token(at: 5, tokens: tokens)) // comma
        XCTAssertEqual(EnglishTokenizer.lemma("running"), "run"); XCTAssertEqual(EnglishTokenizer.lemma("ran"), "run")
        XCTAssertEqual(EnglishTokenizer.lemma("DON’T"), "don't")
        XCTAssertEqual(EnglishTokenizer.lemma("it’s"), "it's")
        XCTAssertEqual(EnglishTokenizer.lemma("researchers’"), EnglishTokenizer.lemma("researchers"))
    }
    func testVocabularyIdempotenceSafeUndoAndAutoAddDisabled() throws {
        let (app, id, _) = try setup(); let learning = try XCTUnwrap(app.learning)
        let token = EnglishToken(surface: "book", range: NSRange(location: 35, length: 4), sentence: "A book can open a new world.")
        XCTAssertNil(try learning.vocabulary.add(token: token, articleID: id, autoAdd: false, at: now))
        XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
        let first = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now))
        let second = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now))
        XCTAssertTrue(first.created); XCTAssertFalse(second.created); XCTAssertEqual(first.entryID, second.entryID)
        XCTAssertThrowsError(try learning.vocabulary.undo(second, at: now))
        XCTAssertThrowsError(try learning.vocabulary.undo(first, at: now)) // a later interaction has used it
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        try learning.vocabulary.remove(entryID: first.entryID, at: now)
        XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
        let readded = try XCTUnwrap(learning.vocabulary.add(token: token, articleID: id, autoAdd: false, explicit: true, at: now))
        XCTAssertTrue(readded.created); XCTAssertEqual(readded.entryID, first.entryID)
        try learning.vocabulary.undo(readded, at: now)
        XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).count, 1)
    }
    func testBundledLegalRFCAndRealDictionaryDataLoad() async throws {
        let app = try AppDependencies.makeLearningInMemory(); let learning = try XCTUnwrap(app.learning)
        try learning.content.installBundledRFC(at: now)
        let article = try learning.content.read(articleID: SourceRegistry.rfc.id, at: now)
        XCTAssertTrue(article.body.contains("Copyright")); XCTAssertTrue(article.body.contains("IETF Trust")); XCTAssertGreaterThan(EnglishTokenizer.tokens(in: article.body).count, 2500)
        let dictionary = try await learning.dictionary.lookup("book")
        XCTAssertFalse(dictionary.senses.isEmpty); XCTAssertTrue(dictionary.senses.allSatisfy { !$0.line.isEmpty && !$0.zh.isEmpty })
        XCTAssertEqual(dictionary.licenseURL, "https://creativecommons.org/licenses/by-sa/4.0/")
        let missing = try await learning.dictionary.lookup("zzzzunverifiableword")
        XCTAssertTrue(missing.senses.isEmpty)
    }
    func testDeterministicSchedulerAndSpellingMaskFixedVectors() {
        XCTAssertEqual(BasicReviewScheduler.interval(previous: 0, grade: .good), 4)
        XCTAssertEqual(BasicReviewScheduler.interval(previous: 4, grade: .good), 8)
        XCTAssertEqual(BasicReviewScheduler.interval(previous: 4, grade: .hard), 6)
        XCTAssertEqual(BasicReviewScheduler.interval(previous: 10, grade: .again), 1)
        XCTAssertEqual(BasicReviewScheduler.mask("book"), "bo__")
        XCTAssertEqual(BasicReviewScheduler.mask("long-term"), "long-t___")
    }
    func testRealEmptyQueueEvidenceCompletesOnlyReviewAndNonemptyCannotSkip() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let empty = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 12, pairCount: 6, clozeCount: 4, at: now)
        XCTAssertNil(empty)
        let saved = try XCTUnwrap(app.cycleRepository.fetch(by: cycle.cycleID))
        XCTAssertEqual(saved.reviewTaskStatus, .deferred); XCTAssertNotNil(saved.reviewEvidence); XCTAssertFalse(saved.isComplete)
        XCTAssertEqual(try app.articleRepository.fetch(articleID: id)?.articleID, id)
    }
    func testActualMatchingSpellingAndLogsCompleteCycleExactlyOnceWithoutDeletingVocabulary() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let token = EnglishToken(surface: "book", range: NSRange(location: 35, length: 4), sentence: "A book can open a new world.")
        _ = try learning.vocabulary.add(token: token, articleID: id, autoAdd: true, at: now)
        XCTAssertThrowsError(try ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: learning.review, at: now))
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 12, pairCount: 6, clozeCount: 4, at: now)
        let session = try XCTUnwrap(prepared)
        XCTAssertEqual(session.matching.count, 1); XCTAssertEqual(session.cloze.count, 1)
        XCTAssertThrowsError(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: "book", at: now))
        XCTAssertFalse(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.matching[0].id, answer: "arbitrary reason", at: now))
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.matching[0].id, answer: session.matching[0].senseID, at: now))
        XCTAssertFalse(try XCTUnwrap(app.cycleRepository.fetch(by: cycle.cycleID)).isComplete)
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: "BOOK", at: now))
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.reviewTaskStatus, .completed)
        XCTAssertNotEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .completed)
        try learning.reader.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.91, offset: 30), at: now)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: false, at: now)
        XCTAssertTrue(try XCTUnwrap(app.cycleRepository.fetch(by: cycle.cycleID)).isComplete)
        let states = try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>())
        XCTAssertEqual(states.first?.repetitions, 1)
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: "book", at: now.addingTimeInterval(100)))
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewLogRecord>()).count, 1)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).first?.repetitions, 1)
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        XCTAssertTrue(try learning.explorationAllowed())
    }
}

extension Round2Tests {
    func testImportOriginalURLDeduplicatesTrackingVariants() throws {
        let (app, _, _) = try setup(); let learning = try XCTUnwrap(app.learning)
        _ = try learning.content.importArticle(ArticleImportDraft(title: "URL owned", body: "Owned writing with a distinct original text.", source: "Author", originalURL: "https://author.example/story?utm_source=reader", rightsConfirmed: true), at: now)
        XCTAssertThrowsError(try learning.content.importArticle(ArticleImportDraft(title: "Duplicate link", body: "Another version of the same original article.", source: "Author", originalURL: "https://author.example/story", rightsConfirmed: true), at: now))
        XCTAssertEqual(try app.articleRepository.allArticleIDs().count, 2)
    }
    func testLibraryIncludesOptOutImportAndExploreCannotReuseDailyAssignment() async throws {
        let (app, assigned, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let extra = try learning.content.importArticle(ArticleImportDraft(title: "Private library article", body: "A separately owned article for exploration.", source: "Author", rightsConfirmed: true, eligibleForDaily: false), at: now)
        XCTAssertEqual(try learning.content.library().count, 2)
        XCTAssertFalse(try learning.content.candidates(excluding: []).contains { $0.id == extra })
        XCTAssertThrowsError(try learning.openExplore(articleID: extra, at: now))
        XCTAssertThrowsError(try learning.reader.save(articleID: extra, cycleID: nil, position: ReaderPosition(), at: now))
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 12, pairCount: 6, clozeCount: 4, at: now)
        try learning.reader.complete(articleID: assigned, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        XCTAssertEqual(try learning.content.allReadableIDs(), [extra])
        XCTAssertThrowsError(try learning.openExplore(articleID: assigned, at: now))
        XCTAssertThrowsError(try learning.reader.save(articleID: assigned, cycleID: nil, position: ReaderPosition(), at: now))
        _ = try learning.openExplore(articleID: extra, at: now)
        try learning.reader.save(articleID: extra, cycleID: nil, position: ReaderPosition(percent: 0.3, offset: 5), at: now)
        XCTAssertTrue(try learning.content.allReadableIDs().isEmpty)
        XCTAssertEqual(try learning.content.library().first { $0.id == extra }?.percent, 0.3)
    }
    func testCacheExpiresAtBoundaryAndClockRollbackCannotResurrectBodyOrEraseLearning() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        try learning.reader.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.4, offset: 10), at: now)
        _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: id, autoAdd: true, at: now)
        let expiry = now.addingTimeInterval(60)
        let context = ModelContext(app.modelContainer)
        let article = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        article.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.until(expiry)); try context.save()
        XCTAssertNoThrow(try learning.content.read(articleID: id, at: expiry.addingTimeInterval(-0.001)))
        XCTAssertThrowsError(try learning.content.read(articleID: id, at: expiry))
        XCTAssertThrowsError(try learning.content.read(articleID: id, at: now))
        XCTAssertFalse(try learning.content.library(at: now)[0].readable)
        XCTAssertNil(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleRecord>()).first?.bodyText)
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ArticleProgressRecord>()).first?.readingPercent, 0.4)
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .inProgress)
    }
    func testReaderViewModelRevokesDisplayedBodyWhenSaveFindsExpiredRights() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let model = ReaderViewModel(articleID: id, cycleID: cycle.cycleID, learning: learning); model.open()
        XCTAssertNotNil(model.article)
        let context = ModelContext(app.modelContainer)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        record.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.until(Date().addingTimeInterval(-1))); try context.save()
        model.flush()
        XCTAssertNil(model.article); XCTAssertNotNil(model.error)
        XCTAssertNotEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .completed)
    }
    func testParagraphAnchorsMatchOnlyUniqueExactParagraphAndSentenceContextIsSpecific() {
        let body = "First sentence. Second sentence.\n\nA unique paragraph.\n"
        let ns = body as NSString
        let anchor = fingerprint(ns.substring(with: ns.paragraphRange(for: NSRange(location: 0, length: 0))))
        XCTAssertEqual(ReadingAnchors.offset(for: anchor, in: body), 0)
        XCTAssertNil(ReadingAnchors.offset(for: fingerprint("missing"), in: body))
        XCTAssertNil(ReadingAnchors.offset(for: fingerprint("same\n"), in: "same\nsame\n"))
        XCTAssertEqual(EnglishTokenizer.tokens(in: body).first { $0.surface == "Second" }?.sentence, "Second sentence.")
    }
    func testChangedVersionNeverUsesStaleOffsetAndPreservesUniqueAnchor() throws {
        let (app, id, cycle) = try setup(body: "First paragraph.\n\nA stable paragraph.\n")
        let learning = try XCTUnwrap(app.learning)
        let body = "A stable paragraph.\n"
        try learning.reader.save(articleID: id, cycleID: cycle.cycleID, position: ReaderPosition(percent: 0.7, anchor: fingerprint(body), offset: 22), at: now)
        var article = try learning.content.read(articleID: id, at: now)
        article = ReadableArticle(id: id, title: article.title, source: article.source, body: "New beginning.\n\n" + body, bodyHash: fingerprint("new version"), topics: article.topics, minutes: 1, publishedAt: nil, originalURL: nil)
        let restored = try learning.reader.position(article: article, cycleID: cycle.cycleID)
        XCTAssertTrue(restored.contentChanged); XCTAssertEqual(restored.percent, 0)
        XCTAssertEqual(restored.offset, ("New beginning.\n\n" as NSString).length)
    }
    func testVocabularyFailureIsNotClearedBySuccessfulDictionaryLookup() async throws {
        let (app, id, _) = try setup(); let learning = try XCTUnwrap(app.learning)
        let model = WordLookupModel(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: "missing-article", autoAdd: true, learning: learning)
        await model.begin()
        XCTAssertNotNil(model.vocabularyError); XCTAssertNotNil(model.result)
        XCTAssertNil(model.addition); XCTAssertTrue(try learning.vocabulary.entries().isEmpty)
        XCTAssertNotNil(try app.articleRepository.fetch(articleID: id))
    }
    func testVocabularyTransactionFailureLeavesNoEntryContextOrReviewState() throws {
        let (app, id, _) = try setup()
        let vocabulary = VocabularyRepository(context: ModelContext(app.modelContainer)) { _ in throw LearningError.invalid("injected") }
        XCTAssertThrowsError(try vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: id, autoAdd: true, at: now))
        let context = ModelContext(app.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VocabularyEntryRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VocabularySourceContextRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewStateRecord>()), 0)
    }
    func testCompleteReviewSaveFailureRollsBackAnswerLogScheduleAndCycle() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: id, autoAdd: true, at: now)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let session = try XCTUnwrap(prepared)
        try learning.review.submit(cycleID: cycle.cycleID, questionID: session.matching[0].id, answer: session.matching[0].senseID, at: now)
        let prior = try app.cycleRepository.fetch(by: cycle.cycleID)
        let failing = ReviewQueueService(context: ModelContext(app.modelContainer), cycles: app.cycleRepository, dictionary: learning.dictionary) { _ in throw LearningError.invalid("injected last answer save failure") }
        XCTAssertThrowsError(try failing.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: "book", at: now))
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID), prior)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        XCTAssertFalse(try XCTUnwrap(learning.review.session(cycleID: cycle.cycleID)).cloze[0].completed)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewStateRecord>()).first?.repetitions, 0)
        try learning.review.submit(cycleID: cycle.cycleID, questionID: session.cloze[0].id, answer: "book", at: now)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 1)
    }
    func testQueueMissingStateBlocksInsteadOfProducingEmptyEvidence() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: id, autoAdd: true, at: now)
        let context = ModelContext(app.modelContainer)
        for state in try context.fetch(FetchDescriptor<ReviewStateRecord>()) { context.delete(state) }; try context.save()
        XCTAssertThrowsError(try ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: learning.review, at: now))
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.reviewTaskStatus, .ready)
    }
    func testLearningDaysUseActualCompletionDateRatherThanAssignmentDate() throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let completion = now.addingTimeInterval(3 * 86400)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: completion)
        let stats = try learning.statistics(timeZone: .current, at: completion)
        XCTAssertEqual(stats.articles, 1); XCTAssertEqual(stats.studyDays, 1); XCTAssertEqual(stats.streak, 1)
        XCTAssertEqual(stats.recentDays, 1)
        XCTAssertEqual(try learning.statistics(timeZone: .current, at: completion.addingTimeInterval(8 * 86400)).recentDays, 0)
    }
    func testProductionNetworkAdapterHTTP429PersistsBackoffAndDoesNotInstallBody() async throws {
        let app = try AppDependencies.makeLearningInMemory(); let learning = try XCTUnwrap(app.learning)
        let service = ArticleAcquisitionService(content: learning.content, client: StubArticleHTTPClient(status: 429, failure: nil))
        do { try await service.refresh(at: now); XCTFail("429 must fail") } catch { }
        let state = try learning.content.acquisitionState()
        XCTAssertNotNil(state.1); XCTAssertGreaterThan(try XCTUnwrap(state.2), now)
        XCTAssertTrue(try app.articleRepository.allArticleIDs().isEmpty)
        do { try await service.refresh(at: now); XCTFail("Backoff must reject") } catch { }
    }
    func testNetworkTimeoutPersistsRecoverableErrorAndExistingArticleRemains() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let service = ArticleAcquisitionService(content: learning.content, client: StubArticleHTTPClient(status: 200, failure: URLError(.timedOut)))
        do { try await service.refresh(at: now); XCTFail("Timeout must fail") } catch { }
        XCTAssertNotNil(try learning.content.acquisitionState().1)
        XCTAssertEqual(try learning.content.read(articleID: id, at: now).id, id)
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleID, id)
    }
    func test3500WordTokenHitPerformanceAndEveryBoundary() {
        let body = Array(repeating: "Reading books helps people discover science.", count: 584).joined(separator: "\n\n")
        measure { let tokens = EnglishTokenizer.tokens(in: body); XCTAssertGreaterThan(tokens.count, 3500); for token in tokens { XCTAssertEqual(EnglishTokenizer.token(at: token.range.location, tokens: tokens)?.surface, token.surface) } }
    }
    func testDiskReopenRestoresProgressVocabularySettingsAndFixedReviewExercises() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("learning.store"))
        var articleID = "", cycleID = UUID(), savedSession: ReviewSessionView?
        do {
            let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: configuration), learningEnabled: true)
            let learning = try XCTUnwrap(app.learning)
            articleID = try learning.content.importArticle(ArticleImportDraft(title: "Disk owned article", body: "Reading a book brings ideas.\n\nA second paragraph is here.", source: "Test author", rightsConfirmed: true), at: now)
            guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail() }; cycleID = cycle.cycleID
            try learning.reader.save(articleID: articleID, cycleID: cycleID, position: ReaderPosition(percent: 0.5, offset: 15), at: now)
            _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 10, length: 4), sentence: "A book."), articleID: articleID, autoAdd: true, at: now)
            let prefs = try app.preferencesRepository.load(); prefs.displayName = "Disk reader"; prefs.readerTheme = "paper"; prefs.autoAddOnWordTap = false; try app.preferencesRepository.save(prefs)
            savedSession = try await learning.review.prepare(cycleID: cycleID, dailyLimit: 6, pairCount: 6, clozeCount: 4, at: now)
        }
        do {
            let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: configuration), learningEnabled: true)
            let learning = try XCTUnwrap(app.learning)
            let article = try learning.content.read(articleID: articleID, at: now)
            XCTAssertEqual(try learning.reader.position(article: article, cycleID: cycleID).percent, 0.5)
            XCTAssertEqual(try learning.reader.position(article: article, cycleID: cycleID).offset, 15)
            XCTAssertEqual(try learning.vocabulary.entries().first?.lemma, "book")
            XCTAssertEqual(try learning.review.session(cycleID: cycleID), savedSession)
            XCTAssertEqual(try app.preferencesRepository.load().displayName, "Disk reader")
            XCTAssertEqual(try app.preferencesRepository.load().readerTheme, "paper")
            XCTAssertFalse(try app.preferencesRepository.load().autoAddOnWordTap)
            XCTAssertEqual(try app.cycleRepository.fetch(by: cycleID)?.articleID, articleID)
        }
    }
}

private struct StubArticleHTTPClient: ArticleHTTPClient {
    let status: Int
    let failure: URLError?
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let failure { throw failure }
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Retry-After": "120"]) else { throw URLError(.badServerResponse) }
        return (Data(), response)
    }
}

extension Round2Tests {
    func testOfficialRFCNetworkRetrievalMatchesBundledLicensedSnapshot() async throws {
        let app = try AppDependencies.makeLearningInMemory(); let learning = try XCTUnwrap(app.learning)
        try await learning.acquisition.refresh(at: now)
        let article = try learning.content.read(articleID: SourceRegistry.rfc.id, at: now)
        XCTAssertEqual(article.bodyHash, ContentRepository.bundledRFCHash)
        XCTAssertNotNil(try learning.content.acquisitionState().0)
        XCTAssertTrue(article.body.contains("IETF Trust"))
    }
    func testCachedChineseSearchAndCacheDeletionKeepVocabularyEntity() async throws {
        let (app, id, _) = try setup(); let learning = try XCTUnwrap(app.learning)
        let result = try await learning.dictionary.lookup("book")
        let chinese = try XCTUnwrap(result.senses.first?.zh)
        _ = try learning.vocabulary.add(token: EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "A book."), articleID: id, autoAdd: true, at: now)
        XCTAssertEqual(try learning.vocabulary.entries(search: chinese).count, 1)
        let context = ModelContext(app.modelContainer)
        for sense in try context.fetch(FetchDescriptor<DictionarySenseRecord>()) { context.delete(sense) }
        for entry in try context.fetch(FetchDescriptor<DictionaryEntryRecord>()) { context.delete(entry) }
        try context.save()
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewStateRecord>()), 1)
    }
}

extension Round2Tests {
    func testPinnedOfficialRefetchRestoresOnlySameExpiredBodyAndPreservesAssignment() throws {
        let app = try AppDependencies.makeLearningInMemory(); let learning = try XCTUnwrap(app.learning)
        try learning.content.installBundledRFC(at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail() }
        let context = ModelContext(app.modelContainer)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
        record.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.until(now.addingTimeInterval(1))); try context.save()
        XCTAssertThrowsError(try learning.content.read(articleID: cycle.articleID, at: now.addingTimeInterval(2)))
        try learning.content.installBundledRFC(at: now.addingTimeInterval(3))
        XCTAssertFalse(try learning.content.read(articleID: cycle.articleID, at: now.addingTimeInterval(3)).body.isEmpty)
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleID, cycle.articleID)
        XCTAssertEqual(try app.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .ready)
        XCTAssertThrowsError(try learning.content.acceptRFC("Fake RFC text", at: now.addingTimeInterval(4)))
    }
}

extension Round2Tests {
    func testRealDueQueueHonorsLimitAndSavedSessionIgnoresLaterLimitChanges() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        for (index, word) in ["book", "science", "world"].enumerated() {
            let added = try XCTUnwrap(learning.vocabulary.add(token: EnglishToken(surface: word, range: NSRange(location: index * 10, length: word.count), sentence: "A test sentence."), articleID: id, autoAdd: true, at: now))
            try learning.vocabulary.annotate(entryID: added.entryID, meaning: "个人释义\(index)", notes: "Explicit test-owned meaning", at: now)
        }
        let context = ModelContext(app.modelContainer)
        let world = try XCTUnwrap(context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first { $0.lemma == "world" })
        let state = try XCTUnwrap(context.fetch(FetchDescriptor<ReviewStateRecord>()).first { $0.entryID == world.entryID })
        state.repetitions = 1; state.dueAt = now.addingTimeInterval(86400); try context.save()
        XCTAssertEqual(try learning.review.pendingCount(at: now), 2)
        let first = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 6, clozeCount: 4, at: now)
        XCTAssertEqual(first?.matching.count, 1)
        let restored = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 24, pairCount: 6, clozeCount: 4, at: now.addingTimeInterval(2 * 86400))
        XCTAssertEqual(first, restored)
        XCTAssertEqual(try learning.review.pendingCount(at: now.addingTimeInterval(2 * 86400)), 3)
    }
    func testCompletedRealCycleAllowsNextLocalDateWithoutReassigningUsedArticle() async throws {
        let (app, id, cycle) = try setup(); let learning = try XCTUnwrap(app.learning)
        let nextID = try learning.content.importArticle(ArticleImportDraft(title: "Next owned article", body: "A distinct piece of original writing for tomorrow.", source: "Author", rightsConfirmed: true), at: now)
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 12, pairCount: 6, clozeCount: 4, at: now)
        try learning.reader.complete(articleID: id, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        guard case let .cycle(same, createdToday) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail() }
        XCTAssertFalse(createdToday); XCTAssertEqual(same.cycleID, cycle.cycleID)
        guard case let .cycle(next, created) = try app.cycleService.ensureCurrentCycle(now: now.addingTimeInterval(86400), timeZone: .current, calendar: .current) else { return XCTFail() }
        XCTAssertTrue(created); XCTAssertEqual(next.articleID, nextID); XCTAssertNotEqual(next.articleID, id)
        XCTAssertEqual(try app.cycleRepository.fetchAll().count, 2)
    }
}

extension Round2Tests {
    func testNativeTextContainerExposesWordsAndPhysicalGlyphHitRejectsPunctuation() throws {
        let text = "Book, science. Don’t stop. Long-term goals."
        var tapped: [EnglishToken] = []
        let component = InteractiveEnglishText(text: text, fontSize: 28, lineSpacing: 1.5, theme: "system", restore: ReaderPosition(), onPosition: { _ in }, onWord: { tapped.append($0) })
        let container = EnglishTextContainer(frame: CGRect(x: 0, y: 0, width: 220, height: 400))
        let view = container.textView
        view.isEditable = false; view.isSelectable = false; view.accessibilityElementsHidden = true
        view.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        view.attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 28)])
        container.layoutIfNeeded()
        let coordinator = InteractiveEnglishText.Coordinator(component)
        coordinator.view = view; coordinator.accessibilityContainer = container; coordinator.tokens = EnglishTokenizer.tokens(in: text)
        coordinator.restorePosition(); coordinator.updateAccessibility()
        let words = try XCTUnwrap(container.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertTrue(words.contains { $0.accessibilityIdentifier == "word-Book" })
        XCTAssertTrue(words.allSatisfy { $0.accessibilityTraits.contains(.button) })
        func touch(_ offset: Int) {
            let glyph = view.layoutManager.glyphIndexForCharacter(at: offset)
            let rect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
            if let token = coordinator.token(at: CGPoint(x: rect.midX + view.textContainerInset.left, y: rect.midY + view.textContainerInset.top)) { tapped.append(token) }
        }
        touch(4) // comma must never select the adjacent word
        XCTAssertTrue(tapped.isEmpty)
        touch(7) // physical touch on science, after punctuation and wrapping
        XCTAssertEqual(tapped.last?.surface, "science")
        XCTAssertEqual(tapped.last?.sentence, "Book, science.")
    }
}

