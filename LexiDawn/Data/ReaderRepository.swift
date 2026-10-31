import Foundation
import SwiftData

struct ReaderPosition: Equatable {
    var percent: Double = 0
    var anchor: String?
    var offset: Int = 0
    var completedAt: Date?
    var contentChanged = false
}
@MainActor final class ReaderProgressService {
    private let writer: RepositoryWriter
    private let content: ContentRepository
    private let cycles: StudyCycleRepository
    init(context: ModelContext, content: ContentRepository, cycles: StudyCycleRepository,
         saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext); self.content = content; self.cycles = cycles
    }
    func position(article: ReadableArticle, cycleID: UUID?) throws -> ReaderPosition {
        try writer.read { context in
            let matches = try context.fetch(FetchDescriptor<ArticleProgressRecord>()).filter { $0.progressID == ArticleProgressRecord.key(article.id, cycleID) }
            guard matches.count <= 1 else { throw PersistenceError.integrity("重复阅读进度") }
            guard let record = matches.first else { return ReaderPosition() }
            try validate(record)
            if record.bodyHash != article.bodyHash {
                let paragraphs = article.body.components(separatedBy: "\n\n")
                let matching = paragraphs.filter { fingerprint($0) == record.anchor }
                return ReaderPosition(percent: 0, anchor: matching.count == 1 ? record.anchor : nil, offset: 0, contentChanged: true)
            }
            return ReaderPosition(percent: record.readingPercent, anchor: record.anchor, offset: record.characterOffset, completedAt: record.completedAt)
        }
    }
    func save(articleID: String, cycleID: UUID?, position: ReaderPosition, at now: Date) throws {
        let article = try content.read(articleID: articleID, at: now)
        try writer.write {
            let context = writer.context
            let record = try progress(article: article, cycleID: cycleID, context: context, at: now)
            try update(record, position: position, article: article, now: now)
            if let cycleID {
                var cycle = try cycleInContext(cycleID, context: context)
                if cycle.articleTaskStatus != .completed {
                    try cycle.update(task: .article, to: .inProgress, at: max(now, cycle.updatedAtUTC))
                    try cycles.applyInTransaction(cycle, context: context)
                }
            }
        }
    }
    func complete(articleID: String, cycleID: UUID?, manualConfirmation: Bool, at now: Date) throws {
        let article = try content.read(articleID: articleID, at: now)
        try writer.write {
            let context = writer.context
            let record = try progress(article: article, cycleID: cycleID, context: context, at: now)
            try validate(record)
            if record.completedAt != nil { return }
            // Evidence uses saved observed progress, never the value supplied by a completion button.
            let timestamp = max(now, record.lastReadAt)
            let evidence = try ReadingCompletionEvidence(articleID: articleID, bodyHash: article.bodyHash, progress: record.readingPercent,
                confirmation: manualConfirmation ? .manualConfirmation : .finishButton, confirmedAt: timestamp)
            if let cycleID {
                var cycle = try cycleInContext(cycleID, context: context)
                if cycle.articleTaskStatus == .completed {
                    record.completedAt = cycle.readingEvidence?.confirmedAt; record.status = "completed"
                    return
                }
                try cycle.completeReading(evidence)
                try cycles.applyInTransaction(cycle, context: context)
            }
            record.status = "completed"; record.completedAt = timestamp; record.lastReadAt = timestamp
        }
    }
    private func progress(article: ReadableArticle, cycleID: UUID?, context: ModelContext, at now: Date) throws -> ArticleProgressRecord {
        if let cycleID { guard try cycleInContext(cycleID, context: context).articleID == article.id else { throw PersistenceError.integrity("进度关联的周期文章不匹配") } }
        let matches = try context.fetch(FetchDescriptor<ArticleProgressRecord>()).filter { $0.progressID == ArticleProgressRecord.key(article.id, cycleID) }
        guard matches.count <= 1 else { throw PersistenceError.integrity("重复阅读进度") }
        if let record = matches.first { return record }
        let record = ArticleProgressRecord(articleID: article.id, cycleID: cycleID, bodyHash: article.bodyHash, at: now)
        context.insert(record); return record
    }
    private func update(_ record: ArticleProgressRecord, position: ReaderPosition, article: ReadableArticle, now: Date) throws {
        guard position.percent.isFinite, (0...1).contains(position.percent), position.offset >= 0,
              position.offset <= (article.body as NSString).length, now.timeIntervalSince1970.isFinite else { throw LearningError.invalid("阅读位置无效，原进度保留。") }
        if record.bodyHash != article.bodyHash { record.bodyHash = article.bodyHash; record.readingPercent = 0; record.characterOffset = 0; record.anchor = nil }
        record.readingPercent = max(record.readingPercent, position.percent)
        record.characterOffset = position.offset; record.anchor = position.anchor; record.lastReadAt = max(record.lastReadAt, now)
        try validate(record)
    }
    private func validate(_ record: ArticleProgressRecord) throws {
        guard record.readingPercent.isFinite, (0...1).contains(record.readingPercent), record.characterOffset >= 0,
              record.bodyHash.count == 64, record.startedAt <= record.lastReadAt,
              ["daily", "explore"].contains(record.mode), ["inProgress", "completed"].contains(record.status),
              (record.status == "completed") == (record.completedAt != nil),
              record.completedAt.map({ $0 >= record.startedAt && $0 <= record.lastReadAt }) ?? true else { throw PersistenceError.integrity("已存阅读进度无效") }
    }
}
@MainActor func cycleInContext(_ cycleID: UUID, context: ModelContext) throws -> DailyStudyCycle {
    let matches = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).filter { $0.cycleID == cycleID.uuidString }
    guard matches.count == 1, let record = matches.first else { throw DailyCycleServiceError.missingCycle(cycleID) }
    return try record.domain()
}
