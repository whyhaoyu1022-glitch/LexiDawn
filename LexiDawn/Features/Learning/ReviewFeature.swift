import SwiftUI
import UIKit

struct ReviewPracticeView: View {
    @ObservedObject var learning: LearningServices
    var body: some View { NavigationStack { ReviewPracticeContent(learning: learning) } }
}
struct ReviewPracticeContent: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var learning: LearningServices
    @State private var cycleID: UUID?
    @State private var session: ReviewSessionView?
    @State private var selected: String?
    @State private var spelling = ""
    @State private var message: String?
    @State private var feedback: String?
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
                    Text("FSRS 4.5 · 两阶段首次正确为 Good；错误或提示为 Hard；显示答案为 Again。题组与下次时间在本地保存。").font(.caption).foregroundStyle(.secondary)
                }
                if loading { ProgressView("正在查询完整复习队列…") }
                else if let session {
                    if extraMode { Label("额外复习 · 不创建每日任务", systemImage: "plus.circle").font(.headline).accessibilityIdentifier("extra-review-label") }
                    if session.completedAt != nil {
                        ContentUnavailableView("本次复习已保存", systemImage: "checkmark.seal.fill", description: Text("作答、复习日志和下次时间已保存。生词本条目继续保留。")).accessibilityIdentifier("review-completed")
                    } else if !session.matchingComplete { matching(session) }
                    else {
                        DisclosureGroup("连线已完成 · 查看全部连接", isExpanded: $showCompletedMatches) { matching(session) }
                            .accessibilityIdentifier("show-completed-matches")
                        cloze(session)
                    }
                } else if emptyResolved { Label("完整队列中没有应复习词条，已记录合法空队列结果。", systemImage: "checkmark.circle") }
                else { Text("请先在今日页获得文章，并在阅读中积累词汇。") }
                ForEach(schedules, id: \.self) { Text($0).font(.footnote).accessibilityIdentifier("review-next-due") }
                if extraEmpty { Text("额外复习暂无到期词条，刚完成的题组不会立即重复。").font(.footnote) }
                if let feedback { Text(feedback).foregroundStyle(feedback == "正确，已保存" ? .green : .orange).accessibilityIdentifier("review-feedback") }
                Button("重新读取 / 重试", action: { Task { await load() } }).disabled(loading)
            }.padding(20)
        }.safeAreaPadding(.bottom, 52).scrollDismissesKeyboard(.interactively).navigationTitle("复习").navigationBarTitleDisplayMode(.inline).task { await load() }
            .onChange(of: feedback) { _, message in if let message { UIAccessibility.post(notification: .announcement, argument: message) } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
    }
    private func matching(_ session: ReviewSessionView) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1 · 连线 \(session.matching.filter(\.completed).count)/\(session.matching.count)").font(.headline)
            Text(verticalSizeClass == .compact ? "先点英文，再点中文；完成的两端均不可再选。" : "先点英文，再点对应中文。中文来自开放词典的可能对应词或你的个人释义。")
            MatchingBoard(session: session, selected: $selected, submit: { questionID, senseID in
                if submit(questionID: questionID, answer: senseID) { selected = nil }
            }, noSelection: { feedback = "请先选择英文词条" })
        }
    }
    @ViewBuilder private func cloze(_ session: ReviewSessionView) -> some View {
        if let question = session.cloze.first(where: { !$0.completed }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("2 · 拼写 \(session.cloze.filter(\.completed).count)/\(session.cloze.count)").font(.headline)
                if let sentence = question.context {
                    Text(maskedContext(sentence, answer: question.answer)).font(.body).accessibilityIdentifier("cloze-context")
                }
                Text(question.prompt).font(.largeTitle.monospaced()).accessibilityIdentifier("cloze-prompt")
                if let meaning = session.matching.first(where: { $0.entryID == question.entryID })?.answer { Text(meaning).font(.headline) }
                Text("输入完整英文词条，大小写不影响判定。")
                if question.acceptedAnswers.count > 1 { Text("本题接受词典明确标注的英美拼写变体。").font(.caption).foregroundStyle(.secondary) }
                TextField("完整拼写", text: $spelling).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("cloze-answer").submitLabel(.done).onSubmit { if submit(questionID: question.id, answer: spelling) { spelling = "" } }
                Button("提交答案") { if submit(questionID: question.id, answer: spelling) { spelling = "" } }.buttonStyle(.borderedProminent).accessibilityIdentifier("submit-spelling")
                HStack {
                    Button("使用提示") { if submit(questionID: question.id, answer: "", hint: true) { feedback = "首字母：\(question.answer.first.map(String.init) ?? "")；提示使用已保存" } }
                    Button("忘记了，显示答案") { if submit(questionID: question.id, answer: "", reveal: true) { feedback = "答案：\(question.answer)。本题记录为 Again。" } }
                }.font(.footnote)
            }
        }
    }
    private func maskedContext(_ sentence: String, answer: String) -> String {
        ClozeContext.mask(sentence, answer: answer)
    }
    private func load() async {
        let generation = UUID(); loadGeneration = generation
        loading = true; message = nil; selected = nil; spelling = ""; feedback = nil; emptyResolved = false; session = nil; schedules = []; extraMode = false; extraEmpty = false; showCompletedMatches = false
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
            if prepared?.completedAt != nil || emptyResolved {
                let extra = try await learning.review.prepareExtra(dailyLimit: prefs.dailyReviewLimit, pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
                guard generation == loadGeneration, !Task.isCancelled else { return }
                if let extra { session = extra; extraMode = true; emptyResolved = false; schedules = try learning.review.extraScheduleFeedback(sessionID: extra.id) }
                else { extraEmpty = true }
            }
            learning.changed()
        } catch { self.message = error.localizedDescription }
        loading = false
    }
    @discardableResult private func submit(questionID: String, answer: String, reveal: Bool = false, hint: Bool = false) -> Bool {
        guard let cycleID else { return false }
        feedback = nil
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
            feedback = correct ? "正确，已保存" : hint ? "提示使用已记录" : "还不正确，请再试一次（尝试次数已保存）"
            learning.changed(); message = nil
            return true
        } catch { message = error.localizedDescription; return false }
    }
}

