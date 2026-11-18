import SwiftUI

@MainActor final class VocabularyRecommendationModel: ObservableObject {
    @Published var allowed = false
    @Published var error: String?
    @Published var saved: Set<String> = []
    func refreshMembership(_ learning: LearningServices) {
        do { saved = Set(try learning.vocabulary.entries().map(\.lemma)); allowed = try learning.explorationAllowed(); error = nil }
        catch { self.error = error.localizedDescription; allowed = false }
    }
}
struct VocabularyRecommendationView: View {
    @ObservedObject var learning: LearningServices
    let continueToday: () -> Void
    @StateObject private var model = VocabularyRecommendationModel()
    @State private var selection: RecommendedVocabulary?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                #if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"]?.hasPrefix("round3-recommendations-") == true { Text("明确词汇推荐测试夹具：Provider状态注入，非生产联网结果。").font(.caption) }
                #endif
                if !model.allowed {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("完成必做后，开启词汇推荐", systemImage: "lock.fill").font(.headline)
                        Button("继续今日任务", action: continueToday)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    if learning.refreshingRecommendations { ProgressView("正在寻找新的词汇…").accessibilityIdentifier("recommendation-loading") }
                    let visible = learning.recommendedVocabulary.filter { !model.saved.contains($0.result.savedHeadword) }
                    ForEach(visible) { item in
                        Button { selection = item } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.result.savedHeadword).font(.system(.title3, design: .serif).weight(.semibold))
                                if let sense = item.result.quickSenses.first(where: BilingualMeaningPolicy.trusted) {
                                    if let ipa = sense.ipa { Text(ipa).font(.caption).opacity(0.8) }
                                    Text(sense.zh).font(.subheadline).lineLimit(2)
                                }
                                else { Text("暂无英中释义").font(.caption).opacity(0.8) }
                            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white).padding(18)
                                .background(LinearGradient(colors: ReadingPalette.colors(topic: item.candidate.topic), startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityIdentifier("recommendation-detail-" + item.candidate.lemma)
                    }
                    if visible.isEmpty && !learning.refreshingRecommendations && model.error == nil && learning.recommendationError == nil { ContentUnavailableView("暂无新的推荐词条", systemImage: "text.magnifyingglass", description: Text("阅读更多完整文章后，可在下次检查时获得新推荐。")) }
                }
                if let error = model.error ?? learning.recommendationError {
                    Text(error).foregroundStyle(.red)
                    if model.allowed { Button("重试推荐") { Task { await learning.refreshRecommendations(retry: true) } } }
                }
            }.padding(.horizontal, 20).padding(.vertical, 14)
        }.navigationTitle("词汇推荐").task {
            model.refreshMembership(learning)
            #if DEBUG && targetEnvironment(simulator)
            if !learning.productionNetworking, model.allowed {
                await learning.refreshRecommendations()
            }
            #endif
        }
            .onReceive(learning.$revision) { _ in model.refreshMembership(learning) }
            .navigationDestination(isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
                if let item = selection {
                    DictionaryDetailView(result: item.result, context: item.candidate.sentence, learning: learning, articleID: item.candidate.articleID, automaticAdditionAllowed: false,
                        sourceToken: .init(surface: item.candidate.surface, range: item.candidate.range, sentence: item.candidate.sentence))
                }
            }
    }
}
