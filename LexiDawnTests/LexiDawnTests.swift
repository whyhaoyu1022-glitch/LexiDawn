import Foundation
import SwiftData
import XCTest
@testable import LexiDawn

@MainActor
final class LexiDawnTests: XCTestCase {
    func testDesignTokensUseFourPointGrid() {
        XCTAssertEqual(LexiDawnSpacing.xs, 4)
        XCTAssertEqual(LexiDawnSpacing.sm, 8)
        XCTAssertEqual(LexiDawnSpacing.md, 16)
        XCTAssertEqual(LexiDawnSpacing.lg, 24)
        XCTAssertEqual(LexiDawnSpacing.xl, 32)
        XCTAssertEqual(LexiDawnSpacing.xxl, 40)
    }

    func testRootTabViewCanBeConstructed() {
        _ = RootTabView()
    }

    func testFirstCycleUsesCandidateAndStoresArticleAssociation() throws {
        let store = InMemoryCycleStore()
        let candidate = fixture(id: "article-1")
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [candidate]))
        let result = try service.ensureCurrentCycle(now: date("2026-10-26T01:00:00Z"), timeZone: utc, calendar: utcCalendar)

        guard case let .cycle(cycle, created) = result else { return XCTFail("Expected a cycle") }
        XCTAssertTrue(created)
        XCTAssertEqual(cycle.articleID, candidate.id)
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
        XCTAssertEqual(cycle.articleTaskStatus, .ready)
        XCTAssertFalse(cycle.isComplete)
    }

    func testSameDayProvisioningIsIdempotent() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]))
        let timestamp = date("2026-10-26T01:00:00Z")

        _ = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar)
        let second = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(60), timeZone: utc, calendar: utcCalendar)

        guard case let .cycle(cycle, created) = second else { return XCTFail("Expected the existing cycle") }
        XCTAssertFalse(created)
        XCTAssertEqual(store.cycles.count, 1)
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
    }

    func testNoCandidateDoesNotCreatePlaceholderCycle() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: EmptyArticleCandidateProvider())
        let result = try service.ensureCurrentCycle(now: date("2026-10-26T01:00:00Z"), timeZone: utc, calendar: utcCalendar)

        XCTAssertEqual(result, .noCandidate)
        XCTAssertTrue(store.cycles.isEmpty)
    }

    func testCompletedCycleSameDayDoesNotCreateAnotherCycle() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]))
        let timestamp = date("2026-10-26T01:00:00Z")
        let firstResult = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar)
        guard case let .cycle(first, _) = firstResult else { return XCTFail("Expected first cycle") }
        try complete(first, with: service, at: timestamp.addingTimeInterval(10))

        let secondResult = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(20), timeZone: utc, calendar: utcCalendar)
        guard case let .cycle(second, created) = secondResult else { return XCTFail("Expected completed cycle") }
        XCTAssertFalse(created)
        XCTAssertEqual(second.cycleID, first.cycleID)
        XCTAssertEqual(store.cycles.count, 1)
    }

    func testOldIncompleteCycleWinsAfterDateChanges() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]))
        let dayOne = date("2026-10-26T23:00:00Z")
        let dayTwo = date("2026-10-27T01:00:00Z")
        _ = try service.ensureCurrentCycle(now: dayOne, timeZone: utc, calendar: utcCalendar)
        let result = try service.ensureCurrentCycle(now: dayTwo, timeZone: utc, calendar: utcCalendar)

        guard case let .cycle(cycle, created) = result else { return XCTFail("Expected carry-over cycle") }
        XCTAssertFalse(created)
        XCTAssertEqual(cycle.articleID, "article-1")
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
        XCTAssertEqual(cycle.carryOverCount, 1)
    }

    func testRepeatedRefreshDoesNotIncreaseCarryOverCount() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]))
        let dayOne = date("2026-10-26T23:00:00Z")
        let dayTwo = date("2026-10-27T01:00:00Z")
        _ = try service.ensureCurrentCycle(now: dayOne, timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: dayTwo, timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: dayTwo.addingTimeInterval(60), timeZone: utc, calendar: utcCalendar)

        XCTAssertEqual(store.cycles.first?.carryOverCount, 1)
    }

    func testArticleAndReviewRemainIndependent() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]))
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }

        _ = try service.updateTask(cycleID: cycle.cycleID, task: .article, to: .completed, at: timestamp.addingTimeInterval(1))
        let current = try XCTUnwrap(store.cycles.first)
        XCTAssertEqual(current.articleTaskStatus, .completed)
        XCTAssertNotEqual(current.reviewTaskStatus, .completed)
        XCTAssertFalse(current.isComplete)
    }

    func testLegalAndIllegalStateTransitionsAreExplicit() throws {
        XCTAssertEqual(try TaskStatus.ready.transitioned(to: .inProgress), .inProgress)
        XCTAssertEqual(try TaskStatus.inProgress.transitioned(to: .completed), .completed)
        XCTAssertThrowsError(try TaskStatus.completed.transitioned(to: .inProgress)) { error in
            XCTAssertEqual(error as? TaskStatusError, .invalidTransition(from: .completed, to: .inProgress))
        }
        XCTAssertThrowsError(try TaskStatus.ready.transitioned(to: .deferred)) { error in
            XCTAssertEqual(error as? TaskStatusError, .deferredReasonRequired)
        }
    }

    func testDeferredStagesCanSatisfyCycleOnlyWithReasons() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]))
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }

        _ = try service.updateTask(cycleID: cycle.cycleID, task: .article, to: .completed, at: timestamp)
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .matching, to: .deferred, reason: "没有到期词条", at: timestamp)
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .cloze, to: .deferred, reason: "没有到期词条", at: timestamp)
        let updated = try service.updateTask(cycleID: cycle.cycleID, task: .review, to: .deferred, reason: "复习队列为空", at: timestamp)
        XCTAssertTrue(updated.isComplete)
        XCTAssertNotNil(updated.completedAtUTC)
        XCTAssertNotEqual(updated.reviewTaskStatus, .completed)
    }

    func testBlockedAndFailedNeverCountAsCompleted() {
        XCTAssertFalse(TaskStatus.blocked.isSatisfied)
        XCTAssertFalse(TaskStatus.failed.isSatisfied)
    }

    func testCrossTimeZoneKeepsAssignedArticleAndDate() throws {
        let store = InMemoryCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]))
        let timestamp = date("2026-10-26T23:30:00Z")
        _ = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar)
        let travelingCalendar = Calendar(identifier: .gregorian)
        let result = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(3600), timeZone: shanghai, calendar: travelingCalendar)

        guard case let .cycle(cycle, created) = result else { return XCTFail() }
        XCTAssertFalse(created)
        XCTAssertEqual(cycle.articleID, "article-1")
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
    }

    func testSwiftDataCycleAndPreferencesSurviveRepositoryRebuild() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let repository = StudyCycleRepository(context: context)
        let timestamp = date("2026-10-26T01:00:00Z")
        let cycle = DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "article-1", createdAtUTC: timestamp, updatedAtUTC: timestamp, assignmentReason: "test-fixture")
        try repository.save(cycle)
        let preferencesRepository = PreferencesRepository(context: context)
        let preferences = try preferencesRepository.load()
        preferences.displayName = "Lexi"
        try preferencesRepository.save(preferences)

        let rebuiltCycleRepository = StudyCycleRepository(context: ModelContext(container))
        let rebuiltPreferencesRepository = PreferencesRepository(context: ModelContext(container))
        XCTAssertEqual(try rebuiltCycleRepository.fetch(by: cycle.cycleID)?.articleID, "article-1")
        XCTAssertEqual(try rebuiltPreferencesRepository.load().displayName, "Lexi")
        XCTAssertEqual(try rebuiltPreferencesRepository.load().dailyReadingReminderHour, 6)
        XCTAssertEqual(try rebuiltPreferencesRepository.load().dailyReadingReminderMinute, 20)
        XCTAssertEqual(try rebuiltPreferencesRepository.load().dailyReviewReminderHour, 21)
        XCTAssertEqual(try rebuiltPreferencesRepository.load().dailyReviewReminderMinute, 20)
        XCTAssertTrue(try rebuiltPreferencesRepository.load().autoAddOnWordTap)
    }

    func testTodayViewModelShowsNoCandidateAndFixtureCycleState() throws {
        let emptyDependencies = try AppDependencies.makeInMemory()
        let emptyViewModel = TodayViewModel(dependencies: emptyDependencies, now: { self.date("2026-10-26T01:00:00Z") })
        emptyViewModel.load()
        XCTAssertEqual(emptyViewModel.state, .noCandidate)

        let fixtureDependencies = try AppDependencies.makeInMemory(candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1", title: "A real fixture article")] ))
        let fixtureViewModel = TodayViewModel(dependencies: fixtureDependencies, now: { self.date("2026-10-26T01:00:00Z") })
        fixtureViewModel.load()
        guard case let .loaded(snapshot) = fixtureViewModel.state else { return XCTFail("Expected loaded state") }
        XCTAssertEqual(snapshot.cycle.articleID, "article-1")
        XCTAssertEqual(snapshot.articleTitle, "A real fixture article")
    }

    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }
    private var shanghai: TimeZone { TimeZone(identifier: "Asia/Shanghai")! }
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }

    private func fixture(id: String, title: String = "Fixture article \(UUID().uuidString)") -> ArticleCandidate {
        ArticleCandidate(id: id, canonicalURL: "https://example.invalid/\(id)", title: title, sourceID: "test-fixture")
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)!
    }

    private func complete(_ cycle: DailyStudyCycle, with service: DailyCycleService, at timestamp: Date) throws {
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .article, to: .completed, at: timestamp)
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .matching, to: .deferred, reason: "test", at: timestamp)
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .cloze, to: .deferred, reason: "test", at: timestamp)
        _ = try service.updateTask(cycleID: cycle.cycleID, task: .review, to: .deferred, reason: "test", at: timestamp)
    }
}

private final class InMemoryCycleStore: StudyCycleStore {
    var cycles: [DailyStudyCycle] = []

    func fetchAll() throws -> [DailyStudyCycle] { cycles }
    func fetchEarliestIncomplete() throws -> DailyStudyCycle? { cycles.sorted { ($0.assignedLocalDate, $0.createdAtUTC) < ($1.assignedLocalDate, $1.createdAtUTC) }.first(where: { $0.hasOutstandingWork }) }
    func fetch(by cycleID: UUID) throws -> DailyStudyCycle? { cycles.first(where: { $0.cycleID == cycleID }) }
    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle? { cycles.first(where: { $0.assignedLocalDate == localDate }) }
    func save(_ cycle: DailyStudyCycle) throws {
        if let index = cycles.firstIndex(where: { $0.cycleID == cycle.cycleID }) { cycles[index] = cycle } else { cycles.append(cycle) }
    }
}
