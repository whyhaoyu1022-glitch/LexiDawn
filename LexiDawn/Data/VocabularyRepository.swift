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
struct VocabularyLegacyAnnotation: Codable, Equatable, Identifiable {
    let id: String, originalLemma: String
    let meaning: String?, notes: String?
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
    var legacyAnnotations: [VocabularyLegacyAnnotation]? = nil
    var personalSenses: [PersonalDictionarySense]? = nil
    var personalHistory: [PersonalMeaningRevision]? = nil
    var dictionaryCacheError: String? = nil
    var reliableChineseKnown: Bool? = nil
    var reviewMeaningSenseID: String? = nil
    var reviewMeaningText: String? = nil
    var reviewMeaningEvidence: String? = nil
    var searchableText: [String] {
        var values = [lemma, meaning ?? ""]
        values.append(contentsOf: surfaces); values.append(contentsOf: dictionaryMeanings)
        values.append(contentsOf: (personalSenses ?? []).map(\.chinese))
        values.append(contentsOf: dictionarySenses.map(\.zh))
        return values
    }
    var primaryChinese: String? {
        if let sense = dictionarySenses.first(where: BilingualMeaningPolicy.trusted) { return sense.zh }
        if reliableChineseKnown == true { return nil }
        return personalSenses?.first(where: \.reviewReady)?.chinese
    }
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
            guard search.isBlank || item.searchableText.contains(where: { $0.localizedCaseInsensitiveContains(search) }) else { return false }
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
        try normalizeIdentities()
        try migrateLegacyPersonalSenses()
        return try writer.read { context in
            let all = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            guard Set(all.map(\.normalizedKey)).count == all.count else { throw PersistenceError.integrity("重复生词身份") }
            let contexts = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>())
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
            let articles = try historicalArticleMetadata(in: context)
            let grants = try context.fetch(FetchDescriptor<ContentGrantRecord>())
            let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
            let providerCaches = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
            let active = all.filter { $0.deletedAt == nil && $0.canonicalEntryID == nil && (type == nil || $0.entryType == type) }
            let values: [VocabularyItem] = try active.map { record in
                let aliases = all.filter { $0.canonicalEntryID == record.entryID }
                let groupIDs = Set([record.entryID] + aliases.map(\.entryID))
                let attached = contexts.filter { groupIDs.contains($0.entryID) }.sorted { ($0.createdAt, $0.contextID) < ($1.createdAt, $1.contextID) }
                // Retired external rows stay on disk for history, never as current meanings.
                let definitions: [String] = []
                let sourceItems: [VocabularyContextItem] = attached.map { source in
                    let article = articles.first { $0.articleID == source.articleID }
                    let dictionaryContext = source.contextKind == "dictionary"
                    return VocabularyContextItem(id: source.contextID, articleID: source.articleID, sentence: source.sentence,
                        title: dictionaryContext ? source.contextTitle ?? "词典释义" : article?.originalTitle ?? source.articleID,
                        attribution: dictionaryContext ? source.contextAttribution ?? "词典来源证据不可用" : article?.sourceAttribution ?? article?.sourceID ?? "来源元数据不可用",
                        originalURL: dictionaryContext ? nil : grants.first { $0.articleID == source.articleID }?.originalURL, originKind: source.contextKind)
                }
                var value = VocabularyItem(id: record.entryID, lemma: record.lemma, type: record.entryType, surfaces: Array(Set(record.surfaceForms + aliases.flatMap(\.surfaceForms))).sorted(),
                    addedAt: record.addedAt, meaning: record.userMeaning, notes: record.notes,
                    contexts: attached.map(\.sentence), sourceArticleID: attached.first?.articleID,
                    dictionaryMeanings: definitions, sourceContexts: sourceItems)
                let providerRows = providerCaches.filter { $0.lemma == record.lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }
                var decoded: [DictionarySense] = []
                for row in providerRows {
                    do { decoded += try JSONDecoder().decode([DictionarySense].self, from: row.payload) }
                    catch { value.dictionaryCacheError = "MDX 派生缓存损坏，请重新查词恢复：" + error.localizedDescription }
                }
                value.dictionarySenses = DictionaryAggregator.merge(decoded)
                value.legacyAnnotations = aliases.map { VocabularyLegacyAnnotation(id: $0.entryID, originalLemma: $0.lemma, meaning: $0.userMeaning, notes: $0.notes) }
                value.personalSenses = try record.personalSensesData.map { try JSONDecoder().decode([PersonalDictionarySense].self, from: $0) }
                value.personalHistory = try record.personalMeaningHistoryData.map { try JSONDecoder().decode([PersonalMeaningRevision].self, from: $0) }
                do { value.reliableChineseKnown = try hasReliableChinese(lemma: record.lemma, context: context) }
                catch { value.dictionaryCacheError = error.localizedDescription }
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
            }
            return values.filter { item in search.isBlank || item.searchableText.contains { $0.localizedCaseInsensitiveContains(search) } }.sorted { $0.addedAt > $1.addedAt }
        }
    }
    /// Additive and repeatable: legacy strings retain their exact text, ID and origin.
    /// Unknown POS stays unconfirmed and cannot become a new review answer.
    private func migrateLegacyPersonalSenses() throws {
        let needed = try writer.read { context in
            try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).contains { $0.personalSensesData == nil && $0.userMeaning?.isBlank == false }
        }
        guard needed else { return }
        try writer.write {
            for entry in try writer.context.fetch(FetchDescriptor<VocabularyEntryRecord>()) where entry.personalSensesData == nil {
                guard let meaning = entry.userMeaning, !meaning.isBlank else { continue }
                var sense = PersonalDictionarySense(id: "legacyPersonal|" + entry.entryID, chinese: meaning)
                sense.originalOrigin = "legacyPersonal"
                entry.personalSensesData = try JSONEncoder().encode([sense])
                entry.personalMeaningRevision = 1
            }
        }
    }
    /// Additive canonical aliases preserve old IDs, annotations, sources, logs and sessions.
    /// A colliding legacy row is linked, never deleted or used to overwrite the chosen root's notes.
    func normalizeIdentities() throws {
        let needed = try writer.read { context in
            let rows = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            guard Set(rows.map(\.normalizedKey)).count == rows.count else { throw PersistenceError.integrity("重复生词身份") }
            for alias in rows where alias.canonicalEntryID != nil {
                guard let root = rows.first(where: { $0.entryID == alias.canonicalEntryID }), root.canonicalEntryID == nil,
                      root.entryType == alias.entryType, EnglishTokenizer.lemma(root.lemma) == EnglishTokenizer.lemma(alias.lemma) else { throw PersistenceError.integrity("词形合并引用损坏，原记录保留") }
            }
            let roots = rows.filter { $0.canonicalEntryID == nil && $0.languageCode == "en" }
            return roots.contains { $0.lemma != EnglishTokenizer.lemma($0.lemma) } || Set(roots.map { $0.entryType + "|" + EnglishTokenizer.lemma($0.lemma) }).count != roots.count
        }
        guard needed else { return }
        try writer.write {
            let context = writer.context
            let rows = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).filter { $0.languageCode == "en" }
            var evidence = try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>())
            let groups = Dictionary(grouping: rows, by: { $0.entryType + "|" + EnglishTokenizer.lemma($0.lemma) })
            let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
            for records in groups.values {
                let sorted = records.filter { $0.canonicalEntryID == nil }.sorted {
                    let a = ($0.deletedAt == nil ? 0 : 1, $0.lemma == EnglishTokenizer.lemma($0.lemma) ? 0 : 1, $0.addedAt, $0.entryID)
                    let b = ($1.deletedAt == nil ? 0 : 1, $1.lemma == EnglishTokenizer.lemma($1.lemma) ? 0 : 1, $1.addedAt, $1.entryID)
                    return a < b
                }
                guard let root = sorted.first else { continue }
                let canonical = EnglishTokenizer.lemma(root.lemma)
                let known = evidence.filter { $0.reliableChineseKnown && EnglishTokenizer.lemma($0.lemma) == canonical }
                if !known.isEmpty, !evidence.contains(where: { $0.lemma == canonical }) {
                    let record = DictionaryEligibilityRecord(lemma: canonical, at: known.map(\.checkedAt).max() ?? root.addedAt, evidence: known.map(\.evidence).joined(separator: "\n"))
                    context.insert(record); evidence.append(record)
                }
                for old in sorted.dropFirst() { old.canonicalEntryID = root.entryID; old.normalizedKey = "legacy-alias|" + old.entryID; old.revision += 1 }
                if root.lemma != canonical {
                    if !root.surfaceForms.contains(root.lemma) { root.surfaceForms.append(root.lemma) }
                    root.lemma = canonical; root.normalizedKey = "en|\(root.entryType)|\(canonical)"; root.revision += 1
                }
                if let state = states.first(where: { $0.entryID == root.entryID }), let earliest = states.filter({ row in records.contains { $0.entryID == row.entryID } }).map(\.dueAt).min() {
                    state.dueAt = min(state.dueAt, earliest)
                }
            }
        }
    }
    func find(surface: String, type: String? = nil, context: String = "") throws -> VocabularyItem? {
        let lemma = EnglishTokenizer.lemma(surface, context: context)
        return try entries(type: type ?? (lemma.contains(" ") ? "phrase" : "word")).first { $0.lemma == lemma }
    }
    func export(_ format: VocabularyExportFormat, at now: Date) throws -> Data {
        let items = try entries()
        struct ExportLog: Codable { let entryID: String, eventID: String, grade: String, algorithmVersion: String; let reviewedAt: Date, nextDueAt: Date }
        struct Payload: Codable { let formatVersion: Int; let exportedAt: Date; let entries: [VocabularyItem]; let reviewLogs: [ExportLog] }
        let ids = Set(items.flatMap { [$0.id] + ($0.legacyAnnotations ?? []).map(\.id) })
        let logs = try writer.read { context in try context.fetch(FetchDescriptor<ReviewLogRecord>()).filter { ids.contains($0.entryID) }.map { ExportLog(entryID: $0.entryID, eventID: $0.eventID, grade: $0.grade, algorithmVersion: $0.algorithmVersion, reviewedAt: $0.reviewedAt, nextDueAt: $0.nextDueAt) } }
        if format == .json {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(Payload(formatVersion: 1, exportedAt: now, entries: items, reviewLogs: logs))
        }
        let date = ISO8601DateFormatter()
        func quote(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var rows = [["entryID", "lemma", "surfaceForms", "type", "personalMeaning", "dictionaryMeanings", "notes", "sourceContextsJSON", "addedAt", "lastReviewedAt", "nextDueAt", "algorithmVersion", "repetitions", "lapses", "stability", "difficulty", "dictionarySensesJSON", "reviewLogsJSON", "reviewMeaningSenseID", "reviewMeaningText", "reviewMeaningEvidence", "personalSensesJSON", "reliableChineseKnown", "legacyAnnotationsJSON", "personalMeaningHistoryJSON"]]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = .sortedKeys
        for item in items {
            rows.append([item.id, item.lemma, item.surfaces.joined(separator: " | "), item.type, item.meaning ?? "", item.dictionaryMeanings.joined(separator: " | "), item.notes ?? "",
                String(decoding: try encoder.encode(item.sourceContexts), as: UTF8.self), date.string(from: item.addedAt), item.lastReviewedAt.map { date.string(from: $0) } ?? "", item.dueAt.map { date.string(from: $0) } ?? "", item.algorithmVersion ?? "", String(item.repetitions), String(item.lapses), item.stability.map { String($0) } ?? "", item.difficulty.map { String($0) } ?? "", String(decoding: try encoder.encode(item.dictionarySenses), as: UTF8.self), String(decoding: try encoder.encode(logs.filter { $0.entryID == item.id }), as: UTF8.self), item.reviewMeaningSenseID ?? "", item.reviewMeaningText ?? "", item.reviewMeaningEvidence ?? "", String(decoding: try encoder.encode(item.personalSenses ?? []), as: UTF8.self), String(item.reliableChineseKnown ?? false), String(decoding: try encoder.encode(item.legacyAnnotations ?? []), as: UTF8.self), String(decoding: try encoder.encode(item.personalHistory ?? []), as: UTF8.self)])
        }
        return Data((rows.map { $0.map(quote).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n").utf8)
    }
    func add(token: EnglishToken, articleID: String, autoAdd: Bool, explicit: Bool = false, origin: VocabularyContextOrigin = .reader, at now: Date) throws -> VocabularyAddition? {
        guard autoAdd || explicit else { return nil }
        try normalizeIdentities()
        if case let .dictionary(headword, evidence, _) = origin, headword.isBlank || evidence.isBlank { throw LearningError.invalid("词典语境缺少真实词条或来源证据，未加入生词本。") }
        let lemma = EnglishTokenizer.lemma(token.surface, context: token.sentence)
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
    /// Explicit dictionary action. A dictionary word does not need a fabricated article.
    func addDictionaryEntry(headword: String, surface: String? = nil, context sentence: String = "", at now: Date) throws -> VocabularyAddition {
        let lemma = EnglishTokenizer.lemma(headword), type = lemma.contains(" ") ? "phrase" : "word"
        let original = surface?.trimmingCharacters(in: .whitespacesAndNewlines) ?? headword
        guard !lemma.isBlank, lemma.count <= 100, !EnglishTokenizer.tokens(in: lemma).isEmpty else { throw LearningError.invalid("请输入有效英文词头。") }
        guard !original.isBlank, original.count <= 100, EnglishTokenizer.lemma(original, context: sentence) == lemma else { throw LearningError.invalid("原始词形与规范词头不一致，请重新查词。") }
        try normalizeIdentities()
        return try writer.write {
            let context = writer.context
            guard try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).contains(where: {
                $0.lemma == lemma && $0.mdxSHA == BundledMDXDictionaryProvider.sourceSHA && ["chinese", "noChinese", "notFound"].contains($0.lookupStatus ?? "")
            }) else { throw LearningError.invalid("请先完成本次 MDX 查询，不能把引擎故障当作查无此词。") }
            let rows = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).filter { $0.normalizedKey == "en|\(type)|\(lemma)" }
            guard rows.count <= 1 else { throw PersistenceError.integrity("重复词条") }
            let token = UUID().uuidString
            if let existing = rows.first {
                let states = try context.fetch(FetchDescriptor<ReviewStateRecord>()).filter { $0.entryID == existing.entryID }
                guard states.count == 1 else { throw PersistenceError.integrity("生词复习状态缺失或重复，不能重新添加") }
                if !existing.surfaceForms.contains(original) { existing.surfaceForms.append(original); existing.revision += 1 }
                if existing.deletedAt == nil { return VocabularyAddition(entryID: existing.entryID, created: false, token: nil, revision: existing.revision) }
                existing.deletedAt = nil; existing.addedAt = now; existing.creationToken = token; existing.revision += 1
                if let state = states.first { state.dueAt = min(state.dueAt, now) }
                return VocabularyAddition(entryID: existing.entryID, created: true, token: token, revision: existing.revision)
            }
            let entry = VocabularyEntryRecord(lemma: lemma, surface: original, type: type, at: now, from: "dictionary", token: token)
            context.insert(entry); context.insert(ReviewStateRecord(entryID: entry.entryID, at: now))
            return VocabularyAddition(entryID: entry.entryID, created: true, token: token, revision: entry.revision)
        }
    }
    func annotate(entryID: String, meaning: String, notes: String, at now: Date) throws {
        guard meaning.count <= 200, notes.count <= 2000 else { throw LearningError.invalid("个人释义或笔记过长。") }
        try writer.write {
            guard let entry = try writer.context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID }), entry.deletedAt == nil else { throw LearningError.invalid("词条已移除。") }
            let updatedMeaning = meaning.isBlank ? nil : meaning
            if entry.userMeaning != updatedMeaning, try !personalAllowed(lemma: entry.lemma, context: writer.context) {
                throw LearningError.invalid("MDX 未确认缺少中文释义，不能修改个人释义。你的笔记仍可保存。")
            }
            if entry.userMeaning != updatedMeaning { entry.reviewMeaningSenseID = nil; entry.reviewMeaningText = nil; entry.reviewMeaningEvidence = nil; entry.reviewMeaningSnapshotData = nil }
            entry.userMeaning = updatedMeaning; entry.notes = notes.isBlank ? nil : notes
            entry.lastOpenedAt = max(now, entry.lastOpenedAt); entry.revision += 1
        }
    }
    private func hasReliableChinese(lemma: String, context: ModelContext) throws -> Bool {
        if try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).contains(where: { $0.lemma == lemma && $0.mdxSHA == BundledMDXDictionaryProvider.sourceSHA && $0.reliableChineseKnown }) { return true }
        return try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.lemma == lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }.contains { row in
            try JSONDecoder().decode([DictionarySense].self, from: row.payload).contains(where: BilingualMeaningPolicy.trusted)
        }
    }
    func personalEditingAllowed(entryID: String) throws -> Bool {
        try writer.read { context in
            guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID && $0.deletedAt == nil }) else { throw LearningError.invalid("词条已移除。") }
            return try personalAllowed(lemma: entry.lemma, context: context)
        }
    }
    private func personalAllowed(lemma: String, context: ModelContext) throws -> Bool {
        guard try !hasReliableChinese(lemma: lemma, context: context) else { return false }
        return try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).contains {
            $0.lemma == lemma && $0.mdxSHA == BundledMDXDictionaryProvider.sourceSHA &&
                BilingualMeaningPolicy.permitsPersonal(senses: [], knownReliableChinese: $0.reliableChineseKnown, availability: MDXDefinitionAvailability(rawValue: $0.lookupStatus ?? "") ?? .checking)
        }
    }
    func savePersonalSenses(entryID: String, senses: [PersonalDictionarySense], at now: Date) throws {
        guard senses.count <= 30, Set(senses.map(\.id)).count == senses.count else { throw LearningError.invalid("义项过多或身份重复。") }
        try senses.forEach { try $0.validate() }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        try writer.write {
            let context = writer.context
            guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID && $0.deletedAt == nil }) else { throw LearningError.invalid("词条已移除。") }
            guard try personalAllowed(lemma: entry.lemma, context: context) else { throw LearningError.invalid("请先完成 MDX 查询。已有中文释义或词典故障时不能编辑个人释义，草稿保留。") }
            let old = try entry.personalSensesData.map { try JSONDecoder().decode([PersonalDictionarySense].self, from: $0) } ?? []
            let updated = senses.map { draft -> PersonalDictionarySense in
                var value = draft
                if let previous = old.first(where: { $0.id == draft.id }) {
                    value.revision = previous.revision
                    if value != previous { value.revision += 1 }
                } else { value.revision = max(1, value.revision) }
                return value
            }
            let data = try encoder.encode(updated)
            if entry.personalSensesData == data { return }
            if entry.personalSensesData != nil {
                var history = try entry.personalMeaningHistoryData.map { try JSONDecoder().decode([PersonalMeaningRevision].self, from: $0) } ?? []
                history.append(PersonalMeaningRevision(revision: entry.personalMeaningRevision ?? 0, archivedAt: now, senses: old))
                entry.personalMeaningHistoryData = try encoder.encode(history)
            }
            entry.personalSensesData = data; entry.personalMeaningRevision = (entry.personalMeaningRevision ?? 0) + 1
            entry.userMeaning = senses.first(where: { !$0.chinese.isBlank })?.chinese
            entry.reviewMeaningSenseID = nil; entry.reviewMeaningText = nil; entry.reviewMeaningEvidence = nil; entry.reviewMeaningSnapshotData = nil
            entry.lastOpenedAt = max(now, entry.lastOpenedAt); entry.revision += 1
        }
    }
    func saveNotes(entryID: String, notes: String, at now: Date) throws {
        guard notes.count <= 2000 else { throw LearningError.invalid("笔记最多2000字。") }
        try writer.write {
            guard let entry = try writer.context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID && $0.deletedAt == nil }) else { throw LearningError.invalid("词条已移除。") }
            let value = notes.isBlank ? nil : notes
            if entry.notes != value { entry.notes = value; entry.revision += 1; entry.lastOpenedAt = max(now, entry.lastOpenedAt) }
        }
    }
    func confirmReviewMeaning(entryID: String, sourceSenseID: String) throws {
        try writer.write {
            let context = writer.context
            guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == entryID && $0.deletedAt == nil }) else { throw LearningError.invalid("词条不存在或已移除。") }
            let official = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.lemma == entry.lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }.flatMap { try JSONDecoder().decode([DictionarySense].self, from: $0.payload) }.filter(BilingualMeaningPolicy.trusted)
            if let sense = official.first(where: { $0.id == sourceSenseID }) {
                guard sense.partOfSpeech?.isBlank == false else { throw LearningError.invalid("该 MDX 义项未提供词性，暂不能用作复习标准答案。") }
                entry.reviewMeaningSenseID = sense.id; entry.reviewMeaningText = sense.zh; entry.reviewMeaningEvidence = sense.line; entry.reviewMeaningSnapshotData = try JSONEncoder().encode(sense); entry.revision += 1; return
            }
            guard try personalAllowed(lemma: entry.lemma, context: context) else { throw LearningError.invalid("请选择内置 MDX 中的中文义项。") }
            let personal = try entry.personalSensesData.map { try JSONDecoder().decode([PersonalDictionarySense].self, from: $0) } ?? []
            guard let sense = personal.filter(\.reviewReady).map({ $0.dictionarySense(entryID: entryID) }).first(where: { $0.id == sourceSenseID }) else { throw LearningError.invalid("请选择已确认、具有词性与中文的个人义项。") }
            entry.reviewMeaningSenseID = sense.id; entry.reviewMeaningText = sense.zh; entry.reviewMeaningEvidence = sense.line
            entry.reviewMeaningSnapshotData = try JSONEncoder().encode(sense)
            entry.revision += 1
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
    var exampleTranslations: [String]? = nil
    var usageLabels: [String]? = nil
    var relatedPhrases: [String]? = nil
    var sourceRevision: String? = nil
    var originKind: String? = nil
    var lexicalHeadword: String? = nil
    var sectionKind: String? = nil
    var policyVersion: String? = nil
    var entryGroupID: String? = nil
    var exampleCollocations: [String]? = nil
}

