import Foundation
import SwiftData
import Combine

@MainActor final class LearningServices: ObservableObject {
    let content: ContentRepository
    let acquisition: ArticleAcquisitionService
    let dictionary: DictionaryLookupService
    let vocabulary: VocabularyRepository
    let reader: ReaderProgressService
    let review: ReviewQueueService
    let cycles: StudyCycleRepository
    private let writer: RepositoryWriter
    @Published private(set) var revision = 0
    init(container: ModelContainer, cycles: StudyCycleRepository) {
        self.cycles = cycles
        let context = ModelContext(container)
        writer = RepositoryWriter(context: context)
        content = ContentRepository(context: context)
        acquisition = ArticleAcquisitionService(content: content)
        dictionary = DictionaryLookupService(context: context)
        vocabulary = VocabularyRepository(context: context)
        reader = ReaderProgressService(context: context, content: content, cycles: cycles)
        review = ReviewQueueService(context: context, cycles: cycles, dictionary: dictionary)
    }
    func changed() { revision += 1 }
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
            return LearningStatistics(articles: Set(progresses.map(\.articleID) + cycles.filter { $0.readingEvidence != nil }.map(\.articleID)).count,
                studyDays: dates.count, streak: streak, vocabulary: vocabularyCount, pending: pending)
        }
    }
    func explorationAllowed() throws -> Bool {
        let all = try cycles.fetchAll()
        return !all.isEmpty && all.allSatisfy(\.isComplete)
    }
    func openExplore(articleID: String, at now: Date) throws -> ReadableArticle {
        guard try explorationAllowed() else { throw LearningError.invalid("必做任务尚未完成，请先继续原学习周期。") }
        guard try !cycles.fetchAll().contains(where: { $0.articleID == articleID }) else { throw LearningError.invalid("此文章已属于每日任务，请从今日或阅读历史继续原任务。") }
        return try content.read(articleID: articleID, at: now)
    }
}
struct LearningStatistics { let articles: Int, studyDays: Int, streak: Int, vocabulary: Int, pending: Int }
