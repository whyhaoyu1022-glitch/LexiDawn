import Foundation
import SwiftData

struct ReviewQuestion: Identifiable, Equatable {
    let id: String, entryID: String, stage: String, prompt: String, answer: String, senseID: String
    let attempts: Int
    let usedHint: Bool
    let completed: Bool
    var context: String? = nil
    var acceptedAnswers: [String] = []
}
struct ReviewSessionView: Equatable {
    let id: String
    let matching: [ReviewQuestion]
    let cloze: [ReviewQuestion]
    let completedAt: Date?
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
        let selected: [(String, String)] = try writer.read { context in
            Array(try eligible(in: context, at: now).prefix(min(dailyLimit, pairCount))).map { ($0.entryID, $0.lemma) }
        }
        // Resolve real dictionary data before entering the write transaction. Missing meanings block, never mean an empty queue.
        try await primeMeanings(selected, at: now)
        try writer.write {
            let context = writer.context
            var cycle = try cycleInContext(cycleID, context: context)
            if try context.fetch(FetchDescriptor<ReviewSessionRecord>()).contains(where: { $0.cycleID == cycleID.uuidString }) { return }
            let eligible = try eligible(in: context, at: now)
            if eligible.isEmpty {
                let reader = TransactionQueueSnapshot(ids: [], revision: fingerprint("complete|\(now.timeIntervalSince1970)"))
                try cycle.resolveEmptyReview(ReviewQueueEvidence.evaluate(cycleID: cycleID, reader: reader, at: max(now, cycle.createdAtUTC)))
                try cycles.applyInTransaction(cycle, context: context); return
            }
            let chosen = Array(eligible.prefix(min(dailyLimit, pairCount)))
            guard chosen.map(\.entryID) == selected.map(\.0) else { throw LearningError.invalid("词汇队列发生变化，请重新生成题组。") }
            let session = ReviewSessionRecord(cycleID: cycleID, entries: chosen.map(\.entryID), at: max(now, cycle.createdAtUTC), limit: dailyLimit)
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
                ReviewQuestion(id: exercise.exerciseID, entryID: exercise.entryID, stage: stage, prompt: exercise.prompt, answer: exercise.answer, senseID: exercise.senseID, attempts: exercise.attempts, usedHint: exercise.usedHint, completed: exercise.completedAt != nil, context: exercise.sourceContext, acceptedAnswers: exercise.acceptedAnswers ?? [exercise.answer])
            }
        }
        return ReviewSessionView(id: session.sessionID, matching: questions("matching"), cloze: questions("cloze"), completedAt: session.completedAt)
    }
    private func primeMeanings(_ selected: [(String, String)], at now: Date) async throws {
        for (id, lemma) in selected {
            let confirmed = try writer.read { context in try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first { $0.entryID == id }?.reviewMeaningText }
            if let confirmed, !confirmed.isBlank { continue }
            let personal = try writer.read { context in try context.fetch(FetchDescriptor<VocabularyEntryRecord>()).first { $0.entryID == id }?.userMeaning }
            if let personal, !personal.isBlank { continue }
            // The local Chinese source works offline. English-only providers cannot invent a Chinese answer.
            _ = try await dictionary.localResult(lemma, at: now)
            try Task.checkCancellation()
        }
    }
    private func insertExercises(session: ReviewSessionRecord, chosen: [VocabularyEntryRecord], clozeCount: Int, context: ModelContext) throws {
        let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
        let sources = try context.fetch(FetchDescriptor<VocabularySourceContextRecord>()).sorted { ($0.createdAt, $0.contextID) < ($1.createdAt, $1.contextID) }
        let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
        let providerCaches = try context.fetch(FetchDescriptor<DictionaryProviderCacheRecord>())
        let rankedSpelling = chosen.enumerated().sorted { a, b in
            let aLapses = states.first { $0.entryID == a.element.entryID }?.lapses ?? 0
            let bLapses = states.first { $0.entryID == b.element.entryID }?.lapses ?? 0
            let aScore = aLapses * 20 + (a.element.surfaceForms.map(\.count).max() ?? a.element.lemma.count)
            let bScore = bLapses * 20 + (b.element.surfaceForms.map(\.count).max() ?? b.element.lemma.count)
            return aScore == bScore ? a.offset < b.offset : aScore > bScore
        }
        let spellingIDs = Set(rankedSpelling.prefix(clozeCount).map { $0.element.entryID })
        var meanings = Set<String>()
        for (position, entry) in chosen.enumerated() {
            let source = sources.first { $0.entryID == entry.entryID }
            let available = senses.filter { $0.entryID == "cedict-reverse-v1|\(entry.lemma)" && !$0.chinese.isBlank && !meanings.contains($0.chinese) }
            let ranked = DictionaryAggregator.rank(available.map { DictionarySense(id: $0.senseID, en: $0.english, zh: $0.chinese, line: $0.sourceLine) }, context: source?.sentence ?? "", surface: entry.lemma)
            let meaning: String, senseID: String
            if let selectedID = entry.reviewMeaningSenseID {
                guard let selectedText = entry.reviewMeaningText, !selectedText.isBlank, entry.reviewMeaningEvidence?.isBlank == false, !meanings.contains(selectedText) else { throw LearningError.invalid("所选复习义项缺少原始证据或与本组其他释义重复，请重新选择义项或修改个人释义。") }
                meaning = selectedText; senseID = selectedID
            } else if let personal = entry.userMeaning, !personal.isBlank, !meanings.contains(personal) {
                meaning = personal; senseID = "user-meaning|\(entry.entryID)|\(fingerprint(personal))"
            } else if let sense = ranked.first { meaning = sense.zh; senseID = sense.id }
            else { throw LearningError.invalid("“\(entry.lemma)”暂无可用且不重复的中文配对义项。请在生词本添加明确标记的个人释义后重试；队列不会被当作空队列。") }
            meanings.insert(meaning)
            context.insert(ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "matching", position: position, prompt: entry.lemma, answer: meaning, senseID: senseID))
            if spellingIDs.contains(entry.entryID) {
                let projection = ClozeContext.make(lemma: entry.lemma, surfaces: source.map { [$0.surface] + entry.surfaceForms } ?? entry.surfaceForms, sentence: source?.sentence)
                let question = ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "cloze", position: position, prompt: BasicReviewScheduler.mask(projection.answer), answer: projection.answer, senseID: senseID)
                question.sourceContext = projection.sentence; context.insert(question)
                let originalSenses = providerCaches.filter { $0.lemma == entry.lemma && DictionaryAggregator.versions[$0.providerID] == $0.sourceVersion }.flatMap { (try? JSONDecoder().decode([DictionarySense].self, from: $0.payload)) ?? [] }
                question.acceptedAnswers = SpellingAnswerPolicy.variants(answer: projection.answer, lemma: entry.lemma, senses: originalSenses)
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
    func prepareExtra(dailyLimit: Int, pairCount: Int, clozeCount: Int, at now: Date) async throws -> ReviewSessionView? {
        try writer.read { try requireExtraAllowed(context: $0, at: now) }
        if let saved = try extraSession() { return saved }
        guard dailyLimit > 0, pairCount > 0, clozeCount > 0 else { throw LearningError.invalid("额外复习题量无效。") }
        let selected = try writer.read { context in Array(try eligible(in: context, at: now).prefix(min(dailyLimit, pairCount))).map { ($0.entryID, $0.lemma) } }
        guard !selected.isEmpty else { return nil }
        try await primeMeanings(selected, at: now)
        let id: String = try writer.write {
            let context = writer.context
            try requireExtraAllowed(context: context, at: now)
            if let pending = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { $0.purpose == "extra" && $0.completedAt == nil }) { return pending.sessionID }
            let chosen = Array(try eligible(in: context, at: now).prefix(min(dailyLimit, pairCount)))
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
            question.attempts += 1
            let correct = question.stage == "matching" ? answer == question.senseID : SpellingAnswerPolicy.accepts(answer, expected: question.answer, alternatives: question.acceptedAnswers ?? [])
            question.firstTryCorrect = question.attempts == 1 && correct && !question.usedHint && !reveal
            if correct || reveal { question.completedAt = timestamp; question.revealed = reveal }
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
                    state.algorithmVersion = FSRSScheduler.version; state.cardState = grade == .again ? "relearning" : "review"
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
            return correct || reveal
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
        guard !matching.isEmpty, !cloze.isEmpty, Set(matching.map(\.entryID)) == Set(session.selectedEntryIDs),
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
            matchingAnsweredIDs: ids("matching", answered: true), clozeAnsweredIDs: ids("cloze", answered: true), recordedAt: session.updatedAt)
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

