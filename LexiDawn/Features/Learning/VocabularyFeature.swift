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
    @State private var exportFile: VocabularyExportFile?
    @State private var cleanupExport: VocabularyExportFile?
    @State private var exportNotice: String?
    private let exportFiles = VocabularyExportFileService()
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
                            if let meaning = item.meaning { Text("个人释义：\(meaning)").font(.subheadline) }
                            else if let meaning = item.dictionaryMeanings.first { Text("可能对应：\(meaning)").font(.subheadline) }
                            Text("\(item.type == "word" ? "单词" : "短语") · \(item.addedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            if let due = item.dueAt { Text("下次复习：" + due.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                            if let last = item.lastReviewedAt { Text("最近复习：" + last.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }.accessibilityIdentifier("vocabulary-entry-\(item.lemma)").swipeActions { Button("移除", role: .destructive) { removing = item } }
                }
                if let error { Text(error).foregroundStyle(.red); Button("重新读取", action: load) }
            }.safeAreaInset(edge: .top) {
                if let exportNotice {
                    Text(exportNotice).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding()
                        .background(.regularMaterial).accessibilityIdentifier("vocabulary-export-completed")
                }
            }.searchable(text: $search, prompt: "搜索词形、lemma 或已缓存中文释义")
                .navigationTitle("生词本").task { load() }.onReceive(learning.$revision) { _ in load() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in load() }
                .toolbar { Menu("导出生词", systemImage: "square.and.arrow.up") { Button("导出 JSON（完整学习数据）") { prepareExport(.json) }; Button("导出 CSV") { prepareExport(.csv) } }.accessibilityIdentifier("vocabulary-export") }
                .sheet(item: $exportFile, onDismiss: clearExport) { file in
                    VocabularyExportPicker(file: file) { destination in
                        guard exportFile?.id == file.id else { return }
                        if let destination { exportNotice = "已导出 " + destination.lastPathComponent }
                        exportFile = nil
                    }.presentationDetents([.large])
                }
                .alert("确认移除生词？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                    Button("取消", role: .cancel) { removing = nil }
                    Button("移除", role: .destructive) { if let item = removing { do { try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed() } catch { self.error = error.localizedDescription } }; removing = nil }
                } message: { Text("这是你主动移除的操作。历史学习与复习日志保留；复习成功不会自动删除词条。") }
        }
    }
    private func load() { do { allItems = try learning.vocabulary.entries(); now = Date(); error = nil } catch { self.error = error.localizedDescription } }
    private func prepareExport(_ format: VocabularyExportFormat) {
        guard exportFile == nil, cleanupExport == nil else { return }
        exportNotice = nil
        do {
            let file = try exportFiles.prepare(learning.vocabulary.export(format, at: Date()), format: format)
            cleanupExport = file; exportFile = file; error = nil
        }
        catch { self.error = error.localizedDescription }
    }
    private func clearExport() {
        guard let file = cleanupExport else { return }
        defer { cleanupExport = nil }
        do { try exportFiles.discard(file) } catch { self.error = error.localizedDescription }
    }
}

