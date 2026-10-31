import Foundation
import SwiftData

/// One synchronous main-actor unit of work. Autosave must never commit a failed operation later.
@MainActor
final class RepositoryWriter {
    let context: ModelContext
    private let saveContext: (ModelContext) throws -> Void

    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.saveContext = saveContext
        context.autosaveEnabled = false
    }

    func write<T>(_ changes: () throws -> T) throws -> T {
        do {
            let result = try changes()
            try saveContext(context)
            return result
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class StudyCycleRepository: StudyCycleStore, AtomicCycleCreationStore {
    private let writer: RepositoryWriter
    private var context: ModelContext { writer.context }

    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext)
    }

    func fetchAll() throws -> [DailyStudyCycle] {
        let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            .sorted { ($0.assignedLocalDate, $0.createdAtUTC, $0.cycleID) < ($1.assignedLocalDate, $1.createdAtUTC, $1.cycleID) }
            .map { try $0.domain() }
        let articles = try context.fetch(FetchDescriptor<ArticleRecord>())
        try validateCollection(cycles, articles: articles)
        return cycles
    }

    func fetchEarliestIncomplete() throws -> DailyStudyCycle? { try fetchAll().first(where: \.hasOutstandingWork) }
    func fetch(by cycleID: UUID) throws -> DailyStudyCycle? { try fetchAll().first { $0.cycleID == cycleID } }
    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle? { try fetchAll().first { $0.assignedLocalDate == localDate } }

    func save(_ cycle: DailyStudyCycle) throws {
        try writer.write {
            try cycle.validate()
            let records = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            let articles = try context.fetch(FetchDescriptor<ArticleRecord>())
            try upsert(cycle, records: records, articles: articles)
        }
    }

    func save(cycle: DailyStudyCycle, candidate: ArticleCandidate, fetchedAt: Date) throws {
        try writer.write {
            try cycle.validate()
            try candidate.validate(at: fetchedAt)
            guard cycle.articleID == candidate.id else { throw PersistenceError.integrity("文章与周期 ID 不匹配") }
            let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            let articles = try context.fetch(FetchDescriptor<ArticleRecord>())
            try ArticleRepository.insertOrValidate(candidate, fetchedAt: fetchedAt, context: context, records: articles)
            let allArticles = try context.fetch(FetchDescriptor<ArticleRecord>())
            try upsert(cycle, records: cycles, articles: allArticles)
        }
    }

    private func upsert(_ cycle: DailyStudyCycle, records: [DailyStudyCycleRecord], articles: [ArticleRecord]) throws {
        guard let article = articles.first(where: { $0.articleID == cycle.articleID }) else { throw PersistenceError.integrity("周期缺少对应文章") }
        if let proof = cycle.readingEvidence {
            guard proof.bodyHash == article.bodyHash else { throw PersistenceError.integrity("完成证据与文章内容版本不匹配") }
        }
        let others = records.filter { $0.cycleID != cycle.cycleID.uuidString }
        guard !others.contains(where: { $0.assignedLocalDate == cycle.assignedLocalDate }) else { throw PersistenceError.duplicateAssignedDate(cycle.assignedLocalDate) }
        guard !others.contains(where: { $0.articleID == cycle.articleID }) else { throw PersistenceError.integrity("文章已经分配给其他周期") }
        if let existing = records.first(where: { $0.cycleID == cycle.cycleID.uuidString }) {
            let previous = try existing.domain()
            guard previous.articleID == cycle.articleID, previous.assignedLocalDate == cycle.assignedLocalDate,
                  previous.assignedTimeZoneID == cycle.assignedTimeZoneID, previous.createdAtUTC == cycle.createdAtUTC,
                  previous.assignmentReason == cycle.assignmentReason, cycle.updatedAtUTC >= previous.updatedAtUTC,
                  cycle.carryOverCount >= previous.carryOverCount else { throw PersistenceError.integrity("更新试图覆盖周期身份或回退进度") }
            for (old, new) in zip([previous.articleTaskStatus, previous.reviewTaskStatus, previous.matchingStageStatus, previous.clozeStageStatus],
                                  [cycle.articleTaskStatus, cycle.reviewTaskStatus, cycle.matchingStageStatus, cycle.clozeStageStatus]) {
                guard old.canTransition(to: new) else { throw TaskStatusError.invalidTransition(from: old, to: new) }
            }
            if let proof = previous.readingEvidence, cycle.readingEvidence != proof { throw PersistenceError.integrity("不能覆盖阅读完成证据") }
            if let proof = previous.reviewEvidence, cycle.reviewEvidence != proof { throw PersistenceError.integrity("不能覆盖空队列证据") }
            if let old = previous.reviewProgress {
                guard let new = cycle.reviewProgress, old.sessionID == new.sessionID,
                      old.matchingQuestionIDs == new.matchingQuestionIDs, old.clozeQuestionIDs == new.clozeQuestionIDs,
                      Set(old.matchingAnsweredIDs).isSubset(of: Set(new.matchingAnsweredIDs)),
                      Set(old.clozeAnsweredIDs).isSubset(of: Set(new.clozeAnsweredIDs)) else { throw PersistenceError.integrity("不能覆盖或回退已保存复习会话") }
            }
            if previous.isComplete && (previous.completedAtUTC != cycle.completedAtUTC || previous.completionReason != cycle.completionReason) {
                throw PersistenceError.integrity("不能重写周期完成记录")
            }
            try existing.apply(cycle)
        } else {
            guard !records.contains(where: { $0.completedAtUTC == nil }) else { throw PersistenceError.integrity("必须先完成旧周期") }
            // No future caller can create a completed assignment and bypass the update contracts.
            guard cycle.articleTaskStatus == .ready, cycle.reviewTaskStatus == .ready,
                  cycle.matchingStageStatus == .ready, cycle.clozeStageStatus == .ready else { throw PersistenceError.integrity("新周期必须从待开始状态建立") }
            try article.candidate().validate(at: cycle.createdAtUTC)
            context.insert(try DailyStudyCycleRecord(cycle: cycle))
        }
        let all = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
        try normalizeCurrent(all)
        try validateCollection(all.map { try $0.domain() }, articles: articles)
    }

    /// Explicit legacy recovery step, before normal domain reads. All repairs commit together or roll back.
    func recoverLegacyRecords(at timestamp: Date) throws {
        let records = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
        guard !records.isEmpty else { return }
        if (try? fetchAll()) != nil { return }
        try writer.write {
            for record in records { _ = try record.repairKnownLegacyState(at: timestamp) }
            try normalizeCurrent(records)
            try validateCollection(records.map { try $0.domain() }, articles: context.fetch(FetchDescriptor<ArticleRecord>()))
        }
    }

    private func normalizeCurrent(_ records: [DailyStudyCycleRecord]) throws {
        let earliest = try records.map { try $0.domain() }.filter(\.hasOutstandingWork)
            .sorted { ($0.assignedLocalDate, $0.createdAtUTC, $0.cycleID.uuidString) < ($1.assignedLocalDate, $1.createdAtUTC, $1.cycleID.uuidString) }.first
        for record in records { record.isCurrent = record.cycleID == earliest?.cycleID.uuidString }
    }

    private func validateCollection(_ cycles: [DailyStudyCycle], articles: [ArticleRecord]) throws {
        guard Set(cycles.map(\.cycleID)).count == cycles.count,
              Set(cycles.map(\.assignedLocalDate)).count == cycles.count,
              Set(cycles.map(\.articleID)).count == cycles.count else { throw PersistenceError.integrity("历史周期存在重复身份、日期或文章指派，需人工核对") }
        for cycle in cycles {
            let matches = articles.filter { $0.articleID == cycle.articleID }
            guard matches.count == 1 else { throw PersistenceError.integrity("周期文章关联不完整") }
            if let proof = cycle.readingEvidence, matches.first?.bodyHash != proof.bodyHash {
                throw PersistenceError.integrity("持久化完成证据与文章内容版本不一致")
            }
        }
        let incomplete = cycles.filter(\.hasOutstandingWork).sorted { ($0.assignedLocalDate, $0.createdAtUTC, $0.cycleID.uuidString) < ($1.assignedLocalDate, $1.createdAtUTC, $1.cycleID.uuidString) }
        guard cycles.filter(\.isCurrent).count == (incomplete.isEmpty ? 0 : 1),
              incomplete.first?.cycleID == cycles.first(where: \.isCurrent)?.cycleID else { throw PersistenceError.integrity("当前周期必须是最早未完成周期") }
    }
}

