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
        let store = FakeCycleStore()
        let candidate = fixture(id: "article-1")
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [candidate]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let result = try service.ensureCurrentCycle(now: date("2026-10-26T01:00:00Z"), timeZone: utc, calendar: utcCalendar)

        guard case let .cycle(cycle, created) = result else { return XCTFail("Expected a cycle") }
        XCTAssertTrue(created)
        XCTAssertEqual(cycle.articleID, candidate.id)
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
        XCTAssertEqual(cycle.articleTaskStatus, .ready)
        XCTAssertFalse(cycle.isComplete)
    }

    func testFakeStoreSameDayProvisioningIsIdempotent() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let timestamp = date("2026-10-26T01:00:00Z")

        _ = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar)
        let second = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(60), timeZone: utc, calendar: utcCalendar)

        guard case let .cycle(cycle, created) = second else { return XCTFail("Expected the existing cycle") }
        XCTAssertFalse(created)
        XCTAssertEqual(store.cycles.count, 1)
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
    }

    func testNoCandidateDoesNotCreatePlaceholderCycle() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: EmptyArticleCandidateProvider())
        let result = try service.ensureCurrentCycle(now: date("2026-10-26T01:00:00Z"), timeZone: utc, calendar: utcCalendar)

        XCTAssertEqual(result, .noCandidate)
        XCTAssertTrue(store.cycles.isEmpty)
    }

    func testCompletedCycleSameDayDoesNotCreateAnotherCycle() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
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
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
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
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let dayOne = date("2026-10-26T23:00:00Z")
        let dayTwo = date("2026-10-27T01:00:00Z")
        _ = try service.ensureCurrentCycle(now: dayOne, timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: dayTwo, timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: dayTwo.addingTimeInterval(60), timeZone: utc, calendar: utcCalendar)

        XCTAssertEqual(store.cycles.first?.carryOverCount, 1)
    }

    func testArticleAndReviewRemainIndependent() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }

        _ = try service.completeReading(cycleID: cycle.cycleID, evidence: readingProof(articleID: cycle.articleID, at: timestamp.addingTimeInterval(1)))
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
            XCTAssertEqual(error as? TaskStatusError, .verifiedEvidenceRequired)
        }
    }

    func testVerifiedEmptyFixtureQueueSatisfiesReviewOnlyAfterExplicitReading() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }
        let reviewOnly = try service.resolveReviewQueue(cycleID: cycle.cycleID, at: timestamp)
        XCTAssertFalse(reviewOnly.isComplete)
        XCTAssertNil(reviewOnly.completedAtUTC)
        let updated = try service.completeReading(cycleID: cycle.cycleID, evidence: readingProof(articleID: cycle.articleID, at: timestamp))
        XCTAssertTrue(updated.isComplete)
        XCTAssertEqual(updated.completionReason, "completed-with-no-review-items")
        XCTAssertEqual(updated.completedAtUTC, timestamp)
        XCTAssertFalse(updated.isCurrent)
        XCTAssertEqual(try service.resolveReviewQueue(cycleID: cycle.cycleID, at: timestamp.addingTimeInterval(10)), updated)
    }

    func testArticleCannotBeDeferred() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(
            cycleStore: store,
            candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")])
        )
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else {
            return XCTFail("Expected a cycle")
        }

        XCTAssertThrowsError(try service.updateTask(
            cycleID: cycle.cycleID,
            task: .article,
            to: .deferred,
            reason: "暂时不读",
            at: timestamp
        )) { error in
            XCTAssertEqual(error as? TaskStatusError, .articleCannotBeDeferred)
        }
        let persisted = try XCTUnwrap(store.cycles.first)
        XCTAssertEqual(persisted.articleTaskStatus, .ready)
        XCTAssertNil(persisted.completedAtUTC)
    }

    func testDeferredReviewCannotCompleteCycleWhenArticleIsIncomplete() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(
            cycleStore: store,
            candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")])
        )
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else {
            return XCTFail("Expected a cycle")
        }

        let proof = try ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: FixtureReviewQueue(), at: timestamp)
        var updated = cycle
        try updated.resolveEmptyReview(proof)
        XCTAssertFalse(updated.isComplete)
        XCTAssertNil(updated.completedAtUTC)
        XCTAssertNil(updated.completionReason)
    }

    func testBlockedAndFailedNeverCountAsCompleted() {
        XCTAssertFalse(TaskStatus.deferred.isSatisfied)
        XCTAssertFalse(TaskStatus.deferred.isSatisfied(for: .article))
        XCTAssertFalse(TaskStatus.deferred.isSatisfied(for: .review))
        XCTAssertFalse(TaskStatus.blocked.isSatisfied)
        XCTAssertFalse(TaskStatus.failed.isSatisfied)
    }

    func testCrossTimeZoneKeepsAssignedArticleAndDate() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let timestamp = date("2026-10-26T23:30:00Z")
        _ = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar)
        let travelingCalendar = Calendar(identifier: .gregorian)
        let result = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(3600), timeZone: shanghai, calendar: travelingCalendar)

        guard case let .cycle(cycle, created) = result else { return XCTFail() }
        XCTAssertFalse(created)
        XCTAssertEqual(cycle.articleID, "article-1")
        XCTAssertEqual(cycle.assignedLocalDate, "2026-10-26")
    }

    func testFakeStoreDateRollbackDoesNotIncreaseCarryOverCount() throws {
        let store = FakeCycleStore()
        let service = DailyCycleService(
            cycleStore: store,
            candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")])
        )
        let assigned = date("2026-10-26T01:00:00Z")
        _ = try service.ensureCurrentCycle(now: assigned, timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: date("2026-10-27T01:00:00Z"), timeZone: utc, calendar: utcCalendar)
        _ = try service.ensureCurrentCycle(now: date("2026-10-26T23:00:00Z"), timeZone: utc, calendar: utcCalendar)
        XCTAssertEqual(store.cycles.first?.carryOverCount, 1)
    }

    func testTodayStartDoesNotPersistUnavailableInProgressState() throws {
        let dependencies = try AppDependencies.makeInMemory(
            candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1")])
        )
        let viewModel = TodayViewModel(dependencies: dependencies, now: { self.date("2026-10-26T01:00:00Z") })
        viewModel.load()
        viewModel.start(task: .article)
        guard case let .loaded(snapshot) = viewModel.state else { return XCTFail("Expected loaded state") }
        XCTAssertEqual(snapshot.cycle.articleTaskStatus, .ready)
        XCTAssertNil(try dependencies.cycleRepository.fetchEarliestIncomplete()?.completedAtUTC)
    }

    func testSwiftDataCycleAndPreferencesSurviveRepositoryRebuild() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let repository = StudyCycleRepository(context: context)
        let timestamp = date("2026-10-26T01:00:00Z")
        let cycle = try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "article-1", createdAtUTC: timestamp, updatedAtUTC: timestamp, assignmentReason: "test-fixture")
        try repository.save(cycle: cycle, candidate: fixture(id: cycle.articleID), fetchedAt: timestamp)
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

    func testDiskContainerReopenRestoresCycleArticleAndPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        let timestamp = date("2026-10-26T01:00:00Z")
        var expected: [DailyStudyCycle] = []
        do {
            let container = try diskContainer(url)
            let context = ModelContext(container)
            let repository = StudyCycleRepository(context: context)
            let service = DailyCycleService(cycleStore: repository, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "article-1"), fixture(id: "article-2")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
            guard case let .cycle(first, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: shanghai, calendar: utcCalendar) else { return XCTFail() }
            try complete(first, with: service, at: timestamp.addingTimeInterval(1))
            _ = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(86400), timeZone: shanghai, calendar: utcCalendar)
            _ = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(86400 * 4), timeZone: utc, calendar: utcCalendar)
            expected = try repository.fetchAll()
            let preferencesRepository = PreferencesRepository(context: context)
            let preferences = try preferencesRepository.load()
            preferences.displayName = "Lexi"; preferences.ageRange = "adult"
            preferences.timeZonePolicy = "fixed"; preferences.fixedTimeZoneID = "Asia/Shanghai"
            preferences.autoAddOnWordTap = false; preferences.dailyReviewLimit = 18
            preferences.dailyReadingReminderEnabled = false; preferences.readerTheme = "dark"
            try preferencesRepository.save(preferences)
        }
        do {
            let reopened = try diskContainer(url)
            let context = ModelContext(reopened)
            let cycles = try StudyCycleRepository(context: context).fetchAll()
            XCTAssertEqual(cycles, expected) // all domain fields including proof, reasons, dates and timestamps
            XCTAssertEqual(cycles.count, 2)
            XCTAssertTrue(cycles[0].isComplete)
            XCTAssertTrue(cycles[1].hasOutstandingWork)
            XCTAssertTrue(cycles[1].isCurrent)
            XCTAssertEqual(cycles[1].carryOverCount, 3)
            let articles = ArticleRepository(context: context)
            for cycle in cycles {
                let record = try XCTUnwrap(articles.fetch(articleID: cycle.articleID))
                XCTAssertEqual(record.articleID, cycle.articleID)
                XCTAssertEqual(try record.candidate(), fixture(id: cycle.articleID))
                XCTAssertEqual(record.bodyText, "Fixture body")
                XCTAssertEqual(record.bodyHash, fixture(id: cycle.articleID).bodyHash)
                XCTAssertEqual(record.wordCount, 2)
                XCTAssertEqual(record.estimatedReadMinutes, 1)
                XCTAssertEqual(record.licenseID, "fixture-license")
                XCTAssertTrue(record.licenseVerified)
                XCTAssertEqual(record.topicTags, ["test"])
                XCTAssertNotNil(record.cachePermissionData)
            }
            let preferences = try PreferencesRepository(context: context).load()
            XCTAssertEqual(preferences.displayName, "Lexi"); XCTAssertEqual(preferences.ageRange, "adult")
            XCTAssertEqual(preferences.timeZonePolicy, "fixed"); XCTAssertEqual(preferences.fixedTimeZoneID, "Asia/Shanghai")
            XCTAssertFalse(preferences.autoAddOnWordTap); XCTAssertFalse(preferences.dailyReadingReminderEnabled)
            XCTAssertEqual(preferences.dailyReviewLimit, 18); XCTAssertEqual(preferences.readerTheme, "dark")
            XCTAssertEqual(preferences.dailyReadingReminderHour, 6); XCTAssertEqual(preferences.dailyReadingReminderMinute, 20)
            XCTAssertEqual(preferences.dailyReviewReminderHour, 21); XCTAssertEqual(preferences.dailyReviewReminderMinute, 20)
            XCTAssertEqual(preferences.matchingPairCount, 6); XCTAssertEqual(preferences.clozeQuestionCount, 4)
        }
    }

    func testSwiftDataRepositoryRejectsNewCycleUntilOldCompletesAndMaintainsCurrent() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let repository = dependencies.cycleRepository
        let service = DailyCycleService(cycleStore: repository, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1"), fixture(id: "a2")]), reviewQueue: FixtureReviewQueue(), readerAvailable: true)
        let timestamp = date("2026-10-26T01:00:00Z")
        guard case let .cycle(first, _) = try service.ensureCurrentCycle(now: timestamp, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }
        let second = try DailyStudyCycle(assignedLocalDate: "2026-10-27", assignedTimeZoneID: "UTC", articleID: "a2", createdAtUTC: timestamp, updatedAtUTC: timestamp, assignmentReason: "test")
        XCTAssertThrowsError(try repository.save(cycle: second, candidate: fixture(id: "a2"), fetchedAt: timestamp))
        XCTAssertNil(try dependencies.articleRepository.fetch(articleID: "a2"))
        XCTAssertEqual(try repository.fetchAll().filter(\.isCurrent).map(\.cycleID), [first.cycleID])
        try complete(first, with: service, at: timestamp)
        _ = try service.ensureCurrentCycle(now: timestamp.addingTimeInterval(86400), timeZone: utc, calendar: utcCalendar)
        let cycles = try repository.fetchAll()
        XCTAssertEqual(cycles.count, 2)
        XCTAssertEqual(cycles.filter(\.isCurrent).map(\.articleID), ["a2"])
        XCTAssertTrue(cycles[0].isComplete)
    }

    func testInvalidCandidateCannotCreateSwiftDataCycleOrArticle() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let invalid = ArticleCandidate(id: "bad", canonicalURL: "https://example.invalid/bad", title: "Bad", sourceID: "fixture")
        let service = DailyCycleService(cycleStore: dependencies.cycleRepository, candidateProvider: FixtureArticleCandidateProvider(fixtures: [invalid]))
        XCTAssertThrowsError(try service.ensureCurrentCycle(now: date("2026-10-26T01:00:00Z"), timeZone: utc, calendar: utcCalendar))
        XCTAssertTrue(try dependencies.cycleRepository.fetchAll().isEmpty)
        XCTAssertTrue(try dependencies.articleRepository.allArticleIDs().isEmpty)
    }

    func testArticleRepositoryRejectsNormalizedDuplicateCanonicalURL() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
        let repository = ArticleRepository(context: ModelContext(container))
        let first = fixture(id: "a1")
        let duplicate = ArticleCandidate(
            id: "a2",
            canonicalURL: "HTTPS://EXAMPLE.INVALID/a1/#fragment",
            title: "Duplicate",
            sourceID: "test-fixture",
            licenseID: "fixture-license",
            licenseVerified: true,
            bodyText: "Fixture body",
            contentStatus: .available,
            topicTags: ["test"], cachePermission: .persistent, sourceAttribution: "Explicit test fixture"
        )
        try repository.save(candidate: first, fetchedAt: .now)
        XCTAssertThrowsError(try repository.save(candidate: duplicate, fetchedAt: .now)) { error in
            XCTAssertTrue(error is PersistenceError)
            XCTAssertTrue(error.localizedDescription.contains("canonicalURL"))
        }
    }

    func testFakeStoreRetryRepeatsFailedUpdateWithoutDuplicateCycle() throws {
        let store = FailingCycleStore(failuresRemaining: 1)
        let cycle = try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "a1", createdAtUTC: .now, updatedAtUTC: .now, assignmentReason: "test")
        store.cycles = [cycle]
        let service = DailyCycleService(cycleStore: store, candidateProvider: EmptyArticleCandidateProvider())
        XCTAssertThrowsError(try service.updateTask(cycleID: cycle.cycleID, task: .article, to: .inProgress, at: .now))
        let retried = try service.updateTask(cycleID: cycle.cycleID, task: .article, to: .inProgress, at: .now)
        XCTAssertEqual(retried.articleTaskStatus, .inProgress)
        XCTAssertEqual(store.cycles.count, 1)
    }

    func testViewModelWithFakeStoreRetriesOriginalBlockedUpdate() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
        let store = FailingCycleStore(failuresRemaining: 1)
        let timestamp = date("2026-10-26T01:00:00Z")
        let cycle = try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "a1", createdAtUTC: timestamp, updatedAtUTC: timestamp, assignmentReason: "test")
        store.cycles = [cycle]
        let service = DailyCycleService(cycleStore: store, candidateProvider: EmptyArticleCandidateProvider())
        let dependencies = AppDependencies(modelContainer: container, calendar: utcCalendar, timeZone: utc, cycleService: service)
        let viewModel = TodayViewModel(dependencies: dependencies, now: { timestamp })

        viewModel.load()
        viewModel.update(task: .article, to: .blocked, reason: "测试写入失败后的重试")
        guard case .saveFailed = viewModel.state else { return XCTFail("Expected the failed write state") }
        viewModel.retry()
        guard case let .loaded(snapshot) = viewModel.state else { return XCTFail("Expected retry to reload the saved cycle") }
        XCTAssertEqual(snapshot.cycle.articleTaskStatus, .blocked)
        XCTAssertEqual(store.cycles.count, 1)
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

    private func fixture(id: String, title: String = "Explicit fixture article") -> ArticleCandidate {
        ArticleCandidate(
            id: id,
            canonicalURL: "https://example.invalid/\(id)",
            title: title,
            sourceID: "test-fixture",
            licenseID: "fixture-license",
            licenseVerified: true,
            bodyText: "Fixture body",
            contentStatus: .available,
            topicTags: ["test"], cachePermission: .persistent, sourceAttribution: "Explicit test fixture"
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)!
    }

    private func complete(_ cycle: DailyStudyCycle, with service: DailyCycleService, at timestamp: Date) throws {
        _ = try service.completeReading(cycleID: cycle.cycleID, evidence: readingProof(articleID: cycle.articleID, at: timestamp))
        _ = try service.resolveReviewQueue(cycleID: cycle.cycleID, at: timestamp)
    }

    private func readingProof(articleID: String, at timestamp: Date, progress: Double = 0.9) throws -> ReadingCompletionEvidence {
        try ReadingCompletionEvidence(articleID: articleID, bodyHash: XCTUnwrap(fixture(id: articleID).bodyHash), progress: progress, confirmation: .finishButton, confirmedAt: timestamp)
    }
    private func diskContainer(_ url: URL) throws -> ModelContainer {
        try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: ModelConfiguration(url: url))
    }

}

