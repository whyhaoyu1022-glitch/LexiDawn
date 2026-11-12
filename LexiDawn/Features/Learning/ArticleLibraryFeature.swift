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
    @State private var rfcMessage: String?
    @State private var showingRFCOptions = false
    @State private var refreshingRFC = false
    @State private var loading = false
    @State private var refreshTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool
    @State private var explorationAllowed = false
    @State private var access = ArticleLearningAccess(cycles: [], localDate: "")
    @State private var importFailed = false
    @State private var resetting: ArticleLibraryItem?
    @State private var editing: ReaderRoute?
    private var visible: [ArticleLibraryItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { $0.readable && (term.isEmpty || ArticleTitlePresentation.display($0.title, sourceID: $0.sourceID).localizedStandardContains(term)) &&
            (source == "all" || $0.sourceID == source) && (topic == "all" || $0.topics.contains(topic)) &&
            (mode == "all" || mode == "favorite" && $0.favorite || mode == "later" && $0.readLater || mode == "history" && $0.started) }
            .sorted { newestFirst ? $0.fetchedAt > $1.fetchedAt : $0.fetchedAt < $1.fetchedAt }
    }
    var body: some View {
        List {
            if !query.isBlank, visible.isEmpty, !loading { emptyLibrary }
            Button("发现新文章", systemImage: "arrow.clockwise") { beginRefresh() }
                .disabled(loading).accessibilityIdentifier("library-discover")
            DiscoveryProgressCard(service: learning.discovery)
            Section {
                HStack { Text("共 \(items.filter(\.readable).count) 篇").font(.headline); Spacer(); Text("当前 \(visible.count) 篇").font(.caption).foregroundStyle(.secondary) }.accessibilityIdentifier("library-count")
                Picker("阅读内容", selection: $mode) {
                    Text("全部").tag("all")
                    Text("收藏 \(items.filter { $0.readable && $0.favorite }.count)").tag("favorite")
                    Text("稍后 \(items.filter { $0.readable && $0.readLater }.count)").tag("later")
                    Text("历史").tag("history")
                }.pickerStyle(.segmented).accessibilityIdentifier("library-mode-filter")
                Picker("来源", selection: $source) { Text("全部来源").tag("all"); ForEach(Array(Set(items.filter(\.readable).map(\.sourceID))).sorted(), id: \.self) { Text(ArticleSourceRegistry.name($0)).tag($0) } }.accessibilityIdentifier("library-source-filter")
                Picker("分类", selection: $topic) { Text("全部分类").tag("all"); ForEach(Array(Set(items.flatMap(\.topics))).sorted(), id: \.self) { Text($0).tag($0) } }.accessibilityIdentifier("library-topic-filter")
                Toggle("最新导入优先", isOn: $newestFirst)
            }
            if let notice { Text(notice).font(.footnote).accessibilityIdentifier("article-notice") }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red); Button(importFailed ? "重试导入" : "重新读取本地数据") { if importFailed { beginRefresh() } else { load() } } }.accessibilityIdentifier("article-import-error") }
            if query.isBlank, visible.isEmpty, !loading { emptyLibrary }
            if query.isBlank { rfcOptions }
            ForEach(visible) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(ArticleTitlePresentation.display(item.title, sourceID: item.sourceID)).font(.system(.headline, design: .serif))
                    Text(([ArticleSourceRegistry.name(item.sourceID)] + item.topics + ["\(item.minutes) 分钟"]).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(item.completed ? "已完成 · 可重读" : item.started ? "进行中 \(Int(item.percent * 100))%" : item.cycleID != nil ? "每日必做" : "未读").font(.subheadline)
                    Button(!access.permits(articleID: item.id, cycleID: item.cycleID) ? "完成必做后解锁" : item.started ? "继续阅读" : "打开文章") {
                        do {
                            _ = try learning.openArticle(articleID: item.id, cycleID: item.cycleID, at: Date())
                            reader = ReaderRoute(articleID: item.id, cycleID: item.cycleID)
                        } catch { self.error = error.localizedDescription }
                    }.disabled(!access.permits(articleID: item.id, cycleID: item.cycleID)).accessibilityIdentifier("library-open-\(item.id)")
                    HStack {
                        Button(item.favorite ? "取消收藏" : "收藏", systemImage: item.favorite ? "star.fill" : "star") { flags(item, favorite: !item.favorite) }
                        Button(item.readLater ? "移出稍后阅读" : "稍后阅读", systemImage: item.readLater ? "bookmark.fill" : "bookmark") { flags(item, later: !item.readLater) }
                    }.buttonStyle(.bordered).font(.caption)
                    if item.cycleID == nil && item.started { Button("重新标记为未开始") { resetting = item }.font(.caption).disabled(!explorationAllowed) }
                    if explorationAllowed && item.sourceID == "user-import" && item.cycleID == nil {
                        Button("更新个人原文") { editing = ReaderRoute(articleID: item.id, cycleID: nil) }.font(.caption)
                    }
                // A List row's automatic button style can dispatch the whole row's
                // actions. Opening, resetting and editing must remain independent.
                }.buttonStyle(.borderless).padding(.vertical, 8)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索完整文章标题")
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { finishSearchInput() }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成搜索", action: finishSearchInput).accessibilityIdentifier("library-finish-search")
            }
        }
        .navigationTitle("文章库与历史")
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable { await beginRefresh().value }
        .task { load() }.onReceive(learning.$revision) { _ in load() }
        .sheet(item: $editing) { route in ArticleImportView(learning: learning, editingArticleID: route.articleID) }
        .alert("重新标记为未开始？", isPresented: Binding(get: { resetting != nil }, set: { if !$0 { resetting = nil } }), presenting: resetting) { item in
            Button("确认重新标记") {
                // Capture the presented item; dismissal may clear the binding first.
                do { try learning.content.resetExploration(articleID: item.id, at: Date()); learning.changed(); load() } catch { self.error = error.localizedDescription }
                resetting = nil
            }
            Button("取消", role: .cancel) { resetting = nil }
        } message: { _ in Text("保留原阅读与完成历史，仅为本篇探索文章建立新的阅读进度。每日任务文章不能这样重置。") }
        .fullScreenCover(item: $reader) { route in NavigationStack { ReaderView(route: route, learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭文章") { reader = nil } } } } }
    }
    private var rfcOptions: some View {
        Section {
            Button { showingRFCOptions.toggle() } label: {
                HStack {
                    Label("备用技术文档", systemImage: "doc.text").font(.subheadline)
                    Spacer()
                    Image(systemName: showingRFCOptions ? "chevron.up" : "chevron.down").font(.caption)
                }.foregroundStyle(.secondary)
            }.accessibilityIdentifier("rfc-example-options").accessibilityValue(showingRFCOptions ? "已展开" : "已收起")
            if showingRFCOptions {
                Button("导入随附 RFC 8890") { do { try learning.content.installBundledRFC(at: Date()); learning.changed(); load() } catch { rfcMessage = error.localizedDescription } }
                Button("从官方来源刷新 RFC") { Task { await refreshRFC() } }.disabled(refreshingRFC).accessibilityIdentifier("refresh-rfc")
                if refreshingRFC { ProgressView("正在刷新 RFC") }
                if let rfcMessage { Text(rfcMessage).font(.caption).accessibilityIdentifier("rfc-refresh-result") }
            }
        }
    }
    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("没有匹配的完整文章", systemImage: "books.vertical").font(.headline)
            Text("调整筛选，或导入完整英文原文。").font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 6).accessibilityElement(children: .combine).accessibilityIdentifier("library-empty")
    }
    private func finishSearchInput() { searchFocused = false; InputComposition.dismissKeyboard() }
    private func refreshRFC() async {
        guard !refreshingRFC else { return }
        refreshingRFC = true; rfcMessage = nil
        defer { refreshingRFC = false }
        do { try await learning.acquisition.refresh(); learning.changed(); load(); rfcMessage = "RFC 8890 已更新。" }
        catch { rfcMessage = error.localizedDescription }
    }
    private func load() { do { items = try learning.content.library(); access = try learning.articleAccess(); explorationAllowed = access.mayExplore; error = nil } catch { access = ArticleLearningAccess(cycles: [], localDate: ""); importFailed = false; self.error = error.localizedDescription } }
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
        catch { importFailed = true; self.error = error.localizedDescription }
    }
}

