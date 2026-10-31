import SwiftUI

struct LearningRootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var learning: LearningServices
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            LiveTodayView(dependencies: dependencies, learning: learning).tabItem { Label("今日", systemImage: "sun.max") }.tag(0)
            LiveExploreView(learning: learning, continueToday: { tab = 0 }).tabItem { Label("探索", systemImage: "safari") }.tag(1)
            VocabularyListView(learning: learning).tabItem { Label("词汇", systemImage: "text.book.closed") }.tag(2)
            ReviewPracticeView(learning: learning).tabItem { Label("复习", systemImage: "rectangle.stack") }.tag(3)
            LearningSettingsView(learning: learning).tabItem { Label("我的", systemImage: "person") }.tag(4)
        }.tint(LexiDawnColor.dawn500)
    }
}
struct LiveTodayView: View {
    @StateObject private var model: TodayViewModel
    @ObservedObject var learning: LearningServices
    let dependencies: AppDependencies
    @State private var importSheet = false
    @State private var reader: ReaderRoute?
    @State private var review = false
    @State private var statistics: LearningStatistics?
    @State private var sourceMessage: String?
    @State private var fetching = false
    init(dependencies: AppDependencies, learning: LearningServices) {
        self.dependencies = dependencies; self.learning = learning
        _model = StateObject(wrappedValue: TodayViewModel(dependencies: dependencies))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting).font(.largeTitle.bold())
                        Text(Date().formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary)
                        Text("让每一次阅读，成为自己的积累。").font(.subheadline)
                    }
                    switch model.state {
                    case let .loaded(snapshot): hero(snapshot)
                    case .noCandidate:
                        ContentUnavailableView("准备第一篇英文阅读", systemImage: "book.closed", description: Text("合法导入自己的文章，或使用已核验许可的 RFC 原文。不会用虚构文章填充候选。"))
                    case let .failed(message), let .saveFailed(message): Text(message).foregroundStyle(.red); Button("重新读取") { reload() }
                    default: ProgressView("正在读取学习记录…")
                    }
                    if let statistics {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("你的积累").font(.title3.bold())
                            HStack { metric("完成文章", statistics.articles); metric("学习日期", statistics.studyDays); metric("连续日期", statistics.streak) }
                            HStack { metric("生词本", statistics.vocabulary); metric("待复习", statistics.pending) }
                            Text("学习日期按周期原始本地日期统计；跨日续接不会伪造新日期。累计文章按完成证据和阅读记录去重。").font(.caption).foregroundStyle(.secondary)
                        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("阅读内容").font(.title3.bold())
                        Button("合法导入文章", systemImage: "square.and.arrow.down") { importSheet = true }.accessibilityIdentifier("import-article")
                        Button("使用官方 RFC 原文", systemImage: "doc.text") { perform { try learning.content.installBundledRFC(at: Date()); learning.changed() } }
                        Button(fetching ? "正在联系 RFC Editor…" : "从官方来源刷新", systemImage: "arrow.clockwise") {
                            fetching = true
                            Task {
                                do { try await learning.acquisition.refresh(); sourceMessage = "官方正文核验成功；现有未完成文章保持不变。"; learning.changed() }
                                catch { sourceMessage = error.localizedDescription }
                                fetching = false
                            }
                        }.disabled(fetching)
                        Text("RFC 8890 · M. Nottingham / IETF Trust。全文连同原版权声明保留。导入内容仅在本地使用，不自动上传，也不据此抓取网页。").font(.caption).foregroundStyle(.secondary)
                        if let sourceMessage { Text(sourceMessage).font(.footnote).foregroundStyle(.secondary) }
                    }.padding().background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                }.padding(20)
            }.accessibilityIdentifier("learning-today-scroll")
            .navigationTitle("词光").navigationBarTitleDisplayMode(.inline)
            .task { reload() }.refreshable { reload() }
            .onReceive(learning.$revision) { _ in reload() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in reload() }
            .sheet(isPresented: $importSheet) { ArticleImportView(learning: learning) }
            .sheet(item: $reader) { route in NavigationStack { ReaderView(route: route, learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回今日") { reader = nil } } } } }
            .sheet(isPresented: $review) { NavigationStack { ReviewPracticeContent(learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回今日") { review = false; reload() } } } } }
        }
    }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
    private func metric(_ label: String, _ value: Int) -> some View { VStack(alignment: .leading) { Text("\(value)").font(.title2.bold().monospacedDigit()); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
    private func hero(_ snapshot: TodayCycleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(snapshot.cycle.isComplete ? "今日必做已完成" : "今天，读一篇真实的英文", systemImage: snapshot.cycle.isComplete ? "checkmark.seal.fill" : "sunrise.fill").font(.subheadline.weight(.semibold))
            Text(snapshot.articleTitle ?? snapshot.cycle.articleID).font(.system(.title, design: .serif).bold()).fixedSize(horizontal: false, vertical: true)
            Text("原始分配日期 \(snapshot.cycle.assignedLocalDate) · \(snapshot.cycle.assignedTimeZoneID)").font(.caption)
            if snapshot.isOverdue { Label("已跨过 \(snapshot.cycle.carryOverCount) 个学习日期，继续原文章", systemImage: "clock").font(.footnote) }
            Button(snapshot.cycle.articleTaskStatus == .completed ? "重新阅读" : snapshot.cycle.articleTaskStatus == .inProgress ? "继续阅读" : "开始阅读") {
                reader = ReaderRoute(articleID: snapshot.cycle.articleID, cycleID: snapshot.cycle.cycleID)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("open-reader")
            taskRow("阅读", snapshot.cycle.articleTaskStatus, reason: snapshot.cycle.articleTaskReason)
            taskRow("连线复习", snapshot.cycle.matchingStageStatus, reason: snapshot.cycle.matchingStageReason)
            taskRow("拼写补全", snapshot.cycle.clozeStageStatus, reason: snapshot.cycle.clozeStageReason)
            Button("进入 / 继续复习", systemImage: "rectangle.stack") { review = true }.buttonStyle(.bordered).accessibilityIdentifier("open-review")
            if snapshot.cycle.isComplete { Label("探索已解锁", systemImage: "lock.open").foregroundStyle(.green).accessibilityIdentifier("cycle-completed") }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color.orange.opacity(0.18), Color.yellow.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }
    private func taskRow(_ title: String, _ status: TaskStatus, reason: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Label(title, systemImage: status == .completed || status == .deferred ? "checkmark.circle.fill" : "circle"); Spacer(); Text(status.displayName).foregroundStyle(.secondary) }
            if let reason, status == .failed || status == .blocked { Text(reason).font(.caption).foregroundStyle(.secondary); Text("可重新打开对应学习页面；读取或保存失败会显示具体错误与重试操作。").font(.caption) }
        }
    }
    private func perform(_ operation: () throws -> Void) { do { try operation(); reload() } catch { sourceMessage = error.localizedDescription } }
    private func reload() {
        model.load()
        do { let prefs = try dependencies.preferencesRepository.load(); let zone = prefs.timeZonePolicy == "fixed" ? TimeZone(identifier: prefs.fixedTimeZoneID ?? "") ?? .current : .current; statistics = try learning.statistics(timeZone: zone, at: Date()) }
        catch { sourceMessage = error.localizedDescription }
    }
}

struct ArticleImportView: View {
    @ObservedObject var learning: LearningServices
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var source = "用户原创"
    @State private var originalURL = ""
    @State private var topic = "个人阅读"
    @State private var rights = false
    @State private var eligible = true
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("本地文章") {
                    TextField("标题", text: $title).accessibilityIdentifier("import-title")
                    TextField("来源 / 用户原创", text: $source)
                    TextField("原始 URL（可选）", text: $originalURL).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("主题", text: $topic)
                    TextEditor(text: $bodyText).frame(minHeight: 200).accessibilityIdentifier("import-body")
                    Text("\(EnglishTokenizer.tokens(in: bodyText).count) 词 · 预计 \(max(1, Int(ceil(Double(EnglishTokenizer.tokens(in: bodyText).count) / 200)))) 分钟").font(.caption)
                }
                Section("授权与分配") {
                    Toggle("我有权导入此内容供本地个人使用", isOn: $rights).accessibilityIdentifier("import-rights")
                    Toggle("允许以后分配为每日文章", isOn: $eligible)
                    Text("此确认不是第三方版权授权。内容不会公开分发或自动上传，也不会根据链接抓取正文。不会替换旧未完成任务。").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("保存到本地文章库") {
                    do {
                        _ = try learning.content.importArticle(ArticleImportDraft(title: title, body: bodyText, source: source, originalURL: originalURL, topic: topic, rightsConfirmed: rights, eligibleForDaily: eligible), at: Date())
                        learning.changed(); dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(!rights).accessibilityIdentifier("save-import")
            }.navigationTitle("合法导入文章").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

struct LiveExploreView: View {
    @ObservedObject var learning: LearningServices
    let continueToday: () -> Void
    @State private var allowed = false
    @State private var cycles: [DailyStudyCycle] = []
    @State private var ids: [String] = []
    @State private var reader: ReaderRoute?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if !allowed {
                    Section { Label("先完成必做，再自由探索", systemImage: "lock.fill").font(.title3.bold())
                        ForEach(cycles.filter(\.hasOutstandingWork), id: \.cycleID) { cycle in
                            Text("原周期：\(cycle.assignedLocalDate)")
                            if cycle.articleTaskStatus != .completed { Text("还需完成阅读") }
                            if cycle.matchingStageStatus != .completed && cycle.matchingStageStatus != .deferred { Text("还需完成连线") }
                            if cycle.clozeStageStatus != .completed && cycle.clozeStageStatus != .deferred { Text("还需完成拼写") }
                        }
                        Button("继续今日任务", action: continueToday)
                    }
                } else {
                    Section("已解锁 · 本地合法文章") {
                        if ids.isEmpty { Text("暂无合法探索内容，可先导入文章。") }
                        ForEach(ids, id: \.self) { id in
                            Button(id == SourceRegistry.rfc.id ? "The Internet is for End Users" : "本地文章 · \(id.prefix(8))") {
                                do { _ = try learning.openExplore(articleID: id, at: Date()); reader = ReaderRoute(articleID: id, cycleID: nil) }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("探索").task { load() }.onReceive(learning.$revision) { _ in load() }
                .sheet(item: $reader) { route in NavigationStack { ReaderView(route: route, learning: learning).toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { reader = nil } } } } }
        }
    }
    private func load() { do { cycles = try learning.cycles.fetchAll(); allowed = try learning.explorationAllowed(); ids = allowed ? try learning.content.allReadableIDs() : []; error = nil } catch { self.error = error.localizedDescription; allowed = false } }
}