@MainActor
private final class FakeCycleStore: StudyCycleStore, AtomicCycleCreationStore {
    var articles: [String: ArticleCandidate] = [:]
    func save(cycle: DailyStudyCycle, candidate: ArticleCandidate, fetchedAt: Date) throws {
        try candidate.validate(at: fetchedAt)
        try save(cycle)
        articles[candidate.id] = candidate
    }
    var cycles: [DailyStudyCycle] = []

    func fetchAll() throws -> [DailyStudyCycle] { cycles }
    func fetchEarliestIncomplete() throws -> DailyStudyCycle? { cycles.sorted { ($0.assignedLocalDate, $0.createdAtUTC) < ($1.assignedLocalDate, $1.createdAtUTC) }.first(where: { $0.hasOutstandingWork }) }
    func fetch(by cycleID: UUID) throws -> DailyStudyCycle? { cycles.first(where: { $0.cycleID == cycleID }) }
    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle? { cycles.first(where: { $0.assignedLocalDate == localDate }) }
    func save(_ cycle: DailyStudyCycle) throws {
        if let index = cycles.firstIndex(where: { $0.cycleID == cycle.cycleID }) { cycles[index] = cycle } else { cycles.append(cycle) }
    }
}

@MainActor
private final class FailingCycleStore: StudyCycleStore {
    var cycles: [DailyStudyCycle] = []
    var failuresRemaining: Int