struct DiscoveryProgressCard: View {
    @ObservedObject var service: ArticleDiscoveryService
    @State private var showingResults = false
    var body: some View {
        if service.progress.phase != .idle {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(service.progress.phase == .running ? "正在发现文章" : service.progress.phase == .cancelled ? "已停止发现" : service.progress.phase == .failed ? "发现未完成" : "来源检查完成").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(service.progress.processedSources)/\(service.progress.totalSources)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressView(value: service.progress.fraction).accessibilityIdentifier("article-discovery-progress")
                    .accessibilityValue("已处理\(service.progress.processedSources)个来源，共\(service.progress.totalSources)个")
                if !service.progress.activeSourceIDs.isEmpty {
                    Text(activeSources).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("article-discovery-active-sources")
                }
                Text("新增\(service.progress.importedCount)篇 · 重复\(service.progress.duplicateCount)篇 · 未导入\(service.progress.failedArticleCount)篇" + (service.progress.failedCount > 0 ? " · \(service.progress.failedCount)个来源未完成" : "")).font(.caption).foregroundStyle(.secondary)
                if service.progress.phase == .running { Button("停止本次发现") { service.cancelRefresh() }.accessibilityIdentifier("cancel-article-discovery") }
                if !service.progress.sourceResults.isEmpty {
                    Button { showingResults.toggle() } label: {
                        Label("本次来源结果", systemImage: showingResults ? "chevron.up" : "chevron.down")
                    }.font(.subheadline).accessibilityIdentifier("article-discovery-results")
                    if showingResults {
                        ForEach(service.progress.sourceResults) { source in
                            let description = ArticleSourceRegistry.name(source.id) + " · " + sourceStatus(source.state)
                            Label(description, systemImage: source.checked ? "checkmark.circle" : source.error != nil ? "exclamationmark.circle" : "clock")
                                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
                                .accessibilityElement(children: .ignore).accessibilityLabel(description)
                                .accessibilityIdentifier("article-discovery-result-" + source.id)
                        }
                    }
                }
            }.padding(.vertical, 8).buttonStyle(.borderless)
                .onChange(of: service.progress.runID) { _, _ in showingResults = false }
        }
    }
    private var activeSources: String {
        service.progress.activeSourceIDs.map { id in
            [ArticleSourceRegistry.name(id), service.progress.stagesBySource[id]].compactMap { $0 }.joined(separator: " · ")
        }.joined(separator: "\n")
    }

    private func sourceStatus(_ state: DiscoverySourceResult.State) -> String {
        switch state {
        case .imported(let count): return "已导入 \(count) 篇"
        case .noNew: return "没有新文章"
        case .recentlyChecked: return "近期已检查"
        case .waitingToRetry: return "等待重试"
        case .failed(let error, let imported):
            let status: String
            switch error {
            case .storage: status = "本地保存失败"
            case .transport: status = "连接失败"
            case .rateLimited: status = "来源暂限流"
            default: status = "无法取得完整原文"
            }
            return imported == 0 ? status : "已导入 \(imported) 篇 · " + status
        }
    }
}
