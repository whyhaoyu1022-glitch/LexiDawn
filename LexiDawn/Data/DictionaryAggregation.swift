import Foundation
import SwiftData
import NaturalLanguage

struct DictionaryProviderOutcome: Sendable {
    let senses: [DictionarySense]
    let failed: [String]
    let successful: [String]
    let empty: [String]
}
struct FreeDictionaryProvider: DictionaryProvider {
    private let fetcher: ArticleFetchService
    init(fetcher: ArticleFetchService = ArticleFetchService()) { self.fetcher = fetcher }
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
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        let transport = ArticleFetchService()
        let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/")!.appendingPathComponent(headword)
        var senses: [DictionarySense] = []
        var lastError: Error?
        do { senses = try Self.parse(await transport.fetch(url, allowedHost: "en.wiktionary.org")) }
        catch is CancellationError { throw CancellationError() }
        catch { lastError = error }
        do {
            let api = try OfficialArticleAPI.url(host: "en.wiktionary.org", fields: ["action": "parse", "page": headword, "prop": "text", "format": "json", "formatversion": "2", "disableeditsection": "1"])
            let data = try await transport.fetch(api, allowedHost: "en.wiktionary.org")
            struct Response: Decodable { struct Page: Decodable { let text: String }; let parse: Page }
            let rich = try Self.parseEnglishHTML(JSONDecoder().decode(Response.self, from: data).parse.text)
            senses = DictionaryAggregator.merge(senses + rich)
        } catch is CancellationError { throw CancellationError() }
        catch { lastError = error }
        do {
            let api = try OfficialArticleAPI.url(host: "zh.wiktionary.org", fields: ["action": "parse", "page": headword, "prop": "text|revid", "format": "json", "formatversion": "2", "disableeditsection": "1"])
            struct Response: Decodable { struct Page: Decodable { let text: String; let revid: Int }; let parse: Page }
            let response = try JSONDecoder().decode(Response.self, from: await transport.fetch(api, allowedHost: "zh.wiktionary.org"))
            senses += try WiktionaryBilingualParser.parse(response.parse.text, revision: String(response.parse.revid))
        } catch is CancellationError { throw CancellationError() }
        catch { lastError = error }
        if senses.isEmpty, let lastError, (lastError as? FullTextImportError) != .notFound { throw lastError }
        return senses.map { value in
            var sense = value; sense.line += " · " + URL(string: "https://en.wiktionary.org/wiki/")!.appendingPathComponent(headword).absoluteString; return sense
        }
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

actor DictionaryAggregator {
    static let versions = ["Free Dictionary API": "api-v2-schema-2", "Wiktionary": "bilingual-action-schema-5"]
    private let providers: [(String, any DictionaryProvider)]
    init(providers: [(String, any DictionaryProvider)] = [("Free Dictionary API", FreeDictionaryProvider()), ("Wiktionary", WiktionaryDictionaryProvider())]) { self.providers = providers }
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
            let key = "\(sense.partOfSpeech ?? "unknown")|\(EnglishTokenizer.normalized(sense.en))|\(sense.zh)"
            if var old = merged[key] {
                old.sources = Array(Set((old.sources ?? []) + (sense.sources ?? []))).sorted()
                if old.line != sense.line { old.line += "\n" + sense.line }
                old.ipa = old.ipa ?? sense.ipa; old.audioURL = old.audioURL ?? sense.audioURL
                old.examples = Array(Set((old.examples ?? []) + (sense.examples ?? []))).sorted()
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
                (grammaticalPart != nil && sense.partOfSpeech == grammaticalPart ? 20 : 0) + (sense.partOfSpeech != nil ? 2 : 0))
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
            // One damaged disposable Provider payload must not block another Provider or live lookup.
            // ModelContext fetch errors still propagate; a successful refresh replaces only that payload.
            let valid = records.compactMap { record -> (DictionaryProviderCacheRecord, [DictionarySense])? in
                guard let senses = try? JSONDecoder().decode([DictionarySense].self, from: record.payload) else { return nil }
                return (record, senses)
            }
            return (valid.flatMap { $0.1 }, Set(valid.filter { $0.0.expiresAt > now }.map { $0.0.providerID }) == Set(DictionaryAggregator.versions.keys), valid.map { $0.0.fetchedAt }.max() ?? now)
        }
    }
    func save(_ lemma: String, senses: [DictionarySense], successful: [String], at now: Date) throws {
        try writer.write {
            let context = writer.context
            let reliable = senses.filter(BilingualMeaningPolicy.trusted)
            if !reliable.isEmpty {
                let rows = try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).filter { $0.lemma == lemma }
                if let old = rows.first { old.reliableChineseKnown = true; old.checkedAt = max(old.checkedAt, now); old.evidence = reliable.map(\.line).joined(separator: "\n") }
                else { context.insert(DictionaryEligibilityRecord(lemma: lemma, at: now, evidence: reliable.map(\.line).joined(separator: "\n"))) }
            }
            for provider in successful {
                guard let version = DictionaryAggregator.versions[provider] else { continue }
                let values = senses.filter { ($0.sources ?? []).contains(provider) && (provider != "Free Dictionary API" || URL(string: $0.licenseURL ?? "")?.host == "creativecommons.org") }
                guard !values.isEmpty else { continue }
                let previous = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.key == "en|\(provider)|\(version)|\(lemma)" }
                if previous.contains(where: { $0.fetchedAt > now }) { continue }
                for old in previous { context.delete(old) }
                context.insert(DictionaryProviderCacheRecord(lemma: lemma, provider: provider, version: version, data: try JSONEncoder().encode(values), at: now))
            }
        }
    }
}
