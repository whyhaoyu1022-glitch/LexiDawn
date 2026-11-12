import SwiftUI
import UIKit

struct VocabularyListView: View {
    @ObservedObject var learning: LearningServices
    var continueToday: () -> Void = { }
    @State private var allItems: [VocabularyItem] = []
    @State private var search = ""
    @State private var filter = "all"
    @State private var error: String?
    @State private var removing: VocabularyItem?
    @State private var dictionarySearch = false
    @State private var status: VocabularyStatusFilter = .all
    @State private var sort: VocabularySort = .added
    @State private var now = Date()
    @StateObject private var exports = VocabularyExportSession()
    private var items: [VocabularyItem] { VocabularyQuery.apply(allItems, search: search, type: filter, status: status, sort: sort, at: now) }
    var body: some View {
        NavigationStack {
            List {
                Picker("词条类型", selection: $filter) { Text("全部").tag("all"); Text("单词").tag("word"); Text("短语").tag("phrase") }.pickerStyle(.segmented)
                NavigationLink { VocabularyRecommendationView(learning: learning, continueToday: continueToday) } label: { Label("高级词汇与短语推荐", systemImage: "sparkles") }.accessibilityIdentifier("vocabulary-recommendations")
                Section {
                    Text("共 \(allItems.count) 条 · 待复习 \(allItems.filter { $0.dueAt.map { $0 <= now } ?? false }.count) · 逾期 \(allItems.filter { $0.dueAt.map { $0 < Calendar.current.startOfDay(for: now) } ?? false }.count)").font(.caption).foregroundStyle(.secondary)
                    Picker("复习状态", selection: $status) { ForEach(VocabularyStatusFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("vocabulary-status-filter")
                    Picker("排序", selection: $sort) { ForEach(VocabularySort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("vocabulary-sort")
                }
                if items.isEmpty { ContentUnavailableView("还没有匹配的生词", systemImage: "text.book.closed", description: Text("在正文点击英文单词，或在查词浮窗手动加入。")) }
                ForEach(items) { item in
                    NavigationLink { VocabularyDetailView(item: item, learning: learning) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.lemma).font(.headline)
                            if let ipa = item.ipa { Text(ipa).font(.caption.monospaced()) }
                            if !item.partsOfSpeech.isEmpty { Text(item.partsOfSpeech.map { BilingualMeaningPolicy.partName($0) }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                            if let meaning = item.primaryChinese { Text(meaning).font(.subheadline).lineLimit(2) }
                            Text("\(item.type == "word" ? "单词" : "短语") · \(item.addedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            if let due = item.dueAt { Text("下次复习：" + due.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                            if let last = item.lastReviewedAt { Text("最近复习：" + last.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }.accessibilityIdentifier("vocabulary-entry-\(item.lemma)").swipeActions { Button("移除", role: .destructive) { removing = item } }
                }
                if let error { Text(error).foregroundStyle(.red); Button("重新读取", action: load) }
                if let error = exports.error { Text(error).foregroundStyle(.red) }
            }.safeAreaInset(edge: .top) {
                if let exportNotice = exports.notice {
                    Text(exportNotice).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding()
                        .background(.regularMaterial).accessibilityIdentifier("vocabulary-export-completed")
                }
            }.searchable(text: $search, prompt: "搜索单词、短语或中文释义")
                .navigationTitle("生词本").task { load() }.onReceive(learning.$revision) { _ in load() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in load() }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("离线词典", systemImage: "book.closed") { dictionarySearch = true }.accessibilityIdentifier("open-offline-dictionary") }
                    ToolbarItem(placement: .topBarTrailing) { Menu("导出生词", systemImage: "square.and.arrow.up") { Button("导出 JSON（完整学习数据）") { prepareExport(.json) }; Button("导出 CSV") { prepareExport(.csv) } }.accessibilityIdentifier("vocabulary-export") }
                }
                .sheet(isPresented: $dictionarySearch) { DictionarySearchView(learning: learning) }
                .sheet(item: $exports.presentation, onDismiss: exports.presentationDidDismiss) { request in
                    VocabularyExportPicker(file: request.file, delegate: request.delegate)
                        .presentationDetents([.large]).interactiveDismissDisabled()
                }
                .alert("确认移除生词？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                    Button("取消", role: .cancel) { removing = nil }
                    Button("移除", role: .destructive) { if let item = removing { do { try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed() } catch { self.error = error.localizedDescription } }; removing = nil }
                } message: { Text("这是你主动移除的操作。历史学习与复习日志保留；复习成功不会自动删除词条。") }
        }
    }
    private func load() { do { allItems = try learning.vocabulary.entries(); now = Date(); error = nil } catch { self.error = error.localizedDescription } }
    private func prepareExport(_ format: VocabularyExportFormat) {
        guard !exports.isBusy else { return }
        do { try exports.prepare(learning.vocabulary.export(format, at: Date()), format: format); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct VocabularyExportPresentation: Identifiable {
    var id: UUID { file.id }
    let file: VocabularyExportFile
    let delegate: VocabularyExportPicker.Coordinator
}

/// Retains the request and UIKit delegate independently of SwiftUI's sheet binding.
/// UIKit can dismiss its presentation before delivering the export completion callback.
@MainActor final class VocabularyExportSession: ObservableObject {
    @Published var presentation: VocabularyExportPresentation?
    @Published private(set) var notice: String?
    @Published private(set) var error: String?
    private var active: VocabularyExportPresentation?
    private let files: VocabularyExportFileService
    var isBusy: Bool { active != nil }
    init(files: VocabularyExportFileService = VocabularyExportFileService()) { self.files = files }
    func prepare(_ data: Data, format: VocabularyExportFormat) throws {
        guard active == nil else { return }
        notice = nil; error = nil
        let file = try files.prepare(data, format: format)
        let delegate = VocabularyExportPicker.Coordinator { [weak self] destination in
            self?.finish(id: file.id, destination: destination)
        }
        let request = VocabularyExportPresentation(file: file, delegate: delegate)
        active = request; presentation = request
        #if DEBUG
        print("VOCAB_EXPORT_DIAGNOSTIC phase=prepared")
        #endif
    }
    func presentationDidDismiss() {
        // Do not invalidate the active request or delete its source before the delegate.
        #if DEBUG
        print("VOCAB_EXPORT_DIAGNOSTIC phase=presentation-dismissed active=\(active != nil)")
        #endif
    }
    private func finish(id: UUID, destination: URL?) {
        guard let request = active, request.id == id else { return }
        #if DEBUG
        print("VOCAB_EXPORT_DIAGNOSTIC phase=callback copied=\(destination != nil)")
        #endif
        if let destination { notice = "已导出 " + destination.lastPathComponent }
        active = nil; presentation = nil
        do { try files.discard(request.file) } catch { self.error = error.localizedDescription }
    }
}

/// Public UIKit export API receives an existing file, never a changing optional document.
struct VocabularyExportPicker: UIViewControllerRepresentable {
    let file: VocabularyExportFile
    let delegate: Coordinator
    func makeCoordinator() -> Coordinator { delegate }
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .systemBackground
        let filename = UILabel()
        filename.text = file.url.lastPathComponent
        filename.font = .preferredFont(forTextStyle: .subheadline)
        filename.adjustsFontForContentSizeCategory = true
        filename.numberOfLines = 0
        filename.accessibilityIdentifier = "vocabulary-export-filename"
        let cancel = UIButton(type: .system)
        cancel.setTitle("取消", for: .normal)
        cancel.accessibilityIdentifier = "cancel-vocabulary-export"
        cancel.addAction(UIAction { _ in delegate.finished(nil) }, for: .touchUpInside)
        cancel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [filename, cancel])
        header.axis = .horizontal; header.alignment = .center; header.spacing = 16
        header.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(header)
        let picker = UIDocumentPickerViewController(forExporting: [file.url], asCopy: true)
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        container.addChild(picker)
        picker.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(picker.view)
        let safe = container.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            cancel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            picker.view.topAnchor.constraint(equalTo: header.bottomAnchor),
            picker.view.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            picker.view.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            picker.view.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ])
        picker.didMove(toParent: container)
        return container
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) { }
    @MainActor final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let finished: (URL?) -> Void
        init(finished: @escaping (URL?) -> Void) { self.finished = finished }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finished(nil) }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finished(urls.first) }
    }
}
private struct VocabularyDraft: Codable {
    let entryID: String
    let base: String
    let notes: String
    let senses: [PersonalDictionarySense]
}
@MainActor final class VocabularyAnnotationModel: ObservableObject {
    @Published var senses: [PersonalDictionarySense]
    @Published var notes: String
    @Published var allowed: Bool
    @Published var state = ""
    @Published var error: String?
    @Published private(set) var hasDraftConflict = false
    private var conflictingDraft: VocabularyDraft?
    private let item: VocabularyItem
    private let learning: LearningServices
    private var base: String
    private var failedSave: String?
    @Published private(set) var persistedSenses: [PersonalDictionarySense]
    private var checkpoint: Task<Void, Never>?
    private var ready = false
    private var draftURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("LexiDawn/annotation-drafts", isDirectory: true).appendingPathComponent(item.id + ".json")
    }
    private static func signature(_ notes: String, _ senses: [PersonalDictionarySense]) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return fingerprint(notes + String(decoding: try encoder.encode(senses), as: UTF8.self))
    }
    init(item: VocabularyItem, learning: LearningServices) {
        self.item = item; self.learning = learning
        let initial = item.personalSenses ?? item.meaning.map { [PersonalDictionarySense(chinese: $0)] } ?? []
        senses = initial; persistedSenses = initial; notes = item.notes ?? ""; allowed = false
        base = ""
        do {
            base = try Self.signature(item.notes ?? "", initial)
            if FileManager.default.fileExists(atPath: draftURL.path) {
                let draft = try JSONDecoder().decode(VocabularyDraft.self, from: Data(contentsOf: draftURL))
                if draft.entryID == item.id, draft.base == base { senses = draft.senses; notes = draft.notes; state = "已恢复未保存草稿" }
                else { conflictingDraft = draft; hasDraftConflict = true; error = "发现另一版本的未保存草稿，请选择恢复或保留当前内容。" }
            }
        } catch { self.error = "草稿读取失败：" + error.localizedDescription }
        ready = true
    }
    func resolveDraftConflict(restore: Bool) {
        guard let draft = conflictingDraft else { return }
        do {
            // Keep the competing version before any explicit replacement, including readonly personal senses.
            let archive = draftURL.deletingPathExtension().appendingPathExtension("conflict-" + UUID().uuidString + ".json")
            try FileManager.default.copyItem(at: draftURL, to: archive)
            try FileManager.default.removeItem(at: draftURL)
            hasDraftConflict = false; conflictingDraft = nil; error = nil
            refreshPolicy()
            if restore { notes = draft.notes; if allowed { senses = draft.senses }; changed(); flush() }
            else { state = "已保留当前内容，旧草稿已存档" }
        } catch { self.error = "草稿仍保留：" + error.localizedDescription }
    }
    func refreshPolicy() {
        do { allowed = try learning.vocabulary.personalEditingAllowed(entryID: item.id) }
        catch { allowed = false; self.error = error.localizedDescription }
    }
    func changed() {
        guard ready else { return }
        do { guard try Self.signature(notes, senses) != base else { return } }
        catch { state = "未保存"; self.error = error.localizedDescription; return }
        state = "尚未保存"
        checkpoint?.cancel()
        checkpoint = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)); try Task.checkCancellation(); self?.persistDraft() }
            catch is CancellationError { }
            catch { self?.error = error.localizedDescription }
        }
    }
    private func persistDraft() {
        guard !hasDraftConflict else { return }
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(VocabularyDraft(entryID: item.id, base: base, notes: notes, senses: senses)).write(to: draftURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = "草稿尚未保存：" + error.localizedDescription }
    }
    func flush() { flush(retry: false) }
    func retrySave() { flush(retry: true) }
    private func flush(retry: Bool) {
        guard !hasDraftConflict else { return }
        guard ready, !InputComposition.hasMarkedText else { persistDraft(); return }
        checkpoint?.cancel()
        var attempted: String?
        do {
            let current = try Self.signature(notes, senses)
            guard current != base, retry || current != failedSave else { return }
            attempted = current
            persistDraft()
            refreshPolicy()
            // Separate transactions: a source-policy change must not prevent saving ordinary notes.
            try learning.vocabulary.saveNotes(entryID: item.id, notes: notes, at: Date())
            if allowed { try learning.vocabulary.savePersonalSenses(entryID: item.id, senses: senses, at: Date()) }
            else if senses != persistedSenses {
                state = "笔记已保存；个人释义草稿只读保留"; return
            }
            if allowed, let updated = try learning.vocabulary.entries().first(where: { $0.id == item.id }) { senses = updated.personalSenses ?? [] }
            persistedSenses = senses; base = try Self.signature(notes, senses); state = "已自动保存"; error = nil; failedSave = nil
            if FileManager.default.fileExists(atPath: draftURL.path) { try FileManager.default.removeItem(at: draftURL) }
            learning.changed()
        } catch { failedSave = attempted; state = "未保存"; self.error = error.localizedDescription }
    }
}
@MainActor enum InputComposition {
    static func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    static var hasMarkedText: Bool {
        func marked(_ view: UIView) -> Bool {
            if view.isFirstResponder, let input = view as? any UITextInput, input.markedTextRange != nil { return true }
            return view.subviews.contains(where: marked)
        }
        return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).contains(where: marked)
    }
}
struct VocabularyDetailView: View {
    let item: VocabularyItem
    @ObservedObject var learning: LearningServices
    @StateObject private var annotation: VocabularyAnnotationModel
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var theme = "system"
    @StateObject private var speech = SystemPronunciation()
    @State private var result: DictionaryResult?
    @State private var dictionaryError: String?
    @State private var removeConfirmation = false
    @State private var choosingMeaning = false
    @State private var showingPersonalEditor: Bool
    @State private var chosenMeaningText: String?
    @State private var selection: WordLookupModel?
    @State private var relatedRoute: DictionaryRelatedRoute?
    @State private var relatedTask: Task<Void, Never>?
    @FocusState private var focusedField: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    init(item: VocabularyItem, learning: LearningServices) {
        self.item = item; self.learning = learning
        _annotation = StateObject(wrappedValue: VocabularyAnnotationModel(item: item, learning: learning))
        _showingPersonalEditor = State(initialValue: item.personalSenses?.isEmpty != false)
    }
    private var displayedResult: DictionaryResult? {
        guard var result else { return nil }
        result.personalSenses = annotation.allowed ? annotation.persistedSenses.map { $0.dictionarySense(entryID: item.id) } : []
        return result
    }
    private var displayedIPA: String? {
        if let result = displayedResult { return DictionaryPresentation.sharedIPA(result.senses + result.personalSenses) }
        return DictionaryPresentation.sharedIPA(item.dictionarySenses)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                DictionaryEntryHeader(headword: item.lemma, ipa: displayedIPA, speech: speech)
                if speech.state == .unavailable { Text("系统英语语音不可用").font(.caption).foregroundStyle(.secondary) }
                if item.surfaces != [item.lemma] { Text(item.surfaces.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                if let result = displayedResult, !result.usableSenses.isEmpty { DictionaryResultContent(result: result, onExampleWord: { token, sense, text in lookupWord(token, origin: .dictionary(headword: item.lemma, evidence: sense.line, text: text)) }, onRelatedEntry: openRelated) }
                else if let result { Label(result.hasMDXEntry ? "词典已收录，暂无中文释义" : "词典未收录，可在下方补充。", systemImage: "text.book.closed").font(.subheadline).foregroundStyle(.secondary) }
                else if dictionaryError == nil { ProgressView("正在查询英中释义…") }
                if result == nil, let cacheError = item.dictionaryCacheError { Text(cacheError).font(.caption).foregroundStyle(.secondary) }
                if let dictionaryError { Text(dictionaryError).font(.footnote).foregroundStyle(.secondary); Button("重试词典") { Task { await lookup() } } }
                if let result {
                    let available = result.reliableChinese.filter { $0.partOfSpeech?.isBlank == false }
                    if !available.isEmpty {
                        Button { choosingMeaning.toggle() } label: {
                            Label(chosenMeaningText.map { "学习义项：" + $0 } ?? "选择学习义项",
                                  systemImage: choosingMeaning ? "chevron.up" : "chevron.down")
                        }.accessibilityIdentifier("choose-review-meaning")
                        if choosingMeaning {
                            ForEach(available) { sense in
                                Button { choose(sense) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sense.zh)
                                        Text(BilingualMeaningPolicy.partName(sense.partOfSpeech)).font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                                }.accessibilityIdentifier("review-meaning-" + sense.id)
                            }
                        }
                    }
                }
                if annotation.hasDraftConflict {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("有未保存的旧草稿", systemImage: "doc.badge.clock").font(.headline)
                        Text("当前记录和旧草稿均已保留。恢复前请确认，可靠英中释义的个人内容仍只读。").font(.footnote).foregroundStyle(.secondary)
                        HStack { Button("恢复草稿") { annotation.resolveDraftConflict(restore: true) }; Button("保留当前内容") { annotation.resolveDraftConflict(restore: false) } }.buttonStyle(.bordered)
                    }.padding(16).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18)).accessibilityIdentifier("annotation-draft-conflict")
                }
                if annotation.allowed {
                    DisclosureGroup("编辑个人义项", isExpanded: $showingPersonalEditor) {
                        personalEditor.disabled(annotation.hasDraftConflict).padding(.top, 12)
                    }
                } else {
                    Label(result?.reliableChinese.isEmpty == false ? "使用 MDX 英中释义，个人释义只读" : "等待 MDX 成功验证后开放个人释义", systemImage: "checkmark.shield").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("personal-meaning-disabled")
                    if !annotation.senses.isEmpty {
                        DisclosureGroup("以前的个人释义（只读）") { ForEach(annotation.senses) { Text($0.chinese).font(.footnote) } }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("我的笔记").font(.headline)
                    TextField("记录自己的理解", text: $annotation.notes, axis: .vertical).lineLimit(3...8).focused($focusedField, equals: "notes").accessibilityIdentifier("vocabulary-notes").disabled(annotation.hasDraftConflict)
                    if !annotation.state.isEmpty { Text(annotation.state).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("annotation-save-state") }
                    if let error = annotation.error { Text(error).font(.caption).foregroundStyle(.red); Button("重试保存", action: annotation.retrySave) }
                }.padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                sourceContexts
                if let history = item.legacyAnnotations, !history.isEmpty {
                    DisclosureGroup("词形合并前的记录") {
                        ForEach(history) { record in
                            VStack(alignment: .leading, spacing: 8) { Text(record.originalLemma).font(.headline); if let meaning = record.meaning { Text(meaning) }; if let notes = record.notes { Text(notes) } }.textSelection(.enabled).padding(.vertical, 8)
                        }
                    }
                }
                Button("移出生词本", role: .destructive) { removeConfirmation = true }.font(.footnote).padding(.top, 10)
            }.padding(24)
        }.background(theme == "paper" ? LexiDawnColor.paperWarm : Color(uiColor: .systemBackground))
            .preferredColorScheme(theme == "dark" ? .dark : ["paper", "light"].contains(theme) ? .light : nil)
            .scrollDismissesKeyboard(.interactively).navigationTitle("词条").navigationBarTitleDisplayMode(.inline)
            .onChange(of: annotation.senses) { _, _ in annotation.changed(); if focusedField == nil { annotation.flush() } }
            .onChange(of: annotation.notes) { _, _ in annotation.changed() }
            .onChange(of: focusedField) { _, value in if value == nil { annotation.flush() } }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in annotation.flush() }
            .onReceive(learning.$revision) { _ in annotation.refreshPolicy() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { annotation.flush() } }
            .onDisappear { annotation.flush(); speech.stop(); relatedTask?.cancel() }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { focusedField = nil } } }
            .task {
                do { theme = try dependencies.preferencesRepository.load().readerTheme } catch { annotation.error = error.localizedDescription }
                showingPersonalEditor = annotation.state == "已恢复未保存草稿" ||
                    !annotation.persistedSenses.contains { BilingualMeaningPolicy.hasChinese($0.chinese) }
                chosenMeaningText = item.reviewMeaningText; annotation.refreshPolicy(); await lookup()
            }
            .popover(item: $selection) { WordLookupSheet(model: $0).presentationCompactAdaptation(.popover) }
            .fullScreenCover(item: $relatedRoute) { route in
                NavigationStack { DictionaryDetailView(result: route.result, context: "", learning: learning, articleID: nil, theme: theme, automaticAdditionAllowed: false,
                    contextOrigin: .dictionary(headword: item.lemma, evidence: BundledMDXDictionaryProvider.sourceName, text: nil)) }
            }
            .alert("确认移除词条", isPresented: $removeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认移除", role: .destructive) { do { annotation.flush(); try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed(); dismiss() } catch { annotation.error = error.localizedDescription } }
            } message: { Text("历史学习和复习记录保留。") }
    }
    @ViewBuilder private var sourceContexts: some View {
        let groups = VocabularyContextGroup.displayGroups(item.sourceContexts)
        if !groups.isEmpty {
            DisclosureGroup("遇见这个词的句子") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title).font(.subheadline.weight(.semibold))
                            if let source = group.sourceName { Text(source).font(.caption).foregroundStyle(.secondary) }
                            ForEach(group.contexts) { context in
                                InlineEnglishText(text: context.sentence, onWord: { lookupWord($0, origin: context.lookupOrigin.withText(context.sentence)) })
                            }
                        }
                    }
                }.padding(.top, 12)
            }
        }
    }
    private func openRelated(_ headword: String) {
        guard let result else { return }
        relatedTask?.cancel()
        relatedTask = Task {
            do {
                let value = try await learning.dictionary.subentry(headword, from: result)
                guard !Task.isCancelled else { return }
                relatedRoute = DictionaryRelatedRoute(result: value)
            } catch is CancellationError { }
            catch { if !Task.isCancelled { annotation.error = error.localizedDescription } }
        }
    }
    private var personalEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("个人英中词条").font(.headline)
                Spacer()
                Button("添加义项", systemImage: "plus") { annotation.senses.append(PersonalDictionarySense()) }.font(.subheadline)
            }
            Text("确认词性和中文释义后，可用于复习。").font(.caption).foregroundStyle(.secondary)
            if let chosenMeaningText { Text("当前学习义项：" + chosenMeaningText).font(.subheadline).foregroundStyle(.secondary) }
            ForEach($annotation.senses) { $sense in
                PersonalSenseEditor(sense: $sense, focusedField: $focusedField,
                    moveUp: { moveSense(sense.id, delta: -1) }, moveDown: { moveSense(sense.id, delta: 1) },
                    remove: { focusedField = nil; annotation.senses.removeAll { $0.id == sense.id } },
                    select: { choosePersonal(sense.id) })
            }
        }
    }
    private func moveSense(_ id: String, delta: Int) {
        guard let index = annotation.senses.firstIndex(where: { $0.id == id }), annotation.senses.indices.contains(index + delta) else { return }
        annotation.senses.swapAt(index, index + delta)
    }
    private func lookup() async {
        do { result = try await learning.dictionary.lookupCanonical(item.lemma); dictionaryError = nil; annotation.refreshPolicy() }
        catch { result = nil; dictionaryError = error.localizedDescription; annotation.refreshPolicy() }
    }
    private func choose(_ sense: DictionarySense) {
        do { try learning.vocabulary.confirmReviewMeaning(entryID: item.id, sourceSenseID: sense.id); chosenMeaningText = sense.zh; choosingMeaning = false; learning.changed() }
        catch { annotation.error = error.localizedDescription }
    }
    private func choosePersonal(_ senseID: String) {
        focusedField = nil; annotation.flush()
        guard annotation.error == nil else { return }
        do {
            guard let current = try learning.vocabulary.entries().first(where: { $0.id == item.id }),
                  let sense = current.personalSenses?.first(where: { $0.id == senseID && $0.reviewReady }) else { throw LearningError.invalid("请先保存并确认这一义项。") }
            choose(sense.dictionarySense(entryID: item.id))
        } catch { annotation.error = error.localizedDescription }
    }
    private func lookupWord(_ token: EnglishToken, origin: VocabularyContextOrigin) {
        selection = WordLookupModel(token: token, articleID: item.sourceArticleID, autoAdd: false, learning: learning, depth: 1, origin: origin)
    }
}

