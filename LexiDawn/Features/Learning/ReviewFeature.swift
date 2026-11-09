import SwiftUI
import UIKit

enum ReviewAnswerPhase: String { case answering, submitting, incorrect, hinted, revealedAwaitingCorrection, answered, saveFailed, completed }
struct ReviewFeedbackIdentity: Equatable {
    let sessionID: String
    let questionID: String
    let attemptID: UUID
    let revision: Int
}

struct ReviewPracticeView: View {
    @ObservedObject var learning: LearningServices
    var returnToday: (() -> Void)? = nil
    var body: some View { NavigationStack { ReviewPracticeContent(learning: learning, returnToday: returnToday) } }
}
struct ReviewPracticeContent: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var learning: LearningServices
    var returnToday: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var cycleID: UUID?
    @State private var session: ReviewSessionView?
    @State private var selected: String?
    @State private var spelling = ""
    @State private var message: String?
    @State private var feedback: String?
    @State private var feedbackFor: String?
    @State private var feedbackIdentity: ReviewFeedbackIdentity?
    @State private var answerPhase = ReviewAnswerPhase.answering
    @StateObject private var entryGate = ReviewEntryCoordinator()
    @State private var deferredResolved = false
    @State private var loading = false
    @State private var schedules: [String] = []
    @State private var emptyResolved = false
    @State private var extraMode = false
    @State private var extraEmpty = false
    @State private var showCompletedMatches = false
    @State private var loadGeneration = UUID()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let message { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).accessibilityIdentifier("review-storage-error") }
                if verticalSizeClass != .compact {
                    Text("把刚认识的词，变成自己的词").font(.title2.bold())
                    Text("先连线，再拼写。让每个词在熟悉的句子里留下来。").font(.caption).foregroundStyle(.secondary)
                }
                if loading { ProgressView("正在查询完整复习队列…") }
                else if let session {
                    if extraMode { Label("额外复习 · 不创建每日任务", systemImage: "plus.circle").font(.headline).accessibilityIdentifier("extra-review-label") }
                    if session.completedAt != nil {
                        ContentUnavailableView("本次复习已保存", systemImage: "checkmark.seal.fill", description: Text("完成 \(session.matching.filter(\.completed).count) 个词 · 延期 \(session.deferredCount) 个词")).accessibilityIdentifier("review-completed")
                        HStack {
                            Button("返回") { if let returnToday { returnToday() } else { dismiss() } }.buttonStyle(.bordered)
                            Button("继续") { Task { await load() } }.buttonStyle(.borderedProminent)
                        }.frame(maxWidth: .infinity)
                    } else if !session.matchingComplete { matching(session) }
                    else {
                        Button { showCompletedMatches.toggle() } label: {
                            Label("连线已完成 · 查看全部连接", systemImage: showCompletedMatches ? "chevron.up" : "chevron.down")
                        }.accessibilityIdentifier("show-completed-matches").accessibilityValue(showCompletedMatches ? "已展开" : "已收起")
                        if showCompletedMatches { matching(session) }
                        cloze(session)
                    }
                } else if emptyResolved { Label(deferredResolved ? "本组已按你的选择延期，未计作答对。" : "今天没有到期词汇。", systemImage: "checkmark.circle") }
                else if message == nil { Text("从今日文章里，积累第一个词。").foregroundStyle(.secondary) }
                if session?.completedAt != nil, !schedules.isEmpty {
                    DisclosureGroup("查看本次复习记录") { ForEach(schedules, id: \.self) { Text($0).font(.footnote).accessibilityIdentifier("review-next-due") } }
                }
                if extraEmpty { Text("额外复习暂无到期词条，刚完成的题组不会立即重复。").font(.footnote) }
                if message != nil { Button("重试", action: { Task { await load() } }).buttonStyle(.bordered).disabled(loading) }
            }.padding(20)
        }.safeAreaPadding(.bottom, 16).scrollDismissesKeyboard(.interactively).navigationTitle("复习").navigationBarTitleDisplayMode(.inline).task { await load() }
            .reviewEntryGate(entryGate, learning: learning)
            .onChange(of: selected) { _, _ in feedback = nil; feedbackFor = nil }
            .onChange(of: activeQuestionKey) { _, _ in spelling = ""; feedback = nil; feedbackFor = nil; feedbackIdentity = nil; answerPhase = restoredPhase }
            .onChange(of: feedback) { _, message in if let message { UIAccessibility.post(notification: .announcement, argument: message) } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
    }
    private var activeQuestionKey: String {
        guard let session else { return "" }
        return session.id + "|" + (session.cloze.first(where: { !$0.completed })?.id ?? "completed")
    }
    private var restoredPhase: ReviewAnswerPhase {
        if session?.completedAt != nil { return .completed }
        return session?.cloze.first(where: { !$0.completed })?.revealed == true ? .revealedAwaitingCorrection : .answering
    }
    private func feedbackBelongs(to questionID: String, in session: ReviewSessionView) -> Bool {
        feedbackIdentity?.sessionID == session.id && feedbackIdentity?.questionID == questionID && feedbackIdentity?.revision == session.revision
    }
    private func matching(_ session: ReviewSessionView) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1 · 连线 \(session.matching.filter(\.completed).count)/\(session.matching.count)").font(.headline)
            Text(verticalSizeClass == .compact ? "先点英文，再点中文；完成的两端均不可再选。" : "先点英文，再点对应中文。已完成的连接会保留。")
            MatchingBoard(session: session, selected: $selected, submit: { questionID, senseID in
                if submit(questionID: questionID, answer: senseID) { selected = nil }
            }, noSelection: { feedbackFor = nil; feedback = "请先选择英文词条" })
            if let feedback, let selected, feedbackFor == selected, feedbackBelongs(to: selected, in: session) { Label(feedback, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("review-feedback") }
        }
    }
    @ViewBuilder private func cloze(_ session: ReviewSessionView) -> some View {
        if let question = session.cloze.first(where: { !$0.completed }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("2 · 拼写 \(session.cloze.filter(\.completed).count)/\(session.cloze.count)").font(.headline)
                if let sentence = question.context {
                    Text(question.contextOrigin == "personal-example" ? "个人例句" : question.contextOrigin == "dictionary" ? "词典例句" : "保存的原句").font(.caption).foregroundStyle(.secondary)
                    Text(maskedContext(sentence, answer: question.answer)).font(.body).accessibilityIdentifier("cloze-context")
                }
                Text(question.prompt).font(.largeTitle.monospaced()).accessibilityIdentifier("cloze-prompt")
                if let meaning = session.matching.first(where: { $0.entryID == question.entryID })?.answer { Text(meaning).font(.headline) }
                if question.revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("答案：" + question.answer).font(.title3.weight(.medium))
                        Text("亲自正确输入一次后继续 · 本题仍计 Again").font(.caption).foregroundStyle(.secondary)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("cloze-correction-required")
                } else { Text("输入原句中的完整词形").font(.subheadline).foregroundStyle(.secondary) }
                if let feedback, feedbackFor == question.id, feedbackBelongs(to: question.id, in: session) { Label(feedback, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("review-feedback") }
                if question.acceptedAnswers.count > 1 { Text("本题接受词典明确标注的英美拼写变体。").font(.caption).foregroundStyle(.secondary) }
                TextField("完整拼写", text: $spelling).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("cloze-answer").submitLabel(.done).onSubmit { if submit(questionID: question.id, answer: spelling) { spelling = "" } }
                Button("提交答案") { if submit(questionID: question.id, answer: spelling) { spelling = "" } }.buttonStyle(.borderedProminent).accessibilityIdentifier("submit-spelling")
                HStack {
                    Button("首字母提示") { _ = submit(questionID: question.id, answer: "", hint: true) }
                    Button("显示答案") { _ = submit(questionID: question.id, answer: "", reveal: true) }.disabled(question.revealed)
                }.font(.footnote).buttonStyle(.bordered)
            }
        }
    }
    private func maskedContext(_ sentence: String, answer: String) -> String {
        ClozeContext.mask(sentence, answer: answer)
    }
    private func load() async {
        let generation = UUID(); loadGeneration = generation
        loading = true; message = nil; selected = nil; spelling = ""; feedback = nil; feedbackFor = nil; emptyResolved = false; schedules = []; extraMode = false; extraEmpty = false; showCompletedMatches = false
        feedbackIdentity = nil; answerPhase = .answering
        defer { if loadGeneration == generation { loading = false } }
        do {
            let cycles = try learning.cycles.fetchAll()
            guard let cycle = cycles.first(where: \.hasOutstandingWork) ?? cycles.last else { session = nil; loading = false; return }
            cycleID = cycle.cycleID
            let prefs = try dependencies.preferencesRepository.load()
            let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: prefs.dailyReviewLimit,
                pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
            guard generation == loadGeneration, !Task.isCancelled else { return }
            session = prepared
            schedules = try learning.review.scheduleFeedback(cycleID: cycle.cycleID)
            let restoredCycle = try learning.cycles.fetch(by: cycle.cycleID)
            emptyResolved = session == nil && restoredCycle?.reviewEvidence != nil
            deferredResolved = restoredCycle?.reviewEvidence?.isUserDeferral == true
            if prepared?.completedAt != nil || emptyResolved {
                let extra = try await learning.review.prepareExtra(dailyLimit: prefs.dailyReviewLimit, pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
                guard generation == loadGeneration, !Task.isCancelled else { return }
                if let extra { session = extra; extraMode = true; emptyResolved = false; schedules = try learning.review.extraScheduleFeedback(sessionID: extra.id) }
                else { extraEmpty = true }
            }
            answerPhase = restoredPhase
            learning.changed()
        } catch { self.message = error.localizedDescription; entryGate.adopt(error, cycleID: cycleID, completion: { Task { await load() } }) }
        loading = false
    }
    @discardableResult private func submit(questionID: String, answer: String, reveal: Bool = false, hint: Bool = false) -> Bool {
        guard let cycleID else { return false }
        guard answerPhase != .submitting, let currentSession = session else { return false }
        let attempt = UUID(); answerPhase = .submitting
        feedbackIdentity = ReviewFeedbackIdentity(sessionID: currentSession.id, questionID: questionID, attemptID: attempt, revision: currentSession.revision)
        feedback = nil; feedbackFor = questionID
        do {
            let correct: Bool
            if extraMode, let saved = session {
                correct = try learning.review.submitExtra(sessionID: saved.id, questionID: questionID, answer: answer, reveal: reveal, hint: hint, at: Date())
                session = try learning.review.extraSession(sessionID: saved.id)
                schedules = try learning.review.extraScheduleFeedback(sessionID: saved.id)
            } else {
                correct = try learning.review.submit(cycleID: cycleID, questionID: questionID, answer: answer, reveal: reveal, hint: hint, at: Date())
                session = try learning.review.session(cycleID: cycleID)
                schedules = try learning.review.scheduleFeedback(cycleID: cycleID)
            }
            feedback = correct ? nil : reveal ? "请按显示答案亲自输入一次" : hint ? "首字母：" + (session?.cloze.first { $0.id == questionID }?.answer.first.map(String.init) ?? "") : "还不正确，请再试一次"
            if let saved = session {
                feedbackIdentity = ReviewFeedbackIdentity(sessionID: saved.id, questionID: questionID, attemptID: attempt, revision: saved.revision)
                answerPhase = saved.completedAt != nil ? .completed : correct ? .answered : reveal ? .revealedAwaitingCorrection : hint ? .hinted : .incorrect
            }
            learning.changed(); message = nil
            return correct
        } catch { feedback = nil; answerPhase = .saveFailed; message = error.localizedDescription; return false }
    }
}


