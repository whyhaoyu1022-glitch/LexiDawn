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
                    }, title: ArticleTitlePresentation.display(article.title), subtitle: compactSource(article) + " · " + (article.publishedAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "") + " · \(article.minutes)分钟", sourceID: article.sourceID)
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
        .alert("明确确认已读完", isPresented: $manualConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认我已读完") { model.complete(manual: true) }
        } message: { Text("适用于短文章、恢复位置不准确或已认真读完的情况。记录实际进度与本次手动确认，不会伪造 90% 进度。") }
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
    private var lookupTask: Task<Void, Never>?
    let token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices
    let origin: VocabularyContextOrigin
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices, depth: Int = 0, origin: VocabularyContextOrigin = .reader) { self.token = token; self.articleID = articleID; self.autoAdd = autoAdd; self.learning = learning; self.depth = depth; self.origin = origin }
    func startLookup(force: Bool = false) {
        guard force || result == nil, lookupTask == nil else { return }
        lookupTask = Task { [weak self] in
            guard let self else { return }
            defer { self.lookupTask = nil }
            await self.begin()
        }
    }
    func cancelLookup() { lookupTask?.cancel(); lookupTask = nil; lookupGeneration = UUID(); loading = false }
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
            if let addition = try learning.vocabulary.add(token: token, articleID: articleID, autoAdd: autoAdd, explicit: explicit, origin: origin, at: Date()) { self.addition = addition; existing = !addition.created; learning.changed() }
            else { existing = try learning.vocabulary.find(surface: token.surface, context: token.sentence) != nil }
            vocabularyError = nil
        } catch { self.vocabularyError = error.localizedDescription }
    }
    func phraseLookup(_ phrase: String) -> WordLookupModel? {
        phraseError = nil
        do {
            let text: String?
            if origin.kind == "reader" { text = try learning.content.read(articleID: articleID, at: Date()).body }
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
    @State private var theme = "system"
    init(token: EnglishToken, articleID: String, autoAdd: Bool, learning: LearningServices) {
        _model = StateObject(wrappedValue: WordLookupModel(token: token, articleID: articleID, autoAdd: autoAdd, learning: learning))
    }
    init(model: WordLookupModel) { _model = StateObject(wrappedValue: model) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.result?.headword ?? EnglishTokenizer.lemma(model.token.surface)).font(.system(.title3, design: .serif).bold())
                if let ipa = model.result?.senses.compactMap(\.ipa).first { Text(ipa).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Spacer(minLength: 2)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.caption).frame(width: 32, height: 32) }.accessibilityLabel("关闭查词").accessibilityIdentifier("close-word")
            }
            if model.loading && model.result?.usableSenses.isEmpty != false { ProgressView("查词中").accessibilityIdentifier("dictionary-loading") }
            if let result = model.result, !result.usableSenses.isEmpty || !model.loading { DictionaryQuickMeaning(result: result) }
            if let error = model.error { Button("词典暂不可用，重试") { model.startLookup(force: true) }.font(.caption).accessibilityHint(error) }
            if let error = model.vocabularyError { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                if model.addition?.created == true {
                    Button { model.undo() } label: { Label("撤销", systemImage: "checkmark.circle.fill") }.accessibilityIdentifier("undo-word")
                } else if model.existing { Label("已加入", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                else { Button("加入生词本", systemImage: "plus.circle") { model.add(explicit: true) }.accessibilityIdentifier("add-word") }
                Spacer()
                Button { showDetails = true } label: { Image(systemName: "arrow.up.right.circle.fill").font(.title2).frame(width: 44, height: 44) }
                    .accessibilityLabel("查看详细释义").accessibilityIdentifier("dictionary-details").disabled(model.loading && model.result?.usableSenses.isEmpty != false)
            }.font(.subheadline)
        }.padding(16).frame(width: dynamicTypeSize.isAccessibilitySize ? 310 : 285).accessibilityElement(children: .contain).accessibilityIdentifier("compact-word-card")
            .fixedSize(horizontal: false, vertical: true)
            .task { if let prefs = try? dependencies.preferencesRepository.load() { theme = prefs.readerTheme } }
            .onAppear { model.startLookup() }
            .onDisappear { if !showDetails { model.cancelLookup() } }
            .onReceive(model.learning.$revision) { _ in model.refreshMembership() }
            .fullScreenCover(isPresented: $showDetails) {
                NavigationStack {
                    DictionaryDetailView(result: model.result ?? DictionaryResult(headword: EnglishTokenizer.lemma(model.token.surface), senses: [], updatedAt: Date(), sourceURL: "", licenseURL: ""), context: model.token.sentence, learning: model.learning, articleID: model.articleID, depth: model.depth, theme: theme, automaticAdditionAllowed: model.autoAdd, contextOrigin: model.origin, lookupModel: model)
                }.preferredColorScheme(theme == "dark" ? .dark : ["light", "paper"].contains(theme) ? .light : nil)
            }
    }
}
/// A bounded reading aid. All original provider senses remain in the separate detail page.
struct DictionaryQuickMeaning: View {
    let result: DictionaryResult
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.usableSenses.isEmpty { Text("暂无英中释义").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(Array(result.usableSenses.prefix(2))) { sense in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let part = sense.partOfSpeech { Text(BilingualMeaningPolicy.partName(part)).font(.caption).foregroundStyle(.secondary) }
                    Text(sense.zh).font(.subheadline).lineLimit(2)
                }.accessibilityIdentifier("dictionary-quick-sense-" + sense.id)
            }
        }
    }
}
/// One bilingual content tree shared by Reader, saved vocabulary and recommendations.
struct DictionaryResultContent: View {
    let result: DictionaryResult
    var onExampleWord: ((EnglishToken, DictionarySense) -> Void)? = nil
    private var senses: [DictionarySense] { result.usableSenses }
    private var parts: [String] { senses.reduce(into: []) { values, sense in let part = sense.partOfSpeech ?? ""; if !values.contains(part) { values.append(part) } } }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let ipa = result.senses.compactMap(\.ipa).first {
                Text(ipa).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("dictionary-ipa-summary")
            }
            if senses.isEmpty {
                ContentUnavailableView("暂无英中释义", systemImage: "text.book.closed", description: Text("可以在生词本补充词性、中文释义和例句。"))
            }
            ForEach(Array(parts.enumerated()), id: \.element) { groupIndex, part in
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(UnicodeScalar(65 + groupIndex % 26)!)+".").foregroundStyle(.secondary)
                        Text(BilingualMeaningPolicy.partName(part)).fontWeight(.medium)
                    }.font(.title3).accessibilityAddTraits(.isHeader)
                    ForEach(Array(senses.filter { ($0.partOfSpeech ?? "") == part }.enumerated()), id: \.element.id) { index, sense in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").font(.caption.weight(.medium)).frame(width: 24, height: 24).background(.quaternary, in: Circle()).accessibilityLabel("义项\(index + 1)")
                            VStack(alignment: .leading, spacing: 10) {
                                if let labels = sense.usageLabels, !labels.isEmpty { Text(labels.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                                Text(sense.zh).font(.system(.title3, design: .serif)).fixedSize(horizontal: false, vertical: true)
                                ForEach(Array((sense.examples ?? []).enumerated()), id: \.offset) { exampleIndex, example in
                                    VStack(alignment: .leading, spacing: 5) {
                                        if let onExampleWord {
                                            InlineEnglishText(text: example, onWord: { onExampleWord($0, sense) })
                                        } else { Text(example).font(.system(.body, design: .serif)) }
                                        if let translations = sense.exampleTranslations, translations.indices.contains(exampleIndex), !translations[exampleIndex].isBlank {
                                            Text(translations[exampleIndex]).foregroundStyle(.secondary)
                                        }
                                    }.padding(.leading, 8).padding(.vertical, 3)
                                }
                                if let forms = sense.forms, !forms.isEmpty { Text(forms.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary) }
                                if let phrases = sense.relatedPhrases, !phrases.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("短语与搭配").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        ForEach(phrases, id: \.self) { Text($0).font(.system(.body, design: .serif)) }
                                    }.padding(.top, 8)
                                }
                                if let synonyms = sense.synonyms, !synonyms.isEmpty { Text("近义词  " + synonyms.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary) }
                                if let antonyms = sense.antonyms, !antonyms.isEmpty { Text("反义词  " + antonyms.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary) }
                                if let etymology = sense.etymology, !etymology.isBlank { DisclosureGroup("词源") { Text(etymology).font(.footnote) } }
                                Text((sense.sources ?? ["CC-CEDICT · 待确认候选"]).joined(separator: " · "))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.accessibilityIdentifier("dictionary-full-sense-" + sense.id)
                    }
                }
            }
            let providers = Array(Set(senses.flatMap { $0.sources ?? ["CC-CEDICT"] })).sorted()
            if !providers.isEmpty {
                Text((providers.count > 1 ? "融合来源：" : "来源：") + providers.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("dictionary-providers")
            }
            if result.cached { Label("本地词典", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary) }
            if !result.failedProviders.isEmpty { Label("部分词典暂不可用", systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary) }
            if result.emptyProviders.contains("Free Dictionary API") { Text("Free Dictionary 当前不可用").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("dictionary-free-unavailable") }
            else if result.senses.contains(where: { ($0.sources ?? []).contains("Free Dictionary API") }), !result.usableSenses.contains(where: { ($0.sources ?? []).contains("Free Dictionary API") }) {
                Text("Free Dictionary 未提供英中释义").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("dictionary-free-no-Chinese")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
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
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var speech = AVSpeechSynthesizer()
    @State private var entry: VocabularyItem?
    @State private var addition: VocabularyAddition?
    @State private var showingSynonyms = false
    @State private var selection: WordLookupModel?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    Text(result.headword).font(.system(.largeTitle, design: .serif).weight(.semibold)).textSelection(.enabled)
                    Spacer(minLength: 12)
                    Button { speak() } label: { Image(systemName: "speaker.wave.2").frame(width: 44, height: 44) }.accessibilityLabel("系统英语朗读")
                }
                HStack {
                    if entry != nil {
                        Label("已加入生词本", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
                        Spacer()
                        if addition?.created == true { Button("撤销本次加入", action: undo).accessibilityIdentifier("undo-word") }
                    } else if articleID != nil { Button("加入生词本", systemImage: "plus") { add() }.buttonStyle(.bordered).accessibilityIdentifier("add-word") }
                }.font(.subheadline)
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
                DictionaryResultContent(result: result, onExampleWord: lookup)
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
                        ForEach(result.usableSenses) { Text($0.line).font(.caption).textSelection(.enabled) }
                        Text("更新于 " + result.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        Text("Oxford：未配置").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }.font(.subheadline)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 24)
        }.background(background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 20) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("返回查词")
                    Spacer()
                    Label(result.headword, systemImage: "book.closed").font(.headline).lineLimit(1)
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("关闭详细释义")
                }.padding(.horizontal, 8).padding(.vertical, 4)
                    .background(reduceTransparency ? AnyShapeStyle(background) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .overlay { Capsule().strokeBorder(.primary.opacity(0.08)) }.padding(.horizontal, 20).padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { refresh() }.onReceive(learning.$revision) { _ in refresh() }
            .popover(item: $selection) { WordLookupSheet(model: $0).presentationCompactAdaptation(.popover) }
            .onDisappear { speech.stopSpeaking(at: .immediate) }
    }
    private var background: Color { theme == "paper" ? LexiDawnColor.paperWarm : theme == "dark" ? Color(red: 0.055, green: 0.065, blue: 0.09) : Color(uiColor: .systemBackground) }
    private func speak() { let value = AVSpeechUtterance(string: result.headword); value.voice = AVSpeechSynthesisVoice(language: "en-US"); speech.speak(value) }
    private func lookup(_ token: EnglishToken, _ sense: DictionarySense) {
        open(token, origin: .dictionary(headword: result.headword, evidence: sense.line, text: (sense.examples ?? []).first { $0.contains(token.surface) }))
    }
    private func lookupContext(_ token: EnglishToken) { open(token, origin: contextOrigin.withText(context)) }
    private func open(_ token: EnglishToken, origin: VocabularyContextOrigin) {
        guard depth < 3, let articleID else { return }
        let auto = (try? dependencies.preferencesRepository.load().autoAddOnWordTap) ?? false
        let model = WordLookupModel(token: token, articleID: articleID, autoAdd: automaticAdditionAllowed && auto, learning: learning, depth: depth + 1, origin: origin)
        model.startAddition(); selection = model
    }
    private func refresh() { do { entry = try learning.vocabulary.find(surface: result.headword) } catch { self.error = error.localizedDescription } }
    private func add() {
        guard let articleID else { return }
        do {
            addition = try learning.vocabulary.add(token: EnglishToken(surface: result.headword, range: NSRange(location: 0, length: (result.headword as NSString).length), sentence: context), articleID: articleID, autoAdd: false, explicit: true, origin: contextOrigin, at: Date())
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
