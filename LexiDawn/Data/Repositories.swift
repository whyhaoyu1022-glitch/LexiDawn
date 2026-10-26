import Foundation
import SwiftData

final class StudyCycleRepository: StudyCycleStore {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func fetchAll() throws -> [DailyStudyCycle] {
        try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            .sorted { ($0.assignedLocalDate, $0.createdAtUTC) < ($1.assignedLocalDate, $1.createdAtUTC) }
            .map { try $0.domain() }
    }

    func fetchEarliestIncomplete() throws -> DailyStudyCycle? {
        try fetchAll().first(where: { $0.hasOutstandingWork })
    }

    func fetch(by cycleID: UUID) throws -> DailyStudyCycle? {
        try fetchAll().first(where: { $0.cycleID == cycleID })
    }

    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle? {
        try fetchAll().first(where: { $0.assignedLocalDate == localDate })
    }

    func save(_ cycle: DailyStudyCycle) throws {
        let records = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
        if let existing = records.first(where: { $0.cycleID == cycle.cycleID.uuidString }) {
            existing.apply(cycle)
        } else {
            context.insert(DailyStudyCycleRecord(cycle: cycle))
        }
        try context.save()
    }
}

final class ArticleRepository: ArticleStore {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func allArticleIDs() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<ArticleRecord>()).map(\.articleID))
    }

    func save(candidate: ArticleCandidate, fetchedAt: Date) throws {
        let records = try context.fetch(FetchDescriptor<ArticleRecord>())
        if let existing = records.first(where: { $0.articleID == candidate.id }) {
            existing.canonicalURL = candidate.canonicalURL
            existing.originalTitle = candidate.title
            existing.sourceID = candidate.sourceID
            existing.fetchedAt = fetchedAt
            existing.updatedAt = fetchedAt
        } else {
            context.insert(ArticleRecord(
                articleID: candidate.id,
                canonicalURL: candidate.canonicalURL,
                originalTitle: candidate.title,
                sourceID: candidate.sourceID,
                fetchedAt: fetchedAt,
                createdAt: fetchedAt,
                updatedAt: fetchedAt
            ))
        }
        try context.save()
    }

    func fetch(articleID: String) throws -> ArticleRecord? {
        try context.fetch(FetchDescriptor<ArticleRecord>()).first(where: { $0.articleID == articleID })
    }
}

final class PreferencesRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func load() throws -> UserPreferencesRecord {
        if let existing = try context.fetch(FetchDescriptor<UserPreferencesRecord>()).first {
            return existing
        }
        let defaults = UserPreferencesRecord()
        context.insert(defaults)
        try context.save()
        return defaults
    }

    func save(_ preferences: UserPreferencesRecord) throws {
        preferences.lastUpdatedAt = Date()
        try context.save()
    }
}

struct EmptyArticleCandidateProvider: ArticleCandidateProvider {
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate] { [] }
}

struct FixtureArticleCandidateProvider: ArticleCandidateProvider {
    let fixtures: [ArticleCandidate]

    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate] {
        fixtures.filter { !articleIDs.contains($0.id) }
    }
}