@MainActor
final class ArticleRepository: ArticleStore {
    private let writer: RepositoryWriter
    private var context: ModelContext { writer.context }
    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext)
    }
    func allArticleIDs() throws -> Set<String> { Set(try context.fetch(FetchDescriptor<ArticleRecord>()).map(\.articleID)) }
    func save(candidate: ArticleCandidate, fetchedAt: Date) throws {
        try writer.write {
            try candidate.validate(at: fetchedAt)
            try Self.insertOrValidate(candidate, fetchedAt: fetchedAt, context: context, records: context.fetch(FetchDescriptor<ArticleRecord>()))
        }
    }
    func fetch(articleID: String) throws -> ArticleRecord? {
        let record = try context.fetch(FetchDescriptor<ArticleRecord>()).first { $0.articleID == articleID }
        // Unknown content status is an error, never an invented available body.
        if let record, ArticleContentStatus(rawValue: record.contentStatus) == nil { throw PersistenceError.integrity("文章内容状态无效") }
        return record
    }

    fileprivate static func insertOrValidate(_ candidate: ArticleCandidate, fetchedAt: Date, context: ModelContext, records: [ArticleRecord]) throws {
        if records.contains(where: { ArticleCandidate.normalizeCanonicalURL($0.canonicalURL) == candidate.canonicalURL && $0.articleID != candidate.id }) {
            throw PersistenceError.duplicateCanonicalURL(candidate.canonicalURL)
        }
        if let existing = records.first(where: { $0.articleID == candidate.id }) {
            // Idempotent retry can reuse the exact snapshot; never overwrite a user's assigned text.
            guard try existing.candidate() == candidate else { throw PersistenceError.integrity("相同文章 ID 的内容或来源发生冲突") }
        } else {
            context.insert(try makeArticleRecord(candidate: candidate, fetchedAt: fetchedAt))
        }
    }

    fileprivate static func makeArticleRecord(candidate: ArticleCandidate, fetchedAt: Date) throws -> ArticleRecord {
        try candidate.validate(at: fetchedAt)
        let record = ArticleRecord(articleID: candidate.id, canonicalURL: candidate.canonicalURL, originalTitle: candidate.title,
            displayTitle: candidate.displayTitle, sourceID: candidate.sourceID, publishedAt: candidate.publishedAt, fetchedAt: fetchedAt,
            licenseID: candidate.licenseID, licenseVerified: candidate.licenseVerified, bodyText: candidate.bodyText,
            bodyHash: candidate.bodyHash, wordCount: candidate.wordCount, estimatedReadMinutes: candidate.estimatedReadMinutes,
            topicTags: candidate.topicTags, difficulty: candidate.difficulty, imageURL: candidate.imageURL,
            imageAttribution: candidate.imageAttribution, contentStatus: candidate.contentStatus.rawValue, createdAt: fetchedAt, updatedAt: fetchedAt)
        record.cachePermissionData = try candidate.cachePermission.map { try JSONEncoder().encode($0) }
        record.imageLicenseID = candidate.imageLicenseID
        record.sourceAttribution = candidate.sourceAttribution
        record.fullTextDisplayAllowed = candidate.fullTextDisplayAllowed
        record.imageLicenseVerified = candidate.imageLicenseVerified
        return record
    }
}