    init(failuresRemaining: Int) { self.failuresRemaining = failuresRemaining }
    func fetchAll() throws -> [DailyStudyCycle] { cycles }
    func fetchEarliestIncomplete() throws -> DailyStudyCycle? { cycles.first(where: { $0.hasOutstandingWork }) }
    func fetch(by cycleID: UUID) throws -> DailyStudyCycle? { cycles.first(where: { $0.cycleID == cycleID }) }
    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle? { cycles.first(where: { $0.assignedLocalDate == localDate }) }
    func save(_ cycle: DailyStudyCycle) throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw NSError(domain: "FailingCycleStore", code: 1)
        }
        if let index = cycles.firstIndex(where: { $0.cycleID == cycle.cycleID }) { cycles[index] = cycle } else { cycles.append(cycle) }
    }
}

@MainActor
private struct FixtureReviewQueue: ReviewQueueReading {
    var ids: [String] = []
    var complete = true
    func eligibleQueue(for cycleID: UUID, at timestamp: Date) throws -> ReviewQueueSnapshot {
        ReviewQueueSnapshot(revision: "explicit-test-snapshot-v1", eligibleEntryIDs: ids, isComplete: complete)
    }
}

extension LexiDawnTests {
    func testArbitraryDeferredReasonsAreRejectedForEveryTaskWithoutMutation() throws {
        let original = try freshCycle()
        for task in DailyTask.allCases {
            for reason in [nil, "", "test", "no-review-items", "系统确认队列为空"] as [String?] {
                var cycle = original
                XCTAssertThrowsError(try cycle.update(task: task, to: .deferred, reason: reason, at: original.updatedAtUTC))
                XCTAssertEqual(cycle, original)
            }
        }
    }

