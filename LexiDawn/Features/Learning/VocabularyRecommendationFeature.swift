import SwiftUI

@MainActor final class VocabularyRecommendationModel: ObservableObject {
    @Published var items: [RecommendedVocabulary] = []
    @Published var loading = false
    @Published var allowed = false
    @Published var error: String?
    @Published var saved: Set<String> = []
    private var generation = UUID()
    func refreshMembership(_ learning: LearningServices) {
        do { saved = Set(try learning.vocabulary.entries().map(\.lemma)); allowed = try learning.explorationAllowed() }
        catch { self.error = error.localizedDescription; allowed = false }
    }
    func load(_ learning: LearningServices) async {
        let request = UUID(); generation = request; items = []; error = nil; loading = true
        defer { if generation == request { loading = false } }
        refreshMembership(learning); guard allowed else { return }
        do {
            _ = try await learning.recommendationService().discover { value in
                if request == self.generation && !Task.isCancelled { self.items.append(value) }
            }
        } catch is CancellationError { }
        catch { if generation == request { self.error = error.localizedDescription } }
    }
    func add(_ item: RecommendedVocabulary, learning: LearningServices) {
        do {
            guard try learning.explorationAllowed() else { throw LearningError.invalid("请先完成当前必做任务。") }
            let token = EnglishToken(surface: item.candidate.surface, range: item.candidate.range, sentence: item.candidate.sentence)
            _ = try learning.vocabulary.add(token: token, articleID: item.candidate.articleID, autoAdd: false, explicit: true, at: Date())
            learning.changed(); refreshMembership(learning); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct VocabularyRecommendationView: View {
    @ObservedObject var learning: LearningServices
    let continueToday: () -> Void
    @StateObject private var model = VocabularyRecommendationModel()
    @State private var retry = 0
    var body: some View {
        List {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"]?.hasPrefix("round3-recommendations-") == true { Text("明确词汇推荐测试夹具：Provider状态注入，非生产联网结果。").font(.caption) }
            #endif
            if !model.allowed {
                Section {
                    Label("完成必做后，开启词汇推荐", systemImage: "lock.fill").font(.headline)
                    Text("生词本始终可以管理；额外的推荐学习需要先完成当前周期。")
                    Button("继续今日任务", action: continueToday)
                }
            } else {
                if model.loading { ProgressView("正在寻找新的词汇…").accessibilityIdentifier("recommendation-loading") }
                ForEach(model.items) { item in
                    NavigationLink {
                        DictionaryDetailView(result: item.result, context: item.candidate.sentence, learning: learning, articleID: item.candidate.articleID, automaticAdditionAllowed: false)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.candidate.lemma).font(.system(.title3, design: .serif).weight(.semibold))
                            if let ipa = item.result.usableSenses.compactMap(\.ipa).first { Text(ipa).font(.caption).opacity(0.8) }
                            if let sense = item.result.usableSenses.first { Text(sense.zh).font(.subheadline).lineLimit(2) }
                            else { Text("暂无英中释义").font(.caption).opacity(0.8) }
                        }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).padding(18)
                            .background(LinearGradient(colors: ReadingPalette.colors(topic: item.candidate.topic), startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain).listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                if model.items.isEmpty && !model.loading && model.error == nil { ContentUnavailableView("暂无新的推荐词条", systemImage: "text.magnifyingglass", description: Text("导入更多完整文章后重试；不会重复推荐已在生词本中的词。")) }
                Button("重新寻找推荐") { retry += 1 }.disabled(model.loading)
            }
            if let error = model.error { Text(error).foregroundStyle(.red); Button("重试推荐") { retry += 1 } }
        }.navigationTitle("词汇推荐").task(id: retry) { await model.load(learning) }
            .onReceive(learning.$revision) { _ in model.refreshMembership(learning) }
    }
}
