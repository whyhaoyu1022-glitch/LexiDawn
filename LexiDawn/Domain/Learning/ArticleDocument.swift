import Foundation

struct ArticleDocument: Codable, Equatable, Sendable {
    struct Block: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable { case heading, paragraph, quotation, listItem, caption }
        let kind: Kind
        let text: String
        var level: Int = 0
        var listOrdinal: Int? = nil
    }
    let blocks: [Block]
    var text: String { blocks.map(\.text).joined(separator: "\n\n") }
    static let extractionVersion = "lexidawn-document-1"
}

enum ArticleDocumentNormalizer {
    /// Only whitespace is changed. Every non-whitespace character must survive in order.
    static func plainText(_ raw: String) -> ArticleDocument {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [ArticleDocument.Block] = [], paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { blocks.append(.init(kind: .paragraph, text: paragraph.joined(separator: " "))); paragraph = [] }
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { flush() }
            else if trimmed.hasPrefix("• ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("> ") {
                flush(); blocks.append(.init(kind: trimmed.hasPrefix("> ") ? .quotation : .listItem, text: trimmed))
            } else { paragraph.append(trimmed) }
        }
        flush()
        return ArticleDocument(blocks: blocks)
    }
    static func preservesOriginal(_ raw: String, document: ArticleDocument) -> Bool {
        func characters(_ value: String) -> String { String(value.filter { !$0.isWhitespace }) }
        return !document.blocks.isEmpty && document.blocks.allSatisfy { !$0.text.isBlank } && characters(raw) == characters(document.text)
    }
}

enum FullTextImportError: String, Error, LocalizedError, Sendable {
    case rights, incomplete, truncated, parsing, transport, rateLimited, storage, duplicate, notFound
    var errorDescription: String? { "无法导入完整文章，未添加到本地文章库。" }
}

struct FullTextRightsEvidence: Codable, Equatable, Sendable {
    let id: String, sourceID: String, termsURL: String, license: String, attribution: String
    let checkedAt: Date
    let acquisitionAllowed: Bool, persistenceAllowed: Bool, offlineAllowed: Bool, displayAllowed: Bool
    var validUntil: Date? = nil
    /// Nil on historical licensed imports. Personal instruction is never represented as publisher licensing.
    var importBasis: String? = nil
    func valid(sourceID: String, at now: Date) -> Bool {
        self.sourceID == sourceID && !id.isBlank && ArticleCandidate.isWebURL(termsURL) && !attribution.isBlank &&
        acquisitionAllowed && persistenceAllowed && offlineAllowed && displayAllowed &&
        checkedAt <= now && (validUntil.map { now < $0 } ?? true)
    }
}

struct FullTextArticleImport: Sendable {
    let sourceID: String, canonicalURL: String, title: String, author: String
    let publishedAt: Date?
    let rawContent: String
    let document: ArticleDocument
    let topics: [String]
    let rights: FullTextRightsEvidence
    /// Issued only by a full-document adapter, never by an RSS description.
    let completeDocument: Bool
    let expectedHash: String?
    let verifiedAt: Date
    var articleID: String { "fulltext-" + fingerprint(ArticleCandidate.normalizeCanonicalURL(canonicalURL)) }
}

enum ArticleQualityValidator {
    static func validate(_ item: FullTextArticleImport, at now: Date) throws {
        guard item.rights.valid(sourceID: item.sourceID, at: now) else { throw FullTextImportError.rights }
        guard item.completeDocument, !item.title.isBlank, ArticleCandidate.isWebURL(item.canonicalURL),
              !item.topics.isEmpty, item.verifiedAt <= now, !item.rawContent.isBlank,
              item.rawContent.utf8.count <= 2_000_000,
              ArticleDocumentNormalizer.preservesOriginal(item.rawContent, document: item.document) else { throw FullTextImportError.incomplete }
        if let expected = item.expectedHash, fingerprint(item.rawContent) != expected { throw FullTextImportError.truncated }
        let lower = item.rawContent.lowercased()
        guard !["subscribe to continue reading", "sign in to continue reading", "verify you are human", "access denied", "[truncated]"].contains(where: lower.contains),
              !lower.hasSuffix("…"), !lower.hasSuffix("..."), !lower.contains("\u{fffd}") else { throw FullTextImportError.truncated }
        let letters = item.rawContent.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let english = letters.filter { $0.isASCII }.count
        guard english > 0, Double(english) / Double(max(1, letters.count)) > 0.8 else { throw FullTextImportError.incomplete }
    }
}

enum ArticleRecommendationService {
    static func score(title: String, topics: [String], interests: Set<String>, publishedAt: Date?, wordCount: Int, at now: Date) -> Double {
        let age = max(0, now.timeIntervalSince(publishedAt ?? .distantPast) / 86400)
        return Double(Set(topics).intersection(interests).count) * 10 + 5 / (1 + age) + (1200...2500).contains(wordCount).doubleValue
    }
}
private extension Bool { var doubleValue: Double { self ? 3 : 0 } }
