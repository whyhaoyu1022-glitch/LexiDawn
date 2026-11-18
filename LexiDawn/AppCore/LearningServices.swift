import Foundation
import SwiftData
import Combine

private struct RecommendationSnapshot: Codable {
    let checkedAt: Date
    let dictionaryVersion: String
    let items: [RecommendedVocabulary]
}

@MainActor final class LearningServices: ObservableObject {
    let content: ContentRepository
    let acquisition: ArticleAcquisitionService
    private(set) var discovery: ArticleDiscoveryService
    var productionNetworking = false
    @Published private(set) var recommendedVocabulary: [RecommendedVocabulary] = []
    @Published private(set) var recommendationError: String?
    @Published private(set) var refreshingRecommendations = false
    private let refreshDefaults: UserDefaults
    private static let recommendationKey = "lexidawn.recommendations.foreground-v1"
    private static let recommendationAttemptKey = "lexidawn.recommendations.attempt-v1"
    private static let articleCheckKey = "lexidawn.articles.foreground-v1"
    private var recommendationCheckedAt: Date?
    private var recommendationAttemptedAt: Date?
    private var foregroundRefreshInProgress = false
    let dictionary: DictionaryLookupService
    private(set) var vocabulary: VocabularyRepository
    private(set) var reader: ReaderProgressService
    private(set) var review: ReviewQueueService
    let cycles: StudyCycleRepository
    private let writer: RepositoryWriter
    @Published private(set) var revision = 0
    init(container: ModelContainer, cycles: StudyCycleRepository, refreshDefaults: UserDefaults = .standard) {
        self.cycles = cycles; self.refreshDefaults = refreshDefaults
        let context = ModelContext(container)
        writer = RepositoryWriter(context: context)
        content = ContentRepository(context: context)
        acquisition = ArticleAcquisitionService(content: content)
        discovery = ArticleDiscoveryService(content: content)
        dictionary = DictionaryLookupService(context: context)
        vocabulary = VocabularyRepository(context: context)
        reader = ReaderProgressService(context: context, content: content, cycles: cycles)
        review = ReviewQueueService(context: context, cycles: cycles, dictionary: dictionary)
        discovery.didStart = { [weak self] time in self?.refreshDefaults.set(time, forKey: Self.articleCheckKey) }
        recommendationAttemptedAt = refreshDefaults.object(forKey: Self.recommendationAttemptKey) as? Date
        if let data = refreshDefaults.data(forKey: Self.recommendationKey) {
            do {
                let snapshot = try JSONDecoder().decode(RecommendationSnapshot.self, from: data)
                if snapshot.dictionaryVersion == BundledMDXDictionaryProvider.sourceVersion {
                    recommendationCheckedAt = snapshot.checkedAt
                    recommendedVocabulary = snapshot.items.filter { $0.result.quickSenses.contains(where: BilingualMeaningPolicy.trusted) }
                } else {
                    recommendationAttemptedAt = nil
                }
            } catch {
                recommendationError = "无法恢复上次的词汇推荐，请重试。"
            }
        }
    }
    #if DEBUG && targetEnvironment(simulator)
    func setDiscoveryForUITesting(_ service: ArticleDiscoveryService) { discovery = service }
    func injectReviewSaveFailureForEvidence() {
        // The first write creates the real question set; the following answer transaction fails once.
        let fault = EvidenceSaveFault(allowSuccessfulWrites: 2)
        review = ReviewQueueService(context: ModelContext(writer.context.container), cycles: cycles, dictionary: dictionary) { context in
            if context.hasChanges, fault.remaining > 0 {
                if fault.allowSuccessfulWrites > 0 { fault.allowSuccessfulWrites -= 1 }
                else { fault.remaining -= 1; throw LearningError.invalid("明确故障注入：复习保存失败，作答、日志与排程均未提交。") }
            }
            try context.save()
        }
    }
    func injectVocabularySaveFailureForEvidence(allowSuccessfulWrites: Int = 0, message: String = "明确故障注入：数据库保存失败，未加入生词本。") {
        let fault = EvidenceSaveFault(allowSuccessfulWrites: allowSuccessfulWrites)
        vocabulary = VocabularyRepository(context: ModelContext(writer.context.container)) { context in
            if fault.remaining > 0 {
                if fault.allowSuccessfulWrites > 0 { fault.allowSuccessfulWrites -= 1 }
                else { fault.remaining -= 1; throw LearningError.invalid(message) }
            }
            try context.save()
        }
    }
    func injectNoteSaveFailureForEvidence() {
        let fault = EvidenceSaveFault(allowSuccessfulWrites: 0)
        vocabulary = VocabularyRepository(context: ModelContext(writer.context.container)) { context in
            if fault.remaining > 0, context.hasChanges,
               try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).contains(where: { $0.notes?.contains("Second note draft") == true }) {
                fault.remaining -= 1
                throw LearningError.invalid("明确故障注入：释义与笔记保存失败，草稿已保留。")
            }
            try context.save()
        }
    }
    #endif
    func changed() { revision += 1 }
    func recommendationService(clock: @escaping @MainActor () -> Date = { Date() }, prefetch: Bool = false) -> VocabularyRecommendationService {
        VocabularyRecommendationService(content: content, dictionary: dictionary, vocabulary: vocabulary, allowed: { [unowned self] in
            if prefetch && self.productionNetworking { return true }
            return try self.explorationAllowed(at: clock())
        })
    }
    func checkForegroundRefresh(at now: Date = Date()) async {
        guard productionNetworking, !foregroundRefreshInProgress, !Task.isCancelled else { return }
        foregroundRefreshInProgress = true
        defer { foregroundRefreshInProgress = false }
        async let articles: Void = checkForegroundArticles(at: now)
        await refreshRecommendations(at: now)
        await articles
    }
    private func checkForegroundArticles(at now: Date) async {
        if ForegroundRefreshPolicy.shouldCheck(last: refreshDefaults.object(forKey: Self.articleCheckKey) as? Date, now: now) {
            do { _ = try await discovery.refresh(at: now, onImport: { self.changed() }); changed() }
            catch is CancellationError { return }
            catch { changed() } // The shared discovery progress retains per-source failures.
        }
    }
    func refreshRecommendations(at now: Date = Date(), retry: Bool = false) async {
        guard !Task.isCancelled, !refreshingRecommendations,
              retry || ForegroundRefreshPolicy.shouldCheck(last: productionNetworking ? recommendationAttemptedAt ?? recommendationCheckedAt : nil, now: now) else { return }
        refreshingRecommendations = true
        recommendationError = nil
        defer { refreshingRecommendations = false }
        do {
            var items: [RecommendedVocabulary] = []
            let service = recommendationService(clock: { now }, prefetch: true)
            _ = try await service.discover { items.append($0) }
            try Task.checkCancellation()
            if productionNetworking {
                let snapshot = RecommendationSnapshot(checkedAt: now, dictionaryVersion: BundledMDXDictionaryProvider.sourceVersion, items: items)
                refreshDefaults.set(try JSONEncoder().encode(snapshot), forKey: Self.recommendationKey)
                refreshDefaults.set(now, forKey: Self.recommendationAttemptKey)
            }
            recommendationAttemptedAt = now; recommendationCheckedAt = now
            recommendedVocabulary = items
        } catch is CancellationError { }
        catch {
            if !Task.isCancelled {
                recommendationAttemptedAt = now
                if productionNetworking { refreshDefaults.set(now, forKey: Self.recommendationAttemptKey) }
                recommendationError = error.localizedDescription
            }
        }
    }
    func statistics(timeZone: TimeZone, at now: Date) throws -> LearningStatistics {
        let cycles = try cycles.fetchAll()
        let vocabularyCount = try vocabulary.entries().count
        let pending = try review.pendingCount(at: now)
        return try writer.read { context in
            let progresses = try context.fetch(FetchDescriptor<ArticleProgressRecord>()).filter { $0.completedAt != nil }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            var dates = Set<String>()
            for cycle in cycles {
                var eventCalendar = Calendar(identifier: .gregorian)
                eventCalendar.timeZone = TimeZone(identifier: cycle.assignedTimeZoneID) ?? timeZone
                if let at = cycle.readingEvidence?.confirmedAt { dates.insert(DailyCycleService.studyDate(for: at, calendar: eventCalendar)) }
                if let result = cycle.reviewProgress, result.isComplete { dates.insert(DailyCycleService.studyDate(for: result.recordedAt, calendar: eventCalendar)) }
            }
            for progress in progresses where progress.cycleID == nil {
                if let at = progress.completedAt { dates.insert(DailyCycleService.studyDate(for: at, calendar: calendar)) }
            }
            let today = DailyCycleService.studyDate(for: now, calendar: calendar)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map { DailyCycleService.studyDate(for: $0, calendar: calendar) }
            var cursor = dates.contains(today) ? today : (yesterday ?? today), streak = 0
            while dates.contains(cursor), let date = DailyStudyCycle.civilDate(cursor), let previous = DailyStudyCycle.civilCalendar.date(byAdding: .day, value: -1, to: date) {
                streak += 1; cursor = DailyCycleService.studyDate(for: previous, calendar: DailyStudyCycle.civilCalendar)
            }
            let start = calendar.date(byAdding: .day, value: -6, to: now).map { DailyCycleService.studyDate(for: $0, calendar: calendar) } ?? today
            let recent = dates.filter { $0 >= start && $0 <= today }.count
            return LearningStatistics(articles: Set(progresses.map(\.articleID) + cycles.filter { $0.readingEvidence != nil }.map(\.articleID)).count,
                studyDays: dates.count, streak: streak, vocabulary: vocabularyCount, pending: pending, recentDays: recent)
        }
    }
    func articleAccess(at now: Date = Date()) throws -> ArticleLearningAccess {
        let all = try cycles.fetchAll()
        return try writer.read { try articleLearningAccess(cycles: all, context: $0, at: now) }
    }
    func explorationAllowed(at now: Date = Date()) throws -> Bool {
        try articleAccess(at: now).mayExplore
    }
    func openArticle(articleID: String, cycleID: UUID?, at now: Date) throws -> ReadableArticle {
        guard try articleAccess(at: now).permits(articleID: articleID, cycleID: cycleID) else {
            throw LearningError.invalid("请先完成当前学习周期；收藏、历史和稍后阅读不会绕过任务锁定。")
        }
        return try content.read(articleID: articleID, at: now)
    }
    func openExplore(articleID: String, at now: Date) throws -> ReadableArticle {
        try openArticle(articleID: articleID, cycleID: nil, at: now)
    }
}
struct LearningStatistics { let articles: Int, studyDays: Int, streak: Int, vocabulary: Int, pending: Int, recentDays: Int }

#if DEBUG && targetEnvironment(simulator)
@MainActor private final class EvidenceSaveFault {
    var remaining = 1
    var allowSuccessfulWrites: Int
    init(allowSuccessfulWrites: Int) { self.allowSuccessfulWrites = allowSuccessfulWrites }
}
#endif