extension ArticleRecord {
    func candidate() throws -> ArticleCandidate {
        guard let status = ArticleContentStatus(rawValue: contentStatus) else { throw PersistenceError.integrity("文章内容状态无效") }
        return ArticleCandidate(id: articleID, canonicalURL: canonicalURL, title: originalTitle, sourceID: sourceID,
            displayTitle: displayTitle, difficulty: difficulty, imageURL: imageURL, imageAttribution: imageAttribution,
            publishedAt: publishedAt, licenseID: licenseID, licenseVerified: licenseVerified, bodyText: bodyText,
            contentStatus: status, topicTags: topicTags,
            cachePermission: try cachePermissionData.map { try JSONDecoder().decode(ArticleCachePermission.self, from: $0) },
            imageLicenseID: imageLicenseID, sourceAttribution: sourceAttribution,
            fullTextDisplayAllowed: fullTextDisplayAllowed == true, imageLicenseVerified: imageLicenseVerified == true)
    }
}

@MainActor
final class PreferencesRepository {
    private let writer: RepositoryWriter
    private var context: ModelContext { writer.context }
    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext)
    }
    func load() throws -> UserPreferencesRecord {
        if let existing = try context.fetch(FetchDescriptor<UserPreferencesRecord>()).first { return existing }
        return try writer.write {
            let defaults = UserPreferencesRecord()
            context.insert(defaults)
            return defaults
        }
    }
    func save(_ preferences: UserPreferencesRecord) throws {
        try writer.write {
            guard preferences.modelContext === context else { throw PersistenceError.integrity("偏好来自其他上下文") }
            guard preferences.schemaVersion == 1,
                  (0...23).contains(preferences.dailyReadingReminderHour), (0...59).contains(preferences.dailyReadingReminderMinute),
                  (0...23).contains(preferences.dailyReviewReminderHour), (0...59).contains(preferences.dailyReviewReminderMinute),
                  ["device", "fixed"].contains(preferences.timeZonePolicy),
                  preferences.timeZonePolicy != "fixed" || TimeZone(identifier: preferences.fixedTimeZoneID ?? "") != nil,
                  preferences.dailyReviewLimit > 0, preferences.matchingPairCount > 0, preferences.clozeQuestionCount > 0 else {
                throw PersistenceError.integrity("偏好值无效或版本不受支持")
            }
            preferences.lastUpdatedAt = Date()
        }
    }
}

struct EmptyArticleCandidateProvider: ArticleCandidateProvider {
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate] { [] }
}
struct FixtureArticleCandidateProvider: ArticleCandidateProvider {
    let fixtures: [ArticleCandidate]
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate] { fixtures.filter { !articleIDs.contains($0.id) } }
}
