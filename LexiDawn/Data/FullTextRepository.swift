import Foundation
import SwiftData

extension ContentRepository {
    /// Admission is repeated at the persistence boundary. Candidate fields never reach disk first.
    @discardableResult func importFullText(_ item: FullTextArticleImport, at now: Date) throws -> Bool {
        guard ArticleSourceRegistry.enabled(item.sourceID), item.rights == ArticleSourceRegistry.wikipediaRights else { throw FullTextImportError.rights }
        try ArticleQualityValidator.validate(item, at: now)
        return try writer.write {
            let context = writer.context
            let records = try context.fetch(FetchDescriptor<ArticleRecord>())
            let canonical = ArticleCandidate.normalizeCanonicalURL(item.canonicalURL), hash = fingerprint(item.rawContent)
            if records.contains(where: { ArticleCandidate.normalizeCanonicalURL($0.canonicalURL) == canonical || $0.bodyHash == hash }) { return false }
            let candidate = ArticleCandidate(id: item.articleID, canonicalURL: canonical, title: item.title, sourceID: item.sourceID,
                publishedAt: item.publishedAt, licenseID: item.rights.id, licenseVerified: true, bodyText: item.rawContent,
                contentStatus: .available, topicTags: item.topics, cachePermission: .persistent,
                sourceAttribution: item.rights.attribution + "\n" + canonical, fullTextDisplayAllowed: true)
            let record = try ArticleRepository.makeArticleRecord(candidate: candidate, fetchedAt: now)
            record.author = item.author; record.structuredBody = try JSONEncoder().encode(item.document)
            record.fullTextRightsEvidenceID = item.rights.id; record.fullTextRightsEvidenceData = try JSONEncoder().encode(item.rights)
            record.completenessVerifiedAt = item.verifiedAt
            context.insert(record)
            context.insert(ContentGrantRecord(articleID: item.articleID, sourceID: item.sourceID, bodyHash: hash,
                scope: "audited-full-text", evidenceURL: item.rights.termsURL, originalURL: canonical, acceptedAt: now, eligibleForDaily: true))
            return true
        }
    }
    func setLibraryFlags(articleID: String, favorite: Bool? = nil, readLater: Bool? = nil) throws {
        try writer.write {
            guard let article = try writer.context.fetch(FetchDescriptor<ArticleRecord>()).first(where: { $0.articleID == articleID }),
                  !article.rawContent.isBlank, article.structuredBody != nil else { throw FullTextImportError.incomplete }
            if let favorite { article.isFavorite = favorite }; if let readLater { article.readLater = readLater }
        }
    }
    /// Idempotent, additive backfill. Original text, IDs and every learning relation stay unchanged.
    func migrateRound3(at now: Date) throws {
        try writer.write {
            for article in try writer.context.fetch(FetchDescriptor<ArticleRecord>()) {
                guard let body = article.bodyText, !body.isBlank, article.structuredBody == nil else { continue }
                let document = ArticleDocumentNormalizer.plainText(body)
                guard ArticleDocumentNormalizer.preservesOriginal(body, document: document) else { throw FullTextImportError.incomplete }
                article.structuredBody = try JSONEncoder().encode(document)
                article.extractionVersion = ArticleDocument.extractionVersion
                article.fullTextRightsEvidenceID = article.licenseID
                article.completenessVerifiedAt = article.fetchedAt
            }
        }
    }
}
