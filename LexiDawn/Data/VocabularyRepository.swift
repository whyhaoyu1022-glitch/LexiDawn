import Foundation
import SwiftData

struct VocabularyItem: Identifiable, Equatable {
    let id: String, lemma: String, type: String
    let surfaces: [String]
    let addedAt: Date
    let meaning: String?
    let notes: String?
    let contexts: [String]
    let sourceArticleID: String?
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
            return all.filter { $0.deletedAt == nil && (type == nil || $0.entryType == type) }.map { record in
                VocabularyItem(id: record.entryID, lemma: record.lemma, type: record.entryType, surfaces: record.surfaceForms,
                    addedAt: record.addedAt, meaning: record.userMeaning, notes: record.notes,
                    contexts: contexts.filter { $0.entryID == record.entryID }.map(\.sentence), sourceArticleID: contexts.first { $0.entryID == record.entryID }?.articleID)
            }.filter { search.isBlank || ([$0.lemma, $0.meaning ?? ""] + $0.surfaces).contains { $0.localizedCaseInsensitiveContains(search) } }
                .sorted { $0.addedAt > $1.addedAt }
        }
    }
    func find(surface: String, type: String = "word") throws -> VocabularyItem? {
        let lemma = EnglishTokenizer.lemma(surface)
        return try entries(type: type).first { $0.lemma == lemma }
    }
    func add(token: EnglishToken, articleID: String, autoAdd: Bool, explicit: Bool = false, at now: Date) throws -> VocabularyAddition? {
        guard autoAdd || explicit else { return nil }
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
            let source = VocabularySourceContextRecord(entryID: record.entryID, articleID: articleID, surface: token.surface, sentence: token.sentence, tokenLocation: token.range.location, at: now)
            if try !context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).contains(where: { $0.contextID == source.contextID }) { context.insert(source) }
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
            entry.userMeaning = meaning.isBlank ? nil : meaning; entry.notes = notes.isBlank ? nil : notes
            entry.lastOpenedAt = max(now, entry.lastOpenedAt); entry.revision += 1
        }
    }
}

struct DictionarySense: Codable, Equatable, Identifiable { let id: String, en: String, zh: String, line: String }
struct DictionaryResult: Equatable {
    let headword: String
    let senses: [DictionarySense]
    let updatedAt: Date
    let sourceURL: String
    let licenseURL: String
}
protocol DictionaryProvider { func lookup(_ headword: String) async throws -> [DictionarySense] }
/// Local, source-derived, legally redistributable index. No network or personal reading history upload.
actor CEDICTDictionaryProvider: DictionaryProvider {
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
    init(context: ModelContext, provider: DictionaryProvider = CEDICTDictionaryProvider()) {
        writer = RepositoryWriter(context: context); self.provider = provider
    }
    func lookup(_ surface: String, at now: Date = Date()) async throws -> DictionaryResult {
        let key = EnglishTokenizer.lemma(surface)
        if let cached = try cached(key) { return cached }
        let senses = try await provider.lookup(key)
        guard Set(senses.map(\.id)).count == senses.count else { throw LearningError.invalid("词典返回重复义项，不能保存。") }
        return try writer.write {
            let context = writer.context
            let record = try context.fetch(FetchDescriptor<DictionaryEntryRecord>()).first { $0.headword == key } ?? DictionaryEntryRecord(headword: key, at: now)
            if record.modelContext == nil { context.insert(record) }
            let old = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
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
            guard let entry = entries.first else { return nil }
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>()).filter { $0.entryID == entry.entryID }
                .sorted { $0.senseID < $1.senseID }.map { DictionarySense(id: String($0.senseID.split(separator: "|").last ?? ""), en: $0.english, zh: $0.chinese, line: $0.sourceLine) }
            return DictionaryResult(headword: key, senses: senses, updatedAt: entry.updatedAt, sourceURL: entry.sourceURL, licenseURL: entry.licenseURL)
        }
    }
}
