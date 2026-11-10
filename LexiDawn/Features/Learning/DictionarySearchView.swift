import SwiftUI
import Combine

@MainActor private final class DictionarySearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var result: DictionaryResult?
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    private var request: Task<Void, Never>?
    private var generation = UUID()
    func search(learning: LearningServices) {
        request?.cancel(); let token = UUID(); generation = token
        let word = query.trimmingCharacters(in: .whitespacesAndNewlines)
        result = nil; error = nil; loading = !word.isEmpty
        guard !word.isEmpty else { return }
        request = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                let value = try await learning.dictionary.lookup(word)
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.result = value; self.loading = false
            } catch is CancellationError { }
            catch {
                guard let self, self.generation == token else { return }
                self.error = error.localizedDescription; self.loading = false
            }
        }
    }
    func cancel() { generation = UUID(); request?.cancel(); loading = false }
}

struct DictionarySearchView: View {
    @ObservedObject var learning: LearningServices
    @StateObject private var model = DictionarySearchModel()
    @State private var details = false
    @State private var editing: VocabularyItem?
    @State private var saveError: String?
    @State private var theme = "system"
    @FocusState private var queryFocused: Bool
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("离线词典").font(.system(.largeTitle, design: .serif).weight(.semibold))
                    Text("App 内置 MDX · 无需联网").font(.caption).foregroundStyle(.secondary)
                    TextField("输入英文单词或短语", text: $model.query)
                        .focused($queryFocused)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        .submitLabel(.search).accessibilityIdentifier("dictionary-search-field")
                        .onSubmit { queryFocused = false; model.search(learning: learning) }
                    if model.loading { ProgressView("正在查询 MDX…").accessibilityIdentifier("dictionary-search-loading") }
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("重试查询") { model.search(learning: learning) }
                    }
                    if let result = model.result {
                        Button { details = true } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { Text(result.headword).font(.system(.title, design: .serif)); Spacer(); Image(systemName: "arrow.up.right") }
                                DictionaryQuickMeaning(result: result)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityIdentifier("dictionary-search-result")
                        if result.reliableChinese.isEmpty {
                            Text(result.senses.isEmpty ? "MDX 未收录此词，可创建个人词条。" : "MDX 未提供中文释义，可补充个人英中义项。")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("创建或编辑个人词条", systemImage: "square.and.pencil") { createPersonal(result) }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("dictionary-create-personal")
                        }
                    } else if !model.loading && model.error == nil {
                        ContentUnavailableView("查找一个词", systemImage: "text.book.closed", description: Text("完整释义、词性、例句和系统发音都在这里。"))
                    }
                    if let saveError { Label(saveError, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .navigationTitle("词典").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭词典") { dismiss() } } }
                .onChange(of: model.query) { _, _ in model.search(learning: learning) }
                .onDisappear { model.cancel() }
                .task {
                    do { theme = try dependencies.preferencesRepository.load().readerTheme } catch { saveError = error.localizedDescription }
                }
                .fullScreenCover(isPresented: $details) {
                    if let result = model.result { NavigationStack { DictionaryDetailView(result: result, context: "", learning: learning, articleID: nil, theme: theme, automaticAdditionAllowed: false,
                        sourceToken: .init(surface: model.query.trimmingCharacters(in: .whitespacesAndNewlines), range: NSRange(location: 0, length: (model.query as NSString).length), sentence: "")) } }
                }
                .sheet(item: $editing) { item in NavigationStack { VocabularyDetailView(item: item, learning: learning) } }
        }
    }
    private func createPersonal(_ result: DictionaryResult) {
        do {
            let addition = try learning.vocabulary.addDictionaryEntry(headword: result.headword, surface: model.query, at: Date())
            guard try learning.vocabulary.personalEditingAllowed(entryID: addition.entryID) else { throw LearningError.invalid("该词已有 MDX 中文释义，不能创建个人义项。") }
            guard let item = try learning.vocabulary.entries().first(where: { $0.id == addition.entryID }) else { throw LearningError.invalid("保存的词条尚未读取成功，请重试。") }
            editing = item; saveError = nil; learning.changed()
        } catch { saveError = error.localizedDescription }
    }
}
