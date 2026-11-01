import SwiftUI

struct ArticleLibraryView: View {
    @ObservedObject var learning: LearningServices
    @State private var items: [ArticleLibraryItem] = []
    @State private var query = ""
    @State private var source = "all"
    @State private var topic = "all"
    @State private var mode = "all"
    @State private var newestFirst = true
    @State private var reader: ReaderRoute?
    @State private var error: String?
    @State private var notice: String?
    @State private var loading = false
    @State private var refreshTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool
    @State private var explorationAllowed = false
    @State private var importFailed = false
    private var visible: [ArticleLibraryItem] {
        items.filter { $0.readable && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) &&
            (source == "all" || $0.sourceID == source) && (topic == "all" || $0.topics.contains(topic)) &&
            (mode == "all" || mode == "favorite" && $0.favorite || mode == "later" && $0.readLater || mode == "history" && $0.started) }
            .sorted { newestFirst ? $0.fetchedAt > $1.fetchedAt : $0.fetchedAt < $1.fetchedAt }
    }
    var body: some View {
        List {
            Section {
                Picker("来源", selection: $source) { Text("全部来源").tag("all"); ForEach(Array(Set(items.filter(\.readable).map(\.sourceID))).sorted(), id: \.self) { Text(ArticleSourceRegistry.name($0)).tag($0) } }.accessibilityIdentifier("library-source-filter")
                Picker("分类", selection: $topic) { Text("全部分类").tag("all"); ForEach(Array(Set(items.flatMap(\.topics))).sorted(), id: \.self) { Text($0).tag($0) } }.accessibilityIdentifier("library-topic-filter")
                Picker("阅读内容", selection: $mode) { Text("全部").tag("all"); Text("收藏").tag("favorite"); Text("稍后阅读").tag("later"); Text("历史").tag("history") }
                Toggle("最新导入优先", isOn: $newestFirst)
            }
            if loading { ProgressView("正在导入完整文章…").accessibilityIdentifier("article-loading"); Button("停止本次发现") { refreshTask?.cancel() }.accessibilityIdentifier("cancel-article-discovery") }
            if let notice { Text(notice).font(.footnote).accessibilityIdentifier("article-notice") }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red); Button(importFailed ? "重试导入" : "重新读取本地数据") { if importFailed { beginRefresh() } else { load() } } }.accessibilityIdentifier("article-import-error") }
            ForEach(visible) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.title).font(.headline)
                    Text(ArticleSourceRegistry.name(item.sourceID)).font(.caption).lineLimit(2)
                    Text("\(item.topics.joined(separator: " · ")) · \(item.minutes) 分钟").font(.caption)
                    Label("完整原文 · 本地离线可读", systemImage: "checkmark.icloud").font(.caption).foregroundStyle(.secondary)
                    Text(item.completed ? "已完成 · 可重读" : item.started ? "进行中 \(Int(item.percent * 100))%" : item.cycleID != nil ? "每日必做" : "未读").font(.subheadline)
                    Button(item.cycleID == nil && !explorationAllowed ? "完成必做后解锁" : item.started ? "继续阅读" : "打开文章") {
                        do {
                            if item.cycleID == nil { _ = try learning.openExplore(articleID: item.id, at: Date()) }
                            reader = ReaderRoute(articleID: item.id, cycleID: item.cycleID)
                        } catch { self.error = error.localizedDescription }
                    }.disabled(item.cycleID == nil && !explorationAllowed).accessibilityIdentifier("library-open-\(item.id)")
                    HStack {
                        Button(item.favorite ? "取消收藏" : "收藏", systemImage: item.favorite ? "star.fill" : "star") { flags(item, favorite: !item.favorite) }
                        Button(item.readLater ? "移出稍后阅读" : "稍后阅读", systemImage: item.readLater ? "bookmark.fill" : "bookmark") { flags(item, later: !item.readLater) }
                    }.buttonStyle(.bordered).font(.caption)
                }.padding(.vertical, 8)
            }
            if visible.isEmpty, !loading { ContentUnavailableView("没有匹配的完整文章", systemImage: "books.vertical", description: Text("调整筛选，或导入有权在本地保存的完整英文原文。")) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索完整文章标题")
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { searchFocused = false }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成搜索") { searchFocused = false } } }
        .navigationTitle("文章库与历史")
        .toolbar { Button("发现完整文章", systemImage: "arrow.clockwise") { beginRefresh() }.disabled(loading) }
        .refreshable { await beginRefresh().value }
        .task { load() }.onReceive(learning.$revision) { _ in load() }
        .onDisappear { refreshTask?.cancel() }
        .fullScreenCover(item: $reader) { route in NavigationStack { ReaderView(route: route, learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭文章") { reader = nil } } } } }
    }
    private func load() { do { items = try learning.content.library(); explorationAllowed = try learning.explorationAllowed(); error = nil } catch { importFailed = false; self.error = error.localizedDescription } }
    @discardableResult private func beginRefresh() -> Task<Void, Never> {
        refreshTask?.cancel(); let task = Task { await refresh() }; refreshTask = task; return task
    }
    private func flags(_ item: ArticleLibraryItem, favorite: Bool? = nil, later: Bool? = nil) {
        do { try learning.content.setLibraryFlags(articleID: item.id, favorite: favorite, readLater: later); load(); error = nil }
        catch { importFailed = false; self.error = error.localizedDescription }
    }
    private func refresh() async {
        guard !loading else { return }; loading = true; notice = nil; error = nil; importFailed = false; defer { loading = false }
        do { let count = try await learning.discovery.refresh(force: true); try Task.checkCancellation(); learning.changed(); notice = count == 0 ? "没有新文章；本地完整版本保持可读。" : "已导入 \(count) 篇完整原文。"; error = nil }
        catch is CancellationError { load(); learning.changed(); notice = "已停止发现；已完整入库的文章保留。" }
        catch { importFailed = true; self.error = FullTextImportError.transport.localizedDescription }
    }
}
