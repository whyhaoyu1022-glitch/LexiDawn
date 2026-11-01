import Foundation
import SwiftData

/// Historical learning references survive migration, but cannot become readable library candidates.
@Model final class ArticleHistoryArchiveRecord {
    @Attribute(.unique) var articleID: String
    var candidateData: Data
    var storedHash: String?
    var fetchedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date
    var reasonCode: String
    var archivedWordCount: Int? = nil
    init(article: ArticleRecord, at now: Date) throws {
        articleID = article.articleID; candidateData = try JSONEncoder().encode(article.candidate())
        storedHash = article.bodyHash; fetchedAt = article.fetchedAt; createdAt = article.createdAt; updatedAt = article.updatedAt
        archivedAt = now; reasonCode = "legacy-fulltext-admission-unproven"
        archivedWordCount = article.wordCount
    }
    /// Detached metadata is used only to validate existing historical cycle references.
    func metadata() throws -> ArticleRecord {
        let value = try JSONDecoder().decode(ArticleCandidate.self, from: candidateData)
        let record = ArticleRecord(articleID: articleID, canonicalURL: value.canonicalURL, originalTitle: value.title,
            displayTitle: value.displayTitle, sourceID: value.sourceID, publishedAt: value.publishedAt, fetchedAt: fetchedAt,
            licenseID: value.licenseID, licenseVerified: value.licenseVerified, bodyText: value.bodyText, bodyHash: storedHash,
            wordCount: archivedWordCount ?? value.wordCount, estimatedReadMinutes: max(1, Int(ceil(Double(archivedWordCount ?? value.wordCount) / 200))), topicTags: value.topicTags,
            contentStatus: value.contentStatus.rawValue, createdAt: createdAt, updatedAt: updatedAt)
        record.cachePermissionData = try value.cachePermission.map { try JSONEncoder().encode($0) }
        record.sourceAttribution = value.sourceAttribution; record.fullTextDisplayAllowed = value.fullTextDisplayAllowed
        return record
    }
}

@MainActor func historicalArticleMetadata(in context: ModelContext) throws -> [ArticleRecord] {
    let live = try context.fetch(FetchDescriptor<ArticleRecord>())
    guard context.container.schema.entities.contains(where: { $0.name.hasSuffix("ArticleHistoryArchiveRecord") }) else { return live }
    let ids = Set(live.map(\.articleID))
    return try live + context.fetch(FetchDescriptor<ArticleHistoryArchiveRecord>()).filter { !ids.contains($0.articleID) }.map { try $0.metadata() }
}

extension ContentRepository {
    /// One migration transaction moves unsupported legacy rows out of ArticleRecord without deleting learning history.
    /// A write/open failure leaves the original store and cold backup available.
    func archiveLegacyIncompleteArticles(at now: Date) throws {
        try writer.write {
            let context = writer.context
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            let existing = try context.fetch(FetchDescriptor<ArticleHistoryArchiveRecord>())
            for article in try context.fetch(FetchDescriptor<ArticleRecord>()) {
                let grant = grants.first { $0.articleID == article.articleID }
                let document = article.structuredBody.flatMap { try? JSONDecoder().decode(ArticleDocument.self, from: $0) }
                let validBody = document.map { ArticleDocumentNormalizer.preservesOriginal(article.rawContent, document: $0) } ?? false
                let permitted = ArticleAccessPolicy.permits(candidate: try article.candidate(), storedHash: article.bodyHash ?? "", grantSource: grant?.sourceID,
                    grantHash: grant?.bodyHash, scope: grant?.scope, now: now, highWater: grant?.accessHighWater ?? now)
                let auditedRightsValid: Bool
                if ["audited-full-text", "personal-full-text"].contains(grant?.scope ?? "") {
                    auditedRightsValid = article.fullTextRightsEvidenceData.flatMap { try? JSONDecoder().decode(FullTextRightsEvidence.self, from: $0) }?.valid(sourceID: article.sourceID, at: now) ?? false
                } else { auditedRightsValid = true }
                if validBody && permitted && auditedRightsValid { continue }
                guard !existing.contains(where: { $0.articleID == article.articleID }) else { throw PersistenceError.integrity("历史文章归档身份冲突，原记录保留") }
                context.insert(try ArticleHistoryArchiveRecord(article: article, at: now)); context.delete(article)
            }
        }
    }
}