    func testUnavailableNonemptyAndIncompleteQueuesCannotDeferReview() throws {
        let readers: [any ReviewQueueReading] = [UnavailableReviewQueue(), FixtureReviewQueue(ids: ["due-word"]), FixtureReviewQueue(complete: false)]
        for reader in readers {
            let cycle = try freshCycle()
            XCTAssertThrowsError(try ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: reader, at: cycle.createdAtUTC))
            XCTAssertEqual(cycle.reviewTaskStatus, .ready)
        }
    }

    func testEmptyQueueProofCannotBeReplayedForAnotherCycle() throws {
        let first = try freshCycle()
        var second = try freshCycle()
        let evidence = try ReviewQueueEvidence.evaluate(cycleID: first.cycleID, reader: FixtureReviewQueue(), at: first.createdAtUTC)
        XCTAssertThrowsError(try second.resolveEmptyReview(evidence))
        XCTAssertNil(second.reviewEvidence)
    }

    func testProductionContractsRejectReadingCompletionAndUnknownQueue() throws {
        let dependencies = try AppDependencies.makeInMemory(candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1")]))
        let now = date("2026-10-26T01:00:00Z")
        guard case let .cycle(cycle, _) = try dependencies.cycleService.ensureCurrentCycle(now: now, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }
        XCTAssertThrowsError(try dependencies.cycleService.completeReading(cycleID: cycle.cycleID, evidence: readingProof(articleID: "a1", at: now)))
        XCTAssertThrowsError(try dependencies.cycleService.resolveReviewQueue(cycleID: cycle.cycleID, at: now))
        XCTAssertEqual(try dependencies.cycleRepository.fetch(by: cycle.cycleID), cycle)
    }

    func testReadingEvidenceRequiresProgressAndExplicitConfirmationOrManualConfirmation() throws {
        let now = date("2026-10-26T01:00:00Z")
        let hash = try XCTUnwrap(fixture(id: "a1").bodyHash)
        for progress in [-0.1, 0, 0.899, 1.1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try ReadingCompletionEvidence(articleID: "a1", bodyHash: hash, progress: progress, confirmation: .finishButton, confirmedAt: now))
        }
        _ = try ReadingCompletionEvidence(articleID: "a1", bodyHash: hash, progress: 0.9, confirmation: .endConfirmation, confirmedAt: now)
        var cycle = try freshCycle()
        let manual = try ReadingCompletionEvidence(articleID: "a1", bodyHash: hash, progress: 0.1, confirmation: .manualConfirmation, confirmedAt: now)
        try cycle.completeReading(manual)
        let completed = cycle
        try cycle.completeReading(manual)
        XCTAssertEqual(cycle, completed)
        XCTAssertThrowsError(try cycle.update(task: .article, to: .ready, at: now))
        XCTAssertThrowsError(try cycle.completeReading(readingProof(articleID: "other", at: now)))
    }

    func testConstructorRejectsInvalidStatusCompletionTimeDateAndReasonCombinations() throws {
        let now = date("2026-10-26T01:00:00Z")
        for task in DailyTask.allCases {
            XCTAssertThrowsError(try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "a1",
                articleTaskStatus: task == .article ? .deferred : .ready,
                reviewTaskStatus: task == .review ? .deferred : .ready,
                matchingStageStatus: task == .matching ? .deferred : .ready,
                clozeStageStatus: task == .cloze ? .deferred : .ready,
                createdAtUTC: now, updatedAtUTC: now, assignmentReason: "test"))
        }
        XCTAssertThrowsError(try DailyStudyCycle(assignedLocalDate: "2026-02-30", assignedTimeZoneID: "UTC", articleID: "a1", createdAtUTC: now, updatedAtUTC: now, assignmentReason: "test"))
        XCTAssertThrowsError(try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "invalid", articleID: "a1", createdAtUTC: now, updatedAtUTC: now, assignmentReason: "test"))
        XCTAssertThrowsError(try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "a1", articleTaskStatus: .completed, createdAtUTC: now, updatedAtUTC: now, assignmentReason: "test"))
        XCTAssertThrowsError(try DailyStudyCycle(assignedLocalDate: "2026-10-26", assignedTimeZoneID: "UTC", articleID: "a1", createdAtUTC: now, updatedAtUTC: now, completedAtUTC: now, assignmentReason: "test"))
        var cycle = try freshCycle()
        XCTAssertThrowsError(try cycle.update(task: .article, to: .failed, at: now))
        XCTAssertEqual(cycle.articleTaskStatus, .ready)
        XCTAssertThrowsError(try cycle.update(task: .article, to: .blocked, reason: "failure", at: now.addingTimeInterval(-1)))
    }

    func testSwiftDataStrictDecodeRejectsLegacyDeferredAndRepairArchivesWithoutLosingAssignment() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let cycle = try freshCycle()
        try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC)
        let context = dependencies.modelContainer.mainContext
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).first)
        record.articleTaskStatusRaw = "deferred"; record.articleTaskReason = "test"
        record.reviewTaskStatusRaw = "deferred"; record.reviewTaskReason = "test"
        try context.save()
        XCTAssertThrowsError(try record.domain())
        XCTAssertThrowsError(try dependencies.cycleRepository.fetchAll())
        try dependencies.cycleRepository.recoverLegacyRecords(at: cycle.createdAtUTC)
        let repaired = try XCTUnwrap(dependencies.cycleRepository.fetch(by: cycle.cycleID))
        XCTAssertEqual(repaired.articleTaskStatus, .blocked); XCTAssertEqual(repaired.reviewTaskStatus, .blocked)
        XCTAssertEqual(repaired.articleID, cycle.articleID); XCTAssertEqual(repaired.assignedLocalDate, cycle.assignedLocalDate)
        XCTAssertEqual(repaired.assignedTimeZoneID, cycle.assignedTimeZoneID); XCTAssertEqual(repaired.createdAtUTC, cycle.createdAtUTC)
        let data = try XCTUnwrap(record.recoveryArchiveData)
        let archive = try JSONDecoder().decode(CycleRecoveryArchive.self, from: data)
        XCTAssertEqual(archive.statuses.prefix(2), ["deferred", "deferred"])
        XCTAssertEqual(archive.reasons.prefix(2), ["test", "test"])
        try dependencies.cycleRepository.recoverLegacyRecords(at: cycle.createdAtUTC)
        XCTAssertEqual(record.recoveryArchiveData, data)
        XCTAssertEqual(try dependencies.articleRepository.fetch(articleID: "a1")?.bodyText, "Fixture body")
    }

    func testUnknownPersistedStateRecoveryFailsAndRetainsOriginalRecord() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let cycle = try freshCycle()
        try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC)
        let context = dependencies.modelContainer.mainContext
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).first)
        record.clozeStageStatusRaw = "future-unknown-state"
        try context.save()
        XCTAssertThrowsError(try dependencies.cycleRepository.recoverLegacyRecords(at: cycle.createdAtUTC))
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).count, 1)
        XCTAssertEqual(record.clozeStageStatusRaw, "future-unknown-state")
        XCTAssertFalse(context.hasChanges)
    }

    func testSwiftDataAtomicCreateInjectedSaveFailureRollsBackAndRetryIsIdempotent() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let context = dependencies.modelContainer.mainContext
        var failures = 1
        let repository = StudyCycleRepository(context: context) { context in
            if failures > 0 { failures -= 1; throw TestFailure.injectedBeforeSave }
            try context.save()
        }
        let cycle = try freshCycle()
        XCTAssertThrowsError(try repository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC))
        XCTAssertFalse(context.hasChanges)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ArticleRecord>()).isEmpty)
        XCTAssertTrue(try ModelContext(dependencies.modelContainer).fetch(FetchDescriptor<DailyStudyCycleRecord>()).isEmpty)
        for _ in 0..<2 { try repository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC) }
        XCTAssertEqual(try context.fetch(FetchDescriptor<ArticleRecord>()).count, 1)
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testSwiftDataUpdateFailureDoesNotLeakIntoLaterPreferenceSave() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let cycle = try freshCycle()
        try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC)
        let context = dependencies.modelContainer.mainContext
        let failing = StudyCycleRepository(context: context) { _ in throw TestFailure.injectedBeforeSave }
        var changed = cycle
        try changed.update(task: .article, to: .blocked, reason: "test-failure", at: cycle.createdAtUTC)
        XCTAssertThrowsError(try failing.save(changed))
        XCTAssertFalse(context.hasChanges)
        let preferences = try dependencies.preferencesRepository.load()
        preferences.displayName = "Later successful save"
        try dependencies.preferencesRepository.save(preferences)
        XCTAssertEqual(try StudyCycleRepository(context: ModelContext(dependencies.modelContainer)).fetch(by: cycle.cycleID), cycle)
        try dependencies.cycleRepository.save(changed)
        XCTAssertEqual(try dependencies.cycleRepository.fetch(by: cycle.cycleID)?.articleTaskStatus, .blocked)
    }

    func testSwiftDataArticleAndPreferenceFailuresRollBackManagedChanges() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let context = dependencies.modelContainer.mainContext
        let failingArticles = ArticleRepository(context: context) { _ in throw TestFailure.injectedBeforeSave }
        XCTAssertThrowsError(try failingArticles.save(candidate: fixture(id: "a1"), fetchedAt: .now))
        XCTAssertFalse(context.hasChanges)
        XCTAssertTrue(try dependencies.articleRepository.allArticleIDs().isEmpty)
        let preferences = try dependencies.preferencesRepository.load()
        preferences.displayName = "unsaved"
        let failingPreferences = PreferencesRepository(context: context) { _ in throw TestFailure.injectedBeforeSave }
        XCTAssertThrowsError(try failingPreferences.save(preferences))
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try dependencies.preferencesRepository.load().displayName, "")
        let fresh = try dependencies.preferencesRepository.load()
        fresh.displayName = "retry"
        try dependencies.preferencesRepository.save(fresh)
        XCTAssertEqual(try PreferencesRepository(context: ModelContext(dependencies.modelContainer)).load().displayName, "retry")
    }

    func testReadOnlyDiskStoreProducesRealSaveErrorAndLeavesOriginalDatabaseReadable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        do {
            let container = try diskContainer(url)
            _ = try PreferencesRepository(context: ModelContext(container)).load()
        }
        do {
            let configuration = ModelConfiguration(url: url, allowsSave: false)
            let container = try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
            let context = ModelContext(container)
            let repository = StudyCycleRepository(context: context)
            let cycle = try freshCycle()
            XCTAssertThrowsError(try repository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC))
            XCTAssertFalse(context.hasChanges)
            XCTAssertTrue(try context.fetch(FetchDescriptor<ArticleRecord>()).isEmpty)
            let preferencesRepository = PreferencesRepository(context: context)
            let preferences = try preferencesRepository.load()
            preferences.displayName = "must fail"
            XCTAssertThrowsError(try preferencesRepository.save(preferences))
            XCTAssertFalse(context.hasChanges)
        }
        let reopened = try diskContainer(url)
        XCTAssertTrue(try ModelContext(reopened).fetch(FetchDescriptor<ArticleRecord>()).isEmpty)
        XCTAssertEqual(try PreferencesRepository(context: ModelContext(reopened)).load().displayName, "")
    }

    func testSwiftDataRepositoryRejectsMissingArticleMismatchedIDDuplicateDateAndReassignment() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let cycle = try freshCycle()
        XCTAssertThrowsError(try dependencies.cycleRepository.save(cycle))
        XCTAssertThrowsError(try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "other"), fetchedAt: cycle.createdAtUTC))
        try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC)
        let sameDate = try freshCycle(articleID: "a2")
        XCTAssertThrowsError(try dependencies.cycleRepository.save(cycle: sameDate, candidate: fixture(id: "a2"), fetchedAt: cycle.createdAtUTC))
        let repeatArticle = try freshCycle(localDate: "2026-10-27")
        XCTAssertThrowsError(try dependencies.cycleRepository.save(cycle: repeatArticle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC))
        XCTAssertNil(try dependencies.articleRepository.fetch(articleID: "a2"))
        XCTAssertEqual(try dependencies.cycleRepository.fetchAll(), [cycle])
        let conflict = fixture(id: "a1", title: "conflicting source snapshot")
        XCTAssertThrowsError(try dependencies.articleRepository.save(candidate: conflict, fetchedAt: cycle.createdAtUTC))
    }

    func testDirectArticleRepositoryRejectsInvalidLicenseCacheImageAndMissingMetadata() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let now = date("2026-10-26T01:00:00Z")
        func candidate(tags: [String] = ["test"], cache: ArticleCachePermission? = .persistent,
                       image: String? = nil, attribution: String? = nil, imageLicense: String? = nil,
                       verified: Bool = true, body: String? = "Fixture body", status: ArticleContentStatus = .available) -> ArticleCandidate {
            ArticleCandidate(id: "a1", canonicalURL: "https://example.invalid/a1", title: "fixture", sourceID: "test",
                imageURL: image, imageAttribution: attribution, licenseID: "fixture-license", licenseVerified: verified,
                bodyText: body, contentStatus: status, topicTags: tags, cachePermission: cache,
                imageLicenseID: imageLicense, sourceAttribution: "test")
        }
        let invalid = [candidate(tags: []), candidate(cache: nil), candidate(cache: .until(now)),
            candidate(image: "file:///private/test", attribution: "test", imageLicense: "test"),
            candidate(image: "https://example.invalid/image"), candidate(verified: false), candidate(body: nil), candidate(status: .partial)]
        for candidate in invalid { XCTAssertThrowsError(try dependencies.articleRepository.save(candidate: candidate, fetchedAt: now)) }
        XCTAssertTrue(try dependencies.articleRepository.allArticleIDs().isEmpty)
        let valid = candidate(image: "https://example.invalid/image", attribution: "test attribution", imageLicense: "fixture-image-license")
        try dependencies.articleRepository.save(candidate: valid, fetchedAt: now)
        let record = try XCTUnwrap(dependencies.articleRepository.fetch(articleID: "a1"))
        XCTAssertEqual(record.bodyHash, valid.bodyHash); XCTAssertEqual(record.wordCount, 2)
        XCTAssertEqual(record.imageLicenseID, "fixture-image-license")
    }

    func testCarryOverCountsSkippedCivilDatesAndNeverRecountsRollback() throws {
        var cycle = try freshCycle()
        let now = cycle.createdAtUTC.addingTimeInterval(86400 * 5)
        XCTAssertTrue(cycle.markCarryOverIfNeeded(for: "2026-10-29", calendar: utcCalendar, at: now))
        XCTAssertEqual(cycle.carryOverCount, 3)
        XCTAssertFalse(cycle.markCarryOverIfNeeded(for: "2026-10-27", calendar: utcCalendar, at: now))
        XCTAssertFalse(cycle.markCarryOverIfNeeded(for: "2026-10-29", calendar: utcCalendar, at: now))
        XCTAssertTrue(cycle.markCarryOverIfNeeded(for: "2026-10-30", calendar: utcCalendar, at: now))
        XCTAssertEqual(cycle.carryOverCount, 4)
    }

    func testDSTAndTravelUseCivilDateHighWaterWithoutChangingAssignment() throws {
        let zones = [try XCTUnwrap(TimeZone(identifier: "America/New_York")), shanghai]
        for (start, end) in [("2026-03-07T17:00:00Z", "2026-03-09T16:00:00Z"), ("2026-10-31T16:00:00Z", "2026-11-02T17:00:00Z")] {
            let store = FakeCycleStore()
            let service = DailyCycleService(cycleStore: store, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1")]))
            _ = try service.ensureCurrentCycle(now: date(start), timeZone: zones[0], calendar: utcCalendar)
            let original = try XCTUnwrap(store.cycles.first)
            _ = try service.ensureCurrentCycle(now: date(end), timeZone: zones[0], calendar: utcCalendar)
            XCTAssertEqual(store.cycles.first?.carryOverCount, 2)
            _ = try service.ensureCurrentCycle(now: date(end), timeZone: zones[1], calendar: utcCalendar)
            XCTAssertEqual(store.cycles.first?.cycleID, original.cycleID)
            XCTAssertEqual(store.cycles.first?.assignedTimeZoneID, original.assignedTimeZoneID)
            XCTAssertEqual(store.cycles.count, 1)
        }
    }

    func testUnavailableInProgressRecoveryPreservesCycleArticleAndOtherProgress() throws {
        let dependencies = try AppDependencies.makeInMemory()
        var cycle = try freshCycle()
        try dependencies.cycleRepository.save(cycle: cycle, candidate: fixture(id: "a1"), fetchedAt: cycle.createdAtUTC)
        try cycle.completeReading(readingProof(articleID: "a1", at: cycle.createdAtUTC))
        try cycle.update(task: .matching, to: .inProgress, at: cycle.createdAtUTC)
        try dependencies.cycleRepository.save(cycle)
        let recovered = try XCTUnwrap(dependencies.cycleService.recoverUnavailableInProgressTasks(at: cycle.createdAtUTC))
        XCTAssertEqual(recovered.articleTaskStatus, .completed)
        XCTAssertEqual(recovered.readingEvidence, cycle.readingEvidence)
        XCTAssertEqual(recovered.matchingStageStatus, .blocked)
        XCTAssertNotNil(recovered.matchingStageReason)
        XCTAssertEqual(recovered.cycleID, cycle.cycleID)
        XCTAssertEqual(recovered.assignedLocalDate, cycle.assignedLocalDate)
        XCTAssertEqual(recovered.articleID, cycle.articleID)
    }

    func testStartupRetryReopensWithoutDeletingStore() throws {
        var attempts = 0
        let startup = AppStartup {
            attempts += 1
            if attempts == 1 { throw TestFailure.injectedBeforeSave }
            return try AppDependencies.makeInMemory()
        }
        XCTAssertNil(startup.dependencies)
        XCTAssertFalse(startup.errorMessage.isEmpty)
        startup.retry()
        XCTAssertNotNil(startup.dependencies)
        XCTAssertEqual(attempts, 2)
    }

    private func freshCycle(localDate: String = "2026-10-26", articleID: String = "a1") throws -> DailyStudyCycle {
        let now = date("2026-10-26T01:00:00Z")
        return try DailyStudyCycle(assignedLocalDate: localDate, assignedTimeZoneID: "UTC", articleID: articleID, createdAtUTC: now, updatedAtUTC: now, assignmentReason: "test-fixture")
    }
}

