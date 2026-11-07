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
                            if !item.partsOfSpeech.isEmpty { Text(item.partsOfSpeech.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
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
            }.searchable(text: $search, prompt: "搜索词形、lemma 或已缓存中文释义")
                .navigationTitle("生词本").task { load() }.onReceive(learning.$revision) { _ in load() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in load() }
                .toolbar { Menu("导出生词", systemImage: "square.and.arrow.up") { Button("导出 JSON（完整学习数据）") { prepareExport(.json) }; Button("导出 CSV") { prepareExport(.csv) } }.accessibilityIdentifier("vocabulary-export") }
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
    private let item: VocabularyItem
    private let learning: LearningServices
    private var base: String
    private var persistedSenses: [PersonalDictionarySense]
    private var checkpoint: Task<Void, Never>?
    private var ready = false
    private var draftURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("LexiDawn/annotation-drafts", isDirectory: true).appendingPathComponent(item.id + ".json")
    }
    private static func signature(_ notes: String, _ senses: [PersonalDictionarySense]) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return fingerprint(notes + String(decoding: (try? encoder.encode(senses)) ?? Data(), as: UTF8.self))
    }
    init(item: VocabularyItem, learning: LearningServices) {
        self.item = item; self.learning = learning
        let initial = item.personalSenses ?? item.meaning.map { [PersonalDictionarySense(chinese: $0)] } ?? []
        senses = initial; persistedSenses = initial; notes = item.notes ?? ""; allowed = item.reliableChineseKnown != true
        base = Self.signature(item.notes ?? "", initial)
        do {
            if FileManager.default.fileExists(atPath: draftURL.path) {
                let draft = try JSONDecoder().decode(VocabularyDraft.self, from: Data(contentsOf: draftURL))
                if draft.entryID == item.id, draft.base == base { senses = draft.senses; notes = draft.notes; state = "已恢复未保存草稿" }
                else { error = "发现与当前版本不同的草稿，已保留，请先核对当前内容。" }
            }
        } catch { self.error = "草稿读取失败：" + error.localizedDescription }
        ready = true
    }
    func refreshPolicy() {
        do { allowed = try learning.vocabulary.personalEditingAllowed(entryID: item.id) }
        catch { allowed = false; self.error = error.localizedDescription }
    }
    func changed() {
        guard ready else { return }; state = "尚未保存"
        checkpoint?.cancel()
        checkpoint = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)); try Task.checkCancellation(); self?.persistDraft() } catch { }
        }
    }
    private func persistDraft() {
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(VocabularyDraft(entryID: item.id, base: base, notes: notes, senses: senses)).write(to: draftURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = "草稿尚未保存：" + error.localizedDescription }
    }
    func flush() {
        guard ready, !InputComposition.hasMarkedText else { persistDraft(); return }
        checkpoint?.cancel()
        guard Self.signature(notes, senses) != base else { return }
        persistDraft()
        do {
            refreshPolicy()
            // Separate transactions: a source-policy change must not prevent saving ordinary notes.
            try learning.vocabulary.saveNotes(entryID: item.id, notes: notes, at: Date())
            if allowed { try learning.vocabulary.savePersonalSenses(entryID: item.id, senses: senses, at: Date()) }
            else if senses != persistedSenses {
                state = "笔记已保存；个人释义草稿只读保留"; return
            }
            persistedSenses = senses; base = Self.signature(notes, senses); state = "已自动保存"; error = nil
            if FileManager.default.fileExists(atPath: draftURL.path) { try FileManager.default.removeItem(at: draftURL) }
            learning.changed()
        } catch { state = "未保存"; self.error = error.localizedDescription }
    }
}
@MainActor enum InputComposition {
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
    @State private var result: DictionaryResult?
    @State private var dictionaryError: String?
    @State private var removeConfirmation = false
    @State private var choosingMeaning = false
    @State private var chosenMeaningText: String?
    @State private var selection: WordLookupModel?
    @FocusState private var focusedField: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    init(item: VocabularyItem, learning: LearningServices) {
        self.item = item; self.learning = learning
        _annotation = StateObject(wrappedValue: VocabularyAnnotationModel(item: item, learning: learning))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(item.lemma).font(.system(.largeTitle, design: .serif).weight(.semibold))
                if item.surfaces != [item.lemma] { Text(item.surfaces.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                if let result { DictionaryResultContent(result: result, onExampleWord: { token, sense in lookupWord(token, origin: .dictionary(headword: item.lemma, evidence: sense.line, text: token.sentence)) }) }
                else if dictionaryError == nil { ProgressView("正在查询英中释义…") }
                if let dictionaryError { Text(dictionaryError).font(.footnote).foregroundStyle(.secondary); Button("重试词典") { Task { await lookup() } } }
                if let result, !result.usableSenses.isEmpty {
                    DisclosureGroup(isExpanded: $choosingMeaning) {
                        ForEach(result.usableSenses) { sense in
                            Button { choose(sense) } label: { VStack(alignment: .leading, spacing: 4) { Text(sense.zh); Text(BilingualMeaningPolicy.partName(sense.partOfSpeech)).font(.caption).foregroundStyle(.secondary) } }.accessibilityIdentifier("review-meaning-" + sense.id)
                        }
                    } label: { Text(chosenMeaningText.map { "学习义项：" + $0 } ?? "选择学习义项") }.accessibilityIdentifier("choose-review-meaning")
                }
                if annotation.allowed {
                    personalEditor
                } else {
                    Label("使用可靠英中释义", systemImage: "checkmark.shield").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("personal-meaning-disabled")
                    if !annotation.senses.isEmpty {
                        DisclosureGroup("以前的个人释义（只读）") { ForEach(annotation.senses) { Text($0.chinese).font(.footnote) } }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("我的笔记").font(.headline)
                    TextField("记录自己的理解", text: $annotation.notes, axis: .vertical).lineLimit(3...8).focused($focusedField, equals: "notes").accessibilityIdentifier("vocabulary-notes")
                    if !annotation.state.isEmpty { Text(annotation.state).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("annotation-save-state") }
                    if let error = annotation.error { Text(error).font(.caption).foregroundStyle(.red); Button("重试保存", action: annotation.flush) }
                }.padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                if !item.sourceContexts.isEmpty {
                    DisclosureGroup("遇见这个词的句子") {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(Set(item.sourceContexts.map(\.articleID))).sorted(), id: \.self) { articleID in
                                let contexts = item.sourceContexts.filter { $0.articleID == articleID }
                                if let first = contexts.first { Text(first.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                                ForEach(contexts) { context in InlineEnglishText(text: context.sentence, onWord: { lookupWord($0, origin: context.lookupOrigin.withText(context.sentence)) }) }
                            }
                        }.padding(.top, 12)
                    }
                }
                Button("移出生词本", role: .destructive) { removeConfirmation = true }.font(.footnote).padding(.top, 10)
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively).navigationTitle("词条").navigationBarTitleDisplayMode(.inline)
            .onChange(of: annotation.senses) { _, _ in annotation.changed(); if focusedField == nil { annotation.flush() } }
            .onChange(of: annotation.notes) { _, _ in annotation.changed() }
            .onChange(of: focusedField) { _, value in if value == nil { annotation.flush() } }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in annotation.flush() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { annotation.flush() } }
            .onDisappear { annotation.flush() }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { focusedField = nil } } }
            .task { chosenMeaningText = item.reviewMeaningText; annotation.refreshPolicy(); await lookup() }
            .popover(item: $selection) { WordLookupSheet(model: $0).presentationCompactAdaptation(.popover) }
            .alert("确认移除词条", isPresented: $removeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认移除", role: .destructive) { do { annotation.flush(); try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed(); dismiss() } catch { annotation.error = error.localizedDescription } }
            } message: { Text("历史学习和复习记录保留。") }
    }
    private var personalEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("个人英中词条").font(.headline); Spacer(); Button("添加义项", systemImage: "plus") { annotation.senses.append(PersonalDictionarySense()) }.font(.subheadline) }
            Text("当前没有可用的可靠英中释义，可明确录入个人词义。词性和中文确认后用于新复习，已有题目保持原答案。").font(.caption).foregroundStyle(.secondary)
            ForEach($annotation.senses) { $sense in
                VStack(alignment: .leading, spacing: 12) {
                    Picker("词性", selection: $sense.partOfSpeech) { Text("待补充").tag(""); ForEach(BilingualMeaningPolicy.parts, id: \.self) { Text(BilingualMeaningPolicy.partName($0)).tag($0) } }.accessibilityIdentifier("personal-part-of-speech")
                    TextField("中文释义", text: $sense.chinese, axis: .vertical).focused($focusedField, equals: sense.id + "zh").accessibilityIdentifier("personal-meaning")
                    TextField("音标（可选）", text: $sense.ipa).focused($focusedField, equals: sense.id + "ipa")
                    TextField("用法 / 语域（可选）", text: $sense.usage).focused($focusedField, equals: sense.id + "usage")
                    TextField("词形变化（可选）", text: $sense.forms).focused($focusedField, equals: sense.id + "forms")
                    TextField("搭配 / 短语（可选）", text: $sense.phrases).focused($focusedField, equals: sense.id + "phrases")
                    ForEach($sense.examples) { $example in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("英文例句", text: $example.english, axis: .vertical).focused($focusedField, equals: example.id + "en").textInputAutocapitalization(.sentences)
                            TextField("例句译文（可选）", text: $example.chinese, axis: .vertical).focused($focusedField, equals: example.id + "zh")
                        }.padding(.leading, 12)
                    }
                    Button("添加例句", systemImage: "plus.circle") { sense.examples.append(PersonalDictionaryExample()) }
                    Toggle("确认作为学习义项", isOn: $sense.confirmed).font(.subheadline)
                }.textFieldStyle(.roundedBorder).padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
    private func lookup() async {
        do { result = try await learning.dictionary.lookup(item.lemma, context: item.contexts.first ?? ""); dictionaryError = nil; annotation.refreshPolicy() }
        catch { dictionaryError = error.localizedDescription }
    }
    private func choose(_ sense: DictionarySense) {
        do { try learning.vocabulary.confirmReviewMeaning(entryID: item.id, sourceSenseID: sense.id); chosenMeaningText = sense.zh; choosingMeaning = false; learning.changed() }
        catch { annotation.error = error.localizedDescription }
    }
    private func lookupWord(_ token: EnglishToken, origin: VocabularyContextOrigin) {
        guard let articleID = item.sourceArticleID else { return }
        selection = WordLookupModel(token: token, articleID: articleID, autoAdd: false, learning: learning, depth: 1, origin: origin)
    }
}
