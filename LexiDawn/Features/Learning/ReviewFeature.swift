import SwiftUI

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
    @State private var emptyResolved = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("把刚认识的词，变成自己的词").font(.title2.bold())
                Text("基础间隔排程 v1 · 不是 FSRS。题组建立后固定，退出后继续原题。").font(.caption).foregroundStyle(.secondary)
                if loading { ProgressView("正在查询完整复习队列…") }
                else if let session {
                    if session.completedAt != nil {
                        ContentUnavailableView("本次复习已保存", systemImage: "checkmark.seal.fill", description: Text("作答、复习日志和下次时间已保存。生词本条目继续保留。"))
                    } else if !session.matchingComplete { matching(session) }
                    else { cloze(session) }
                } else if emptyResolved { Label("完整队列中没有应复习词条，已记录合法空队列结果。", systemImage: "checkmark.circle") }
                else { Text("请先在今日页获得文章，并在阅读中积累词汇。") }
                if let feedback { Text(feedback).foregroundStyle(feedback == "正确，已保存" ? .green : .orange).accessibilityIdentifier("review-feedback") }
                if let message { Text(message).foregroundStyle(.red) }
                Button("重新读取 / 重试", action: { Task { await load() } }).disabled(loading)
            }.padding(20)
        }.navigationTitle("复习").task { await load() }
    }
    private func matching(_ session: ReviewSessionView) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1 · 连线 \(session.matching.filter(\.completed).count)/\(session.matching.count)").font(.headline)
            Text("先点英文，再点对应中文。中文来自开放词典的可能对应词或你的个人释义。")
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    ForEach(session.matching) { question in
                        Button { selected = question.id } label: {
                            Text(question.completed ? "✓ \(question.prompt)" : question.prompt).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.bordered).tint(selected == question.id ? .orange : .accentColor).disabled(question.completed)
                            .accessibilityIdentifier("match-word-\(question.prompt)")
                    }
                }
                VStack(spacing: 12) {
                    ForEach(session.matching.sorted { fingerprint(session.id + $0.senseID) < fingerprint(session.id + $1.senseID) }) { option in
                        Button {
                            guard let selected else { feedback = "请先选择英文词条"; return }
                            submit(questionID: selected, answer: option.senseID)
                            self.selected = nil
                        } label: { Text(option.answer).frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.bordered).accessibilityIdentifier("match-meaning-\(option.answer)")
                    }
                }
            }
        }
    }
    @ViewBuilder private func cloze(_ session: ReviewSessionView) -> some View {
        if let question = session.cloze.first(where: { !$0.completed }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("2 · 拼写 \(session.cloze.filter(\.completed).count)/\(session.cloze.count)").font(.headline)
                Text(question.prompt).font(.largeTitle.monospaced()).accessibilityIdentifier("cloze-prompt")
                Text("输入完整英文词条，大小写不影响判定。")
                TextField("完整拼写", text: $spelling).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("cloze-answer")
                Button("提交答案") { submit(questionID: question.id, answer: spelling); spelling = "" }.buttonStyle(.borderedProminent).accessibilityIdentifier("submit-spelling")
                HStack {
                    Button("使用提示") { submit(questionID: question.id, answer: "", hint: true); feedback = "首字母：\(question.answer.first.map(String.init) ?? "")；本题将记为使用提示" }
                    Button("忘记了，显示答案") { submit(questionID: question.id, answer: "", reveal: true); feedback = "答案：\(question.answer)。本题记录为 Again。" }
                }.font(.footnote)
            }
        }
    }
    private func load() async {
        loading = true; message = nil
        do {
            let cycles = try learning.cycles.fetchAll()
            guard let cycle = cycles.first(where: \.hasOutstandingWork) ?? cycles.last else { session = nil; loading = false; return }
            cycleID = cycle.cycleID
            let prefs = try dependencies.preferencesRepository.load()
            session = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: prefs.dailyReviewLimit,
                pairCount: prefs.matchingPairCount, clozeCount: prefs.clozeQuestionCount, at: Date())
            let restoredCycle = try learning.cycles.fetch(by: cycle.cycleID)
            emptyResolved = session == nil && restoredCycle?.reviewEvidence != nil
            learning.changed()
        } catch { self.message = error.localizedDescription }
        loading = false
    }
    private func submit(questionID: String, answer: String, reveal: Bool = false, hint: Bool = false) {
        guard let cycleID else { return }
        do {
            let correct = try learning.review.submit(cycleID: cycleID, questionID: questionID, answer: answer, reveal: reveal, hint: hint, at: Date())
            session = try learning.review.session(cycleID: cycleID)
            feedback = correct ? "正确，已保存" : hint ? "提示使用已记录" : "还不正确，请再试一次（尝试次数已保存）"
            learning.changed(); message = nil
        } catch { message = error.localizedDescription }
    }
}
