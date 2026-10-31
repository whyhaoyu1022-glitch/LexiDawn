import Foundation
import SwiftData

struct ReadableArticle: Identifiable {
    let id: String, title: String, source: String, body: String, bodyHash: String
    let topics: [String]
    let minutes: Int
    let publishedAt: Date?
    let originalURL: String?
    var accessExpiresAt: Date? = nil
}

struct ArticleLibraryItem: Identifiable {
    let id: String, title: String, source: String, topics: [String]
    let minutes: Int
    let originalURL: String?
    let cycleID: UUID?
    let percent: Double
    let completed: Bool
    let started: Bool
    let readable: Bool
}

struct ArticleAccessError: LocalizedError {
    let originalURL: String?
    var errorDescription: String? { "全文展示或缓存许可已失效，或缺少可验证的授权。学习记录已保留；请从原文入口核对许可。" }
}

@MainActor final class ContentRepository: ArticleCandidateProvider {
    let writer: RepositoryWriter
    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext)
    }
    @discardableResult func importArticle(_ draft: ArticleImportDraft, at now: Date) throws -> String {
        try draft.validate()
        let id = UUID().uuidString
        let candidate = ArticleCandidate(id: id, canonicalURL: "lexidawn-local://article/\(id)", title: draft.title,
            sourceID: "user-import", licenseID: "user-declared-local-use", licenseVerified: true, bodyText: draft.body,
            contentStatus: .available, topicTags: [draft.topic], cachePermission: .persistent,
            sourceAttribution: draft.source, fullTextDisplayAllowed: true)
        try save(candidate, scope: "user-local", evidenceURL: "local-user-confirmation", originalURL: draft.originalURL.isBlank ? nil : draft.originalURL,
                 eligible: draft.eligibleForDaily, at: now)
        return id
    }
    private func save(_ candidate: ArticleCandidate, scope: String, evidenceURL: String, originalURL: String?, eligible: Bool, at now: Date) throws {
        try candidate.validate(at: now)
        guard (candidate.sourceID == "user-import" && scope == "user-local" && evidenceURL == "local-user-confirmation") ||
                (candidate.sourceID == SourceRegistry.rfc.id && scope == "ietf-full-unmodified" && evidenceURL == SourceRegistry.rfc.licenseURL &&
                 candidate.canonicalURL == SourceRegistry.rfc.endpoint && candidate.bodyHash == Self.bundledRFCHash) else {
            throw LearningError.invalid("来源与许可凭据不匹配，不能保存为全文内容。")
        }
        try writer.write {
            let context = writer.context
            if let originalURL {
                let canonical = ArticleCandidate.normalizeCanonicalURL(originalURL)
                let allGrants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
                guard !allGrants.contains(where: { $0.articleID != candidate.id && $0.originalURL.map(ArticleCandidate.normalizeCanonicalURL) == canonical }) else {
                    throw PersistenceError.duplicateCanonicalURL(canonical)
                }
            }
            try ArticleRepository.insertOrValidate(candidate, fetchedAt: now, context: context, records: context.fetch(FetchDescriptor<ArticleRecord>()))
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>()).filter { $0.articleID == candidate.id }
            guard grants.count <= 1 else { throw PersistenceError.integrity("重复内容授权记录") }
            if let old = grants.first {
                guard old.bodyHash == candidate.bodyHash, old.sourceID == candidate.sourceID, old.scope == scope else { throw PersistenceError.integrity("不能覆盖原内容授权") }
            } else {
                context.insert(ContentGrantRecord(articleID: candidate.id, sourceID: candidate.sourceID, bodyHash: candidate.bodyHash ?? "",
                    scope: scope, evidenceURL: evidenceURL, originalURL: originalURL, acceptedAt: now, eligibleForDaily: eligible))
            }
        }
    }
    static var bundledRFCHash: String? {
        guard let url = Bundle.main.url(forResource: "rfc8890", withExtension: "txt"), let data = try? Data(contentsOf: url), let body = String(data: data, encoding: .utf8) else { return nil }
        return fingerprint(body)
    }
    func installBundledRFC(at now: Date) throws {
        guard let url = Bundle.main.url(forResource: "rfc8890", withExtension: "txt") else { throw LearningError.invalid("随附的合法 RFC 正文缺失，请使用本地导入或重试。") }
        guard let body = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw LearningError.invalid("随附 RFC 编码无效。") }
        try acceptRFC(body, at: now)
    }
    func acceptRFC(_ body: String, at now: Date) throws {
        let source = SourceRegistry.rfc
        guard fingerprint(body) == Self.bundledRFCHash else { throw LearningError.invalid("RFC 正文版本与核验原文不同，保留旧文章，等待重新核验许可与完整性。") }
        try save(ArticleCandidate(id: source.id, canonicalURL: source.endpoint, title: "The Internet is for End Users", sourceID: source.id,
            publishedAt: ISO8601DateFormatter().date(from: "2020-08-01T00:00:00Z"), licenseID: "IETF-TLP-5-3c-i", licenseVerified: true,
            bodyText: body, contentStatus: .available, topicTags: ["科技", "互联网"], cachePermission: .persistent,
            sourceAttribution: source.attribution, fullTextDisplayAllowed: true), scope: "ietf-full-unmodified", evidenceURL: source.licenseURL,
            originalURL: source.endpoint, eligible: true, at: now)
    }
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate] {
        try writer.read { context in
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            let started = Set(try context.fetch(FetchDescriptor<ArticleProgressRecord>()).filter { $0.mode == "explore" }.map(\.articleID))
            return try context.fetch(FetchDescriptor<ArticleRecord>()).sorted { $0.createdAt > $1.createdAt }.compactMap { record in
                guard !articleIDs.contains(record.articleID), !started.contains(record.articleID) else { return nil }
                let matches = grants.filter { $0.articleID == record.articleID }
                guard matches.count <= 1 else { throw PersistenceError.integrity("重复内容授权记录") }
                guard let grant = matches.first, grant.eligibleForDaily else { return nil }
                let candidate = try record.candidate()
                guard ArticleAccessPolicy.permits(candidate: candidate, storedHash: record.bodyHash ?? "", grantSource: grant.sourceID,
                    grantHash: grant.bodyHash, scope: grant.scope, now: Date(), highWater: grant.accessHighWater) else { return nil }
                return candidate
            }
        }
    }
    func allReadableIDs() throws -> [String] {
        try library().filter { $0.readable && $0.cycleID == nil && !$0.started }.map(\.id)
    }
    /// Metadata remains available even when display rights lapse. No body leaves this method.
    func library(at now: Date = Date()) throws -> [ArticleLibraryItem] {
        try writer.read { context in
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            let cycles = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>())
            let progresses = try context.fetch(FetchDescriptor<ArticleProgressRecord>())
            return try context.fetch(FetchDescriptor<ArticleRecord>()).sorted { $0.createdAt > $1.createdAt }.map { article in
                try article.validateStoredMetadata()
                let grant = grants.first { $0.articleID == article.articleID }
                let cycle = cycles.first { $0.articleID == article.articleID }
                let progress = progresses.first { $0.articleID == article.articleID && $0.cycleID == cycle?.cycleID }
                let readable = ArticleAccessPolicy.permits(candidate: try article.candidate(), storedHash: article.bodyHash ?? "",
                    grantSource: grant?.sourceID, grantHash: grant?.bodyHash, scope: grant?.scope, now: now, highWater: grant?.accessHighWater ?? now)
                return ArticleLibraryItem(id: article.articleID, title: article.originalTitle, source: article.sourceAttribution ?? article.sourceID,
                    topics: article.topicTags, minutes: article.estimatedReadMinutes, originalURL: grant?.originalURL,
                    cycleID: cycle.flatMap { UUID(uuidString: $0.cycleID) }, percent: progress?.readingPercent ?? 0,
                    completed: progress?.completedAt != nil || cycle?.articleTaskStatusRaw == "completed", started: progress != nil, readable: readable)
            }
        }
    }
    func read(articleID: String, at now: Date) throws -> ReadableArticle {
        // Persist a monotone access clock before returning any body. Clock rollback cannot resurrect an expired grant.
        let result: ReadableArticle? = try writer.write {
            let context = writer.context
            guard let article = try context.fetch(FetchDescriptor<ArticleRecord>()).first(where: { $0.articleID == articleID }) else { throw LearningError.invalid("找不到文章，学习周期已保留。") }
            try article.validateStoredMetadata()
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>()).filter { $0.articleID == articleID }
            guard grants.count == 1, let grant = grants.first else { throw ArticleAccessError(originalURL: ArticleCandidate.isWebURL(article.canonicalURL) ? article.canonicalURL : nil) }
            grant.accessHighWater = max(now, grant.accessHighWater)
            let candidate = try article.candidate()
            let permitted = ArticleAccessPolicy.permits(candidate: candidate, storedHash: article.bodyHash ?? "", grantSource: grant.sourceID,
                grantHash: grant.bodyHash, scope: grant.scope, now: now, highWater: grant.accessHighWater)
            if !permitted {
                if candidate.cachePermission?.permits(at: grant.accessHighWater) == false {
                    article.bodyText = nil; article.contentStatus = ArticleContentStatus.unavailable.rawValue
                }
                return nil
            }
            var result = ReadableArticle(id: articleID, title: article.originalTitle, source: article.sourceAttribution ?? article.sourceID,
                body: article.bodyText ?? "", bodyHash: article.bodyHash ?? "", topics: article.topicTags, minutes: article.estimatedReadMinutes,
                publishedAt: article.publishedAt, originalURL: grant.originalURL)
            if case let .until(expiry)? = candidate.cachePermission { result.accessExpiresAt = expiry }
            return result
        }
        guard let result else {
            let originalURL = try library(at: now).first { $0.id == articleID }?.originalURL
            throw ArticleAccessError(originalURL: originalURL)
        }
        return result
    }
    func acquisitionState() throws -> (Date?, String?, Date?) {
        try writer.read { context in
            let state = try context.fetch(FetchDescriptor<SourceAcquisitionRecord>()).first { $0.sourceID == SourceRegistry.rfc.id }
            return (state?.lastSuccess, state?.lastError, state?.retryAfter)
        }
    }
    func beginFetch(at now: Date) throws {
        try writer.write {
            let context = writer.context
            let state = try context.fetch(FetchDescriptor<SourceAcquisitionRecord>()).first { $0.sourceID == SourceRegistry.rfc.id } ?? SourceAcquisitionRecord(sourceID: SourceRegistry.rfc.id)
            guard state.enabled, state.retryAfter.map({ $0 <= now }) ?? true else { throw LearningError.invalid("来源仍在退避期，请稍后重试。") }
            if state.modelContext == nil { context.insert(state) }
            state.lastAttempt = now; state.retryAfter = now.addingTimeInterval(SourceRegistry.rfc.minimumRequestInterval)
        }
    }
    func finishFetch(error: String?, retryAfter: Date?, at now: Date) throws {
        try writer.write {
            guard let state = try writer.context.fetch(FetchDescriptor<SourceAcquisitionRecord>()).first else { throw PersistenceError.integrity("缺少来源请求记录") }
            state.lastError = error; if error == nil { state.lastSuccess = now }
            state.retryAfter = max(state.retryAfter ?? now, retryAfter ?? now)
        }
    }
}

