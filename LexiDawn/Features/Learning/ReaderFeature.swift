import SwiftUI
import Combine
import AVFoundation

@MainActor final class ReaderViewModel: ObservableObject {
    @Published var article: ReadableArticle?
    @Published var position = ReaderPosition()
    @Published var error: String?
    @Published var notice: String?
    @Published var sourceURL: String?
    let articleID: String
    let cycleID: UUID?
    let learning: LearningServices
    private var lastSave = Date.distantPast
    init(articleID: String, cycleID: UUID?, learning: LearningServices) { self.articleID = articleID; self.cycleID = cycleID; self.learning = learning }
    func open() {
        do {
            let article = try cycleID == nil ? learning.openExplore(articleID: articleID, at: Date()) : learning.content.read(articleID: articleID, at: Date())
            position = try learning.reader.position(article: article, cycleID: cycleID)
            if position.contentChanged { notice = "正文版本已变化。已尝试匹配原段落；不能匹配时从开头恢复，完成记录不会伪造。" }
            self.article = article; sourceURL = article.originalURL; error = nil
        } catch { self.article = nil; sourceURL = (error as? ArticleAccessError)?.originalURL; self.error = error.localizedDescription }
    }
    func observe(_ observed: ReaderPosition) {
        position.percent = max(position.percent, observed.percent); position.offset = observed.offset; position.anchor = observed.anchor
        if Date().timeIntervalSince(lastSave) >= 2 { flush() }
    }
    func flush() {
        guard article != nil else { return }
        do { try learning.reader.save(articleID: articleID, cycleID: cycleID, position: position, at: Date()); lastSave = Date(); error = nil }
        catch { if let denied = error as? ArticleAccessError { article = nil; sourceURL = denied.originalURL }; self.error = error.localizedDescription }
    }
    func complete(manual: Bool) {
        flush(); guard error == nil else { return }
        do {
            try learning.reader.complete(articleID: articleID, cycleID: cycleID, manualConfirmation: manual, at: Date())
            if let article { position = try learning.reader.position(article: article, cycleID: cycleID) }
            learning.changed(); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct ReaderRoute: Identifiable { var id: String { "\(cycleID?.uuidString ?? "explore")|\(articleID)" }; let articleID: String; let cycleID: UUID? }
struct ReaderView: View {
    @StateObject private var model: ReaderViewModel
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: WordLookupModel?
    @State private var manualConfirmation = false
    @State private var fontSize: Double = 19
    @State private var lineSpacing: Double = 1.5
    @State private var theme = "system"
    init(route: ReaderRoute, learning: LearningServices) { _model = StateObject(wrappedValue: ReaderViewModel(articleID: route.articleID, cycleID: route.cycleID, learning: learning)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let article = model.article {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title).font(.title3.bold()).lineLimit(3)
                    Text("\(article.topics.joined(separator: " · ")) · \(article.minutes) 分钟").font(.caption).foregroundStyle(.secondary)
                    if let published = article.publishedAt { Text("发布：\(published.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    if let url = article.originalURL.flatMap(URL.init(string:)) { Link("原文与来源", destination: url).font(.caption) }
                    DisclosureGroup("来源与许可") { Text(article.source).font(.caption); Text("全文授权在每次访问及保存时重新检查。导入内容仅限本地使用。").font(.caption) }
                    HStack { ProgressView(value: model.position.percent); Text("\(Int(model.position.percent * 100))%").font(.caption.monospacedDigit()).accessibilityIdentifier("reader-progress") }
                }.padding(.horizontal)
                if let notice = model.notice { Text(notice).font(.caption).padding(.horizontal) }
                InteractiveEnglishText(text: article.body, fontSize: fontSize, lineSpacing: lineSpacing, theme: theme, restore: model.position,
                    onPosition: model.observe, onWord: { token in
                        do {
                            let auto = try dependencies.preferencesRepository.load().autoAddOnWordTap; model.flush()
                            guard model.article != nil else { return }
                            let lookup = WordLookupModel(token: token, articleID: model.articleID, autoAdd: auto, learning: model.learning)
                            lookup.startAddition(); selection = lookup
                        }
                        catch { model.error = error.localizedDescription }
                    })
                if model.position.completedAt != nil { Label("阅读已完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green).padding(.horizontal).accessibilityIdentifier("reading-completed") }
                else {
                    Button(model.position.percent >= 0.9 ? "确认完成阅读" : "我已读完，手动确认") {
                        if model.position.percent >= 0.9 { model.complete(manual: false) } else { manualConfirmation = true }
                    }.buttonStyle(.borderedProminent).padding(.horizontal).accessibilityIdentifier("finish-reading")
                }
            } else {
                ContentUnavailableView("暂时无法读取全文", systemImage: "doc.text.magnifyingglass", description: Text("学习记录保留，请检查许可、来源与存储。"))
                if let url = model.sourceURL.flatMap(URL.init(string:)) { Link("前往原文核对授权", destination: url) }
                Button("重新读取") { model.open() }
            }
            if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal); Button("重试保存 / 读取") { if model.article == nil { model.open() } else { model.flush() } } }
        }
        .navigationTitle("英文阅读").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu("阅读外观", systemImage: "textformat.size") {
                    Button("增大字号") { saveAppearance(size: min(32, fontSize + 1), theme: theme) }
                    Button("减小字号") { saveAppearance(size: max(14, fontSize - 1), theme: theme) }
                    ForEach(["system", "light", "dark", "paper"], id: \.self) { value in
                        Button(["system": "跟随系统", "light": "浅色", "dark": "深色", "paper": "暖纸色"][value] ?? value) { saveAppearance(size: fontSize, theme: value) }
                    }
                }
            }
        }
        .task {
            do { let prefs = try dependencies.preferencesRepository.load(); fontSize = prefs.readerFontSize; lineSpacing = prefs.readerLineSpacing; theme = prefs.readerTheme }
            catch { model.error = error.localizedDescription }
            model.open()
        }
        .onDisappear { model.flush(); model.learning.changed() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.flush() } else { model.open() } }
        .task(id: model.article?.accessExpiresAt) {
            guard let expiry = model.article?.accessExpiresAt else { return }
            do {
                while !Task.isCancelled {
                    let seconds = expiry.timeIntervalSinceNow
                    if seconds <= 0 { model.open(); return }
                    try await Task.sleep(for: .seconds(min(seconds, 30)))
                }
            } catch { }
        }
        .sheet(item: $selection) { selected in WordLookupSheet(model: selected) }
        .alert("明确确认已读完", isPresented: $manualConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认我已读完") { model.complete(manual: true) }
        } message: { Text("适用于短文章、恢复位置不准确或已认真读完的情况。记录实际进度与本次手动确认，不会伪造 90% 进度。") }
    }
    private func saveAppearance(size: Double, theme: String) {
        do {
            let prefs = try dependencies.preferencesRepository.load(); prefs.readerFontSize = size; prefs.readerTheme = theme
            try dependencies.preferencesRepository.save(prefs); fontSize = size; self.theme = theme; model.learning.changed()
        } catch { model.error = error.localizedDescription }
    }
}