struct ReviewEntryProblem: Identifiable {
    let id = UUID()
    let message: String
    let issue: ReviewMeaningIssue?
}
@MainActor final class ReviewEntryCoordinator: ObservableObject {
    @Published var busy = false
    @Published var problem: ReviewEntryProblem?
    @Published var editingWord: VocabularyItem?
    @Published var confirmAll = false
    @Published var pendingDeferral: ReviewMeaningIssue?
    private var cycleID: UUID?
    private var generation = UUID()
    private var ready: (() -> Void)?
    private(set) var extra = false
    func cancel() { generation = UUID(); busy = false; problem = nil; ready = nil }
    func open(dependencies: AppDependencies, learning: LearningServices, onReady: @escaping () -> Void) async {
        guard !busy else { return }
        ready = onReady; await retry(dependencies: dependencies, learning: learning)
    }
    func adopt(_ error: Error, cycleID: UUID?, completion: @escaping () -> Void) {
        self.cycleID = cycleID; ready = completion
        problem = ReviewEntryProblem(message: error.localizedDescription, issue: error as? ReviewMeaningIssue)
    }
    func retry(dependencies: AppDependencies, learning: LearningServices) async {
        let token = UUID(); generation = token; busy = true; problem = nil
        defer { if token == generation { busy = false } }
        do {
            let all = try learning.cycles.fetchAll()
            guard let cycle = all.first(where: \.hasOutstandingWork) ?? all.last else { ready?(); return }
            cycleID = cycle.cycleID; extra = cycle.reviewTaskStatus == .completed || cycle.reviewTaskStatus == .deferred
            let prefs = try dependencies.preferencesRepository.load()
            let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: prefs.dailyReviewLimit, pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
            let current = try learning.cycles.fetch(by: cycle.cycleID)
            if prepared?.completedAt != nil || current?.reviewEvidence != nil {
                _ = try await learning.review.prepareExtra(dailyLimit: prefs.dailyReviewLimit, pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
            }
            guard generation == token, !Task.isCancelled else { return }
            learning.changed(); ready?()
        } catch is CancellationError { }
        catch { if generation == token { problem = ReviewEntryProblem(message: error.localizedDescription, issue: error as? ReviewMeaningIssue) } }
    }
    func edit(_ issue: ReviewMeaningIssue, learning: LearningServices) {
        do {
            guard issue.canEditPersonal else { return }
            editingWord = try learning.vocabulary.entries().first { $0.id == issue.entryID }
            if editingWord == nil { throw LearningError.invalid("词条已移除，请重新检查复习队列。") }
            problem = nil
        } catch { problem = ReviewEntryProblem(message: error.localizedDescription, issue: nil) }
    }
    func requestDeferral(_ issue: ReviewMeaningIssue, dependencies: AppDependencies, learning: LearningServices) async {
        do {
            guard let cycleID else { return }
            if try learning.review.remainingPreparationCount(cycleID: cycleID) == 1 { pendingDeferral = issue; confirmAll = true }
            else { await deferWord(issue, dependencies: dependencies, learning: learning) }
        } catch { problem = ReviewEntryProblem(message: error.localizedDescription, issue: nil) }
    }
    func deferWord(_ issue: ReviewMeaningIssue, dependencies: AppDependencies, learning: LearningServices) async {
        do {
            guard let cycleID else { return }
            try learning.review.deferEntry(cycleID: cycleID, issue: issue, at: Date())
            problem = nil; pendingDeferral = nil
            await retry(dependencies: dependencies, learning: learning)
        } catch { problem = ReviewEntryProblem(message: error.localizedDescription, issue: nil) }
    }
}
struct ReviewEntryPresentation: ViewModifier {
    @ObservedObject var gate: ReviewEntryCoordinator
    @ObservedObject var learning: LearningServices
    @EnvironmentObject private var dependencies: AppDependencies
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if gate.busy { HStack { ProgressView(); Text("正在准备复习…").font(.subheadline); Spacer(); Button("取消", action: gate.cancel) }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding() }
            }
            .alert("复习还未准备好", isPresented: Binding(get: { gate.problem != nil }, set: { if !$0 { gate.problem = nil } }), presenting: gate.problem) { value in
                Button("取消", role: .cancel, action: gate.cancel)
                if let issue = value.issue {
                    if issue.canEditPersonal { Button("立即填写") { gate.edit(issue, learning: learning) } }
                    if !gate.extra { Button("本次延期该词") { Task { await gate.requestDeferral(issue, dependencies: dependencies, learning: learning) } } }
                }
                Button("重试") { Task { await gate.retry(dependencies: dependencies, learning: learning) } }
            } message: { value in Text(value.message) }
            .confirmationDialog("确认本组全部延期？", isPresented: $gate.confirmAll, presenting: gate.pendingDeferral) { issue in
                Button("确认本组全部延期") { Task { await gate.deferWord(issue, dependencies: dependencies, learning: learning) } }
                Button("取消", role: .cancel) { gate.pendingDeferral = nil }
            } message: { _ in Text("不会记录为答对，也不更新这些词的复习排程；生词和历史保留。") }
            .sheet(item: $gate.editingWord, onDismiss: { Task { await gate.retry(dependencies: dependencies, learning: learning) } }) { item in
                NavigationStack { VocabularyDetailView(item: item, learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回复习") { gate.editingWord = nil } } } }
            }
    }
}
extension View {
    func reviewEntryGate(_ gate: ReviewEntryCoordinator, learning: LearningServices) -> some View { modifier(ReviewEntryPresentation(gate: gate, learning: learning)) }
}
