import Foundation
import SwiftData

struct VocabularyContextItem: Identifiable, Equatable, Codable {
    let id: String, articleID: String, sentence: String, title: String, attribution: String
    let originalURL: String?
    var originKind: String? = nil
    var lookupOrigin: VocabularyContextOrigin {
        if originKind == "dictionary" { return .dictionary(headword: title.replacingOccurrences(of: "词典释义：", with: ""), evidence: attribution, text: sentence) }
        if originKind == "reader" { return .reader }
        return .historical(title: title, evidence: attribution, text: sentence)
    }
}
struct VocabularyItem: Identifiable, Equatable, Codable {
    let id: String, lemma: String, type: String
    let surfaces: [String]
    let addedAt: Date
    let meaning: String?
    let notes: String?
    let contexts: [String]
    let sourceArticleID: String?
    let dictionaryMeanings: [String]
    let sourceContexts: [VocabularyContextItem]
    var ipa: String? = nil
    var partsOfSpeech: [String] = []
    var dueAt: Date? = nil
    var lastReviewedAt: Date? = nil
    var intervalDays = 0
    var repetitions = 0
    var lapses = 0
    var algorithmVersion: String? = nil
    var stability: Double? = nil
    var difficulty: Double? = nil
    var dictionarySenses: [DictionarySense] = []
    var reviewMeaningSenseID: String? = nil
    var reviewMeaningText: String? = nil
    var reviewMeaningEvidence: String? = nil
}
enum VocabularyStatusFilter: String, CaseIterable { case all = "全部状态", due = "待复习", overdue = "逾期", recent = "近7日添加", familiar = "较熟悉" }
enum VocabularySort: String, CaseIterable { case added = "最近添加", due = "到期时间", alphabet = "字母顺序", priority = "复习优先级" }
enum VocabularyExportFormat: Equatable { case json, csv }

struct VocabularyExportFile: Identifiable {
    let id: UUID
    let url: URL
}