private enum TestFailure: Error { case injectedBeforeSave }

extension LexiDawnTests {
    func testLegacyRound1DiskSchemaUpgradesPreservingArticleCycleProgressAndPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy-round1.store")
        let cycle = try freshCycle()
        do {
            let legacy = try ModelContainer(for: LegacyRound1Schema.ArticleRecord.self, LegacyRound1Schema.DailyStudyCycleRecord.self,
                LegacyRound1Schema.UserPreferencesRecord.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(legacy); context.autosaveEnabled = false
            context.insert(LegacyRound1Schema.ArticleRecord(articleID: "a1", canonicalURL: "https://example.invalid/a1", originalTitle: "Legacy fixture", sourceID: "legacy-test", fetchedAt: cycle.createdAtUTC, licenseID: "legacy-test-license", licenseVerified: true, bodyText: "Old persisted body", createdAt: cycle.createdAtUTC, updatedAt: cycle.updatedAtUTC))
            let oldCycle = LegacyRound1Schema.DailyStudyCycleRecord(cycle: cycle)
            oldCycle.matchingStageStatusRaw = "inProgress"
            context.insert(oldCycle)
            context.insert(LegacyRound1Schema.UserPreferencesRecord(displayName: "Old Lexi", dailyReadingReminderHour: 8, autoAddOnWordTap: false))
            try context.save()
        }
        do {
            let upgraded = try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url))
            let dependencies = AppDependencies(modelContainer: upgraded)
            try dependencies.cycleRepository.recoverLegacyRecords(at: cycle.createdAtUTC)
            let restored = try XCTUnwrap(dependencies.cycleRepository.fetch(by: cycle.cycleID))
            XCTAssertEqual(restored.matchingStageStatus, .inProgress)
            XCTAssertEqual(restored.articleID, cycle.articleID)
            XCTAssertEqual(restored.assignedLocalDate, cycle.assignedLocalDate)
            XCTAssertEqual(restored.assignedTimeZoneID, cycle.assignedTimeZoneID)
            XCTAssertEqual(restored.createdAtUTC, cycle.createdAtUTC)
            XCTAssertEqual(try dependencies.articleRepository.fetch(articleID: "a1")?.bodyText, "Old persisted body")
            let preferences = try dependencies.preferencesRepository.load()
            XCTAssertEqual(preferences.displayName, "Old Lexi"); XCTAssertEqual(preferences.dailyReadingReminderHour, 8)
            XCTAssertFalse(preferences.autoAddOnWordTap); XCTAssertNil(preferences.ageRange)
            XCTAssertEqual(preferences.dailyReviewLimit, 20) // preserve saved legacy preference, do not reset to new default
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("before-r2").path))
        }
        // Verify the pre-upgrade backup itself remains usable by the actual old model.
        let backupURL = url.appendingPathExtension("before-r2").appendingPathComponent(url.lastPathComponent)
        let backup = try ModelContainer(for: LegacyRound1Schema.ArticleRecord.self, LegacyRound1Schema.DailyStudyCycleRecord.self,
            LegacyRound1Schema.UserPreferencesRecord.self, configurations: ModelConfiguration(url: backupURL))
        XCTAssertEqual(try ModelContext(backup).fetch(FetchDescriptor<LegacyRound1Schema.ArticleRecord>()).first?.bodyText, "Old persisted body")
    }

    func testLegacyRemediatedDiskSchemaRepairsUnprovenCompletionWithAuditArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy-remediated.store")
        let cycle = try freshCycle()
        do {
            let legacy = try ModelContainer(for: LegacyRemediatedSchema.ArticleRecord.self, LegacyRemediatedSchema.DailyStudyCycleRecord.self,
                LegacyRemediatedSchema.UserPreferencesRecord.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(legacy); context.autosaveEnabled = false
            context.insert(LegacyRemediatedSchema.ArticleRecord(articleID: "a1", canonicalURL: "https://example.invalid/a1", originalTitle: "Legacy fixture", sourceID: "legacy-test", fetchedAt: cycle.createdAtUTC, licenseID: "legacy-test-license", licenseVerified: true, bodyText: "Old persisted body", createdAt: cycle.createdAtUTC, updatedAt: cycle.updatedAtUTC))
            let oldCycle = LegacyRemediatedSchema.DailyStudyCycleRecord(cycle: cycle)
            oldCycle.articleTaskStatusRaw = "completed"
            oldCycle.reviewTaskStatusRaw = "deferred"; oldCycle.matchingStageStatusRaw = "deferred"; oldCycle.clozeStageStatusRaw = "deferred"
            oldCycle.reviewTaskReason = "test"; oldCycle.matchingStageReason = "test"; oldCycle.clozeStageReason = "test"
            oldCycle.completedAtUTC = cycle.createdAtUTC; oldCycle.completionReason = "completed-with-no-review-items"; oldCycle.isCurrent = false
            context.insert(oldCycle)
            context.insert(LegacyRemediatedSchema.UserPreferencesRecord(displayName: "Old Lexi", fixedTimeZoneID: "Asia/Shanghai"))
            try context.save()
        }
        do {
            let upgraded = try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url))
            let dependencies = AppDependencies(modelContainer: upgraded)
            XCTAssertThrowsError(try dependencies.cycleRepository.fetchAll())
            try dependencies.cycleRepository.recoverLegacyRecords(at: cycle.createdAtUTC)
            let restored = try XCTUnwrap(dependencies.cycleRepository.fetch(by: cycle.cycleID))
            XCTAssertEqual(restored.articleTaskStatus, .blocked); XCTAssertEqual(restored.reviewTaskStatus, .blocked)
            XCTAssertEqual(restored.matchingStageStatus, .blocked); XCTAssertEqual(restored.clozeStageStatus, .blocked)
            XCTAssertNil(restored.completedAtUTC); XCTAssertTrue(restored.isCurrent)
            XCTAssertEqual(restored.articleID, cycle.articleID); XCTAssertEqual(restored.assignedLocalDate, cycle.assignedLocalDate)
            XCTAssertEqual(restored.assignedTimeZoneID, cycle.assignedTimeZoneID)
            let record = try XCTUnwrap(upgraded.mainContext.fetch(FetchDescriptor<DailyStudyCycleRecord>()).first)
            let archive = try JSONDecoder().decode(CycleRecoveryArchive.self, from: XCTUnwrap(record.recoveryArchiveData))
            XCTAssertEqual(archive.completedAtUTC, cycle.createdAtUTC)
            XCTAssertEqual(archive.statuses, ["completed", "deferred", "deferred", "deferred"])
            XCTAssertEqual(try dependencies.articleRepository.fetch(articleID: "a1")?.bodyText, "Old persisted body")
            XCTAssertEqual(try dependencies.preferencesRepository.load().displayName, "Old Lexi")
        }
        let reopened = try diskContainer(url)
        XCTAssertEqual(try StudyCycleRepository(context: ModelContext(reopened)).fetchAll().count, 1)
    }

    func testFailedStoreOpenRetainsOriginalBytesAndPreUpgradeBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("invalid.store")
        let invalid = Data("intentionally invalid database fixture".utf8)
        try invalid.write(to: url)
        XCTAssertThrowsError(try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)))
        XCTAssertEqual(try Data(contentsOf: url), invalid)
        let backup = url.appendingPathExtension("before-r2").appendingPathComponent(url.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: backup), invalid)
    }
}