private struct PersonalSenseEditor: View {
    @Binding var sense: PersonalDictionarySense
    @FocusState.Binding var focusedField: String?
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void
    let select: () -> Void
    @State private var showingDetails = false
    private func optional(_ path: WritableKeyPath<PersonalDictionarySense, String?>) -> Binding<String> {
        Binding(get: { sense[keyPath: path] ?? "" }, set: { sense[keyPath: path] = $0.isBlank ? nil : $0 })
    }
    private func lines(_ path: WritableKeyPath<PersonalDictionarySense, [String]?>) -> Binding<String> {
        Binding(get: { (sense[keyPath: path] ?? []).joined(separator: "\n") }, set: { sense[keyPath: path] = $0.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("义项 · 版本 \(sense.revision)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: moveUp) { Image(systemName: "arrow.up").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("义项上移")
                Button(action: moveDown) { Image(systemName: "arrow.down").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("义项下移")
                Button(role: .destructive, action: remove) { Image(systemName: "trash").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("删除义项，保留历史")
            }
            Picker("词性", selection: $sense.partOfSpeech) {
                Text("待补充").tag("")
                ForEach(BilingualMeaningPolicy.parts, id: \.self) { Text(BilingualMeaningPolicy.partName($0)).tag($0) }
            }.accessibilityIdentifier("personal-part-of-speech")
            if sense.reviewReady { Button("用这一义项复习", action: select).buttonStyle(.bordered).accessibilityIdentifier("personal-select-" + sense.id) }
            TextField("中文释义", text: $sense.chinese, axis: .vertical).focused($focusedField, equals: sense.id + "zh").accessibilityIdentifier("personal-meaning")
            TextField("英文解释（可选）", text: optional(\.englishDefinition), axis: .vertical).focused($focusedField, equals: sense.id + "en")
            DisclosureGroup("语法、搭配和更多", isExpanded: $showingDetails) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("语法标签（可选）", text: optional(\.grammar)).focused($focusedField, equals: sense.id + "grammar")
                    TextField("音标（可选）", text: $sense.ipa).focused($focusedField, equals: sense.id + "ipa")
                    TextField("用法 / 语域（可选）", text: $sense.usage).focused($focusedField, equals: sense.id + "usage")
                    TextField("使用场景（可选）", text: optional(\.scenarios), axis: .vertical).focused($focusedField, equals: sense.id + "scenarios")
                    TextField("词形变化（可选）", text: $sense.forms).focused($focusedField, equals: sense.id + "forms")
                    TextField("常见短语（可选）", text: $sense.phrases, axis: .vertical).focused($focusedField, equals: sense.id + "phrases")
                    TextField("固定搭配，每行一条", text: lines(\.collocations), axis: .vertical).focused($focusedField, equals: sense.id + "collocations")
                    TextField("习语，每行一条", text: lines(\.idioms), axis: .vertical).focused($focusedField, equals: sense.id + "idioms")
                }.padding(.top, 10)
            }.font(.subheadline).accessibilityIdentifier("personal-more-" + sense.id)
            ForEach($sense.examples) { $example in
                PersonalExampleEditor(example: $example, focusedField: $focusedField, remove: { sense.examples.removeAll { $0.id == example.id } })
            }
            Button("添加例句", systemImage: "plus.circle") { sense.examples.append(PersonalDictionaryExample()) }
            TextField("义项备注（可选）", text: optional(\.notes), axis: .vertical).focused($focusedField, equals: sense.id + "notes")
            Toggle("确认作为学习义项", isOn: $sense.confirmed).font(.subheadline)
        }.textFieldStyle(.roundedBorder).padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
    }
}
private struct PersonalExampleEditor: View {
    @Binding var example: PersonalDictionaryExample
    @FocusState.Binding var focusedField: String?
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("英文例句", text: $example.english, axis: .vertical).focused($focusedField, equals: example.id + "en").textInputAutocapitalization(.sentences)
            TextField("例句译文（可选）", text: $example.chinese, axis: .vertical).focused($focusedField, equals: example.id + "zh")
            TextField("例句备注（可选）", text: Binding(get: { example.notes ?? "" }, set: { example.notes = $0 }), axis: .vertical).focused($focusedField, equals: example.id + "notes")
            Button("删除这条例句", role: .destructive, action: remove).font(.caption)
        }.padding(.leading, 12)
    }
}