/// Stages an immutable repository snapshot before presenting the system exporter.
/// Each request owns its directory; cancellation never touches another export or database.
struct VocabularyExportFileService {
    let directory: URL
    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("LexiDawn-vocabulary-exports", isDirectory: true)) {
        self.directory = directory.standardizedFileURL
    }
    func prepare(_ data: Data, format: VocabularyExportFormat) throws -> VocabularyExportFile {
        guard !data.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        let id = UUID(), folder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        let url = folder.appendingPathComponent("LexiDawn-vocabulary." + (format == .json ? "json" : "csv"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do { try data.write(to: url, options: .atomic) }
        catch { try? FileManager.default.removeItem(at: folder); throw error }
        return VocabularyExportFile(id: id, url: url)
    }
    func discard(_ file: VocabularyExportFile) throws {
        let folder = file.url.deletingLastPathComponent().standardizedFileURL
        guard folder.lastPathComponent == file.id.uuidString,
              folder.deletingLastPathComponent().standardizedFileURL.path == directory.path else { throw CocoaError(.fileWriteNoPermission) }
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }
}
enum VocabularyQuery {
    static func apply(_ entries: [VocabularyItem], search: String, type: String, status: VocabularyStatusFilter, sort: VocabularySort, at now: Date) -> [VocabularyItem] {
        entries.filter { item in
            guard type == "all" || item.type == type else { return false }
            guard search.isBlank || ([item.lemma, item.meaning ?? ""] + item.surfaces + item.dictionaryMeanings).contains(where: { $0.localizedCaseInsensitiveContains(search) }) else { return false }
            switch status {
            case .all: return true
            case .due: return item.dueAt.map { $0 <= now } ?? false
            case .overdue: return item.dueAt.map { $0 < Calendar.current.startOfDay(for: now) } ?? false
            case .recent: return item.addedAt >= now.addingTimeInterval(-7 * 86400)
            case .familiar: return item.repetitions >= 3 && item.intervalDays >= 21
            }
        }.sorted { a, b in
            switch sort {
            case .added: return (a.addedAt, a.id) > (b.addedAt, b.id)
            case .alphabet: return (a.lemma, a.id) < (b.lemma, b.id)
            case .due: return (a.dueAt ?? .distantFuture, a.id) < (b.dueAt ?? .distantFuture, b.id)
            case .priority: return (a.dueAt ?? .distantFuture, -a.lapses, a.id) < (b.dueAt ?? .distantFuture, -b.lapses, b.id)
            }
        }
    }
}
struct VocabularyAddition {
    let entryID: String
    let created: Bool
    let token: String?
    let revision: Int
}
@MainActor final class VocabularyRepository {
    private let writer: RepositoryWriter
    init(context: ModelContext, saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) { writer = RepositoryWriter(context: context, saveContext: saveContext) }
    func entries(search: String = "", type: String? = nil) throws -> [VocabularyItem] {
        try writer.read { context in
            let all = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            guard Set(all.map(\.normalizedKey)).count == all.count else { throw PersistenceError.integrity("重复生词身份") }
            let contexts = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>())
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
            let articles = try historicalArticleMetadata(in: context)
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
            let providerCaches = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
            return all.filter { $0.deletedAt == nil && (type == nil || $0.entryType == type) }.map { record in
                let attached = contexts.filter { $0.entryID == record.entryID }
                let definitions = senses.filter { $0.entryID == "cedict-reverse-v1|\(record.lemma)" }.sorted { $0.senseID < $1.senseID }.map(\.chinese)
                let sourceItems: [VocabularyContextItem] = attached.map { source in
                    let article = articles.first { $0.articleID == source.articleID }
                    let dictionaryContext = source.contextKind == "dictionary"
                    return VocabularyContextItem(id: source.contextID, articleID: source.articleID, sentence: source.sentence,
                        title: dictionaryContext ? source.contextTitle ?? "词典释义" : article?.originalTitle ?? source.articleID,
                        attribution: dictionaryContext ? source.contextAttribution ?? "词典来源证据不可用" : article?.sourceAttribution ?? article?.sourceID ?? "来源元数据不可用",
                        originalURL: dictionaryContext ? nil : grants.first { $0.articleID == source.articleID }?.originalURL, originKind: source.contextKind)
                }
                var value = VocabularyItem(id: record.entryID, lemma: record.lemma, type: record.entryType, surfaces: record.surfaceForms,
                    addedAt: record.addedAt, meaning: record.userMeaning, notes: record.notes,
                    contexts: attached.map(\.sentence), sourceArticleID: attached.first?.articleID,
                    dictionaryMeanings: definitions, sourceContexts: sourceItems)
                let providerRows = providerCaches.filter { $0.lemma == record.lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }
                value.dictionarySenses = DictionaryAggregator.merge(providerRows.flatMap { (try? JSONDecoder().decode([DictionarySense].self, from: $0.payload)) ?? [] })
                value.ipa = value.dictionarySenses.compactMap(\.ipa).first
                value.reviewMeaningSenseID = record.reviewMeaningSenseID
                value.reviewMeaningText = record.reviewMeaningText; value.reviewMeaningEvidence = record.reviewMeaningEvidence
                value.partsOfSpeech = Array(Set(value.dictionarySenses.compactMap(\.partOfSpeech))).sorted()
                if let state = states.first(where: { $0.entryID == record.entryID }) {
                    value.dueAt = state.dueAt; value.lastReviewedAt = state.lastReviewedAt; value.intervalDays = state.intervalDays
                    value.repetitions = state.repetitions; value.lapses = state.lapses; value.algorithmVersion = state.algorithmVersion
                    value.stability = state.stability; value.difficulty = state.difficulty
                }
                return value
            }.filter { search.isBlank || ([$0.lemma, $0.meaning ?? ""] + $0.surfaces + $0.dictionaryMeanings).contains { $0.localizedCaseInsensitiveContains(search) } }
                .sorted { $0.addedAt > $1.addedAt }
        }
    }
    func find(surface: String, type: String? = nil) throws -> VocabularyItem? {
        let lemma = EnglishTokenizer.lemma(surface)
        return try entries(type: type ?? (lemma.contains(" ") ? "phrase" : "word")).first { $0.lemma == lemma }
    }
    func export(_ format: VocabularyExportFormat, at now: Date) throws -> Data {
        let items = try entries()
        struct ExportLog: Codable { let entryID: String, eventID: String, grade: String, algorithmVersion: String; let reviewedAt: Date, nextDueAt: Date }
        struct Payload: Codable { let formatVersion: Int; let exportedAt: Date; let entries: [VocabularyItem]; let reviewLogs: [ExportLog] }
        let ids = Set(items.map(\.id))
        let logs = try writer.read { context in try context.fetch(FetchDescriptor<ReviewLogRecord>()).filter { ids.contains($0.entryID) }.map { ExportLog(entryID: $0.entryID, eventID: $0.eventID, grade: $0.grade, algorithmVersion: $0.algorithmVersion, reviewedAt: $0.reviewedAt, nextDueAt: $0.nextDueAt) } }
        if format == .json {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(Payload(formatVersion: 1, exportedAt: now, entries: items, reviewLogs: logs))
        }
        let date = ISO8601DateFormatter()
        func quote(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var rows = [["entryID", "lemma", "surfaceForms", "type", "personalMeaning", "dictionaryMeanings", "notes", "sourceContextsJSON", "addedAt", "lastReviewedAt", "nextDueAt", "algorithmVersion", "repetitions", "lapses", "stability", "difficulty", "dictionarySensesJSON", "reviewLogsJSON", "reviewMeaningSenseID", "reviewMeaningText", "reviewMeaningEvidence"]]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = .sortedKeys
        for item in items {
            rows.append([item.id, item.lemma, item.surfaces.joined(separator: " | "), item.type, item.meaning ?? "", item.dictionaryMeanings.joined(separator: " | "), item.notes ?? "",
                String(decoding: try encoder.encode(item.sourceContexts), as: UTF8.self), date.string(from: item.addedAt), item.lastReviewedAt.map { date.string(from: $0) } ?? "", item.dueAt.map { date.string(from: $0) } ?? "", item.algorithmVersion ?? "", String(item.repetitions), String(item.lapses), item.stability.map { String($0) } ?? "", item.difficulty.map { String($0) } ?? "", String(decoding: try encoder.encode(item.dictionarySenses), as: UTF8.self), String(decoding: try encoder.encode(logs.filter { $0.entryID == item.id }), as: UTF8.self), item.reviewMeaningSenseID ?? "", item.reviewMeaningText ?? "", item.reviewMeaningEvidence ?? ""])
        }
        return Data((rows.map { $0.map(quote).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n").utf8)
    }
    func add(token: EnglishToken, articleID: String, autoAdd: Bool, explicit: Bool = false, origin: VocabularyContextOrigin = .reader, at now: Date) throws -> VocabularyAddition? {
        guard autoAdd || explicit else { return nil }
        if case let .dictionary(headword, evidence, _) = origin, headword.isBlank || evidence.isBlank { throw LearningError.invalid("词典语境缺少真实词条或来源证据，未加入生词本。") }
        let lemma = EnglishTokenizer.lemma(token.surface)
        let type = lemma.contains(" ") ? "phrase" : "word"
        guard !lemma.isBlank, lemma.count <= 100, !EnglishTokenizer.tokens(in: lemma).isEmpty else { throw LearningError.invalid("不是有效英文词条。") }
        return try writer.write {
            let context = writer.context
            guard try context.fetch(FetchDescriptor<ArticleRecord>()).filter({ $0.articleID == articleID }).count == 1 else { throw PersistenceError.integrity("词条来源文章不存在") }
            let records = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).filter { $0.normalizedKey == "en|\(type)|\(lemma)" }
            guard records.count <= 1 else { throw PersistenceError.integrity("重复词条") }
            let nonce = UUID().uuidString
            let record: VocabularyEntryRecord
            let created: Bool
            if let existing = records.first {
                record = existing; created = existing.deletedAt != nil
                if created { record.deletedAt = nil; record.addedAt = now; record.creationToken = nonce }
                record.revision += 1; record.lastOpenedAt = max(now, record.lastOpenedAt)
                if !record.surfaceForms.contains(token.surface) { record.surfaceForms.append(token.surface) }
            } else {
                record = VocabularyEntryRecord(lemma: lemma, surface: token.surface, type: type, at: now, from: articleID, token: nonce)
                context.insert(record); context.insert(ReviewStateRecord(entryID: record.entryID, at: now)); created = true
            }
            let states = try context.fetch(FetchDescriptor<ReviewStateRecord>()).filter { $0.entryID == record.entryID }
            guard states.count == 1 else { throw PersistenceError.integrity("生词复习状态缺失或重复，不能假定队列为空") }
            if created, let state = states.first { state.dueAt = min(state.dueAt, now) }
            let source = VocabularySourceContextRecord(entryID: record.entryID, articleID: articleID, surface: token.surface, sentence: token.sentence, tokenLocation: token.range.location, at: now)
            source.contextID += "|\(fingerprint(token.sentence))"
            if origin.kind == "dictionary" { source.contextID += "|dictionary|" + fingerprint((origin.title ?? "") + (origin.evidence ?? "")) }
            source.contextKind = origin.kind; source.contextTitle = origin.title; source.contextAttribution = origin.evidence
            if let existing = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).first(where: { $0.contextID == source.contextID }) {
                // This explicit new lookup supplies provenance; legacy rows are never guessed in migration.
                if existing.contextKind == nil { existing.contextKind = source.contextKind; existing.contextTitle = source.contextTitle; existing.contextAttribution = source.contextAttribution }
            } else { context.insert(source) }
            return VocabularyAddition(entryID: record.entryID, created: created, token: created ? nonce : nil, revision: record.revision)
        }
    }
    func undo(_ addition: VocabularyAddition, at now: Date) throws {
        guard addition.created, let token = addition.token else { throw LearningError.invalid("此前已存在的词条不能通过本次查词撤销。") }
        try writer.write {
            let context = writer.context
            guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == addition.entryID }),
                  entry.deletedAt == nil, entry.creationToken == token, entry.revision == addition.revision,
                  try !context.fetch(FetchDescriptor<ReviewExerciseRecord>()).contains(where: { $0.entryID == addition.entryID }) else {
                throw LearningError.invalid("该词条已被后续操作使用，不能撤销本次创建；需要移除时请在生词本确认。")
            }
            entry.deletedAt = now; entry.revision += 1
        }
    }
    func remove(entryID: String, at now: Date) throws {
        try writer.write {
            guard let entry = try writer.context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID }) else { throw LearningError.invalid("找不到词条。") }
            entry.deletedAt = now; entry.revision += 1
        }
    }
    func annotate(entryID: String, meaning: String, notes: String, at now: Date) throws {
        guard meaning.count <= 200, notes.count <= 2000 else { throw LearningError.invalid("个人释义或笔记过长。") }
        try writer.write {
            guard let entry = try writer.context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID }), entry.deletedAt == nil else { throw LearningError.invalid("词条已移除。") }
            let updatedMeaning = meaning.isBlank ? nil : meaning
            if entry.userMeaning != updatedMeaning { entry.reviewMeaningSenseID = nil; entry.reviewMeaningText = nil; entry.reviewMeaningEvidence = nil }
            entry.userMeaning = updatedMeaning; entry.notes = notes.isBlank ? nil : notes
            entry.lastOpenedAt = max(now, entry.lastOpenedAt); entry.revision += 1
        }
    }
    func confirmReviewMeaning(entryID: String, sourceSenseID: String) throws {
        try writer.write {
            let context = writer.context
            guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID && $0.deletedAt == nil }) else { throw LearningError.invalid("词条不存在或已移除。") }
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>()).filter { $0.entryID == "cedict-reverse-v1|\(entry.lemma)" && !$0.chinese.isBlank && ($0.senseID == sourceSenseID || $0.senseID.hasSuffix("|" + sourceSenseID)) }
            guard senses.count == 1, let sense = senses.first else { throw LearningError.invalid("无法唯一核实此中文义项，请重新查词或填写个人释义。") }
            entry.reviewMeaningSenseID = sense.senseID; entry.reviewMeaningText = sense.chinese; entry.reviewMeaningEvidence = sense.sourceLine; entry.revision += 1
        }
    }
}