extension LexiDawnTests {
    func testPartialReadingReviewAndMatchingProgressSurviveMultipleDaysWithoutNewAssignment() throws {
        for scenario in ["reading-only", "review-only", "matching-only"] {
            let dependencies = try AppDependencies.makeInMemory(candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1"), fixture(id: "a2")]))
            let now = date("2026-10-26T01:00:00Z")
            guard case let .cycle(original, _) = try dependencies.cycleService.ensureCurrentCycle(now: now, timeZone: utc, calendar: utcCalendar) else { return XCTFail() }
            var partial = original
            if scenario == "reading-only" {
                try partial.completeReading(readingProof(articleID: "a1", at: now))
            } else {
                let result = ReviewSessionResult(cycleID: original.cycleID, sessionID: UUID(), sourceRevision: "explicit-saved-session-fixture",
                    matchingQuestionIDs: ["match-1"], clozeQuestionIDs: ["cloze-1"], matchingAnsweredIDs: ["match-1"],
                    clozeAnsweredIDs: scenario == "review-only" ? ["cloze-1"] : [], recordedAt: now)
                try partial.recordReviewProgress(result)
                if scenario == "review-only" { XCTAssertEqual(partial.reviewTaskStatus, .completed) }
                else { XCTAssertEqual(partial.matchingStageStatus, .completed); XCTAssertNotEqual(partial.clozeStageStatus, .completed) }
            }
            try dependencies.cycleRepository.save(partial)
            guard case let .cycle(restored, created) = try dependencies.cycleService.ensureCurrentCycle(now: now.addingTimeInterval(86400 * 3), timeZone: utc, calendar: utcCalendar) else { return XCTFail() }
            XCTAssertFalse(created); XCTAssertEqual(restored.cycleID, original.cycleID)
            XCTAssertEqual(restored.articleID, original.articleID); XCTAssertEqual(restored.assignedLocalDate, original.assignedLocalDate)
            XCTAssertEqual(restored.articleTaskStatus, partial.articleTaskStatus); XCTAssertEqual(restored.reviewTaskStatus, partial.reviewTaskStatus)
            XCTAssertEqual(restored.matchingStageStatus, partial.matchingStageStatus); XCTAssertEqual(restored.clozeStageStatus, partial.clozeStageStatus)
            XCTAssertEqual(restored.reviewProgress, partial.reviewProgress); XCTAssertEqual(restored.carryOverCount, 3)
            XCTAssertEqual(try dependencies.cycleRepository.fetchAll().count, 1)
        }
    }

    func testSavedReviewSessionResultRejectsInvalidAnswersAndCannotRegressOrMixEmptyQueue() throws {
        var cycle = try freshCycle()
        let sessionID = UUID()
        func result(_ answers: [String], matching: [String] = ["m1"]) -> ReviewSessionResult {
            ReviewSessionResult(cycleID: cycle.cycleID, sessionID: sessionID, sourceRevision: "test-saved-session", matchingQuestionIDs: matching,
                clozeQuestionIDs: ["c1"], matchingAnsweredIDs: answers, clozeAnsweredIDs: [], recordedAt: cycle.createdAtUTC)
        }
        XCTAssertThrowsError(try cycle.recordReviewProgress(result(["unknown"])))
        XCTAssertThrowsError(try cycle.recordReviewProgress(result(["m1", "m1"])))
        XCTAssertThrowsError(try cycle.recordReviewProgress(result([], matching: [])))
        try cycle.recordReviewProgress(result(["m1"]))
        XCTAssertThrowsError(try cycle.recordReviewProgress(result([])))
        let evidence = try ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: FixtureReviewQueue(), at: cycle.createdAtUTC)
        XCTAssertThrowsError(try cycle.resolveEmptyReview(evidence))
    }

