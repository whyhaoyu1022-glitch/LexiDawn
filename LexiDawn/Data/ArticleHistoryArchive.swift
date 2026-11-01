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
    init(article: ArticleRecord, at now: Date) throws {
        articleID = article.articleID; candidateData = try JSONEncoder().encode(article.candidate())
        storedHash = article.bodyHash; fetchedAt = article.fetchedAt; createdAt = article.createdAt; updatedAt = article.updatedAt
        archivedAt = now; reasonCode = "legacy-fulltext-admission-unproven"
    }
    /// Detached metadata is used only to validate existing historical cycle references.
    func metadata() throws -> ArticleRecord {
        let value = try JSONDecoder().decode(ArticleCandidate.self, from: candidateData)
        let record = ArticleRecord(articleID: articleID, canonicalURL: value.canonicalURL, originalTitle: value.title,
            displayTitle: value.displayTitle, sourceID: value.sourceID, publishedAt: value.publishedAt, fetchedAt: fetchedAt,
            licenseID: value.licenseID, licenseVerified: value.licenseVerified, bodyText: value.bodyText, bodyHash: storedHash,
            wordCount: value.wordCount, estimatedReadMinutes: value.estimatedReadMinutes, topicTags: value.topicTags,
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
