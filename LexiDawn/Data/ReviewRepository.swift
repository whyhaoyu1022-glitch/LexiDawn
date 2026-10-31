import Foundation
import SwiftData

struct ReviewQuestion: Identifiable, Equatable {
    let id: String, entryID: String, stage: String, prompt: String, answer: String, senseID: String
    let attempts: Int
    let usedHint: Bool
    let completed: Bool
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
                  state.repetitions >= 0, state.intervalDays >= 0, state.algorithmVersion == BasicReviewScheduler.version else {
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
        if let saved = try session(cycleID: cycleID) { return saved }
        let cycle = try writer.read { try cycleInContext(cycleID, context: $0) }
        if cycle.reviewEvidence != nil { return nil }
        guard dailyLimit > 0, pairCount > 0, clozeCount > 0 else { throw LearningError.invalid("复习题量设置无效。") }
        let selected: [(String, String)] = try writer.read { context in
            Array(try eligible(in: context, at: now).prefix(min(dailyLimit, pairCount))).map { ($0.entryID, $0.lemma) }
        }
        // Resolve real dictionary data before entering the write transaction. Missing meanings block, never mean an empty queue.
        for (_, lemma) in selected { _ = try await dictionary.lookup(lemma, at: now) }
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
            let senses = try context.fetch(FetchDescriptor<DictionarySenseRecord>())
            var meanings = Set<String>()
            var resolved: [(VocabularyEntryRecord, String, String)] = []
            for entry in chosen {
                if let personal = entry.userMeaning, !personal.isBlank, !meanings.contains(personal) {
                    meanings.insert(personal); resolved.append((entry, personal, "user-meaning|\(entry.entryID)|\(fingerprint(personal))"))
                } else if let sense = senses.filter({ $0.entryID == "cedict-reverse-v1|\(entry.lemma)" && !meanings.contains($0.chinese) }).sorted(by: { $0.senseID < $1.senseID }).first {
                    meanings.insert(sense.chinese); resolved.append((entry, sense.chinese, sense.senseID))
                } else {
                    throw LearningError.invalid("“\(entry.lemma)”暂无可用且不重复的中文配对义项。请在生词本添加明确标记的个人释义后重试；队列不会被当作空队列。")
                }
            }
            let session = ReviewSessionRecord(cycleID: cycleID, entries: chosen.map(\.entryID), at: max(now, cycle.createdAtUTC), limit: dailyLimit)
            context.insert(session)
            for (position, value) in resolved.enumerated() {
                let (entry, meaning, senseID) = value
                context.insert(ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "matching", position: position,
                    prompt: entry.lemma, answer: meaning, senseID: senseID))
                if position < clozeCount {
                    context.insert(ReviewExerciseRecord(sessionID: session.sessionID, entryID: entry.entryID, stage: "cloze", position: position,
                        prompt: BasicReviewScheduler.mask(entry.lemma), answer: entry.lemma, senseID: senseID))
                }
            }
        }
        return try session(cycleID: cycleID)
    }
    func session(cycleID: UUID) throws -> ReviewSessionView? {
        try writer.read { context in
            let records = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).filter { $0.cycleID == cycleID.uuidString }
            guard records.count <= 1 else { throw PersistenceError.integrity("一个周期存在多个必做复习会话") }
            guard let session = records.first else { return nil }
            let exercises = try validatedExercises(session, context: context)
            func questions(_ stage: String) -> [ReviewQuestion] {
                exercises.filter { $0.stage == stage }.sorted { $0.position < $1.position }.map {
                    ReviewQuestion(id: $0.exerciseID, entryID: $0.entryID, stage: stage, prompt: $0.prompt, answer: $0.answer, senseID: $0.senseID,
                                   attempts: $0.attempts, usedHint: $0.usedHint, completed: $0.completedAt != nil)
                }
            }
            return ReviewSessionView(id: session.sessionID, matching: questions("matching"), cloze: questions("cloze"), completedAt: session.completedAt)
        }
    }
    @discardableResult func submit(cycleID: UUID, questionID: String, answer: String, reveal: Bool = false, hint: Bool = false, at now: Date) throws -> Bool {
        try writer.write {
            let context = writer.context
            guard let session = try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first(where: { $0.cycleID == cycleID.uuidString }) else { throw LearningError.invalid("复习会话不存在。") }
            let exercises = try validatedExercises(session, context: context)
            guard let question = exercises.first(where: { $0.exerciseID == questionID }) else { throw LearningError.invalid("题目不属于当前已保存会话。") }
            if question.completedAt != nil { return true }
            guard session.completedAt == nil, question.stage == "matching" || exercises.filter({ $0.stage == "matching" }).allSatisfy({ $0.completedAt != nil }) else { throw LearningError.invalid("请先完成连线阶段。") }
            let timestamp = max(now, session.updatedAt)
            if hint { question.usedHint = true; session.revision += 1; session.updatedAt = timestamp; return false }
            question.attempts += 1
            let correct = question.stage == "matching" ? answer == question.senseID : EnglishTokenizer.normalized(answer) == EnglishTokenizer.normalized(question.answer)
            question.firstTryCorrect = question.attempts == 1 && correct && !question.usedHint && !reveal
            if correct || reveal { question.completedAt = timestamp; question.revealed = reveal }
            session.revision += 1; session.updatedAt = timestamp
            let snapshot = try snapshot(session, context: context)
            let result = try ReviewSessionResult.read(cycleID: cycleID, reader: TransactionSessionSnapshot(snapshot: snapshot), at: timestamp)
            var cycle = try cycleInContext(cycleID, context: context)
            try cycle.recordReviewProgress(result)
            if result.isComplete {
                let states = try context.fetch(FetchDescriptor<ReviewStateRecord>())
                let logs = try context.fetch(FetchDescriptor<ReviewLogRecord>())
                for entryID in session.selectedEntryIDs {
                    guard let state = states.first(where: { $0.entryID == entryID }), !logs.contains(where: { $0.eventID == "\(session.sessionID)|\(entryID)" }) else { throw PersistenceError.integrity("复习排程状态缺失或日志重复") }
                    let entryQuestions = exercises.filter { $0.entryID == entryID }
                    let grade: BasicReviewScheduler.Grade = entryQuestions.contains(where: \.revealed) ? .again : entryQuestions.allSatisfy(\.firstTryCorrect) ? .good : .hard
                    let interval = BasicReviewScheduler.interval(previous: state.intervalDays, grade: grade)
                    let next = timestamp.addingTimeInterval(Double(interval) * 86400)
                    context.insert(ReviewLogRecord(sessionID: session.sessionID, entryID: entryID, grade: grade.rawValue, at: timestamp, previousDueAt: state.dueAt, nextDueAt: next))
                    state.dueAt = next; state.intervalDays = interval; state.repetitions += 1; state.lapses += grade == .again ? 1 : 0; state.lastReviewedAt = timestamp
                }
                session.completedAt = timestamp
            }
            try cycles.applyInTransaction(cycle, context: context)
            return correct || reveal
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