/// Complete prior versions of explicitly edited, unassigned personal originals.
@Model final class ArticleContentVersionRecord {
    @Attribute(.unique) var versionID: String
    var articleID: String
    var title: String
    var rawContent: String
    var structuredBody: Data
    var bodyHash: String
    var attribution: String
    var originalURL: String?
    var archivedAt: Date
    init(article: ArticleRecord, originalURL: String?, at now: Date) throws {
        guard let body = article.bodyText, !body.isBlank, let data = article.structuredBody,
              ArticleDocumentNormalizer.preservesOriginal(body, document: try JSONDecoder().decode(ArticleDocument.self, from: data)) else { throw FullTextImportError.incomplete }
        let hash = fingerprint(body), source = article.sourceAttribution ?? article.sourceID
        articleID = article.articleID; title = article.originalTitle; rawContent = body; structuredBody = data
        bodyHash = hash; attribution = source; self.originalURL = originalURL; archivedAt = now
        versionID = fingerprint(article.articleID + hash + article.originalTitle + source + (originalURL ?? ""))
    }
}

extension ContentRepository {
    func originalForEditing(articleID: String, at now: Date) throws -> ArticleImportDraft {
        try writer.read { context in
            let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).map { try $0.domain() }
            guard try articleLearningAccess(cycles: cycles, context: context, at: now).permits(articleID: articleID, cycleID: nil),
                  let article = try context.fetch(FetchDescriptor<ArticleRecord>()).first(where: { $0.articleID == articleID && $0.sourceID == "user-import" }),
                  let grant = try context.fetch(FetchDescriptor<ContentGrantRecord>()).first(where: { $0.articleID == articleID && $0.scope == "user-local" }) else { throw LearningError.invalid("只有解锁后的未指派个人原文可以更新；每日任务原文保持不变。") }
            return ArticleImportDraft(title: article.originalTitle, body: article.rawContent, source: article.sourceAttribution ?? "用户原创", originalURL: grant.originalURL ?? "", topic: article.topicTags.first ?? "个人阅读", rightsConfirmed: false, eligibleForDaily: grant.eligibleForDaily)
        }
    }
    func updateOriginal(articleID: String, draft: ArticleImportDraft, at now: Date) throws {
        try draft.validate()
        try writer.write {
            let context = writer.context
            let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).map { try $0.domain() }
            guard try articleLearningAccess(cycles: cycles, context: context, at: now).permits(articleID: articleID, cycleID: nil) else { throw LearningError.invalid("请先完成当前任务；不能修改每日已指派文章。") }
            let articles = try context.fetch(FetchDescriptor<ArticleRecord>()), grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            guard let article = articles.first(where: { $0.articleID == articleID && $0.sourceID == "user-import" }),
                  let grant = grants.first(where: { $0.articleID == articleID && $0.scope == "user-local" }) else { throw LearningError.invalid("只能更新你明确导入的个人原文。") }
            let hash = fingerprint(draft.body), canonical = ArticleCandidate.normalizeCanonicalURL(draft.originalURL)
            guard !articles.contains(where: { $0.articleID != articleID && $0.bodyHash == hash }),
                  draft.originalURL.isBlank || !grants.contains(where: { $0.articleID != articleID && $0.originalURL.map(ArticleCandidate.normalizeCanonicalURL) == canonical }) else { throw LearningError.invalid("与已有完整文章重复，原版本保留。") }
            let document = ArticleDocumentNormalizer.plainText(draft.body)
            guard ArticleDocumentNormalizer.preservesOriginal(draft.body, document: document) else { throw FullTextImportError.incomplete }
            let version = try ArticleContentVersionRecord(article: article, originalURL: grant.originalURL, at: now)
            if try !context.fetch(FetchDescriptor<ArticleContentVersionRecord>()).contains(where: { $0.versionID == version.versionID }) { context.insert(version) }
            if article.bodyHash != hash {
                for progress in try context.fetch(FetchDescriptor<ArticleProgressRecord>()) where progress.articleID == articleID && progress.completedAt != nil && progress.archivedAt == nil {
                    progress.archivedAt = now; progress.progressID += "|archive|" + UUID().uuidString
                }
            }
            let candidate = ArticleCandidate(id: articleID, canonicalURL: article.canonicalURL, title: draft.title, sourceID: "user-import", licenseID: "user-declared-local-use", licenseVerified: true, bodyText: draft.body, contentStatus: .available, topicTags: [draft.topic], cachePermission: .persistent, sourceAttribution: draft.source, fullTextDisplayAllowed: true)
            try candidate.validate(at: now)
            article.originalTitle = draft.title; article.bodyText = draft.body; article.bodyHash = hash
            article.structuredBody = try JSONEncoder().encode(document); article.wordCount = candidate.wordCount
            article.estimatedReadMinutes = candidate.estimatedReadMinutes; article.topicTags = [draft.topic]; article.sourceAttribution = draft.source
            article.extractionVersion = ArticleDocument.extractionVersion
            article.fetchedAt = now; article.updatedAt = max(article.updatedAt, now); article.completenessVerifiedAt = now
            grant.bodyHash = hash; grant.originalURL = draft.originalURL.isBlank ? nil : draft.originalURL; grant.eligibleForDaily = draft.eligibleForDaily
        }
    }
}
