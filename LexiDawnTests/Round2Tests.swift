import XCTest
import SwiftData
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
