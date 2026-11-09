import Foundation

/// Owner 2026-11-07: English-to-Chinese only. English glosses are parser metadata,
/// not a usable definition and never a reason to disable personal Chinese senses.
enum BilingualMeaningPolicy {
    static let version = "english-chinese-1"
    static func hasChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x3134F).contains($0.value) }
    }
    static func trusted(_ sense: DictionarySense) -> Bool {
        !sense.zh.isBlank && hasChinese(sense.zh) && sense.originKind == "mdx" &&
            sense.sourceRevision == BundledMDXDictionaryProvider.sourceVersion &&
            sense.sources == [BundledMDXDictionaryProvider.sourceName]
    }
    static func displaySenses(_ senses: [DictionarySense]) -> [DictionarySense] {
        let values = senses.filter { !$0.zh.isBlank && hasChinese($0.zh) && (trusted($0) || $0.originKind == "personal") }
        return values.filter(trusted) + values.filter { !trusted($0) }
    }
    static func permitsPersonal(senses: [DictionarySense], knownReliableChinese: Bool) -> Bool {
        !knownReliableChinese && !senses.contains(where: trusted)
    }
    static func partName(_ value: String?) -> String {
        switch value?.lowercased() {
        case "noun": return "n. 名词"
        case "verb": return "v. 动词"
        case "modal verb": return "情态动词"
        case "intransitive verb": return "vi. 不及物动词"
        case "transitive verb": return "vt. 及物动词"
        case "adjective": return "adj. 形容词"
        case "adverb": return "adv. 副词"
        case "pronoun": return "pron. 代词"
        case "preposition": return "prep. 介词"
        case "conjunction": return "conj. 连词"
        case "interjection": return "interj. 感叹词"
        case "determiner": return "限定词"
        case "phrase": return "短语"
        default: return "词性待补充"
        }
    }
    static let parts = ["noun", "verb", "transitive verb", "intransitive verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "determiner", "phrase"]
}

struct PersonalDictionaryExample: Codable, Equatable, Identifiable, Sendable {
    var id = UUID().uuidString
    var english = ""
    var chinese = ""
}
struct PersonalDictionarySense: Codable, Equatable, Identifiable, Sendable {
    var id = UUID().uuidString
    var partOfSpeech = ""
    var chinese = ""
    var ipa = ""
    var usage = ""
    var forms = ""
    var phrases = ""
    var examples: [PersonalDictionaryExample] = []
    var confirmed = false
    var revision = 1
    var reviewReady: Bool { confirmed && BilingualMeaningPolicy.parts.contains(partOfSpeech) && BilingualMeaningPolicy.hasChinese(chinese) }
    func dictionarySense(entryID: String) -> DictionarySense {
        DictionarySense(id: "personal|" + entryID + "|" + id, en: "", zh: chinese, line: "用户填写 · 修订 \(revision)", partOfSpeech: partOfSpeech.isBlank ? nil : partOfSpeech,
                        ipa: ipa.isBlank ? nil : ipa, examples: examples.map(\.english), forms: forms.isBlank ? nil : [forms], sources: ["个人释义"],
                        exampleTranslations: examples.map(\.chinese), usageLabels: usage.isBlank ? nil : [usage], relatedPhrases: phrases.isBlank ? nil : [phrases], originKind: "personal")
    }
    func validate() throws {
        guard chinese.count <= 500, ipa.count <= 120, usage.count <= 200, forms.count <= 500, phrases.count <= 1000, examples.count <= 20,
              examples.allSatisfy({ $0.english.count <= 1500 && $0.chinese.count <= 1500 }) else { throw LearningError.invalid("释义、例句或用法过长，请缩短后重试。") }
    }
}

struct ReviewMeaningIssue: Error, LocalizedError, Identifiable, Equatable {
    var id: String { entryID }
    let entryID: String, lemma: String, reason: String
    let canEditPersonal: Bool
    var errorDescription: String? { "“\(lemma)”" + reason }
}

/// Immutable deterministic mask. Punctuation and word separators are never consumed.
enum SpellingMaskPolicy {
    static let version = "distributed-1"
    static func mask(_ text: String, seed: String) -> (text: String, indices: [Int]) {
        let chars = Array(text), positions = chars.indices.filter { chars[$0].isLetter }
        guard positions.count >= 3 else { return (text, []) }
        let count = min(positions.count - 1, max(1, Int((Double(positions.count) * 0.35).rounded())))
        let hidden = Array(positions.sorted { fingerprint(seed + "|\($0)") < fingerprint(seed + "|\($1)") }.prefix(count)).sorted()
        let selected = Set(hidden)
        return (String(chars.indices.map { selected.contains($0) ? "_" : chars[$0] }), hidden)
    }
}

