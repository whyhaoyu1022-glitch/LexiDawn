import Foundation
import CryptoKit
import NaturalLanguage

enum LearningError: Error, LocalizedError, Equatable {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
func fingerprint(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }

struct EnglishToken: Equatable, Identifiable {
    var id: Int { range.location }
    let surface: String
    let range: NSRange
    let sentence: String
}
struct EnglishTokenizer {
    static func tokens(in text: String) -> [EnglishToken] {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        let exclusions = (try? NSRegularExpression(pattern: #"(?s)```.*?```|`[^`\n]*`|https?://[^\s]+|www\.[^\s]+|[\w.+-]+@[\w.-]+\.[A-Za-z]+|\b\w*\d\w*\b"#))?.matches(in: text, range: whole).map(\.range) ?? []
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z]+(?:['’][A-Za-z]+)*(?:[-‐][A-Za-z]+(?:['’][A-Za-z]+)*)*['’]?"#) else { return [] }
        return regex.matches(in: text, range: whole).compactMap { match in
            guard !exclusions.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return nil }
            let sentenceRange = ns.paragraphRange(for: match.range)
            return EnglishToken(surface: ns.substring(with: match.range), range: match.range,
                                sentence: ns.substring(with: sentenceRange).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    static func token(at offset: Int, tokens: [EnglishToken]) -> EnglishToken? {
        var lower = 0, upper = tokens.count
        while lower < upper { let middle = (lower + upper) / 2; if tokens[middle].range.location <= offset { lower = middle + 1 } else { upper = middle } }
        guard lower > 0, NSLocationInRange(offset, tokens[lower - 1].range) else { return nil }
        return tokens[lower - 1]
    }
    static func normalized(_ surface: String) -> String {
        surface.precomposedStringWithCanonicalMapping.lowercased().replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func lemma(_ surface: String) -> String {
        let key = normalized(surface)
        // Explicit English irregular forms; avoid destructive generic suffix stripping.
        let irregular = ["ran": "run", "running": "run", "runs": "run", "went": "go", "gone": "go", "children": "child", "mice": "mouse"]
        if let lemma = irregular[key] { return lemma }
        guard !key.contains("-"), !key.contains(" "), !key.isEmpty else { return key }
        let tagger = NLTagger(tagSchemes: [.lemma]); tagger.string = key
        tagger.setLanguage(.english, range: key.startIndex..<key.endIndex)
        let (tag, _) = tagger.tag(at: key.startIndex, unit: .word, scheme: .lemma)
        return tag?.rawValue.lowercased() ?? key
    }
}

struct BasicReviewScheduler {
    static let version = "lexidawn-basic-1" // Deliberately NOT FSRS. Immutable logs allow a later FSRS migration.
    enum Grade: String { case again, hard, good }
    static func interval(previous: Int, grade: Grade) -> Int {
        let bounded = min(max(0, previous), 3650)
        switch grade { case .again: return 1; case .hard: return max(2, min(3650, bounded + 2)); case .good: return max(4, min(3650, bounded * 2)) }
    }
    static func mask(_ word: String) -> String {
        let letters = Array(word); let indices = letters.indices.filter { letters[$0].isLetter }
        let count = max(1, Int(ceil(Double(indices.count) * 0.35)))
        let hidden = Set(indices.dropFirst(indices.count > 1 ? 1 : 0).reversed().prefix(count))
        return String(letters.indices.map { hidden.contains($0) ? "_" : letters[$0] })
    }
}

struct ArticleImportDraft {
    var title: String
    var body: String
    var source: String
    var originalURL: String = ""
    var topic: String = "个人阅读"
    var rightsConfirmed: Bool = false
    var eligibleForDaily: Bool = true
    func validate() throws {
        guard rightsConfirmed else { throw LearningError.invalid("请明确确认有权将内容导入本地个人使用；此声明不授予第三方版权，也不会抓取网页。") }
        guard !title.isBlank, title.count <= 250, !source.isBlank, source.count <= 200, !topic.isBlank else { throw LearningError.invalid("请填写有效标题、来源和主题。") }
        guard !body.isBlank, body.utf8.count <= 500_000, !EnglishTokenizer.tokens(in: body).isEmpty,
              !body.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && ![9, 10, 13].contains(Int($0.value)) }) else { throw LearningError.invalid("正文须包含英文，最多 500 KB，且不能包含控制字符。") }
        guard originalURL.isBlank || ArticleCandidate.isWebURL(originalURL) else { throw LearningError.invalid("原始链接必须是没有账号密码的 HTTP/HTTPS URL。") }
    }
}

struct ArticleSource {
    let id: String, name: String, domain: String, type: String, endpoint: String, licenseURL: String, attribution: String
    let fullText: Bool, persistentCache: Bool, images: Bool, derivatives: Bool
    let minimumRequestInterval: TimeInterval
}
enum SourceRegistry {
    static let rfc = ArticleSource(id: "rfc-editor-8890", name: "RFC Editor · RFC 8890", domain: "www.rfc-editor.org", type: "official-plain-text",
        endpoint: "https://www.rfc-editor.org/rfc/rfc8890.txt", licenseURL: "https://trustee.ietf.org/documents/trust-legal-provisions/tlp-5/",
        attribution: "M. Nottingham · RFC 8890 (August 2020). Copyright © 2020 IETF Trust and the identified authors. Full unmodified document including notices.",
        fullText: true, persistentCache: true, images: false, derivatives: false, minimumRequestInterval: 60)
}

struct ArticleAccessPolicy {
    static func permits(candidate: ArticleCandidate, storedHash: String, grantSource: String?, grantHash: String?, scope: String?, now: Date, highWater: Date) -> Bool {
        guard now.timeIntervalSince1970.isFinite, highWater.timeIntervalSince1970.isFinite,
              candidate.bodyHash == storedHash, grantHash == storedHash, grantSource == candidate.sourceID,
              ["user-local", "ietf-full-unmodified"].contains(scope ?? "") else { return false }
        return (try? candidate.validate(at: max(now, highWater))) != nil
    }
}
