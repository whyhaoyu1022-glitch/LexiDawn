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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    init(route: ReaderRoute, learning: LearningServices) { _model = StateObject(wrappedValue: ReaderViewModel(articleID: route.articleID, cycleID: route.cycleID, learning: learning)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let article = model.article {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title).font(.title3.bold()).lineLimit(verticalSizeClass == .compact ? 1 : 2)
                    Text("\(article.topics.joined(separator: " · ")) · \(article.minutes) 分钟").font(.caption).foregroundStyle(.secondary)
                    if verticalSizeClass != .compact, let published = article.publishedAt { Text("发布：\(published.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    if verticalSizeClass != .compact { DisclosureGroup("来源与许可") { Text(article.source).font(.caption).textSelection(.enabled); Text("全文授权在每次访问及保存时重新检查。导入内容仅限本地使用。").font(.caption) } }
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
                    }, document: article.document)
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity).layoutPriority(1)
                if model.position.completedAt != nil { Label("阅读已完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green).padding(.horizontal).accessibilityIdentifier("reading-completed") }
                else {
                    Button(model.position.percent >= 0.9 ? "确认完成阅读" : "我已读完，手动确认") {
                        if model.position.percent >= 0.9 { model.complete(manual: false) } else { manualConfirmation = true }
                    }.buttonStyle(.borderedProminent).padding(.horizontal).accessibilityIdentifier("finish-reading")
                }
            } else {
                ContentUnavailableView("暂时无法读取全文", systemImage: "doc.text.magnifyingglass", description: Text("学习记录保留，请检查许可、来源与存储。"))
                Button("重新读取") { model.open() }
            }
            if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal); Button("重试保存 / 读取") { if model.article == nil { model.open() } else { model.flush() } } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(readerBackground)
        .toolbarBackground(readerBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(theme == "dark" ? .dark : ["paper", "light"].contains(theme) ? .light : nil)
        .navigationTitle("英文阅读").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu("阅读外观", systemImage: "textformat.size") {
                    Button("增大字号") { saveAppearance(size: min(32, fontSize + 1), theme: theme) }
                    Button("减小字号") { saveAppearance(size: max(14, fontSize - 1), theme: theme) }
                    ForEach(["system", "light", "dark", "paper"], id: \.self) { value in
                        Button(["system": "跟随系统", "light": "浅色", "dark": "深色", "paper": "暖纸色"][value] ?? value) { saveAppearance(size: fontSize, theme: value) }
                    }
                }.accessibilityIdentifier("reader-appearance")
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
    private var readerBackground: Color {
        theme == "dark" ? Color(white: 0.08) : theme == "paper" ? Color(red: 0.97, green: 0.94, blue: 0.87) : theme == "light" ? .white : Color(uiColor: .systemBackground)
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
    private var lookupGeneration = UUID()
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
        let generation = UUID(); lookupGeneration = generation; loading = true
        defer { if lookupGeneration == generation { loading = false } }
        do {
            if let local = try? await learning.dictionary.localResult(token.surface), generation == lookupGeneration, !Task.isCancelled { result = local }
            let value = try await learning.dictionary.lookup(token.surface, context: token.sentence)
            guard generation == lookupGeneration, !Task.isCancelled else { return }
            result = value; error = nil
        } catch is CancellationError { }
        catch { if generation == lookupGeneration { self.error = error.localizedDescription } }
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
    @State private var phraseSelection: WordLookupModel?
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices) {
        _model = StateObject(wrappedValue: WordLookupModel(token: token, articleID: articleID, autoAdd: autoAdd, learning: learning))
    }
    init(model: WordLookupModel) { _model = StateObject(wrappedValue: model) }
    var body: some View {
        NavigationStack {
            List {
                Section { Text(model.token.surface).font(.largeTitle.bold()); Text("标准词形：\(EnglishTokenizer.lemma(model.token.surface))"); Text(model.token.sentence).font(.body.italic()) }
                if model.depth < 3 {
                    let phrases = EnglishPhraseRecognizer.phrases(around: model.token.surface, sentence: model.token.sentence)
                    if !phrases.isEmpty {
                        Section("语境短语") {
                            ForEach(phrases, id: \.self) { phrase in
                                Button(phrase) {
                                    let token = EnglishToken(surface: phrase, range: NSRange(location: model.token.range.location, length: (phrase as NSString).length), sentence: model.token.sentence)
                                    phraseSelection = WordLookupModel(token: token, articleID: model.articleID, autoAdd: model.autoAdd, learning: model.learning, depth: model.depth + 1)
                                }
                            }
                        }
                    }
                }
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
            .sheet(item: $phraseSelection) { WordLookupSheet(model: $0) }
    }
}
struct DictionaryResultContent: View {
    let result: DictionaryResult
    var body: some View {
        Section("词典义项与来源") {
            if let pronunciation = result.senses.compactMap(\.ipa).first { Text(pronunciation).font(.headline.monospaced()).accessibilityIdentifier("dictionary-ipa-summary") }
            let providers = Array(Set(result.senses.flatMap { $0.sources ?? ["CC-CEDICT"] })).sorted()
            if !providers.isEmpty { Text("已合并：" + providers.joined(separator: " · ")).font(.caption).accessibilityIdentifier("dictionary-providers") }
            if result.senses.isEmpty { Text("暂无可验证的释义。可以继续阅读，或在生词本添加明确标记的个人释义。") }
            ForEach(result.senses) { sense in
                VStack(alignment: .leading, spacing: 6) {
                    if !sense.zh.isEmpty { Text(sense.zh).font(.headline) }
                    else { Text("暂无可靠中文释义").font(.caption).foregroundStyle(.secondary) }
                    if let pos = sense.partOfSpeech { Text(pos).font(.caption.bold()) }
                    if let ipa = sense.ipa { Text(ipa).font(.body.monospaced()).accessibilityIdentifier("dictionary-ipa") }
                    Text(sense.en)
                    ForEach(sense.examples ?? [], id: \.self) { Text($0).italic() }
                    if let synonyms = sense.synonyms, !synonyms.isEmpty { Text("同义词：" + synonyms.joined(separator: " · ")).font(.footnote) }
                    if let antonyms = sense.antonyms, !antonyms.isEmpty { Text("反义词：" + antonyms.joined(separator: " · ")).font(.footnote) }
                    if let etymology = sense.etymology { Text("词源：" + etymology).font(.footnote) }
                    Text((sense.sources ?? ["CC-CEDICT reverse index"]).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            if result.cached { Label("本地缓存 · 离线可用", systemImage: "internaldrive").font(.caption) }
            if !result.failedProviders.isEmpty { Label("部分来源不可用：" + result.failedProviders.joined(separator: "、") + "。已保留其他真实结果。", systemImage: "exclamationmark.triangle").font(.caption) }
            Text("中文反向索引是可能对应词；语境排序使用确定性词汇重合规则，不保证已完成语义消歧。").font(.caption).foregroundStyle(.secondary)
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
                if entry != nil { Label("已在生词本", systemImage: "bookmark.fill"); if let meaning = entry?.meaning { Text("个人释义：" + meaning) }; Button("手动移除词条", role: .destructive) { removeConfirmation = true } }
                else if articleID != nil { Button("加入生词本") { add() } }
                if let error { Text(error).foregroundStyle(.red) }
            }
            DictionaryResultContent(result: result)
            Section("可点击的英文释义") {
                ForEach(result.senses) { sense in english(sense.en); ForEach(sense.examples ?? [], id: \.self) { english($0) } }
            }
            Section("当前文章语境（并非词典例句）") { english(context) }
            Section("数据来源") {
                if let url = URL(string: result.sourceURL) { Link("词典数据来源", destination: url) }
                if let url = URL(string: result.licenseURL) { Link("CC BY-SA 4.0 · 派生索引使用同一许可", destination: url) }
                Text("数据版本：\(result.versions.isEmpty ? "CEDICT 2026-10-30" : result.versions.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))；缓存：\(result.updatedAt.formatted())").font(.caption)
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