/// Source-scoped parser: only the English-language section of Chinese Wiktionary.
/// No machine translation and no arbitrary Chinese text from another language section.
#if DEBUG && targetEnvironment(simulator)
enum WiktionaryBilingualParser {
    static func parse(_ html: String, revision: String) throws -> [DictionarySense] {
        let heading = try NSRegularExpression(pattern: #"<h2\b[^>]*>(.*?)</h2>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ns = html as NSString
        let headings = heading.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard let index = headings.firstIndex(where: { match in
            let text = (try? ArticleHTMLExtractor.extract(ns.substring(with: match.range(at: 1))).text) ?? ""
            return ["英語", "英语", "English"].contains(where: { text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix($0) })
        }) else { return [] }
        let start = NSMaxRange(headings[index].range), end = index + 1 < headings.count ? headings[index + 1].range.location : ns.length
        let document = try ArticleHTMLExtractor.extract(ns.substring(with: NSRange(location: start, length: end - start)))
        let mapping = ["名詞":"noun", "名词":"noun", "動詞":"verb", "动词":"verb", "形容詞":"adjective", "形容词":"adjective", "副詞":"adverb", "副词":"adverb", "代詞":"pronoun", "代词":"pronoun", "介詞":"preposition", "介词":"preposition", "連詞":"conjunction", "连词":"conjunction", "感嘆詞":"interjection", "感叹词":"interjection", "短語":"phrase", "短语":"phrase", "限定詞":"determiner", "限定词":"determiner"]
        var part: String?, ipa: String?, senses: [DictionarySense] = [], forms: [String] = []
        for block in document.blocks {
            if block.kind == .heading {
                part = mapping.first { block.text.hasPrefix($0.key) }?.value
            } else if block.text.contains("IPA"), block.text.contains("/") {
                ipa = block.text
            } else if block.kind == .listItem, block.listOrdinal != nil, let part, BilingualMeaningPolicy.hasChinese(block.text) {
                let value = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                senses.append(DictionarySense(id: "wiktionary-zh|" + fingerprint(part + "|" + value), en: "", zh: value,
                    line: "中文维基词典贡献者 · CC BY-SA 4.0 · revision " + revision, partOfSpeech: part, ipa: ipa, forms: forms.isEmpty ? nil : forms,
                    sources: ["Wiktionary"], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/", sourceRevision: revision))
            } else if block.kind == .listItem, block.listOrdinal == nil, !senses.isEmpty, block.text.unicodeScalars.contains(where: { (65...122).contains($0.value) }) {
                var last = senses.removeLast(); last.examples = (last.examples ?? []) + [block.text]; senses.append(last)
            } else if part != nil, block.kind == .paragraph, block.text.contains("複數") || block.text.contains("过去式") || block.text.contains("過去式") {
                forms.append(block.text)
            }
        }
        return senses
    }
}

/// English Wiktionary's explicitly labelled Chinese translations, scoped to one English POS/table.
/// English glosses remain ranking metadata; they are never shown as Chinese definitions.
enum WiktionaryChineseTranslationParser {
    static func parse(_ html: String, revision: String) throws -> [DictionarySense] {
        guard html.utf8.count <= 4_000_000 else { throw FullTextImportError.parsing }
        let ns = html as NSString
        func matches(_ pattern: String, in text: String) throws -> [NSTextCheckingResult] {
            try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]).matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        }
        func plain(_ text: String) -> String { (try? ArticleHTMLExtractor.extract(text).text) ?? "" }
        let languageHeads = try matches(#"<h2\b[^>]*>(.*?)</h2>"#, in: html)
        guard let englishIndex = languageHeads.firstIndex(where: { plain(ns.substring(with: $0.range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines) == "English" }) else { return [] }
        let start = NSMaxRange(languageHeads[englishIndex].range)
        let end = englishIndex + 1 < languageHeads.count ? languageHeads[englishIndex + 1].range.location : ns.length
        let english = ns.substring(with: NSRange(location: start, length: end - start)), en = english as NSString
        let headings = try matches(#"<h[3-6]\b[^>]*>(.*?)</h[3-6]>"#, in: english)
        let tags = try matches(#"<div\b[^>]*>|</div\s*>"#, in: english)
        var stack: [(start: Int, isTranslation: Bool)] = [], frames: [NSRange] = []
        for tag in tags {
            let value = en.substring(with: tag.range).lowercased()
            if value.hasPrefix("</") {
                if let open = stack.popLast(), open.isTranslation { frames.append(NSRange(location: open.start, length: NSMaxRange(tag.range) - open.start)) }
            } else {
                let nav = value.range(of: #"class\s*=\s*["'][^"']*\bnavframe\b"#, options: .regularExpression) != nil
                stack.append((tag.range.location, nav))
            }
        }
        let richMetadata = (try? WiktionaryDictionaryProvider.parseEnglishHTML("<h2 id=\"English\">English</h2>" + english)) ?? []
        var values: [DictionarySense] = []
        for frame in frames.sorted(by: { $0.location < $1.location }) {
            let previous = headings.filter { $0.range.location < frame.location }.compactMap { match -> String? in
                let value = plain(en.substring(with: match.range(at: 1))).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return BilingualMeaningPolicy.parts.contains(value) ? value : nil
            }
            guard let part = previous.last else { continue }
            let text = en.substring(with: frame), table = text as NSString
            let chinese = try matches(#"<span\b[^>]*\blang\s*=\s*["'](?:zh|cmn|yue)["'][^>]*>(.*?)</span>"#, in: text).map { plain(table.substring(with: $0.range(at: 1))) }.filter { BilingualMeaningPolicy.hasChinese($0) && $0.count <= 100 }
            var seen = Set<String>(); let translations = chinese.filter { seen.insert($0).inserted }
            guard !translations.isEmpty else { continue }
            let glossMatch = try matches(#"<div\b[^>]*class=["'][^"']*\bNavHead\b[^"']*["'][^>]*>(.*?)</div>"#, in: text).first
            let gloss = glossMatch.map { plain(table.substring(with: $0.range(at: 1))) } ?? ""
            // Only attach shared metadata from the same POS; do not align unrelated example indices.
            let metadata = richMetadata.first { $0.partOfSpeech == part }
            let chineseText = translations.joined(separator: "；")
            values.append(DictionarySense(id: "wiktionary-translations|" + fingerprint(part + "|" + gloss + "|" + chineseText), en: gloss, zh: chineseText,
                line: "English Wiktionary contributors · 中文翻译表 · CC BY-SA 4.0 · revision " + revision, partOfSpeech: part,
                ipa: metadata?.ipa, forms: metadata?.forms, sources: ["Wiktionary"], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/", sourceRevision: revision))
        }
        return values
    }
}

#endif