struct DictionarySense: Codable, Equatable, Identifiable, Sendable {
    let id: String, en: String, zh: String
    var line: String
    var partOfSpeech: String? = nil
    var ipa: String? = nil
    var examples: [String]? = nil
    var synonyms: [String]? = nil
    var antonyms: [String]? = nil
    var forms: [String]? = nil
    var etymology: String? = nil
    var audioURL: String? = nil
    var sources: [String]? = nil
    var licenseURL: String? = nil
}

struct DictionaryResult: Equatable {
    let headword: String
    let senses: [DictionarySense]
    let updatedAt: Date
    let sourceURL: String
    let licenseURL: String
    var failedProviders: [String] = []
    var cached: Bool = false
    var versions: [String: String] = [:]
}
protocol DictionaryProvider: Sendable { func lookup(_ headword: String) async throws -> [DictionarySense] }
/// Local, source-derived, legally redistributable index. No network or personal reading history upload.
actor CEDICTDictionaryProvider: DictionaryProvider {
    static let sourceVersion = "2026-10-30-reverse-v1"
    private var index: [String: [DictionarySense]]?
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        if index == nil {
            guard let url = Bundle.main.url(forResource: "cedict-reverse", withExtension: "json") else { throw LearningError.invalid("开放词典资源缺失，请重试或重新安装受信任版本。") }
            index = try JSONDecoder().decode([String: [DictionarySense]].self, from: Data(contentsOf: url))
        }
        return index?[headword] ?? []
    }
}
@MainActor final class DictionaryLookupService {
    private let writer: RepositoryWriter
    private let provider: DictionaryProvider
    private var aggregator: DictionaryAggregator?
    private var richCache: DictionaryCacheRepository?
    #if DEBUG && targetEnvironment(simulator)
    private var fixtureWithoutLocal = false
    func configureDictionaryEvidence(providers: [(String, any DictionaryProvider)], cachedSenses: [DictionarySense] = [], stale: Bool = false) throws {
        fixtureWithoutLocal = true; aggregator = DictionaryAggregator(providers: providers)
        let cache = DictionaryCacheRepository(context: writer.context); richCache = cache
        if !cachedSenses.isEmpty { try cache.save("internet", senses: cachedSenses, successful: Array(DictionaryAggregator.versions.keys), at: Date().addingTimeInterval(stale ? -31 * 86400 : 0)) }
    }
    #endif
    func enableOnlineProviders() { aggregator = DictionaryAggregator(); richCache = DictionaryCacheRepository(context: writer.context) }
    func clearCaches() throws -> Int {
        try writer.write {
            let context = writer.context
            let local = try context.fetch(FetchDescriptor<DictionaryEntryRecord>())
            let remote = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
            for record in try context.fetch(FetchDescriptor<DictionarySenseRecord>()) { context.delete(record) }
            for record in local { context.delete(record) }; for record in remote { context.delete(record) }
            return local.count + remote.count
        }
    }
    init(context: ModelContext, provider: DictionaryProvider = CEDICTDictionaryProvider()) {
        writer = RepositoryWriter(context: context); self.provider = provider
    }
    func lookup(_ surface: String, context: String = "", at now: Date = Date()) async throws -> DictionaryResult {
        if let aggregator, let richCache {
            let key = EnglishTokenizer.lemma(surface)
            let old = try richCache.load(key, at: now)
            if old.complete {
                let local = try? await lookupLocal(surface, at: now)
                return DictionaryResult(headword: key, senses: DictionaryAggregator.rank((local?.senses ?? []) + old.senses, context: context, surface: key), updatedAt: old.date, sourceURL: "https://dictionaryapi.dev/", licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/", cached: true, versions: DictionaryAggregator.versions) }
            let outcome = await aggregator.lookup(key)
            try Task.checkCancellation()
            let local = try? await lookupLocal(surface, at: now)
            let all = (local?.senses ?? []) + outcome.senses
            let fallback = old.senses.filter { !Set($0.sources ?? []).intersection(outcome.failed).isEmpty }
            let senses = DictionaryAggregator.merge(all + fallback)
            guard !senses.isEmpty || outcome.failed.isEmpty else { throw LearningError.invalid("词典来源暂时不可用；本地没有缓存，请联网后重试。") }
            if !outcome.senses.isEmpty { try richCache.save(key, senses: outcome.senses, successful: outcome.successful, at: now) }
            let resultDate = outcome.senses.isEmpty ? (old.senses.isEmpty ? local?.updatedAt ?? now : old.date) : now
            return DictionaryResult(headword: key, senses: DictionaryAggregator.rank(senses, context: context, surface: key), updatedAt: resultDate,
                sourceURL: "https://dictionaryapi.dev/", licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/", failedProviders: outcome.failed,
                cached: !fallback.isEmpty || outcome.senses.isEmpty && !(local?.senses.isEmpty ?? true), versions: DictionaryAggregator.versions)
        }
        return try await lookupLocal(surface, at: now)
    }
    func localResult(_ surface: String, at now: Date = Date()) async throws -> DictionaryResult {
        var value = try await lookupLocal(surface, at: now); value.cached = true; return value
    }
    private func lookupLocal(_ surface: String, at now: Date) async throws -> DictionaryResult {
        let key = EnglishTokenizer.lemma(surface)
        #if DEBUG && targetEnvironment(simulator)
        if fixtureWithoutLocal { return DictionaryResult(headword: key, senses: [], updatedAt: now, sourceURL: "https://dictionaryapi.dev/", licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/") }
        #endif
        if let cached = try cached(key) { return cached }
        let senses = try await provider.lookup(key)
        try Task.checkCancellation()
        guard Set(senses.map(\.id)).count == senses.count else { throw LearningError.invalid("词典返回重复义项，不能保存。") }
        return try writer.write {
            let context = writer.context
            let record = try context.fetch(FetchDescriptor<DictionaryEntryRecord>()).first { $0.headword == key } ?? DictionaryEntryRecord(headword: key, at: now)
            if record.modelContext == nil { context.insert(record) }
            var old = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
            if record.sourceVersion != CEDICTDictionaryProvider.sourceVersion {
                for stale in old where stale.entryID == record.entryID { context.delete(stale) }
                old.removeAll { $0.entryID == record.entryID }
                record.sourceVersion = CEDICTDictionaryProvider.sourceVersion; record.updatedAt = now
            }
            for sense in senses where !old.contains(where: { $0.senseID == record.entryID + "|" + sense.id }) {
                context.insert(DictionarySenseRecord(senseID: record.entryID + "|" + sense.id, entryID: record.entryID, english: sense.en, chinese: sense.zh, sourceLine: sense.line))
            }
            return DictionaryResult(headword: key, senses: senses, updatedAt: record.updatedAt, sourceURL: record.sourceURL, licenseURL: record.licenseURL)
        }
    }
    func cached(_ key: String) throws -> DictionaryResult? {
        try writer.read { context in
            let entries = try context.fetch(FetchDescriptor<DictionaryEntryRecord>()).filter { $0.headword == key }
            guard entries.count <= 1 else { throw PersistenceError.integrity("重复词典缓存") }
            guard let entry = entries.first, entry.sourceVersion == CEDICTDictionaryProvider.sourceVersion else { return nil }
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>()).filter { $0.entryID == entry.entryID }
                .sorted { $0.senseID < $1.senseID }.map { DictionarySense(id: String($0.senseID.split(separator: "|").last ?? ""), en: $0.english, zh: $0.chinese, line: $0.sourceLine) }
            return DictionaryResult(headword: key, senses: senses, updatedAt: entry.updatedAt, sourceURL: entry.sourceURL, licenseURL: entry.licenseURL)
        }
    }
}

