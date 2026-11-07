import Foundation
import SwiftData

struct ReviewQuestion: Identifiable, Equatable {
    let id: String, entryID: String, stage: String, prompt: String, answer: String, senseID: String
    let attempts: Int
    let usedHint: Bool
    let completed: Bool
    var context: String? = nil
    var acceptedAnswers: [String] = []
    var revealed = false
    var meaning: DictionarySense? = nil
    var contextOrigin: String? = nil
}
struct ReviewSessionView: Equatable {
    let id: String
    let matching: [ReviewQuestion]
    let cloze: [ReviewQuestion]
    let completedAt: Date?
    var deferredCount: Int = 0
    var matchingComplete: Bool { !matching.isEmpty && matching.allSatisfy(\.completed) }
}

@MainActor final class ReviewQueueService: ReviewQueueReading, ReviewSessionReading {
    private let writer: RepositoryWriter
    private let cycles: StudyCycleRepository
    private let dictionary: DictionaryLookupService
    init(context: ModelContext, cycles: StudyCycleRepository, dictionary: DictionaryLookupService,
         saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        writer = RepositoryWriter(context: context, saveContext: saveContext); self.cycles = cycles; self.dictionary = dictionary
    }
    private func eligible(in context: ModelContext, at now: Date) throws -> [VocabularyEntryRecord] {
        guard now.timeIntervalSince1970.isFinite else { throw LearningError.invalid("复习时间无效。") }
        let entries = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).filter { $0.deletedAt == nil }
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        guard Set(entries.map(\.entryID)).count == entries.count, Set(states.map(\.entryID)).count == states.count else { throw PersistenceError.integrity("词汇或复习状态重复") }
        for entry in entries {
            guard let state = states.first(where: { $0.entryID == entry.entryID }), state.dueAt.timeIntervalSince1970.isFinite,
                  state.repetitions >= 0, state.intervalDays >= 0, [BasicReviewScheduler.version, FSRSScheduler.version].contains(state.algorithmVersion) else {
                throw PersistenceError.integrity("词条 \(entry.lemma) 的复习状态缺失或不受支持，不能证明队列为空")
            }
        }
        let due = entries.filter { entry in states.contains { $0.entryID == entry.entryID && ($0.repetitions == 0 || $0.dueAt <= now) } }
        return due.sorted { left, right in
            let a = states.first { $0.entryID == left.entryID }?.dueAt ?? now
            let b = states.first { $0.entryID == right.entryID }?.dueAt ?? now
            return (a, left.addedAt, left.entryID) < (b, right.addedAt, right.entryID)
        }
    }
    func eligibleQueue(for cycleID: UUID, at timestamp: Date) throws -> ReviewQueueSnapshot {
        try writer.read { context in
            _ = try cycleInContext(cycleID, context: context)
            let ids = try eligible(in: context, at: timestamp).map(\.entryID)
            return ReviewQueueSnapshot(revision: fingerprint(ids.joined(separator: "|") + "|" + String(timestamp.timeIntervalSince1970)), eligibleEntryIDs: ids, isComplete: true)
        }
    }
    func pendingCount(at now: Date) throws -> Int { try writer.read { try eligible(in: $0, at: now).count } }
    func prepare(cycleID: UUID, dailyLimit: Int, pairCount: Int, clozeCount: Int, at now: Date) async throws -> ReviewSessionView? {
        try snapshotLegacyContexts(cycleID: cycleID)
        if let saved = try session(cycleID: cycleID) { return saved }
        let cycle = try writer.read { try cycleInContext(cycleID, context: $0) }
        if cycle.reviewEvidence != nil { return nil }
        guard dailyLimit > 0, pairCount > 0, clozeCount > 0 else { throw LearningError.invalid("复习题量设置无效。") }
        let originalIDs: [String] = try writer.write {
            let context = writer.context
            if let existing = try context.fetch(FetchDescriptor<ReviewPreparationRecord>()).first(where: { $0.cycleID == cycleID.uuidString }) { return existing.selectedEntryIDs }
            let ids = Array(try eligible(in: context, at: now).prefix(min(dailyLimit, pairCount))).map(\.entryID)
            context.insert(ReviewPreparationRecord(cycleID: cycleID, entries: ids, at: now)); return ids
        }
        let skipped = try deferredIDs(cycleID: cycleID)
        let selected: [(String, String)] = try writer.read { context in
            let entries = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            return try originalIDs.filter { !skipped.contains($0) }.map { id in
                guard let entry = entries.first(where: { $0.entryID == id && $0.deletedAt == nil }) else { throw LearningError.invalid("本次词条已移除，请返回生词本核对。") }
                return (id, entry.lemma)
            }
        }
        try await primeMeanings(selected, at: now)
        try writer.write {
            let context = writer.context
            var cycle = try cycleInContext(cycleID, context: context)
            if try context.fetch(FetchDescriptor<ReviewSessionRecord>()).contains(where: { $0.cycleID == cycleID.uuidString }) { return }
            if cycle.reviewEvidence != nil { return }
            if selected.isEmpty {
                if originalIDs.isEmpty {
                    guard try eligible(in: context, at: now).isEmpty else { throw LearningError.invalid("队列已有新词，请重新检查。") }
                    let reader = TransactionQueueSnapshot(ids: [], revision: fingerprint("complete|\(now.timeIntervalSince1970)"))
                    try cycle.resolveEmptyReview(ReviewQueueEvidence.evaluate(cycleID: cycleID, reader: reader, at: max(now, cycle.createdAtUTC)))
                } else {
                    let proof = try context.fetch(FetchDescriptor<ReviewDeferralRecord>()).filter { $0.cycleID == cycleID.uuidString }
                    let ids = originalIDs.filter { id in proof.contains { $0.entryID == id } }
                    let timestamp = max(now, cycle.createdAtUTC)
                    let evidence = try ReviewQueueEvidence.userDeferred(cycleID: cycleID, original: originalIDs, deferred: ids, revision: fingerprint(proof.map(\.id).sorted().joined()), at: timestamp)
                    try cycle.resolveDeferredReview(evidence)
                }
                try cycles.applyInTransaction(cycle, context: context); return
            }
            let entries = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            let chosen = try selected.map { id, _ -> VocabularyEntryRecord in
                guard let value = entries.first(where: { $0.entryID == id && $0.deletedAt == nil }) else { throw LearningError.invalid("复习词条发生变化，请重试。") }
                return value
            }
            let session = ReviewSessionRecord(cycleID: cycleID, entries: chosen.map(\.entryID), at: max(now, cycle.createdAtUTC), limit: dailyLimit)
            session.deferredEntryIDs = skipped.sorted()
            context.insert(session)
            try insertExercises(session: session, chosen: chosen, clozeCount: clozeCount, context: context)
        }
        return try session(cycleID: cycleID)
    }
    func session(cycleID: UUID) throws -> ReviewSessionView? {
        try writer.read { context in
            let records = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).filter { $0.cycleID == cycleID.uuidString }
            guard records.count <= 1 else { throw PersistenceError.integrity("一个周期存在多个必做复习会话") }
            guard let session = records.first else { return nil }
            return try view(session, context: context)
        }
    }
    private func view(_ session: ReviewSessionRecord, context: ModelContext) throws -> ReviewSessionView {
        let exercises = try validatedExercises(session, context: context)
        func questions(_ stage: String) -> [ReviewQuestion] {
            exercises.filter { $0.stage == stage }.sorted { $0.position < $1.position }.map { exercise in
                var question = ReviewQuestion(id: exercise.exerciseID, entryID: exercise.entryID, stage: stage, prompt: exercise.prompt, answer: exercise.answer, senseID: exercise.senseID, attempts: exercise.attempts, usedHint: exercise.usedHint, completed: exercise.completedAt != nil, context: exercise.sourceContext, acceptedAnswers: exercise.acceptedAnswers ?? [exercise.answer])
                question.contextOrigin = exercise.contextOriginKind
                question.revealed = exercise.revealed
                question.meaning = exercise.meaningSnapshot.flatMap { try? JSONDecoder().decode(DictionarySense.self, from: $0) }
                return question
            }
        }
        return ReviewSessionView(id: session.sessionID, matching: questions("matching"), cloze: questions("cloze"), completedAt: session.completedAt, deferredCount: session.deferredEntryIDs?.count ?? 0)
    }
    func deferredIDs(cycleID: UUID) throws -> Set<String> {
        try writer.read { context in Set(try context.fetch(FetchDescriptor<ReviewDeferralRecord>()).filter { $0.cycleID == cycleID.uuidString }.map(\.entryID)) }
    }
    func deferEntry(cycleID: UUID, issue: ReviewMeaningIssue, at now: Date) throws {
        try writer.write {
            let context = writer.context
            _ = try cycleInContext(cycleID, context: context)
            guard let prepared = try context.fetch(FetchDescriptor<ReviewPreparationRecord>()).first(where: { $0.cycleID == cycleID.uuidString }), prepared.selectedEntryIDs.contains(issue.entryID),
                  !(try context.fetch(FetchDescriptor<ReviewSessionRecord>())).contains(where: { $0.cycleID == cycleID.uuidString }) else { throw LearningError.invalid("当前题组已变化，请重新检查。") }
            let key = cycleID.uuidString + "|" + issue.entryID
            if try !context.fetch(FetchDescriptor<ReviewDeferralRecord>()).contains(where: { $0.id == key }) {
                context.insert(ReviewDeferralRecord(cycleID: cycleID, entryID: issue.entryID, reason: issue.reason, at: now))
            }
        }
    }
    func remainingPreparationCount(cycleID: UUID) throws -> Int {
        let skipped = try deferredIDs(cycleID: cycleID)
        return try writer.read { context in
            guard let prepared = try context.fetch(FetchDescriptor<ReviewPreparationRecord>()).first(where: { $0.cycleID == cycleID.uuidString }) else { return 0 }
            return prepared.selectedEntryIDs.filter { !skipped.contains($0) }.count
        }
    }
    private func primeMeanings(_ selected: [(String, String)], at now: Date) async throws {
        for (id, lemma) in selected {
            let ready = try writer.read { context in
                guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == id }) else { return false }
                return (try? resolveMeaning(entry, context: context)) != nil
            }
            if ready && !dictionary.onlineEnabled { continue }
            do {
                let sentence = try writer.read { context in try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).first { $0.entryID == id }?.sentence ?? "" }
                _ = try await dictionary.lookup(lemma, context: sentence, at: now)
            } catch is CancellationError { throw CancellationError() }
            catch let error as PersistenceError { throw error }
            catch { if !ready { /* Resolution below distinguishes missing meanings from an empty queue. */ } }
            try Task.checkCancellation()
            try writer.read { context in
                guard let entry = try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first(where: { $0.entryID == id && $0.deletedAt == nil }) else { throw LearningError.invalid("词条已移除。") }
                _ = try resolveMeaning(entry, context: context)
            }
        }
    }
    private func resolveMeaning(_ entry: VocabularyEntryRecord, context: ModelContext) throws -> DictionarySense {
        let caches = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>()).filter { $0.lemma == entry.lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }
        let official = caches.flatMap { (try? JSONDecoder().decode([DictionarySense].self, from: $0.payload)) ?? [] }.filter(BilingualMeaningPolicy.trusted)
        let known = try context.fetch(FetchDescriptor<DictionaryEligibilityRecord>()).contains { $0.lemma == entry.lemma && $0.reliableChineseKnown }
        let source = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).filter { $0.entryID == entry.entryID }.sorted { $0.createdAt < $1.createdAt }.first
        if let data = entry.reviewMeaningSnapshotData, let selected = try? JSONDecoder().decode(DictionarySense.self, from: data), BilingualMeaningPolicy.trusted(selected) { return selected }
        if let selected = official.first(where: { $0.id == entry.reviewMeaningSenseID }) { return selected }
        if let sense = DictionaryAggregator.rank(official, context: source?.sentence ?? "", surface: entry.lemma).first {
            guard sense.partOfSpeech != nil else { throw ReviewMeaningIssue(entryID: entry.entryID, lemma: entry.lemma, reason: "的词性尚不完整，请重试词典或本次延期。", canEditPersonal: false) }
            return sense
        }
        if known { throw ReviewMeaningIssue(entryID: entry.entryID, lemma: entry.lemma, reason: "的可靠英中资料暂不可用，请重新查词或本次延期。", canEditPersonal: false) }
        if let data = entry.personalSensesData {
            let senses = try JSONDecoder().decode([PersonalDictionarySense].self, from: data)
            if let sense = senses.first(where: \.reviewReady) { return sense.dictionarySense(entryID: entry.entryID) }
        }
        // Explicitly selected historical Chinese candidates remain personal confirmation,
        // never an automatically trusted reverse-index answer.
        if let selectedID = entry.reviewMeaningSenseID, let text = entry.reviewMeaningText, BilingualMeaningPolicy.hasChinese(text), entry.reviewMeaningEvidence?.isBlank == false {
            let record = try context.fetch(FetchDescriptor<DictionarySenseRecord>()).first { $0.senseID == selectedID }
            if let part = record?.partOfSpeech { return DictionarySense(id: selectedID, en: "", zh: text, line: "用户确认 · " + (entry.reviewMeaningEvidence ?? ""), partOfSpeech: part, sources: ["个人确认"], originKind: "personal") }
        }
        throw ReviewMeaningIssue(entryID: entry.entryID, lemma: entry.lemma, reason: "还没有可复习的英中义项。请补充词性、中文并确认学习义项，或本次延期。", canEditPersonal: true)
    }
    private func insertExercises(session: ReviewSessionRecord, chosen: [VocabularyEntryRecord], clozeCount: Int, context: ModelContext) throws {
        let sources = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).sorted { ($0.createdAt, $0.contextID) < ($1.createdAt, $1.contextID) }
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        let providerCaches = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
        let ranked = chosen.filter { $0.lemma.filter(\.isLetter).count >= 3 }.sorted { a, b in
            let aLapses = states.first { $0.entryID == a.entryID }?.lapses ?? 0
            let bLapses = states.first { $0.entryID == b.entryID }?.lapses ?? 0
            return aLapses == bLapses ? a.entryID < b.entryID : aLapses > bLapses
        }
        let spellingIDs = Set(ranked.prefix(clozeCount).map(\.entryID))
        if spellingIDs.isEmpty { session.clozeExclusionReason = "targets-under-three-letters" }
        var meanings = Set<String>()
        for (position, entry) in chosen.enumerated() {
            let sense = try resolveMeaning(entry, context: context)
            let source = sources.first { $0.entryID == entry.entryID }
            let meaning = sense.zh
            guard meanings.insert(meaning).inserted else { throw ReviewMeaningIssue(entryID: entry.entryID, lemma: entry.lemma, reason: "与本组另一词的中文答案相同，请明确选择其他语境义或本次延期。", canEditPersonal: !BilingualMeaningPolicy.trusted(sense)) }
            let snapshot = try JSONEncoder().encode(sense)
            let matching = ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "matching", position: position, prompt: entry.lemma, answer: meaning, senseID: sense.id)
            matching.meaningSnapshot = snapshot; context.insert(matching)
            if spellingIDs.contains(entry.entryID) {
                var projection = ClozeContext.make(lemma: entry.lemma, surfaces: source.map { [$0.surface] + entry.surfaceForms } ?? entry.surfaceForms, sentence: source?.sentence)
                var contextOrigin = source?.contextKind == "reader" ? "article" : source?.contextKind == "dictionary" ? "dictionary" : "saved-context"
                if projection.sentence == nil, let data = entry.personalSensesData {
                    let personal = try JSONDecoder().decode([PersonalDictionarySense].self, from: data)
                    let examples = personal.filter(\.reviewReady).flatMap(\.examples)
                    for example in examples {
                        let value = ClozeContext.make(lemma: entry.lemma, surfaces: entry.surfaceForms, sentence: example.english)
                        if value.sentence != nil { projection = value; contextOrigin = "personal-example"; break }
                    }
                }
                guard projection.sentence != nil else { throw ReviewMeaningIssue(entryID: entry.entryID, lemma: entry.lemma, reason: "缺少包含目标词的有效例句，请补充例句或本次延期。", canEditPersonal: !BilingualMeaningPolicy.trusted(sense)) }
                let mask = SpellingMaskPolicy.mask(projection.answer, seed: session.sessionID + "|" + entry.entryID)
                let question = ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "cloze", position: position, prompt: mask.text, answer: projection.answer, senseID: sense.id)
                question.contextOriginKind = contextOrigin
                question.sourceContext = projection.sentence; question.meaningSnapshot = snapshot; question.maskIndices = mask.indices; question.maskVersion = SpellingMaskPolicy.version
                let originalSenses = providerCaches.filter { $0.lemma == entry.lemma }.flatMap { (try? JSONDecoder().decode([DictionarySense].self, from: $0.payload)) ?? [] }
                question.acceptedAnswers = SpellingAnswerPolicy.variants(answer: projection.answer, lemma: entry.lemma, senses: originalSenses)
                context.insert(question)
            }
        }
    }
    private func requireExtraAllowed(context: ModelContext, at now: Date) throws {
        let all = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).map { try $0.domain() }
        guard !all.isEmpty, all.allSatisfy({ $0.reviewTaskStatus == .completed || $0.reviewTaskStatus == .deferred }) else { throw LearningError.invalid("请先完成当前必做复习，再开启额外复习。") }
        let access = try articleLearningAccess(cycles: all, context: context, at: now)
        guard access.current != nil || access.mayExplore else { throw LearningError.invalid("学习日期已变化，请先返回今日确认当前任务。") }
    }
    func extraSession(sessionID: String? = nil) throws -> ReviewSessionView? {
        try writer.read { context in
            let rows = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).filter { $0.purpose == "extra" && (sessionID == nil ? $0.completedAt == nil : $0.sessionID == sessionID) }.sorted { $0.createdAt < $1.createdAt }
            guard rows.count <= 1 else { throw PersistenceError.integrity("存在多个未完成额外复习会话") }
            return try rows.first.map { try view($0, context: context) }
        }
    }
    private func extraEligible(in context: ModelContext, at now: Date) throws -> [VocabularyEntryRecord] {
        let latest = try context.fetch(FetchDescriptor<DailyStudyCycleRecord>()).sorted { $0.createdAtUTC < $1.createdAtUTC }.last
        let excluded = Set(try context.fetch(FetchDescriptor<ReviewDeferralRecord>()).filter { $0.cycleID == latest?.cycleID }.map(\.entryID))
        return try eligible(in: context, at: now).filter { !excluded.contains($0.entryID) }
    }
    func prepareExtra(dailyLimit: Int, pairCount: Int, clozeCount: Int, at now: Date) async throws -> ReviewSessionView? {
        try writer.read { try requireExtraAllowed(context: $0, at: now) }
        if let saved = try extraSession() { return saved }
        guard dailyLimit > 0, pairCount > 0, clozeCount > 0 else { throw LearningError.invalid("额外复习题量无效。") }
        let selected = try writer.read { context in Array(try extraEligible(in: context, at: now).prefix(min(dailyLimit, pairCount))).map { ($0.entryID, $0.lemma) } }
        guard !selected.isEmpty else { return nil }
        try await primeMeanings(selected, at: now)
        let id: String = try writer.write {
            let context = writer.context
            try requireExtraAllowed(context: context, at: now)
            if let pending = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { $0.purpose == "extra" && $0.completedAt == nil }) { return pending.sessionID }
            let chosen = Array(try extraEligible(in: context, at: now).prefix(min(dailyLimit, pairCount)))
            guard chosen.map(\.entryID) == selected.map(\.0) else { throw LearningError.invalid("词汇队列已变化，请重试额外复习。") }
            let session = ReviewSessionRecord(cycleID: UUID(), entries: chosen.map(\.entryID), at: now, limit: dailyLimit)
            session.purpose = "extra"; session.cycleID = "extra|" + session.sessionID
            context.insert(session); try insertExercises(session: session, chosen: chosen, clozeCount: clozeCount, context: context)
            return session.sessionID
        }
        return try extraSession(sessionID: id)
    }
    func extraScheduleFeedback(sessionID: String) throws -> [String] { try writer.read { try feedback(sessionID: sessionID, context: $0) } }

    /// Freeze legacy context once without changing answers, attempts, completion or scheduling.
    private func snapshotLegacyContexts(cycleID: UUID) throws {
        let needed = try writer.read { context in
            let ids = Set(try context.fetch(FetchDescriptor<ReviewSessionRecord>()).filter { $0.cycleID == cycleID.uuidString }.map(\.sessionID))
            return try context.fetch(FetchDescriptor<ReviewExerciseRecord>()).contains { ids.contains($0.sessionID) && $0.contextSnapshotVersion == nil }
        }
        guard needed else { return }
        try writer.write {
            let context = writer.context
            let ids = Set(try context.fetch(FetchDescriptor<ReviewSessionRecord>()).filter { $0.cycleID == cycleID.uuidString }.map(\.sessionID))
            let sources = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).sorted { ($0.createdAt, $0.contextID) < ($1.createdAt, $1.contextID) }
            for question in try context.fetch(FetchDescriptor<ReviewExerciseRecord>()) where ids.contains(question.sessionID) && question.contextSnapshotVersion == nil {
                question.sourceContext = question.stage == "cloze" ? sources.filter { $0.entryID == question.entryID }.compactMap { ClozeContext.safeSentence($0.sentence, answer: question.answer) }.first : nil
                question.contextSnapshotVersion = 1
            }
        }
    }
    @discardableResult func submit(cycleID: UUID, questionID: String, answer: String, reveal: Bool = false, hint: Bool = false, at now: Date) throws -> Bool {
        try submitSaved(cycleID: cycleID, extraSessionID: nil, questionID: questionID, answer: answer, reveal: reveal, hint: hint, at: now)
    }
    @discardableResult func submitExtra(sessionID: String, questionID: String, answer: String, reveal: Bool = false, hint: Bool = false, at now: Date) throws -> Bool {
        try submitSaved(cycleID: nil, extraSessionID: sessionID, questionID: questionID, answer: answer, reveal: reveal, hint: hint, at: now)
    }
    private func submitSaved(cycleID: UUID?, extraSessionID: String?, questionID: String, answer: String, reveal: Bool, hint: Bool, at now: Date) throws -> Bool {
        try writer.write {
            let context = writer.context
            if extraSessionID != nil { try requireExtraAllowed(context: context, at: now) }
            guard let session = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { record in
                if let cycleID { return record.cycleID == cycleID.uuidString && record.purpose != "extra" }
                return record.sessionID == extraSessionID && record.purpose == "extra"
            }) else { throw LearningError.invalid("复习会话不存在。") }
            let exercises = try validatedExercises(session, context: context)
            guard let question = exercises.first(where: { $0.exerciseID == questionID }) else { throw LearningError.invalid("题目不属于当前已保存会话。") }
            if question.completedAt != nil { return true }
            guard session.completedAt == nil, question.stage == "matching" || exercises.filter({ $0.stage == "matching" }).allSatisfy({ $0.completedAt != nil }) else { throw LearningError.invalid("请先完成连线阶段。") }
            let timestamp = max(now, session.updatedAt)
            if hint { question.usedHint = true; session.revision += 1; session.updatedAt = timestamp; return false }
            if question.stage == "matching", exercises.contains(where: { $0.stage == "matching" && $0.senseID == answer && $0.completedAt != nil }) {
                throw LearningError.invalid("此释义已完成配对，请选择未完成的释义。")
            }
            if reveal {
                question.revealed = true; session.revision += 1; session.updatedAt = timestamp
                return false
            }
            question.attempts += 1
            let correct = question.stage == "matching" ? answer == question.senseID : SpellingAnswerPolicy.accepts(answer, expected: question.answer, alternatives: question.acceptedAnswers ?? [])
            question.firstTryCorrect = question.attempts == 1 && correct && !question.usedHint && !question.revealed
            if correct { question.completedAt = timestamp; if question.revealed { question.correctionCompletedAt = timestamp } }
            session.revision += 1; session.updatedAt = timestamp
            if let cycleID {
                let snapshot = try snapshot(session, context: context)
                let result = try ReviewSessionResult.read(cycleID: cycleID, reader: TransactionSessionSnapshot(snapshot: snapshot), at: timestamp)
                var cycle = try cycleInContext(cycleID, context: context)
                try cycle.recordReviewProgress(result)
                try cycles.applyInTransaction(cycle, context: context)
            }
            if exercises.allSatisfy({ $0.completedAt != nil }) {
                let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
                let logs = try context.fetch(FetchDescriptor<ReviewLogRecord>())
                for entryID in session.selectedEntryIDs {
                    guard let state = states.first(where: { $0.entryID == entryID }), !logs.contains(where: { $0.eventID == "\(session.sessionID)|\(entryID)" }) else { throw PersistenceError.integrity("复习排程状态缺失或日志重复") }
                    let entryQuestions = exercises.filter { $0.entryID == entryID }
                    let grade: BasicReviewScheduler.Grade = entryQuestions.contains(where: \.revealed) ? .again : entryQuestions.allSatisfy(\.firstTryCorrect) ? .good : .hard
                    let memory = try FSRSScheduler.schedule(stability: state.stability ?? (state.repetitions > 0 ? Double(max(1, state.intervalDays)) : nil),
                        difficulty: state.difficulty ?? (state.repetitions > 0 ? 5 : nil),
                        elapsedDays: max(0, timestamp.timeIntervalSince(state.lastReviewedAt ?? timestamp) / 86400), grade: grade)
                    let interval = memory.intervalDays
                    state.stability = memory.stability; state.difficulty = memory.difficulty; state.retrievability = memory.retrievability
                    state.algorithmVersion = FSRSScheduler.version
                    state.cardState = grade == .again ? (state.repetitions == 0 || state.cardState == "learning" ? "learning" : "relearning") : "review"
                    state.againCount = (state.againCount ?? 0) + (grade == .again ? 1 : 0)
                    state.hardCount = (state.hardCount ?? 0) + (grade == .hard ? 1 : 0)
                    state.goodCount = (state.goodCount ?? 0) + (grade == .good ? 1 : 0)
                    state.lastGradeSource = extraSessionID == nil ? "matching-and-spelling" : "extra-matching-and-spelling"
                    let next = timestamp.addingTimeInterval(Double(interval) * 86400)
                    context.insert(ReviewLogRecord(sessionID: session.sessionID, entryID: entryID, grade: grade.rawValue, at: timestamp, previousDueAt: state.dueAt, nextDueAt: next))
                    state.dueAt = next; state.intervalDays = interval; state.repetitions += 1; state.lapses += grade == .again ? 1 : 0; state.lastReviewedAt = timestamp
                }
                session.completedAt = timestamp
            }
            return correct
        }
    }
    func scheduleFeedback(cycleID: UUID) throws -> [String] {
        try writer.read { context in
            guard let session = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { $0.cycleID == cycleID.uuidString }) else { return [] }
            return try feedback(sessionID: session.sessionID, context: context)
        }
    }
    private func feedback(sessionID: String, context: ModelContext) throws -> [String] {
            let entries = try context.fetch(FetchDescriptor<VocabularyEntryRecord>())
            return try context.fetch(FetchDescriptor<ReviewLogRecord>()).filter { $0.sessionID == sessionID }.sorted { $0.entryID < $1.entryID }.map { log in
                let lemma = entries.first { $0.entryID == log.entryID }?.lemma ?? "词条"
                let explanation = log.grade == "again" ? "已查看答案，安排重新学习" : log.grade == "hard" ? "有错误或使用提示，按 Hard 重新计算" : "两阶段首次正确，按 Good 重新计算"
                return "\(lemma) · \(log.grade.capitalized) · \(explanation)\n原定 \(log.previousDueAt.formatted(date: .abbreviated, time: .shortened)) → 下次复习 \(log.nextDueAt.formatted(date: .abbreviated, time: .shortened))"
            }
    }
    func savedSession(for cycleID: UUID, at timestamp: Date) throws -> SavedReviewSessionSnapshot {
        try writer.read { context in
            guard let record = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { $0.cycleID == cycleID.uuidString }) else { throw LearningError.invalid("没有已保存会话。") }
            return try snapshot(record, context: context)
        }
    }
    private func validatedExercises(_ session: ReviewSessionRecord, context: ModelContext) throws -> [ReviewExerciseRecord] {
        let exercises = try context.fetch(FetchDescriptor<ReviewExerciseRecord>()).filter { $0.sessionID == session.sessionID }
        let matching = exercises.filter { $0.stage == "matching" }, cloze = exercises.filter { $0.stage == "cloze" }
        guard !matching.isEmpty, (!cloze.isEmpty || session.clozeExclusionReason == "targets-under-three-letters" && matching.allSatisfy { $0.prompt.filter(\.isLetter).count < 3 }), Set(matching.map(\.entryID)) == Set(session.selectedEntryIDs),
              matching.count == session.selectedEntryIDs.count, Set(cloze.map(\.entryID)).isSubset(of: Set(session.selectedEntryIDs)),
              Set(exercises.map(\.exerciseID)).count == exercises.count,
              exercises.allSatisfy({ ["matching", "cloze"].contains($0.stage) && !$0.answer.isBlank && $0.attempts >= 0 }),
              cloze.allSatisfy({ $0.completedAt == nil }) || matching.allSatisfy({ $0.completedAt != nil }) else { throw PersistenceError.integrity("已保存题组不完整，不能伪造完成") }
        return exercises
    }
    private func snapshot(_ session: ReviewSessionRecord, context: ModelContext) throws -> SavedReviewSessionSnapshot {
        guard let cycleID = UUID(uuidString: session.cycleID), let sessionID = UUID(uuidString: session.sessionID) else { throw PersistenceError.integrity("会话身份无效") }
        let exercises = try validatedExercises(session, context: context)
        func ids(_ stage: String, answered: Bool) -> [String] { exercises.filter { $0.stage == stage && (!answered || $0.completedAt != nil) }.sorted { $0.position < $1.position }.map(\.exerciseID) }
        return SavedReviewSessionSnapshot(cycleID: cycleID, sessionID: sessionID, sourceRevision: "\(session.sessionID)|\(session.revision)",
            matchingQuestionIDs: ids("matching", answered: false), clozeQuestionIDs: ids("cloze", answered: false),
            matchingAnsweredIDs: ids("matching", answered: true), clozeAnsweredIDs: ids("cloze", answered: true), recordedAt: session.updatedAt, clozeExclusionReason: session.clozeExclusionReason)
    }
}
@MainActor private struct TransactionQueueSnapshot: ReviewQueueReading {
    let ids: [String], revision: String
    func eligibleQueue(for cycleID: UUID, at timestamp: Date) throws -> ReviewQueueSnapshot { ReviewQueueSnapshot(revision: revision, eligibleEntryIDs: ids, isComplete: true) }
}
@MainActor private struct TransactionSessionSnapshot: ReviewSessionReading {
    let snapshot: SavedReviewSessionSnapshot
    func savedSession(for cycleID: UUID, at timestamp: Date) throws -> SavedReviewSessionSnapshot { snapshot }
}