@MainActor final class WordLookupModel: ObservableObject, Identifiable {
    let id = UUID()
    let depth: Int
    @Published var result: DictionaryResult?
    @Published var error: String?
    @Published var addition: VocabularyAddition?
    @Published var existing = false
    @Published var loading = false
    @Published var vocabularyError: String?
    private var started = false
    let token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices, depth: Int = 0) { self.token = token; self.articleID = articleID; self.autoAdd = autoAdd; self.learning = learning; self.depth = depth }
    func begin() async {
        startAddition()
        await lookup()
    }
    func startAddition() { if !started { started = true; add(explicit: false) } }
    func refreshMembership() {
        do {
            if try learning.vocabulary.find(surface: token.surface) == nil { addition = nil; existing = false }
            else if addition == nil { existing = true }
        } catch { vocabularyError = error.localizedDescription }
    }
    func lookup() async {
        loading = true
        do { result = try await learning.dictionary.lookup(token.surface); error = nil }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    func add(explicit: Bool) {
        do {
            if let addition = try learning.vocabulary.add(token: token, articleID: articleID, autoAdd: autoAdd, explicit: explicit, at: Date()) { self.addition = addition; existing = !addition.created; learning.changed() }
            else { existing = try learning.vocabulary.find(surface: token.surface) != nil }
            vocabularyError = nil
        } catch { self.vocabularyError = error.localizedDescription }
    }
    func undo() {
        guard let addition else { return }
        do { try learning.vocabulary.undo(addition, at: Date()); self.addition = nil; existing = false; learning.changed(); vocabularyError = nil }
        catch { self.vocabularyError = error.localizedDescription }
    }
}
struct WordLookupSheet: View {
    @StateObject private var model: WordLookupModel
    @Environment(\.dismiss) private var dismiss
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices) {
        _model = StateObject(wrappedValue: WordLookupModel(token: token, articleID: articleID, autoAdd: autoAdd, learning: learning))
    }
    init(model: WordLookupModel) { _model = StateObject(wrappedValue: model) }
    var body: some View {
        NavigationStack {
            List {
                Section { Text(model.token.surface).font(.largeTitle.bold()); Text("标准词形：\(EnglishTokenizer.lemma(model.token.surface))"); Text(model.token.sentence).font(.body.italic()) }
                Section("生词本") {
                    if model.addition?.created == true { Label("刚刚加入", systemImage: "checkmark.circle"); Button("撤销本次加入") { model.undo() }.accessibilityIdentifier("undo-word") }
                    else if model.existing { Label("此前已加入", systemImage: "bookmark.fill") }
                    else { Button("加入生词本") { model.add(explicit: true) }.accessibilityIdentifier("add-word") }
                    if let error = model.vocabularyError { Text(error).foregroundStyle(.red); Button("重试保存生词") { model.add(explicit: true) } }
                }
                if model.loading { ProgressView("正在查询本地开放词典…") }
                if let result = model.result {
                    DictionaryResultContent(result: result)
                    NavigationLink("查看详细释义") { DictionaryDetailView(result: result, context: model.token.sentence, learning: model.learning, articleID: model.articleID, depth: model.depth) }
                }
                if let error = model.error { Text(error).foregroundStyle(.red); Button("重试词典查询") { Task { await model.lookup() } } }
            }
            .navigationTitle("查词").toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("close-word") } }
            .task { await model.begin() }
            .onReceive(model.learning.$revision) { _ in model.refreshMembership() }
        }.presentationDetents([.medium, .large])
    }
}
struct DictionaryResultContent: View {
    let result: DictionaryResult
    var body: some View {
        Section("可能含义 · CC-CEDICT 反向检索") {
            if result.senses.isEmpty { Text("暂无可验证的释义。可以继续阅读，或在生词本添加明确标记的个人释义。") }
            ForEach(result.senses) { sense in VStack(alignment: .leading, spacing: 4) { Text(sense.zh).font(.headline); Text(sense.en); Text("词性 / 英语音标：来源未提供").font(.caption).foregroundStyle(.secondary) } }
            Text("此来源是中英词典的反向索引，不能确定当前语境义；未将机器翻译冒充词典原文。").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct DictionaryDetailView: View {
    let result: DictionaryResult
    let context: String
    @ObservedObject var learning: LearningServices
    let articleID: String?
    var depth: Int = 0
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var speech = AVSpeechSynthesizer()
    @State private var entry: VocabularyItem?
    @State private var removeConfirmation = false
    @State private var selection: WordLookupModel?
    @State private var error: String?
    var body: some View {
        List {
            Section { Text(result.headword).font(.largeTitle); Button("系统英语朗读") { let utterance = AVSpeechUtterance(string: result.headword); utterance.voice = AVSpeechSynthesisVoice(language: "en-US"); speech.speak(utterance) } }
            Section("生词本") {
                if entry != nil { Label("已在生词本", systemImage: "bookmark.fill"); Button("手动移除词条", role: .destructive) { removeConfirmation = true } }
                else if articleID != nil { Button("加入生词本") { add() } }
                if let error { Text(error).foregroundStyle(.red) }
            }
            DictionaryResultContent(result: result)
            Section("可点击的英文释义") {
                ForEach(result.senses) { sense in english(sense.en) }
            }
            Section("当前文章语境（并非词典例句）") { english(context) }
            Section("数据来源") {
                if let url = URL(string: result.sourceURL) { Link("MDBG · CC-CEDICT 编辑与贡献者", destination: url) }
                if let url = URL(string: result.licenseURL) { Link("CC BY-SA 4.0 · 派生索引使用同一许可", destination: url) }
                Text("数据版本：2026-10-30；缓存：\(result.updatedAt.formatted())").font(.caption)
                Text("原始义项")
                ForEach(result.senses) { Text($0.line).font(.caption) }
            }
        }.navigationTitle("详细释义").task { refresh() }.onReceive(learning.$revision) { _ in refresh() }
            .sheet(item: $selection) { selected in WordLookupSheet(model: selected) }
            .alert("确认移除词条", isPresented: $removeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认移除", role: .destructive) {
                    do { if let entry { try learning.vocabulary.remove(entryID: entry.id, at: Date()); learning.changed() }; refresh() }
                    catch { self.error = error.localizedDescription }
                }
            } message: { Text("复习日志保留，仅本次明确操作移除生词。") }
            .onDisappear { speech.stopSpeaking(at: .immediate) }
    }
    @ViewBuilder private func english(_ text: String) -> some View {
        if let articleID, !text.isEmpty, depth < 3 {
            InlineEnglishText(text: text, onWord: { token in
                do {
                    let auto = try dependencies.preferencesRepository.load().autoAddOnWordTap
                    let model = WordLookupModel(token: token, articleID: articleID, autoAdd: auto, learning: learning, depth: depth + 1)
                    model.startAddition(); selection = model
                } catch { self.error = error.localizedDescription }
            })
        } else {
            Text(text)
            if depth >= 3 { Text("已达本次查词深度上限；返回上一层后可继续查词。").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func refresh() { do { entry = try learning.vocabulary.find(surface: result.headword) } catch { self.error = error.localizedDescription } }
    private func add() {
        guard let articleID else { return }
        do {
            _ = try learning.vocabulary.add(token: EnglishToken(surface: result.headword, range: NSRange(location: 0, length: (result.headword as NSString).length), sentence: context), articleID: articleID, autoAdd: false, explicit: true, at: Date())
            learning.changed(); refresh(); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
