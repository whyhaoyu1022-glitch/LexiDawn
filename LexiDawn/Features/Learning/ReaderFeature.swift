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
            let article = try learning.openArticle(articleID: articleID, cycleID: cycleID, at: Date())
            position = try learning.reader.position(article: article, cycleID: cycleID)
            try learning.reader.save(articleID: articleID, cycleID: cycleID, position: position, at: Date())
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
    @State private var wordAnchor = UnitPoint.center
    @State private var manualConfirmation = false
    @State private var fontSize: Double = 19
    @State private var lineSpacing: Double = 1.5
    @State private var theme = "system"
    @State private var sourceDetails = false
    @State private var appearancePresented = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    init(route: ReaderRoute, learning: LearningServices) { _model = StateObject(wrappedValue: ReaderViewModel(articleID: route.articleID, cycleID: route.cycleID, learning: learning)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let article = model.article {
                HStack { ProgressView(value: model.position.percent); Text("\(Int(model.position.percent * 100))%").font(.caption.monospacedDigit()).accessibilityIdentifier("reader-progress") }.padding(.horizontal)
                if let notice = model.notice { Text(notice).font(.caption).padding(.horizontal) }
                InteractiveEnglishText(text: article.body, fontSize: fontSize, lineSpacing: lineSpacing, theme: theme, restore: model.position,
                    onPosition: model.observe, onWord: { token in
                        do {
                            let auto = try dependencies.preferencesRepository.load().autoAddOnWordTap; model.flush()
                            guard model.article != nil else { return }
                            let lookup = WordLookupModel(token: token, articleID: model.articleID, autoAdd: auto, learning: model.learning)
                            lookup.startAddition(); lookup.startLookup(); selection = lookup
                        }
                        catch { model.error = error.localizedDescription }
                    }, document: article.document, onWordAnchor: { point, size in
                        wordAnchor = UnitPoint(x: min(0.96, max(0.04, point.x / max(1, size.width))), y: min(0.96, max(0.04, point.y / max(1, size.height))))
                    }, title: ArticleTitlePresentation.display(article.title, sourceID: article.sourceID), subtitle: readerSubtitle(article), sourceID: article.sourceID)
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity).layoutPriority(1)
                .popover(item: $selection, attachmentAnchor: .point(wordAnchor), arrowEdge: .top) { selected in
                    WordLookupSheet(model: selected).presentationCompactAdaptation(.popover)
                }
                if model.position.completedAt != nil { Label("阅读已完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green).padding(.horizontal).accessibilityIdentifier("reading-completed") }
                else {
                    Button(verticalSizeClass == .compact ? "完成阅读" : model.position.percent >= 0.9 ? "确认完成阅读" : "我已读完，手动确认") {
                        if model.position.percent >= 0.9 { model.complete(manual: false) } else { manualConfirmation = true }
                    }.buttonStyle(.borderedProminent).dynamicTypeSize(...DynamicTypeSize.xxxLarge).padding(.horizontal).accessibilityIdentifier("finish-reading")
                }
            } else {
                ContentUnavailableView("暂时无法读取全文", systemImage: "doc.text.magnifyingglass", description: Text("学习记录保留，请检查许可、来源与存储。"))
                Button("重新读取") { model.open() }
            }
            if let error = model.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal); Button("重试保存 / 读取") { if model.article == nil { model.open() } else { model.flush() } } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(readerBackground)
        .accessibilityHidden(selection != nil || sourceDetails)
        .toolbarBackground(readerBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(theme == "dark" ? .dark : ["paper", "light"].contains(theme) ? .light : nil)
        .navigationTitle("英文阅读").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("来源详情", systemImage: "info.circle") { sourceDetails = true }.labelStyle(.iconOnly) }
            ToolbarItem(placement: .topBarTrailing) {
                Button("阅读外观", systemImage: "textformat.size") { appearancePresented = true }
                    .labelStyle(.iconOnly).accessibilityLabel("阅读外观").accessibilityIdentifier("reader-appearance")
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
        .sheet(isPresented: $appearancePresented) {
            NavigationStack {
                List {
                    Button("增大字号") { saveAppearance(size: min(32, fontSize + 1), theme: theme); appearancePresented = false }
                    Button("减小字号") { saveAppearance(size: max(14, fontSize - 1), theme: theme); appearancePresented = false }
                    ForEach(["system", "light", "dark", "paper"], id: \.self) { value in
                        Button(["system": "跟随系统", "light": "浅色", "dark": "深色", "paper": "暖纸色"][value] ?? value) {
                            saveAppearance(size: fontSize, theme: value); appearancePresented = false
                        }
                    }
                }.scrollContentBackground(.hidden).background(readerBackground)
                    .navigationTitle("阅读外观").navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(readerBackground, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭外观设置") { appearancePresented = false } } }
            }.presentationDetents([.large]).presentationBackground(readerBackground)
        }
        .sheet(isPresented: $sourceDetails) {
            NavigationStack {
                ScrollView { Text(model.article?.source ?? "来源信息不可用").font(.body).textSelection(.enabled).padding() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(readerBackground)
                    .navigationTitle("来源详情").navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(readerBackground, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { sourceDetails = false }.accessibilityIdentifier("close-source-details") } }
            }.presentationBackground(readerBackground)
        }
        .alert("确认已读完？", isPresented: $manualConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认我已读完") { model.complete(manual: true) }
        } message: { Text("当前阅读进度为 \(Int(model.position.percent * 100))%。确认后会记录为手动完成。") }
    }
    private func readerSubtitle(_ article: ReadableArticle) -> String {
        [compactSource(article), article.publishedAt?.formatted(date: .abbreviated, time: .omitted), "\(article.minutes) 分钟"]
            .compactMap { $0 }.filter { !$0.isBlank }.joined(separator: " · ")
    }
    private func compactSource(_ article: ReadableArticle) -> String {
        if article.sourceID == SourceRegistry.rfc.id { return "RFC Editor · M. Nottingham" }
        if article.sourceID == "wikipedia" { return "Wikipedia · Contributors" }
        if article.sourceID == "user-import" { return article.source }
        let source = ArticleSourceRegistry.name(article.sourceID)
        if let author = article.author, !author.isBlank, author != source { return source + " · " + author }
        return source
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
    @Published private(set) var phraseError: String?
    private var started = false
    private var lookupGeneration = UUID()
    private var lookupJob = UUID()
    private var lookupTask: Task<Void, Never>?
    let token: EnglishToken
    let articleID: String?
    let autoAdd: Bool
    let learning: LearningServices
    let origin: VocabularyContextOrigin
    init(token: EnglishToken, articleID: String?, autoAdd: Bool, learning: LearningServices, depth: Int = 0, origin: VocabularyContextOrigin = .reader) { self.token = token; self.articleID = articleID; self.autoAdd = autoAdd; self.learning = learning; self.depth = depth; self.origin = origin }
    func startLookup(force: Bool = false) {
        guard force || result == nil, lookupTask == nil else { return }
        let job = UUID()
        lookupJob = job
        lookupTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.lookupJob == job { self.lookupTask = nil } }
            await self.begin()
        }
    }
    func cancelLookup() { lookupTask?.cancel(); lookupTask = nil; lookupJob = UUID(); lookupGeneration = UUID(); loading = false }
    func begin() async {
        startAddition()
        await lookup()
    }
    func startAddition() { if !started { started = true; add(explicit: false) } }
    func refreshMembership() {
        do {
            if try learning.vocabulary.find(surface: token.surface, context: token.sentence) == nil { addition = nil; existing = false }
            else if addition == nil { existing = true }
        } catch { vocabularyError = error.localizedDescription }
    }
    func lookup() async {
        let generation = UUID(); lookupGeneration = generation; loading = true; error = nil
        defer { if lookupGeneration == generation { loading = false } }
        do {
            let value = try await learning.dictionary.lookup(token.surface, context: token.sentence)
            guard generation == lookupGeneration, !Task.isCancelled else { return }
            result = value; error = nil
        } catch is CancellationError { }
        catch { if generation == lookupGeneration { result = nil; self.error = error.localizedDescription } }
    }
    func add(explicit: Bool) {
        do {
            let saved: VocabularyAddition?
            if let articleID { saved = try learning.vocabulary.add(token: token, articleID: articleID, autoAdd: autoAdd, explicit: explicit, origin: origin, at: Date()) }
            else if explicit { saved = try learning.vocabulary.addDictionaryEntry(headword: result?.headword ?? EnglishTokenizer.lemma(token.surface, context: token.sentence), surface: token.surface, context: token.sentence, at: Date()) }
            else { saved = nil }
            if let saved { self.addition = saved; existing = !saved.created; learning.changed() }
            else { existing = try learning.vocabulary.find(surface: token.surface, context: token.sentence) != nil }
            vocabularyError = nil
        } catch { self.vocabularyError = error.localizedDescription }
    }
    func phraseLookup(_ phrase: String) -> WordLookupModel? {
        phraseError = nil
        do {
            let text: String?
            if origin.kind == "reader" {
                guard let articleID else { throw LearningError.invalid("原文章关联缺失，不能猜测短语位置。") }
                text = try learning.content.read(articleID: articleID, at: Date()).body
            }
            else { text = origin.sourceText }
            guard let text, let phraseToken = EnglishPhraseRecognizer.token(for: phrase, around: token, sourceText: text) else { throw LearningError.invalid("无法核验本次短语的原始位置，请返回原文或释义重新点词。") }
            return WordLookupModel(token: phraseToken, articleID: articleID, autoAdd: autoAdd, learning: learning, depth: depth + 1, origin: origin)
        } catch { phraseError = error.localizedDescription; return nil }
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
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDetails = false
    @State private var closeLookupAfterDetails = false
    @State private var theme = "system"
    @State private var preferencesError: String?
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices) {
        _model = StateObject(wrappedValue: WordLookupModel(token: token, articleID: articleID, autoAdd: autoAdd, learning: learning))
    }
    init(model: WordLookupModel) { _model = StateObject(wrappedValue: model) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.result?.headword ?? EnglishTokenizer.lemma(model.token.surface)).font(.system(.title3, design: .serif).bold()).accessibilityIdentifier("dictionary-headword")
                if let result = model.result, let ipa = result.quickSenses.first?.ipa ?? DictionaryPresentation.sharedIPA(result.senses) {
                    Text(ipa).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 2)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.caption).frame(width: 44, height: 44) }.accessibilityLabel("关闭查词").accessibilityIdentifier("close-word")
            }
            if model.loading && model.result?.usableSenses.isEmpty != false { ProgressView("查词中").accessibilityIdentifier("dictionary-loading") }
            if let result = model.result, !result.usableSenses.isEmpty || !model.loading { DictionaryQuickMeaning(result: result) }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityIdentifier("dictionary-resource-error")
                Button("词典暂不可用，重试") { model.startLookup(force: true) }.font(.caption).accessibilityHint(error)
            }
            if let error = model.vocabularyError {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityIdentifier("word-save-error")
            }
            if let preferencesError { Text(preferencesError).font(.caption).foregroundStyle(.red) }
            HStack {
                if model.addition?.created == true {
                    Button { model.undo() } label: { Label("撤销", systemImage: "checkmark.circle.fill") }.accessibilityIdentifier("undo-word")
                } else if model.existing { Label("已加入", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                else {
                    Button(model.vocabularyError == nil ? "加入生词本" : "重试保存生词", systemImage: model.vocabularyError == nil ? "plus.circle" : "arrow.clockwise") {
                        model.add(explicit: true)
                    }.accessibilityIdentifier("add-word")
                }
                Spacer()
                Button { showDetails = true } label: { Image(systemName: "arrow.up.right.circle.fill").font(.title2).frame(width: 44, height: 44) }
                    .accessibilityLabel("查看详细释义").accessibilityIdentifier("dictionary-details").disabled(model.loading || model.error != nil || model.result == nil)
            }.font(.subheadline)
        }.padding(16).frame(width: dynamicTypeSize.isAccessibilitySize ? 310 : 285).accessibilityElement(children: .contain).accessibilityIdentifier("compact-word-card")
            .fixedSize(horizontal: false, vertical: true)
            .task { do { theme = try dependencies.preferencesRepository.load().readerTheme } catch { preferencesError = "阅读设置读取失败：" + error.localizedDescription } }
            .onAppear { model.startLookup() }
            .onDisappear { if !showDetails { model.cancelLookup() } }
            .onReceive(model.learning.$revision) { _ in model.refreshMembership() }
            .fullScreenCover(isPresented: $showDetails, onDismiss: {
                if closeLookupAfterDetails { closeLookupAfterDetails = false; dismiss() }
            }) {
                NavigationStack {
                    if let result = model.result {
                        DictionaryDetailView(result: result, context: model.token.sentence, learning: model.learning, articleID: model.articleID, depth: model.depth,
                            theme: theme, automaticAdditionAllowed: model.autoAdd, contextOrigin: model.origin, lookupModel: model,
                            closeStack: { closeLookupAfterDetails = true; showDetails = false })
                    }
                }.preferredColorScheme(theme == "dark" ? .dark : ["light", "paper"].contains(theme) ? .light : nil)
            }
    }
}
/// A bounded reading aid. All original provider senses remain in the separate detail page.
struct DictionaryQuickMeaning: View {
    let result: DictionaryResult
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.quickSenses.isEmpty { Text("暂无英中释义").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(Array(result.quickSenses.prefix(2))) { sense in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let part = sense.partOfSpeech { Text(BilingualMeaningPolicy.partName(part)).font(.caption).foregroundStyle(.secondary) }
                    Text(sense.zh).font(.subheadline).lineLimit(2)
                }.accessibilityIdentifier("dictionary-quick-sense-" + sense.id)
            }
        }
    }
}
/// One bilingual content tree shared by Reader, saved vocabulary and recommendations.
enum DictionaryPresentation {
    static func sharedIPA(_ senses: [DictionarySense]) -> String? {
        let values = Array(Set(senses.compactMap(\.ipa).filter { !$0.isBlank }))
        return values.count == 1 ? values.first : nil
    }
    static func letter(_ index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < alphabet.count ? String(alphabet[index]) : String(index + 1)
    }
}
struct DictionaryEntryHeader: View {
    let headword: String
    let ipa: String?
    @ObservedObject var speech: SystemPronunciation
    private var word: some View { Text(headword).font(.system(.largeTitle, design: .serif).weight(.semibold)).textSelection(.enabled).accessibilityIdentifier("dictionary-full-headword") }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    word.fixedSize()
                    if let ipa { Text(ipa).font(.subheadline).foregroundStyle(.primary.opacity(0.65)).fixedSize().accessibilityIdentifier("dictionary-ipa-summary") }
                }
                VStack(alignment: .leading, spacing: 8) {
                    word.fixedSize(horizontal: false, vertical: true)
                    if let ipa { Text(ipa).font(.subheadline).foregroundStyle(.primary.opacity(0.65)).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("dictionary-ipa-summary") }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { speech.toggle(headword: headword) } label: {
                Image(systemName: speech.state == .speaking ? "stop.circle" : "speaker.wave.2").frame(width: 44, height: 44)
            }.accessibilityLabel(speech.state == .speaking ? "停止系统朗读" : "系统英语朗读").accessibilityIdentifier("dictionary-system-pronunciation")
        }
    }
}
struct DictionaryResultContent: View {
    let result: DictionaryResult
    var onExampleWord: ((EnglishToken, DictionarySense, String) -> Void)? = nil
    var onRelatedEntry: ((String) -> Void)? = nil
    private var senses: [DictionarySense] { result.usableSenses }
    private func group(_ sense: DictionarySense) -> String {
        if let section = sense.sectionKind { return "section|" + section }
        return "part|" + (sense.partOfSpeech ?? "") + "|" + (sense.entryGroupID ?? "")
    }
    private var parts: [String] {
        let values: [String] = senses.reduce(into: []) { values, sense in let key = group(sense); if !values.contains(key) { values.append(key) } }
        let order = ["noun", "verb", "intransitive verb", "transitive verb", "modal verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "determiner", "phrase"]
        let main = values.filter { $0.hasPrefix("part|") }.sorted { lhs, rhs in
            let a = order.firstIndex(of: lhs.components(separatedBy: "|")[1]) ?? order.count
            let b = order.firstIndex(of: rhs.components(separatedBy: "|")[1]) ?? order.count
            return a == b ? (values.firstIndex(of: lhs) ?? 0) < (values.firstIndex(of: rhs) ?? 0) : a < b
        }
        return main + values.filter { $0 == "section|phrasalVerb" } + values.filter { $0 == "section|idiom" }
    }
    private func title(_ key: String) -> String {
        if key == "section|phrasalVerb" { return "短语动词" }
        if key == "section|idiom" { return "习语" }
        return BilingualMeaningPolicy.partName(key.components(separatedBy: "|")[1])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if senses.isEmpty {
                ContentUnavailableView(result.hasMDXEntry ? "词典已收录，暂无中文释义" : "暂无英中释义", systemImage: "text.book.closed", description: Text("可在生词本补充中文释义和例句。"))
            }
            ForEach(Array(parts.enumerated()), id: \.element) { groupIndex, part in
                VStack(alignment: .leading, spacing: 16) {
                    if part.hasPrefix("section|") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(part == "section|phrasalVerb" ? "PHRASAL VERBS" : "IDIOMS").font(.system(.subheadline, design: .serif).weight(.semibold)).tracking(0.8)
                                Text(title(part)).font(.caption).foregroundStyle(.secondary)
                            }
                            Divider()
                        }.accessibilityAddTraits(.isHeader)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(DictionaryPresentation.letter(groupIndex) + ".").foregroundStyle(.primary.opacity(0.65))
                            Text(title(part)).fontWeight(.medium)
                        }.font(.title3).accessibilityAddTraits(.isHeader)
                    }
                    let grouped = senses.filter { group($0) == part }
                    if DictionaryPresentation.sharedIPA(senses) == nil, let ipa = grouped.compactMap(\.ipa).first { Text(ipa).font(.subheadline).foregroundStyle(.primary.opacity(0.65)) }
                    if part.hasPrefix("part|"), let forms = grouped.compactMap(\.forms).first, !forms.isEmpty { Text(forms.joined(separator: " · ")).font(.subheadline).foregroundStyle(.primary.opacity(0.65)) }
                    ForEach(Array(grouped.enumerated()), id: \.element.id) { index, sense in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)").font(.caption.weight(.medium)).frame(minWidth: 23, minHeight: 23).overlay { Circle().strokeBorder(.primary.opacity(0.3)) }.accessibilityLabel("义项\(index + 1)")
                            DictionarySenseBody(sense: sense, headword: result.headword, onExampleWord: onExampleWord, onRelatedEntry: onRelatedEntry)
                        }.accessibilityIdentifier("dictionary-full-sense-" + sense.id)
                    }
                }
            }
            let providers = Array(Set(senses.flatMap { $0.sources ?? [] })).sorted()
            if !providers.isEmpty { Text("来源：" + providers.joined(separator: " · ")).font(.caption).foregroundStyle(.primary.opacity(0.65)).accessibilityIdentifier("dictionary-providers") }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct DictionarySenseBody: View {
    let sense: DictionarySense
    let headword: String
    let onExampleWord: ((EnglishToken, DictionarySense, String) -> Void)?
    let onRelatedEntry: ((String) -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let related = sense.lexicalHeadword, related != headword {
                if let onRelatedEntry {
                    Button { onRelatedEntry(related) } label: { HStack { Text(related).font(.system(.title3, design: .serif).weight(.semibold)); Image(systemName: "arrow.up.right").font(.caption) } }
                        .buttonStyle(.plain).accessibilityIdentifier("dictionary-related-entry-" + related)
                } else { Text(related).font(.system(.title3, design: .serif).weight(.semibold)) }
            }
            if let labels = sense.usageLabels, !labels.isEmpty { Text(labels.joined(separator: " · ")).font(.caption).foregroundStyle(.primary.opacity(0.65)) }
            Text(sense.zh).font(.body).fixedSize(horizontal: false, vertical: true)
            if sense.originKind == "personal", !sense.en.isBlank { Text(sense.en).font(.subheadline).foregroundStyle(.secondary) }
            if let phrases = sense.relatedPhrases, !phrases.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("短语与搭配").font(.caption.weight(.semibold)).foregroundStyle(.primary.opacity(0.65))
                    ForEach(phrases, id: \.self) { Text($0).font(.system(.body, design: .serif).weight(.medium)) }
                }.padding(.leading, 10)
            }
            ForEach(Array((sense.examples ?? []).enumerated()), id: \.offset) { index, example in
                HStack(alignment: .top, spacing: 7) {
                    Text("▸").font(.caption).foregroundStyle(.primary.opacity(0.65)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        if let collocations = sense.exampleCollocations, collocations.indices.contains(index), !collocations[index].isBlank {
                            Text(collocations[index]).font(.system(.body, design: .serif).weight(.semibold))
                        }
                        if let onExampleWord { InlineEnglishText(text: example, onWord: { onExampleWord($0, sense, example) }, emphasized: true) }
                        else { Text(example).font(.system(.body, design: .serif).weight(.medium)) }
                        if let translations = sense.exampleTranslations, translations.indices.contains(index), !translations[index].isBlank {
                            Text(translations[index]).font(.body).foregroundStyle(.primary.opacity(0.78))
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                }.padding(.leading, 9).padding(.vertical, 3)
            }
            DictionarySupplementContent(sense: sense, onExampleWord: onExampleWord, onRelatedEntry: onRelatedEntry)
            if sense.originKind == "personal" { Text(sense.line).font(.caption2).foregroundStyle(.primary.opacity(0.65)) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct DictionarySupplementContent: View {
    let sense: DictionarySense
    let onExampleWord: ((EnglishToken, DictionarySense, String) -> Void)?
    let onRelatedEntry: ((String) -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let synonyms = sense.synonyms, !synonyms.isEmpty { Text("近义词  " + synonyms.joined(separator: " · ")).font(.footnote).foregroundStyle(.primary.opacity(0.65)) }
            if let antonyms = sense.antonyms, !antonyms.isEmpty { Text("反义词  " + antonyms.joined(separator: " · ")).font(.footnote).foregroundStyle(.primary.opacity(0.65)) }
            if let references = sense.seeAlso, !references.isEmpty {
                DisclosureGroup("另见") {
                    ForEach(references, id: \.self) { word in
                        if let onRelatedEntry { Button(word) { onRelatedEntry(word) }.accessibilityIdentifier("dictionary-reference-" + word) }
                        else { Text(word) }
                    }
                }.font(.subheadline)
            }
            if let notes = sense.usageNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(note.label).font(.caption.weight(.semibold)).foregroundStyle(.primary.opacity(0.65))
                            if !note.english.isBlank {
                                if let onExampleWord { InlineEnglishText(text: note.english, onWord: { onExampleWord($0, sense, note.english) }) }
                                else { Text(note.english).font(.system(.body, design: .serif)) }
                            }
                            if !note.chinese.isBlank { Text(note.chinese).foregroundStyle(.primary.opacity(0.78)) }
                        }
                    }
                }.padding(.leading, 9)
            }
            if let etymology = sense.etymology, !etymology.isBlank { DisclosureGroup("词源") { Text(etymology).font(.footnote) } }
            if let warnings = sense.sourceWarnings, !warnings.isEmpty {
                DisclosureGroup("部分补充资料未能读取") {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in Text(warning).font(.caption).foregroundStyle(.red) }
                }.font(.footnote).accessibilityIdentifier("dictionary-supplement-error")
            }
        }
    }
}
struct DictionaryRelatedRoute: Identifiable {
    let id = UUID()
    let result: DictionaryResult
}
struct DictionaryDetailView: View {
    let result: DictionaryResult
    let context: String
    @ObservedObject var learning: LearningServices
    let articleID: String?
    var depth: Int = 0
    var theme: String = "system"
    var automaticAdditionAllowed = true
    var contextOrigin: VocabularyContextOrigin = .reader
    var lookupModel: WordLookupModel? = nil
    var sourceToken: EnglishToken? = nil
    var closeStack: (() -> Void)? = nil
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var speech = SystemPronunciation()
    @State private var entry: VocabularyItem?
    @State private var addition: VocabularyAddition?
    @State private var showingSynonyms = false
    @State private var selection: WordLookupModel?
    @State private var relatedRoute: DictionaryRelatedRoute?
    @State private var relatedTask: Task<Void, Never>?
    @State private var closeAfterRelated = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DictionaryEntryHeader(headword: result.headword, ipa: DictionaryPresentation.sharedIPA(result.senses + result.personalSenses), speech: speech)
                if speech.state == .unavailable { Text("系统英语语音不可用").font(.caption).foregroundStyle(.secondary) }
                DictionaryResultContent(result: result, onExampleWord: lookup, onRelatedEntry: depth < 3 ? openRelated : nil)
                let synonyms = Array(Set(result.usableSenses.flatMap { $0.synonyms ?? [] })).filter { $0.lowercased() != result.headword.lowercased() }.sorted()
                if !synonyms.isEmpty {
                    DisclosureGroup(isExpanded: $showingSynonyms) {
                        ForEach(synonyms, id: \.self) { synonym in
                            NavigationLink { DictionaryComparisonView(original: result, synonym: synonym, context: context, learning: learning, theme: theme) } label: { Text(result.headword + " / " + synonym) }.accessibilityIdentifier("dictionary-compare-" + synonym)
                        }
                    } label: { Text("对照同义词") }.accessibilityIdentifier("dictionary-synonym-comparison")
                }
                if let lookupModel, depth < 3 {
                    let phrases = EnglishPhraseRecognizer.phrases(around: lookupModel.token.surface, sentence: context)
                    if !phrases.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("语境短语").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(phrases, id: \.self) { phrase in Button(phrase) { selection = lookupModel.phraseLookup(phrase) } }
                            if let error = lookupModel.phraseError { Text(error).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                if !context.isBlank {
                    DisclosureGroup(contextOrigin.kind == "reader" ? "遇见这个词的句子" : "查词语境") {
                        InlineEnglishText(text: context, onWord: { lookupContext($0) }).padding(.top, 8)
                    }.font(.subheadline)
                }
                DisclosureGroup("来源详情") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("词典随 App 安装，可离线查询。发音由 iOS 提供。").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }.font(.subheadline)
            }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 24)
        }.clipped().background(background.ignoresSafeArea())
            .preferredColorScheme(theme == "dark" ? .dark : ["light", "paper"].contains(theme) ? .light : nil)
            .safeAreaInset(edge: .bottom) { detailControls }
            .toolbar(.hidden, for: .navigationBar)
            .task { refresh() }.onReceive(learning.$revision) { _ in refresh() }
            .popover(item: $selection) { WordLookupSheet(model: $0).presentationCompactAdaptation(.popover) }
            .fullScreenCover(item: $relatedRoute, onDismiss: {
                if closeAfterRelated { closeAfterRelated = false; closeDetails() }
            }) { route in
                NavigationStack {
                    let sentence = route.result.senses.compactMap(\.examples).flatMap { $0 }.first ?? route.result.headword
                    DictionaryDetailView(result: route.result, context: sentence, learning: learning, articleID: nil, depth: depth + 1, theme: theme, automaticAdditionAllowed: false,
                        contextOrigin: .dictionary(headword: result.headword, evidence: BundledMDXDictionaryProvider.sourceName, text: sentence),
                        closeStack: { closeAfterRelated = true; relatedRoute = nil })
                }
            }
            .onDisappear { speech.stop(); relatedTask?.cancel() }
    }
    private var detailControls: some View {
        VStack(spacing: 6) {
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red)
                    .padding(8).background(background, in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 4) {
                if closeStack != nil {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel(lookupModel == nil ? "返回上一个词条" : "返回查词")
                }
                Spacer(minLength: 0)
                if entry == nil {
                    Button(action: add) {
                        VStack(spacing: 2) {
                            footerHeadword(icon: "book.closed")
                            Text("加入生词本").font(.caption)
                        }.frame(minHeight: 44)
                    }.accessibilityLabel("加入生词本").accessibilityIdentifier("add-word")
                } else {
                    VStack(spacing: 2) {
                        footerHeadword(icon: "checkmark.circle.fill")
                        Text("已加入生词本").font(.caption).foregroundStyle(.secondary)
                    }
                    if addition?.created == true {
                        Button(action: undo) { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                            .accessibilityLabel("撤销本次加入").accessibilityIdentifier("undo-word")
                    }
                }
                Spacer(minLength: 0)
                Button(action: closeDetails) { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                    .accessibilityLabel("关闭详细释义")
            }.padding(.horizontal, 8).padding(.vertical, 4)
                .background(reduceTransparency ? AnyShapeStyle(background) : AnyShapeStyle(.regularMaterial), in: Capsule())
                .overlay { Capsule().strokeBorder(.primary.opacity(0.08)) }
        }.padding(.horizontal, 20).padding(.bottom, 8)
    }
    private func footerHeadword(icon: String) -> some View {
        Label(result.headword, systemImage: icon).font(.headline).lineLimit(1)
    }
    private func closeDetails() {
        if let closeStack { closeStack() } else { dismiss() }
    }
    private var background: Color { theme == "paper" ? LexiDawnColor.paperWarm : theme == "dark" ? Color(red: 0.055, green: 0.065, blue: 0.09) : Color(uiColor: .systemBackground) }
    private func openRelated(_ headword: String) {
        relatedTask?.cancel()
        relatedTask = Task {
            do {
                let value = try await learning.dictionary.subentry(headword, from: result)
                guard !Task.isCancelled else { return }
                relatedRoute = DictionaryRelatedRoute(result: value); error = nil
            } catch is CancellationError { }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func lookup(_ token: EnglishToken, _ sense: DictionarySense, _ sourceText: String) {
        open(token, origin: .dictionary(headword: result.headword, evidence: sense.line, text: sourceText))
    }
    private func lookupContext(_ token: EnglishToken) { open(token, origin: contextOrigin.withText(context)) }
    private func open(_ token: EnglishToken, origin: VocabularyContextOrigin) {
        guard depth < 3 else { return }
        do {
            let auto = try dependencies.preferencesRepository.load().autoAddOnWordTap
            let model = WordLookupModel(token: token, articleID: articleID, autoAdd: articleID != nil && automaticAdditionAllowed && auto, learning: learning, depth: depth + 1, origin: origin)
            model.startAddition(); selection = model
        } catch { self.error = error.localizedDescription }
    }
    private func refresh() { do { entry = try learning.vocabulary.find(surface: result.headword) } catch { self.error = error.localizedDescription } }
    private func add() {
        do {
            if let lookupModel {
                lookupModel.add(explicit: true)
                if let error = lookupModel.vocabularyError { throw LearningError.invalid(error) }
                guard let saved = lookupModel.addition else { throw LearningError.invalid("加入结果尚未确认，请重试。") }
                addition = saved
            } else if let articleID, let sourceToken {
                addition = try learning.vocabulary.add(token: sourceToken, articleID: articleID, autoAdd: false, explicit: true, origin: contextOrigin, at: Date())
            } else { addition = try learning.vocabulary.addDictionaryEntry(headword: result.headword, surface: sourceToken?.surface, context: context, at: Date()) }
            learning.changed(); refresh(); error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func undo() {
        guard let addition else { return }
        do { try learning.vocabulary.undo(addition, at: Date()); self.addition = nil; learning.changed(); refresh(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}



@MainActor final class DictionaryComparisonModel: ObservableObject {
    @Published var result: DictionaryResult?
    @Published var error: String?
    @Published var loading = false
    private var generation = UUID()
    func load(_ word: String, context: String, learning: LearningServices) async {
        let current = UUID(); generation = current; loading = true; error = nil
        defer { if generation == current { loading = false } }
        do {
            let value = try await learning.dictionary.lookup(word, context: context)
            guard generation == current, !Task.isCancelled else { return }; result = value
        } catch is CancellationError { }
        catch { if generation == current { self.error = error.localizedDescription } }
    }
}
struct DictionaryComparisonView: View {
    let original: DictionaryResult
    let synonym: String, context: String
    @ObservedObject var learning: LearningServices
    var theme: String = "system"
    @StateObject private var model = DictionaryComparisonModel()
    var body: some View {
        List {
            Section("当前查词语境") { Text(context) }
            Section("对照词：" + synonym) {
                if model.loading { ProgressView("正在查询对照词…").accessibilityIdentifier("dictionary-comparison-loading") }
                if let error = model.error { Text(error).foregroundStyle(.red); Button("重试对照查词") { Task { await model.load(synonym, context: context, learning: learning) } }.accessibilityIdentifier("dictionary-comparison-retry") }
                if model.result?.usableSenses.isEmpty == true { Text("对照词暂无可验证义项。原词释义仍可阅读。").accessibilityIdentifier("dictionary-comparison-empty") }
            }
            if let result = model.result, !result.usableSenses.isEmpty { Text(synonym).font(.title2.bold()); DictionaryResultContent(result: result) }
            Text("原词：" + original.headword).font(.title2.bold())
            DictionaryResultContent(result: original)
        }.scrollContentBackground(.hidden)
            .background(theme == "paper" ? Color(red: 0.97, green: 0.94, blue: 0.87) : theme == "dark" ? Color(white: 0.08) : Color(uiColor: .systemGroupedBackground))
            .navigationTitle("同义词对照").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).task { await model.load(synonym, context: context, learning: learning) }
    }
}
