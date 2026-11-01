import Foundation
import SwiftData

extension ContentRepository {
    func exploreRecommendations(at now: Date = Date()) throws -> [ArticleLibraryItem] {
        let interests = try writer.read { context in Set(try context.fetch(FetchDescriptor<UserPreferencesRecord>()).first?.interestTopics ?? []) }
        return try library(at: now).filter { $0.readable && $0.cycleID == nil && !$0.started }.sorted { a, b in
            let left = ArticleRecommendationService.score(title: a.title, topics: a.topics, interests: interests, publishedAt: a.publishedAt, wordCount: a.wordCount, at: now, sourceID: a.sourceID)
            let right = ArticleRecommendationService.score(title: b.title, topics: b.topics, interests: interests, publishedAt: b.publishedAt, wordCount: b.wordCount, at: now, sourceID: b.sourceID)
            return left == right ? a.id < b.id : left > right
        }
    }
    func resetExploration(articleID: String, at now: Date) throws {
        try writer.write {
            let context = writer.context
            let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).map { try $0.domain() }
            let access = try articleLearningAccess(cycles: cycles, context: context, at: now)
            guard access.permits(articleID: articleID, cycleID: nil) else { throw LearningError.invalid("请先完成当前任务；每日文章不能重置为探索内容。") }
            for progress in try context.fetch(FetchDescriptor<ArticleProgressRecord>()) where progress.articleID == articleID && progress.cycleID == nil && progress.archivedAt == nil {
                progress.archivedAt = now; progress.progressID += "|archive|" + UUID().uuidString
            }
        }
    }
    /// Only unreferenced, unmarked, re-downloadable official text is cache data.
    /// Every cycle, progress and vocabulary context protects its article, regardless of completion.
    func clearUnusedArticleCache() throws -> Int {
        try writer.write {
            let context = writer.context
            let protected = Set(try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).map(\.articleID))
                .union(try context.fetch(FetchDescriptor<ArticleProgressRecord>()).map(\.articleID))
                .union(try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).map(\.articleID))
            let records = try context.fetch(FetchDescriptor<ArticleRecord>()).filter {
                (ArticleSourceRegistry.canAttempt($0.sourceID) || $0.sourceID == SourceRegistry.rfc.id) && !protected.contains($0.articleID) && !$0.isFavorite && !$0.readLater
            }
            let ids = Set(records.map(\.articleID))
            for grant in try context.fetch(FetchDescriptor<ContentGrantRecord>()) where ids.contains(grant.articleID) { context.delete(grant) }
            for article in records { context.delete(article) }
            return records.count
        }
    }
    func sourceRefreshState(_ sourceID: String) throws -> (success: Date?, error: String?, retryAfter: Date?) {
        try writer.read { context in
            let records = try context.fetch(FetchDescriptor<SourceAcquisitionRecord>()).filter { $0.sourceID == sourceID }
            guard records.count <= 1 else { throw PersistenceError.integrity("来源刷新状态重复") }
            return (records.first?.lastSuccess, records.first?.lastError, records.first?.retryAfter)
        }
    }
    func recordSourceRefresh(_ sourceID: String, beginning: Bool, errorCode: String? = nil, at now: Date) throws {
        guard ArticleSourceRegistry.canAttempt(sourceID) else { throw FullTextImportError.rights }
        try writer.write {
            let context = writer.context
            let state = try context.fetch(FetchDescriptor<SourceAcquisitionRecord>()).first { $0.sourceID == sourceID } ?? SourceAcquisitionRecord(sourceID: sourceID)
            if state.modelContext == nil { context.insert(state) }
            if beginning { state.lastAttempt = now }
            else {
                state.lastError = errorCode
                if errorCode == nil { state.lastSuccess = now; state.retryAfter = nil }
                else { state.retryAfter = now.addingTimeInterval(errorCode == FullTextImportError.rateLimited.rawValue ? 3600 : 60) }
            }
        }
    }
    /// Admission is repeated at the persistence boundary. Candidate fields never reach disk first.
    @discardableResult func importFullText(_ item: FullTextArticleImport, at now: Date) throws -> Bool {
        guard ArticleSourceRegistry.canAttempt(item.sourceID), item.rights == ArticleSourceRegistry.evidence(for: item.sourceID) else { throw FullTextImportError.rights }
        if let source = ArticleSourceRegistry.personalSource(item.sourceID) {
            guard let url = URL(string: item.canonicalURL), ArticleWebPageExtractor.accepts(url, source: source) else { throw FullTextImportError.incomplete }
        }
        if item.sourceID == "wikinews" { guard let date = item.publishedAt, date >= Date(timeIntervalSince1970: 1734393600) else { throw FullTextImportError.rights } }
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
                scope: item.rights.importBasis == nil ? "audited-full-text" : "personal-full-text", evidenceURL: item.rights.termsURL, originalURL: canonical, acceptedAt: now, eligibleForDaily: true))
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