protocol ArticleHTTPClient { func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) }
struct URLSessionArticleClient: ArticleHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw LearningError.invalid("来源没有返回 HTTP 响应。") }
        return (data, response)
    }
}
@MainActor final class ArticleAcquisitionService {
    let content: ContentRepository
    let client: ArticleHTTPClient
    init(content: ContentRepository, client: ArticleHTTPClient = URLSessionArticleClient()) { self.content = content; self.client = client }
    func refresh(at now: Date = Date()) async throws {
        try content.beginFetch(at: now)
        do {
            guard let url = URL(string: SourceRegistry.rfc.endpoint) else { throw LearningError.invalid("来源地址错误。") }
            var request = URLRequest(url: url); request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await client.data(for: request)
            guard response.url?.host == SourceRegistry.rfc.domain, response.statusCode == 200 else {
                let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 300
                try content.finishFetch(error: "HTTP \(response.statusCode)", retryAfter: now.addingTimeInterval(max(60, min(86400, delay))), at: now)
                throw LearningError.invalid("文章来源请求失败：HTTP \(response.statusCode)，请等待退避期后重试。")
            }
            guard data.count <= 500_000, let body = String(data: data, encoding: .utf8) else { throw LearningError.invalid("来源正文过大或编码无效。") }
            try content.acceptRFC(body, at: now)
            try content.finishFetch(error: nil, retryAfter: nil, at: now)
        } catch {
            try content.finishFetch(error: error.localizedDescription, retryAfter: now.addingTimeInterval(60), at: now)
            throw error
        }
    }
}
