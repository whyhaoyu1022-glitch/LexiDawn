import Foundation
import SwiftData

struct DictionaryProviderOutcome: Sendable {
    let senses: [DictionarySense]
    let failed: [String]
    let successful: [String]
}
struct FreeDictionaryProvider: DictionaryProvider {
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/")!.appendingPathComponent(headword)
        let data = try await ArticleFetchService().fetch(url, allowedHost: "api.dictionaryapi.dev")
        return try Self.parse(data)
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
                    etymology: entry.origin, audioURL: entry.phonetics?.compactMap(\.audio).first { $0.hasPrefix("https://") }, sources: ["Free Dictionary API"])
            } }
        }
    }
}
struct WiktionaryDictionaryProvider: DictionaryProvider {
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/")!.appendingPathComponent(headword)
        let data = try await ArticleFetchService().fetch(url, allowedHost: "en.wiktionary.org")
        return try Self.parse(data)
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
    static let versions = ["Free Dictionary API": "v2", "Wiktionary": "rest-definition-1"]
    private let providers: [(String, any DictionaryProvider)]
    init(providers: [(String, any DictionaryProvider)] = [("Free Dictionary API", FreeDictionaryProvider()), ("Wiktionary", WiktionaryDictionaryProvider())]) { self.providers = providers }
    func lookup(_ lemma: String) async -> DictionaryProviderOutcome {
        await withTaskGroup(of: (String, [DictionarySense]?).self) { group in
            for (name, provider) in providers { group.addTask { do { return (name, try await provider.lookup(lemma)) } catch { return (name, nil) } } }
            var senses: [DictionarySense] = [], failed: [String] = [], successful: [String] = []
            for await (name, result) in group {
                if let result { senses += result; successful.append(name) } else { failed.append(name) }
            }
            return DictionaryProviderOutcome(senses: Self.merge(senses), failed: failed.sorted(), successful: successful.sorted())
        }
    }
    nonisolated static func merge(_ senses: [DictionarySense]) -> [DictionarySense] {
        var merged: [String: DictionarySense] = [:]
        for sense in senses.sorted(by: { $0.id < $1.id }) {
            let key = "\(sense.partOfSpeech ?? "unknown")|\(EnglishTokenizer.normalized(sense.en))|\(sense.zh)"
            if var old = merged[key] { old.sources = Array(Set((old.sources ?? []) + (sense.sources ?? []))).sorted(); merged[key] = old }
            else { merged[key] = sense }
        }
        return merged.values.sorted { $0.id < $1.id }
    }
    nonisolated static func rank(_ senses: [DictionarySense], context: String) -> [DictionarySense] {
        let stop: Set<String> = ["the", "and", "with", "this", "that", "from", "into", "have", "been"]
        func words(_ string: String) -> Set<String> { Set(string.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 && !stop.contains($0) }) }
        let contextWords = words(context)
        func score(_ sense: DictionarySense) -> Int { contextWords.intersection(words(sense.en + " " + (sense.examples ?? []).joined(separator: " "))).count }
        return merge(senses).sorted { score($0) == score($1) ? $0.id < $1.id : score($0) > score($1) }
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
            let senses = try records.flatMap { try JSONDecoder().decode([DictionarySense].self, from: $0.payload) }
            return (senses, Set(records.filter { $0.expiresAt > now }.map(\.providerID)) == Set(DictionaryAggregator.versions.keys), records.map(\.fetchedAt).max() ?? now)
        }
    }
    func save(_ lemma: String, senses: [DictionarySense], successful: [String], at now: Date) throws {
        try writer.write {
            let context = writer.context
            for provider in successful {
                guard let version = DictionaryAggregator.versions[provider] else { continue }
                let values = senses.filter { ($0.sources ?? []).contains(provider) && (provider != "Free Dictionary API" || $0.line.contains("creativecommons.org")) }
                guard !values.isEmpty else { continue }
                for old in try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()) where old.key == "en|\(provider)|\(version)|\(lemma)" { context.delete(old) }
                context.insert(DictionaryProviderCacheRecord(lemma: lemma, provider: provider, version: version, data: try JSONEncoder().encode(values), at: now))
            }
        }
    }
}
