import Foundation
import SwiftData
import NaturalLanguage

struct DictionaryProviderOutcome: Sendable {
    let senses: [DictionarySense]
    let failed: [String]
    let successful: [String]
    let empty: [String]
}
#if DEBUG && targetEnvironment(simulator)
struct FreeDictionaryProvider: DictionaryProvider {
    private let fetcher: ArticleFetchService
    init(fetcher: ArticleFetchService? = nil) {
        if let fetcher { self.fetcher = fetcher }
        else { let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 8; self.fetcher = ArticleFetchService(configuration: config) }
    }
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/")!.appendingPathComponent(headword)
        let transport = fetcher
        // A negative lookup is distinct from an unavailable provider. Revalidate transient CDN negatives
        // using the same documented endpoint, without changing hosts, credentials or request identity.
        for attempt in 0..<3 {
            do { return try Self.parse(await transport.fetch(url, allowedHost: "api.dictionaryapi.dev", revalidate: attempt > 0)) }
            catch FullTextImportError.notFound {
                if attempt == 2 { return [] }
                try await Task.sleep(for: .seconds(Double(attempt + 1)))
            }
        }
        return []
    }
    static func parse(_ data: Data) throws -> [DictionarySense] {
        struct Entry: Decodable {
            struct Phonetic: Decodable { let text: String?; let audio: String? }
            struct License: Decodable { let name: String; let url: String }
            struct Meaning: Decodable {
                struct Definition: Decodable { let definition: String; let example: String?; let synonyms: [String]?; let antonyms: [String]? }
                let partOfSpeech: String; let definitions: [Definition]; let synonyms: [String]?; let antonyms: [String]?
            }
            let word: String; let phonetic: String?; let phonetics: [Phonetic]?; let meanings: [Meaning]; let origin: String?; let license: License?
        }
        return try JSONDecoder().decode([Entry].self, from: data).flatMap { entry in
            entry.meanings.flatMap { meaning in meaning.definitions.map { definition in
                DictionarySense(id: "free|" + fingerprint(meaning.partOfSpeech + definition.definition), en: definition.definition, zh: "", line: entry.license.map { "\($0.name) \($0.url)" } ?? "Free Dictionary API; license not supplied; memory only",
                    partOfSpeech: meaning.partOfSpeech, ipa: entry.phonetic ?? entry.phonetics?.compactMap(\.text).first,
                    examples: definition.example.map { [$0] }, synonyms: definition.synonyms ?? meaning.synonyms, antonyms: definition.antonyms ?? meaning.antonyms,
                    etymology: entry.origin, audioURL: entry.phonetics?.compactMap(\.audio).first { $0.hasPrefix("https://") }, sources: ["Free Dictionary API"], licenseURL: entry.license?.url)
            } }
        }
    }
}
struct WiktionaryDictionaryProvider: DictionaryProvider {
    private let fetcher: ArticleFetchService
    init(fetcher: ArticleFetchService? = nil) {
        if let fetcher { self.fetcher = fetcher }
        else { let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 8; self.fetcher = ArticleFetchService(configuration: config) }
    }
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        struct Response: Decodable { struct Page: Decodable { let text: String; let revid: Int }; let parse: Page? }
        var firstError: Error?
        for host in ["zh.wiktionary.org", "en.wiktionary.org"] {
            try Task.checkCancellation()
            let api = try OfficialArticleAPI.url(host: host, fields: ["action": "parse", "page": headword, "prop": "text|revid", "format": "json", "formatversion": "2", "disableeditsection": "1"])
            do {
                let response = try JSONDecoder().decode(Response.self, from: await fetcher.fetch(api, allowedHost: host))
                guard let page = response.parse else { continue }
                let values = try host == "zh.wiktionary.org" ? WiktionaryBilingualParser.parse(page.text, revision: String(page.revid)) : WiktionaryChineseTranslationParser.parse(page.text, revision: String(page.revid))
                if !values.isEmpty { return values.map { value in
                    var sense = value; sense.line += " · " + URL(string: "https://" + host + "/wiki/")!.appendingPathComponent(headword).absoluteString; return sense
                } }
            } catch is CancellationError { throw CancellationError() }
            catch FullTextImportError.notFound { continue }
            catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
        return []
    }
    static func parseEnglishHTML(_ html: String) throws -> [DictionarySense] {
        guard let marker = html.range(of: "id=\"English\""),
              let start = html.range(of: "<h2", options: .backwards, range: html.startIndex..<marker.lowerBound) else { return [] }
        let end = html.range(of: "<h2", range: marker.upperBound..<html.endIndex)?.lowerBound ?? html.endIndex
        let englishHTML = String(html[start.lowerBound..<end])
        let document = try ArticleHTMLExtractor.extract(englishHTML)
        func sourceFragments(_ pattern: String) throws -> [String] {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let ns = englishHTML as NSString
            return try regex.matches(in: englishHTML, range: NSRange(location: 0, length: ns.length)).map { try ArticleHTMLExtractor.extract(ns.substring(with: $0.range(at: 1))).text }
        }
        let pronunciations = try sourceFragments(#"<span\b[^>]*class=["'][^"']*\bIPA\b[^"']*["'][^>]*>(.*?)</span>"#)
        let forms = try sourceFragments(#"<(?:p|span)\b[^>]*class=["'][^"']*(?:headword-line|form-of)[^"']*["'][^>]*>(.*?)</(?:p|span)>"#)
        let parts: Set<String> = ["noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "determiner", "phrase"]
        var pos: String?, section = "", etymology: [String] = [], senses: [DictionarySense] = []
        var currentIPA: String?, currentForms: [String] = []
        for block in document.blocks {
            if block.kind == .heading {
                let previousSection = section
                section = block.text.lowercased().trimmingCharacters(in: .whitespaces)
                let heading = section.split(separator: " ").first.map(String.init) ?? section
                pos = parts.contains(heading) ? heading : nil
                if pos != nil { currentForms = []; if !previousSection.hasPrefix("pronunciation") { currentIPA = nil } }
                if heading == "etymology" { etymology = []; currentIPA = nil; currentForms = [] }
            } else if section.hasPrefix("pronunciation") {
                let values = pronunciations.filter { block.text.contains($0) }
                if !values.isEmpty { currentIPA = Array(Set(values)).sorted().joined(separator: " · ") }
            } else if pos != nil, forms.contains(block.text) {
                currentForms = Array(Set(currentForms + [block.text])).sorted()
            } else if section.hasPrefix("etymology"), block.kind == .paragraph { etymology.append(block.text) }
            else if block.kind == .listItem, block.listOrdinal != nil, let pos {
                senses.append(DictionarySense(id: "wiktionary|" + fingerprint(pos + block.text), en: block.text, zh: "", line: "English Wiktionary contributors · CC BY-SA 4.0", partOfSpeech: pos,
                    ipa: currentIPA, forms: currentForms.isEmpty ? nil : currentForms, etymology: etymology.isEmpty ? nil : etymology.joined(separator: "\n\n"), sources: ["Wiktionary"]))
            } else if block.kind == .listItem, block.listOrdinal == nil, pos != nil, !senses.isEmpty {
                var last = senses.removeLast(); last.examples = (last.examples ?? []) + [block.text]; senses.append(last)
            }
        }
        return senses
    }
    static func parse(_ data: Data) throws -> [DictionarySense] {
        struct Section: Decodable {
            struct Definition: Decodable { let definition: String; let examples: [String]? }
            let partOfSpeech: String; let definitions: [Definition]
        }
        let sections = try JSONDecoder().decode([String: [Section]].self, from: data)["en"] ?? []
        return try sections.flatMap { section in try section.definitions.map { definition in
            let plain = try ArticleHTMLExtractor.extract(definition.definition).text
            return DictionarySense(id: "wiktionary|" + fingerprint(section.partOfSpeech + plain), en: plain, zh: "", line: "English Wiktionary contributors · CC BY-SA 4.0",
                partOfSpeech: section.partOfSpeech.lowercased(), examples: try definition.examples?.map { try ArticleHTMLExtractor.extract($0).text }, sources: ["Wiktionary"])
        } }
    }
}

#endif

actor DictionaryAggregator {
    static let versions = [BundledMDXDictionaryProvider.sourceName: BundledMDXDictionaryProvider.sourceVersion]
    private let providers: [(String, any DictionaryProvider)]
    init(providers: [(String, any DictionaryProvider)] = []) { self.providers = providers }
    func lookup(_ lemma: String) async -> DictionaryProviderOutcome {
        await withTaskGroup(of: (String, [DictionarySense]?).self) { group in
            for (name, provider) in providers { group.addTask { do { return (name, try await provider.lookup(lemma)) } catch { return (name, nil) } } }
            var senses: [DictionarySense] = [], failed: [String] = [], successful: [String] = [], empty: [String] = []
            for await (name, result) in group {
                if let result { senses += result; successful.append(name); if result.isEmpty { empty.append(name) } } else { failed.append(name) }
            }
            return DictionaryProviderOutcome(senses: Self.merge(senses), failed: failed.sorted(), successful: successful.sorted(), empty: empty.sorted())
        }
    }
    nonisolated static func merge(_ senses: [DictionarySense]) -> [DictionarySense] {
        var merged: [String: DictionarySense] = [:]
        for sense in senses.sorted(by: { $0.id < $1.id }) {
            let key = sense.originKind == "mdx" ? sense.id : "\(sense.partOfSpeech ?? "unknown")|\(EnglishTokenizer.normalized(sense.en))|\(sense.zh)"
            if var old = merged[key] {
                old.sources = Array(Set((old.sources ?? []) + (sense.sources ?? []))).sorted()
                if old.line != sense.line { old.line += "\n" + sense.line }
                old.ipa = old.ipa ?? sense.ipa; old.audioURL = old.audioURL ?? sense.audioURL
                // Keep each example with its own translation; sorting examples alone mispairs translations.
                var examples = old.examples ?? [], translations = old.exampleTranslations ?? []
                translations += Array(repeating: "", count: max(0, examples.count - translations.count))
                for (index, example) in (sense.examples ?? []).enumerated() {
                    let translation = sense.exampleTranslations.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? ""
                    if let oldIndex = examples.firstIndex(of: example) {
                        if translations[oldIndex].isBlank { translations[oldIndex] = translation }
                    } else { examples.append(example); translations.append(translation) }
                }
                old.examples = examples; old.exampleTranslations = translations
                old.usageLabels = Array(Set((old.usageLabels ?? []) + (sense.usageLabels ?? []))).sorted()
                old.relatedPhrases = Array(Set((old.relatedPhrases ?? []) + (sense.relatedPhrases ?? []))).sorted()
                old.synonyms = Array(Set((old.synonyms ?? []) + (sense.synonyms ?? []))).sorted()
                old.antonyms = Array(Set((old.antonyms ?? []) + (sense.antonyms ?? []))).sorted()
                old.forms = Array(Set((old.forms ?? []) + (sense.forms ?? []))).sorted()
                old.etymology = old.etymology ?? sense.etymology
                merged[key] = old
            }
            else { merged[key] = sense }
        }
        return merged.values.sorted { $0.id < $1.id }
    }
    nonisolated static func rank(_ senses: [DictionarySense], context: String, surface: String? = nil) -> [DictionarySense] {
        let stop: Set<String> = ["the", "and", "with", "this", "that", "from", "into", "have", "been"]
        func words(_ string: String) -> Set<String> { Set(string.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 && !stop.contains($0) }) }
        let contextWords = words(context)
        var grammaticalPart: String?
        if let surface, let token = EnglishTokenizer.tokens(in: context).first(where: { EnglishTokenizer.lemma($0.surface) == EnglishTokenizer.lemma(surface) }), let range = Range(token.range, in: context) {
            let tagger = NLTagger(tagSchemes: [.lexicalClass]); tagger.string = context
            tagger.setLanguage(.english, range: context.startIndex..<context.endIndex)
            grammaticalPart = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0?.rawValue.lowercased()
        }
        let embedding = context.isBlank ? nil : NLEmbedding.sentenceEmbedding(for: .english)
        func score(_ sense: DictionarySense) -> Double {
            let definition = sense.en + " " + (sense.examples ?? []).joined(separator: " ")
            let lexical = Double(contextWords.intersection(words(definition)).count * 10 +
                (grammaticalPart != nil && (sense.partOfSpeech == grammaticalPart || grammaticalPart == "verb" && sense.partOfSpeech == "modal verb") ? 20 : 0) + (sense.partOfSpeech != nil ? 2 : 0))
            guard let embedding else { return lexical }
            let distance = embedding.distance(between: String(context.prefix(1200)), and: String(definition.prefix(1200)))
            return lexical + (distance.isFinite ? max(0, 2 - distance) * 4 : 0)
        }
        let scored = merge(senses).map { ($0, score($0)) }
        return scored.sorted {
            let a = BilingualMeaningPolicy.trusted($0.0), b = BilingualMeaningPolicy.trusted($1.0)
            if a != b { return a }
            return $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 > $1.1
        }.map(\.0)
    }
}

@Model final class DictionaryProviderCacheRecord {
    @Attribute(.unique) var key: String
    var lemma: String
    var providerID: String
    var sourceVersion: String
    var payload: Data
    var fetchedAt: Date
    var expiresAt: Date
    init(lemma: String, provider: String, version: String, data: Data, at now: Date) {
        key = "en|\(provider)|\(version)|\(lemma)"; self.lemma = lemma; providerID = provider; sourceVersion = version
        payload = data; fetchedAt = now; expiresAt = now.addingTimeInterval(30 * 86400)
    }
}
@MainActor final class DictionaryCacheRepository {
    private let writer: RepositoryWriter
    init(context: ModelContext) { writer = RepositoryWriter(context: context) }
    func load(_ lemma: String, at now: Date) throws -> (senses: [DictionarySense], complete: Bool, date: Date) {
        try writer.read { context in
            let records = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.lemma == lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }
            let valid = try records.map { record -> (DictionaryProviderCacheRecord, [DictionarySense]) in
                (record, try JSONDecoder().decode([DictionarySense].self, from: record.payload))
            }
            return (valid.flatMap { $0.1 }, Set(valid.filter { $0.0.expiresAt > now }.map { $0.0.providerID }) == Set(DictionaryAggregator.versions.keys), valid.map { $0.0.fetchedAt }.max() ?? now)
        }
    }
    func save(_ lemma: String, senses: [DictionarySense], successful: [String], at now: Date) throws {
        guard successful == [BundledMDXDictionaryProvider.sourceName], senses.allSatisfy({
            $0.originKind == "mdx" && $0.sourceRevision == BundledMDXDictionaryProvider.sourceVersion && $0.sources == [BundledMDXDictionaryProvider.sourceName]
        }) else { throw LearningError.invalid("只允许保存当前内置 MDX 的派生数据。") }
        try writer.write {
            let context = writer.context
            let reliable = senses.filter(BilingualMeaningPolicy.trusted)
            let rows = try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).filter { $0.lemma == lemma }
            guard rows.count <= 1 else { throw PersistenceError.integrity("重复词典资格证据") }
            let eligibility = rows.first ?? DictionaryEligibilityRecord(lemma: lemma, at: now, evidence: "")
            if eligibility.modelContext == nil { context.insert(eligibility) }
            eligibility.mdxSHA = BundledMDXDictionaryProvider.sourceSHA
            eligibility.reliableChineseKnown = !reliable.isEmpty
            eligibility.lookupStatus = reliable.isEmpty ? (senses.isEmpty ? "notFound" : "noChinese") : "chinese"
            eligibility.lookupError = nil; eligibility.checkedAt = now
            eligibility.evidence = "mdx|" + BundledMDXDictionaryProvider.sourceSHA
            for provider in successful {
                guard let version = DictionaryAggregator.versions[provider] else { continue }
                let values = senses.filter { ($0.sources ?? []).contains(provider) && (provider != "Free Dictionary API" || URL(string: $0.licenseURL ?? "")?.host == "creativecommons.org") }
                let previous = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.key == "en|\(provider)|\(version)|\(lemma)" }
                if previous.contains(where: { $0.fetchedAt > now }) { continue }
                for old in previous { context.delete(old) }
                context.insert(DictionaryProviderCacheRecord(lemma: lemma, provider: provider, version: version, data: try JSONEncoder().encode(values), at: now))
            }
        }
    }
    func recordFailure(_ lemma: String, error: String, at now: Date) throws {
        try writer.write {
            let context = writer.context
            let rows = try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).filter { $0.lemma == lemma }
            guard rows.count <= 1 else { throw PersistenceError.integrity("重复词典资格证据") }
            let record = rows.first ?? DictionaryEligibilityRecord(lemma: lemma, at: now, evidence: "")
            if record.modelContext == nil { context.insert(record) }
            if record.mdxSHA != BundledMDXDictionaryProvider.sourceSHA { record.reliableChineseKnown = false }
            record.mdxSHA = BundledMDXDictionaryProvider.sourceSHA; record.lookupStatus = "failed"
            record.lookupError = error; record.checkedAt = now
        }
    }
}
