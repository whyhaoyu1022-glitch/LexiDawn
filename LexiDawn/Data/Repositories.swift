import Foundation
import SwiftData

final class StudyCycleRepository: StudyCycleStore, AtomicCycleCreationStore {
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
            if records.contains(where: { $0.assignedLocalDate == cycle.assignedLocalDate }) {
                throw PersistenceError.duplicateAssignedDate(cycle.assignedLocalDate)
            }
            context.insert(DailyStudyCycleRecord(cycle: cycle))
        }
        if cycle.isCurrent {
            for record in records where record.cycleID != cycle.cycleID.uuidString {
                record.isCurrent = false
            }
        }
        try context.save()
    }

    /// Saves the article and cycle in one ModelContext save boundary. SwiftData
    /// does not expose a cross-process transaction here, so repository calls
    /// are serialized on the app's main actor; rollback prevents a failed save
    /// from leaving an article inserted without its cycle.
    func save(cycle: DailyStudyCycle, candidate: ArticleCandidate, fetchedAt: Date) throws {
        do {
            let articleRecords = try context.fetch(FetchDescriptor<ArticleRecord>())
            if let duplicate = articleRecords.first(where: {
                ArticleCandidate.normalizeCanonicalURL($0.canonicalURL) == candidate.canonicalURL && $0.articleID != candidate.id
            }) {
                throw PersistenceError.duplicateCanonicalURL(duplicate.canonicalURL)
            }
            if let article = articleRecords.first(where: { $0.articleID == candidate.id }) {
                ArticleRepository.apply(candidate, to: article, fetchedAt: fetchedAt)
            } else {
                context.insert(ArticleRepository.makeArticleRecord(candidate: candidate, fetchedAt: fetchedAt))
            }

            let cycleRecords = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            if cycleRecords.contains(where: {
                $0.assignedLocalDate == cycle.assignedLocalDate && $0.cycleID != cycle.cycleID.uuidString
            }) {
                throw PersistenceError.duplicateAssignedDate(cycle.assignedLocalDate)
            }
            if let existing = cycleRecords.first(where: { $0.cycleID == cycle.cycleID.uuidString }) {
                existing.apply(cycle)
            } else {
                context.insert(DailyStudyCycleRecord(cycle: cycle))
            }
            if cycle.isCurrent {
                for record in cycleRecords where record.cycleID != cycle.cycleID.uuidString {
                    record.isCurrent = false
                }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
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
        if records.contains(where: {
            ArticleCandidate.normalizeCanonicalURL($0.canonicalURL) == candidate.canonicalURL && $0.articleID != candidate.id
        }) {
            throw PersistenceError.duplicateCanonicalURL(candidate.canonicalURL)
        }
        if let existing = records.first(where: { $0.articleID == candidate.id }) {
            Self.apply(candidate, to: existing, fetchedAt: fetchedAt)
        } else {
            context.insert(Self.makeArticleRecord(candidate: candidate, fetchedAt: fetchedAt))
        }
        try context.save()
    }

    func fetch(articleID: String) throws -> ArticleRecord? {
        try context.fetch(FetchDescriptor<ArticleRecord>()).first(where: { $0.articleID == articleID })
    }

    fileprivate static func makeArticleRecord(candidate: ArticleCandidate, fetchedAt: Date) -> ArticleRecord {
        ArticleRecord(
            articleID: candidate.id,
            canonicalURL: candidate.canonicalURL,
            originalTitle: candidate.title,
            displayTitle: candidate.displayTitle,
            sourceID: candidate.sourceID,
            publishedAt: candidate.publishedAt,
            fetchedAt: fetchedAt,
            licenseID: candidate.licenseID,
            licenseVerified: candidate.licenseVerified,
            bodyText: candidate.bodyText,
            difficulty: candidate.difficulty,
            imageURL: candidate.imageURL,
            imageAttribution: candidate.imageAttribution,
            contentStatus: candidate.contentStatus.rawValue,
            createdAt: fetchedAt,
            updatedAt: fetchedAt
        )
    }

    fileprivate static func apply(_ candidate: ArticleCandidate, to record: ArticleRecord, fetchedAt: Date) {
        record.canonicalURL = candidate.canonicalURL
        record.originalTitle = candidate.title
        record.displayTitle = candidate.displayTitle
        record.sourceID = candidate.sourceID
        record.publishedAt = candidate.publishedAt
        record.fetchedAt = fetchedAt
        record.licenseID = candidate.licenseID
        record.licenseVerified = candidate.licenseVerified
        record.bodyText = candidate.bodyText
        record.difficulty = candidate.difficulty
        record.imageURL = candidate.imageURL
        record.imageAttribution = candidate.imageAttribution
        record.contentStatus = candidate.contentStatus.rawValue
        record.updatedAt = fetchedAt
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