/// Public UIKit export API receives an existing file, never a changing optional document.
struct VocabularyExportPicker: UIViewControllerRepresentable {
    let file: VocabularyExportFile
    let finished: (URL?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }
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
        cancel.addAction(UIAction { _ in finished(nil) }, for: .touchUpInside)
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
struct VocabularyDetailView: View {
    let item: VocabularyItem
    @ObservedObject var learning: LearningServices
    @State private var meaning = ""
    @State private var notes = ""
    @State private var result: DictionaryResult?
    @State private var error: String?
    @State private var saved = false
    @State private var saveError: String?
    @State private var dictionaryError: String?
    @State private var selectedMeaningSaved = false
    @State private var selectedMeaningError: String?
    @State private var choosingMeaning = false
    @State private var chosenMeaningText: String?
    @State private var removeConfirmation = false
    @State private var source: ArticleLibraryItem?
    @FocusState private var editing: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section { Text(item.lemma).font(.largeTitle.bold()); Text(item.surfaces.joined(separator: " · ")) }
            Section("你的释义与笔记") {
                TextField("个人中文释义（非词典原文）", text: $meaning).focused($editing).submitLabel(.done).onSubmit { editing = false }.accessibilityIdentifier("personal-meaning")
                TextField("笔记", text: $notes, axis: .vertical).focused($editing).accessibilityIdentifier("vocabulary-notes")
                if let saveError { Text(saveError).foregroundStyle(.red); Button("重试保存释义与笔记", action: save) }
                if saved { Label("已保存", systemImage: "checkmark.circle") }
                Text("来源没有可用中文对应词时，可填写自己的释义用于复习。个人内容与开放词典数据明确区分。").font(.caption).foregroundStyle(.secondary)
            }
            if let result {
                Section("复习用义项") {
                    if let selected = chosenMeaningText { Text("已确认：" + selected).font(.subheadline) }
                    Text("可明确选择词典中的中文义项用于以后新题组。修改个人释义后改用个人释义；已保存题组保持原答案。").font(.caption).foregroundStyle(.secondary)
                    if selectedMeaningSaved { Label("复习义项已保存", systemImage: "checkmark.circle") }
                    Button { choosingMeaning.toggle() } label: { Label("选择词典中文义项", systemImage: choosingMeaning ? "chevron.up" : "chevron.down") }
                        .accessibilityIdentifier("choose-review-meaning").accessibilityValue(choosingMeaning ? "已展开" : "已收起")
                    if choosingMeaning {
                        ForEach(result.senses.filter { !$0.zh.isEmpty }) { sense in
                            Button(sense.zh) {
                                do { try learning.vocabulary.confirmReviewMeaning(entryID: item.id, sourceSenseID: sense.id); selectedMeaningSaved = true; choosingMeaning = false; chosenMeaningText = sense.zh; selectedMeaningError = nil; learning.changed() }
                                catch { selectedMeaningSaved = false; selectedMeaningError = error.localizedDescription }
                            }.accessibilityIdentifier("review-meaning-" + sense.id)
                        }
                    }
                    if let selectedMeaningError { Text(selectedMeaningError).foregroundStyle(.red) }
                }
                DictionaryResultContent(result: result)
                NavigationLink("详细词典") { DictionaryDetailView(result: result, context: item.contexts.first ?? "", learning: learning, articleID: item.sourceArticleID, contextOrigin: item.sourceContexts.first?.lookupOrigin ?? .reader) }
            }
            Section("来源上下文") {
                if let source {
                    if item.sourceContexts.first?.originKind == "dictionary" { Text("关联的阅读文章").font(.caption).foregroundStyle(.secondary) }
                    Text(source.title).font(.headline); Text(source.source).font(.caption).foregroundStyle(.secondary)
                    if let attribution = source.originalURL { Text(attribution).font(.caption).textSelection(.enabled) }
                }
                ForEach(item.sourceContexts) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        if context.originKind == nil || context.originKind == "historical" { Text("历史上下文 · 来源类型未记录").font(.caption).foregroundStyle(.secondary) }
                        Text(context.title).font(.headline)
                        Text(context.attribution).font(.caption).foregroundStyle(.secondary)
                        Text(context.sentence)
                        if let attribution = context.originalURL { Text(attribution).font(.caption).textSelection(.enabled) }
                    }
                }
            }
            Section { Button("手动移除词条", role: .destructive) { removeConfirmation = true } }
            if let error { Text(error).foregroundStyle(.red) }
            if let dictionaryError { Text(dictionaryError).foregroundStyle(.red); Button("重试词典") { Task { await lookup() } } }
        }.scrollDismissesKeyboard(.interactively).navigationTitle(item.lemma).navigationBarTitleDisplayMode(.inline)
            .onChange(of: meaning) { _, _ in saved = false; selectedMeaningSaved = false }.onChange(of: notes) { _, _ in saved = false }
            .toolbar {
                // Keep the single save action reachable above the keyboard, including
                // on SE where a Form row can be obscured by the input accessory.
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .accessibilityLabel("保存个人释义与笔记")
                        .accessibilityIdentifier("save-vocabulary-annotation")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { editing = false } }
            }
            .task {
                meaning = item.meaning ?? ""; notes = item.notes ?? ""; chosenMeaningText = item.reviewMeaningText
                do { source = try learning.content.library().first { $0.id == item.sourceArticleID } } catch { self.error = error.localizedDescription }
                await lookup()
            }
            .alert("确认移除词条", isPresented: $removeConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认移除", role: .destructive) { do { try learning.vocabulary.remove(entryID: item.id, at: Date()); learning.changed(); dismiss() } catch { self.error = error.localizedDescription } }
            } message: { Text("仅由本次明确操作移除，复习状态和历史日志保留。") }
    }
    private func save() {
        saved = false; editing = false
        do { try learning.vocabulary.annotate(entryID: item.id, meaning: meaning, notes: notes, at: Date()); chosenMeaningText = try learning.vocabulary.find(surface: item.lemma)?.reviewMeaningText; saved = true; saveError = nil; learning.changed() }
        catch { saveError = error.localizedDescription }
    }
    private func lookup() async { do { result = try await learning.dictionary.lookup(item.lemma); dictionaryError = nil } catch { self.dictionaryError = error.localizedDescription } }
}

