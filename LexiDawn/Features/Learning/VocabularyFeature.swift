import SwiftUI

struct VocabularyListView: View {
    @ObservedObject var learning: LearningServices
    @State private var items: [VocabularyItem] = []
    @State private var search = ""
    @State private var filter = "all"
    @State private var error: String?
    @State private var removing: VocabularyItem?
    var body: some View {
        NavigationStack {
            List {
                Picker("词条类型", selection: $filter) { Text("全部").tag("all"); Text("单词").tag("word"); Text("短语").tag("phrase") }.pickerStyle(.segmented)
                if items.isEmpty { ContentUnavailableView("还没有匹配的生词", systemImage: "text.book.closed", description: Text("在正文点击英文单词，或在查词浮窗手动加入。")) }
                ForEach(items) { item in
                    NavigationLink { VocabularyDetailView(item: item, learning: learning) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.lemma).font(.headline)
                            if let meaning = item.meaning { Text("个人释义：\(meaning)").font(.subheadline) }
                            else if let meaning = item.dictionaryMeanings.first { Text("可能对应：\(meaning)").font(.subheadline) }
                            Text("\(item.type == "word" ? "单词" : "短语") · \(item.addedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }
                    }.swipeActions { Button("移除", role: .destructive) { removing = item } }
                }
                if let error { Text(error).foregroundStyle(.red); Button("重新读取", action: load) }
            }.searchable(text: $search, prompt: "搜索词形、lemma 或已缓存中文释义")
                .navigationTitle("生词本").task { load() }.onReceive(learning.$revision) { _ in load() }
                .onChange(of: search) { _, _ in load() }.onChange(of: filter) { _, _ in load() }
                .alert("确认移除生词？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                    Button("取消", role: .cancel) { removing = nil }
                    Button("移除", role: .destructive) { if let item = removing { do { try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed() } catch { self.error = error.localizedDescription } }; removing = nil }
                } message: { Text("这是你主动移除的操作。历史学习与复习日志保留；复习成功不会自动删除词条。") }
        }
    }
    private func load() { do { items = try learning.vocabulary.entries(search: search, type: filter == "all" ? nil : filter); error = nil } catch { self.error = error.localizedDescription } }
}
struct VocabularyDetailView: View {
    let item: VocabularyItem
    @ObservedObject var learning: LearningServices
    @State private var meaning = ""
    @State private var notes = ""
    @State private var result: DictionaryResult?
    @State private var error: String?
    @State private var saved = false
    @State private var removeConfirmation = false
    @State private var source: ArticleLibraryItem?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section { Text(item.lemma).font(.largeTitle.bold()); Text(item.surfaces.joined(separator: " · ")) }
            Section("你的释义与笔记") {
                TextField("个人中文释义（非词典原文）", text: $meaning).accessibilityIdentifier("personal-meaning")
                TextField("笔记", text: $notes, axis: .vertical)
                Button("保存个人释义与笔记") {
                    do { try learning.vocabulary.annotate(entryID: item.id, meaning: meaning, notes: notes, at: Date()); saved = true; learning.changed(); error = nil }
                    catch { self.error = error.localizedDescription }
                }
                if saved { Label("已保存", systemImage: "checkmark.circle") }
                Text("来源没有可用中文对应词时，可填写自己的释义用于复习。个人内容与开放词典数据明确区分。").font(.caption).foregroundStyle(.secondary)
            }
            if let result { DictionaryResultContent(result: result); NavigationLink("详细词典") { DictionaryDetailView(result: result, context: item.contexts.first ?? "", learning: learning, articleID: item.sourceArticleID) } }
            Section("来源上下文") {
                if let source {
                    Text(source.title).font(.headline); Text(source.source).font(.caption).foregroundStyle(.secondary)
                    if let url = source.originalURL.flatMap(URL.init(string:)) { Link("原文与署名", destination: url) }
                }
                ForEach(item.sourceContexts) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.title).font(.headline)
                        Text(context.attribution).font(.caption).foregroundStyle(.secondary)
                        Text(context.sentence)
                        if let url = context.originalURL.flatMap(URL.init(string:)) { Link("原文来源", destination: url) }
                    }
                }
            }
            Section { Button("手动移除词条", role: .destructive) { removeConfirmation = true } }
            if let error { Text(error).foregroundStyle(.red); Button("重试词典") { Task { await lookup() } } }
        }.navigationTitle(item.lemma)
            .task {
                meaning = item.meaning ?? ""; notes = item.notes ?? ""
                do { source = try learning.content.library().first { $0.id == item.sourceArticleID } } catch { self.error = error.localizedDescription }
                await lookup()
            }
            .alert("确认移除词条", isPresented: $removeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认移除", role: .destructive) { do { try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed(); dismiss() } catch { self.error = error.localizedDescription } }
            } message: { Text("仅由本次明确操作移除，复习状态和历史日志保留。") }
    }
    private func lookup() async { do { result = try await learning.dictionary.lookup(item.lemma); error = nil } catch { self.error = error.localizedDescription } }
}