struct DictionaryResult: Equatable {
    let headword: String
    let senses: [DictionarySense]
    let updatedAt: Date
    let sourceURL: String
    let licenseURL: String
    var failedProviders: [String] = []
    var emptyProviders: [String] = []
    var cached: Bool = false
    var versions: [String: String] = [:]
    var usableSenses: [DictionarySense] { BilingualMeaningPolicy.displaySenses(senses) }
    var reliableChinese: [DictionarySense] { senses.filter(BilingualMeaningPolicy.trusted) }
}
protocol DictionaryProvider: Sendable { func lookup(_ headword: String) async throws -> [DictionarySense] }
/// Local, source-derived, legally redistributable index. No network or personal reading history upload.
// Historical parser fixtures only. Never constructed by the application.
#if DEBUG && targetEnvironment(simulator)
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
#else
enum CEDICTDictionaryProvider { static let sourceVersion = "2026-10-30-reverse-v1" }
#endif
@MainActor final class DictionaryLookupService {
    private let writer: RepositoryWriter
    private var provider: any DictionaryProvider
    private let cache: DictionaryCacheRepository
    init(context: ModelContext, provider: any DictionaryProvider = BundledMDXDictionaryProvider()) {
        writer = RepositoryWriter(context: context); self.provider = provider
        cache = DictionaryCacheRepository(context: context)
    }
    var onlineEnabled: Bool { false }
    func clearCaches() throws -> Int {
        try writer.write {
            let context = writer.context
            let local = try context.fetch(FetchDescriptor<DictionaryEntryRecord>())
            let remote = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
            for record in try context.fetch(FetchDescriptor<DictionarySenseRecord>()) { context.delete(record) }
            for record in local { context.delete(record) }
            for record in remote { context.delete(record) }
            return local.count + remote.count
        }
    }
    func lookup(_ surface: String, context: String = "", at now: Date = Date()) async throws -> DictionaryResult {
        let key = EnglishTokenizer.lemma(surface, context: context)
        var senses: [DictionarySense]
        do {
            senses = try await provider.lookup(key)
            if senses.isEmpty, let native = provider as? BundledMDXDictionaryProvider {
                let previous = try cache.load(key, at: now).senses
                let hints = Self.recordHints(previous)
                if !hints.isEmpty { senses = try await native.lookupSubentry(key, recordHints: hints) }
            }
            try Task.checkCancellation()
        } catch is CancellationError { throw CancellationError() }
        catch {
            try cache.recordFailure(key, error: error.localizedDescription, at: now)
            throw error
        }
        guard Set(senses.map(\.id)).count == senses.count else { throw MDXDictionaryError.invalidEntry("重复义项身份") }
        try cache.save(key, senses: senses, successful: [BundledMDXDictionaryProvider.sourceName], at: now)
        return DictionaryResult(headword: key, senses: senses, updatedAt: now, sourceURL: "", licenseURL: "", cached: true, versions: DictionaryAggregator.versions)
    }
    func subentry(_ headword: String, from parent: DictionaryResult, at now: Date = Date()) async throws -> DictionaryResult {
        let candidates = parent.senses.filter { $0.lexicalHeadword?.caseInsensitiveCompare(headword) == .orderedSame }
        let hints = Self.recordHints(candidates)
        guard let native = provider as? BundledMDXDictionaryProvider, !hints.isEmpty else { throw MDXDictionaryError.invalidEntry("此内部词条缺少 MDX 记录身份") }
        let senses = try await native.lookupSubentry(headword, recordHints: hints)
        try Task.checkCancellation()
        let key = EnglishTokenizer.lemma(headword)
        try cache.save(key, senses: senses, successful: [BundledMDXDictionaryProvider.sourceName], at: now)
        return DictionaryResult(headword: key, senses: senses, updatedAt: now, sourceURL: "", licenseURL: "", cached: true, versions: DictionaryAggregator.versions)
    }
    private static func recordHints(_ senses: [DictionarySense]) -> [Int] {
        Array(Set(senses.filter(BilingualMeaningPolicy.trusted).compactMap { sense -> Int? in
            let fields = sense.id.split(separator: "|", omittingEmptySubsequences: false)
            guard fields.count >= 5, fields[0] == "mdx", fields[1] == BundledMDXDictionaryProvider.sourceSHA, let number = Int(fields[2]), number >= 0 else { return nil }
            return number
        })).sorted()
    }
    func localResult(_ surface: String, at now: Date = Date()) async throws -> DictionaryResult {
        try await lookup(surface, at: now)
    }
    func cached(_ key: String) throws -> DictionaryResult? {
        let result = try cache.load(key, at: Date())
        guard result.complete else { return nil }
        return DictionaryResult(headword: key, senses: result.senses, updatedAt: result.date, sourceURL: "", licenseURL: "", cached: true, versions: DictionaryAggregator.versions)
    }
    #if DEBUG && targetEnvironment(simulator)
    func configureMDXResourceForEvidence(_ url: URL) { provider = BundledMDXDictionaryProvider(resource: url) }
    func recordEmptyEligibilityFixture(_ lemma: String, at now: Date) throws {
        try cache.save(lemma, senses: [], successful: [BundledMDXDictionaryProvider.sourceName], at: now)
    }
    func configureDictionaryEvidence(providers: [(String, any DictionaryProvider)], cachedSenses: [DictionarySense] = [], stale: Bool = false) throws {
        provider = MDXEvidenceAdapter(providers: providers)
        if !cachedSenses.isEmpty {
            try cache.save("internet", senses: cachedSenses.map(MDXEvidenceAdapter.mark), successful: [BundledMDXDictionaryProvider.sourceName], at: Date().addingTimeInterval(stale ? -31 * 86400 : 0))
        }
    }
    #endif
}
#if DEBUG && targetEnvironment(simulator)
/// Explicit UI/transport fixtures, excluded from Release. Never proves MDX parsing.
private struct MDXEvidenceAdapter: DictionaryProvider {
    let providers: [(String, any DictionaryProvider)]
    static func mark(_ sense: DictionarySense) -> DictionarySense {
        var value = sense
        value.line = "Explicit fixture · " + value.line
        value.sources = [BundledMDXDictionaryProvider.sourceName]
        value.sourceRevision = BundledMDXDictionaryProvider.sourceVersion; value.originKind = "mdx"
        return value
    }
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        var values: [DictionarySense] = []
        for (_, provider) in providers { values += try await provider.lookup(headword) }
        var ids = Set<String>()
        return values.map(Self.mark).filter { ids.insert($0.id).inserted }
    }
}
#endif