    func testSameContainerSeparateContextsObserveSequentialProvisioningWithoutDuplicates() throws {
        let dependencies = try AppDependencies.makeInMemory()
        let now = date("2026-10-26T01:00:00Z")
        for _ in 0..<2 {
            let repository = StudyCycleRepository(context: ModelContext(dependencies.modelContainer))
            let service = DailyCycleService(cycleStore: repository, candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1")]))
            _ = try service.ensureCurrentCycle(now: now, timeZone: utc, calendar: utcCalendar)
        }
        let context = ModelContext(dependencies.modelContainer)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ArticleRecord>()).count, 1)
    }
}

extension LexiDawnTests {
    func testViewModelHonorsFixedStudyTimeZoneAndGregorianDate() throws {
        let dependencies = try AppDependencies.makeInMemory(candidateProvider: FixtureArticleCandidateProvider(fixtures: [fixture(id: "a1")]))
        let preferences = try dependencies.preferencesRepository.load()
        preferences.timeZonePolicy = "fixed"; preferences.fixedTimeZoneID = "America/Los_Angeles"
        try dependencies.preferencesRepository.save(preferences)
        let now = date("2026-10-26T01:00:00Z")
        let viewModel = TodayViewModel(dependencies: dependencies, now: { now })
        viewModel.load()
        guard case let .loaded(snapshot) = viewModel.state else { return XCTFail() }
        XCTAssertEqual(snapshot.cycle.assignedLocalDate, "2026-10-25")
        XCTAssertEqual(snapshot.cycle.assignedTimeZoneID, "America/Los_Angeles")
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = utc
        XCTAssertEqual(DailyCycleService.studyDate(for: now, calendar: buddhist), "2026-10-26")
    }
}
