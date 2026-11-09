import SwiftUI
import UIKit

private struct SettingsDraft: Codable {
    let base: String
    let name: String, age: String, goal: String, topics: String
    let fontSize: Double, lineSpacing: Double
    let theme: String, autoAdd: Bool, dailyLimit: Int, timezonePolicy: String, fixedTimezone: String
}
struct LearningSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var learning: LearningServices
    @State private var name = ""
    @State private var age = ""
    @State private var goal = ""
    @State private var topics = ""
    @State private var fontSize = 19.0
    @State private var lineSpacing = 1.5
    @State private var theme = "system"
    @State private var autoAdd = true
    @State private var dailyLimit = 12
    @State private var timezonePolicy = "device"
    @State private var fixedTimezone = "Asia/Shanghai"
    @State private var message: String?
    @State private var saveFailed = false
    @State private var loaded = false
    @State private var savedSignature = ""
    @State private var draftConflict: SettingsDraft?
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    @State private var cacheKind: String?
    var body: some View {
        NavigationStack {
            Form {
                if draftConflict != nil {
                    Section("恢复未保存设置") {
                        Text("发现另一版本的设置草稿。当前设置与草稿均保留，请选择要继续使用的版本。").font(.footnote)
                        Button("恢复设置草稿") { resolveConflict(restore: true) }
                        Button("保留当前设置") { resolveConflict(restore: false) }
                    }
                }
                Section("个人资料") {
                    TextField("昵称", text: $name).accessibilityIdentifier("settings-name")
                    Picker("年龄段（可选）", selection: $age) { Text("不填写").tag(""); Text("未满 18 岁").tag("under18"); Text("18–24 岁").tag("18-24"); Text("25–44 岁").tag("25-44"); Text("45 岁及以上").tag("45+") }
                    TextField("学习目标", text: $goal)
                    TextField("兴趣主题（逗号分隔）", text: $topics)
                }
                Section("阅读与查词") {
                    Stepper("字号：\(Int(fontSize)) pt", value: $fontSize, in: 14...32)
                    Slider(value: $lineSpacing, in: 1.2...2.0, step: 0.05, onEditingChanged: { editing in if !editing { saveTask?.cancel(); save() } }).accessibilityLabel("阅读行距")
                    Text("行距：\(lineSpacing, specifier: "%.2f")")
                    Picker("阅读主题", selection: $theme) { Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark"); Text("暖纸色").tag("paper") }.accessibilityIdentifier("reader-theme")
                    Toggle("点击单词自动加入生词本", isOn: $autoAdd).accessibilityIdentifier("auto-add")
                }
                Section("复习与学习日期") {
                    Stepper("每日复习上限：\(dailyLimit)", value: $dailyLimit, in: 1...100)
                    Picker("学习时区", selection: $timezonePolicy) { Text("跟随设备").tag("device"); Text("固定时区").tag("fixed") }
                    if timezonePolicy == "fixed" { TextField("IANA 时区，例如 Asia/Shanghai", text: $fixedTimezone).textInputAutocapitalization(.never) }
                    Text("原周期分配日期与时区保持不变；新设置只影响以后判断本地学习日期。题组创建后保留原题量。").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if let message { Text(message).font(.footnote).accessibilityIdentifier("settings-message") }
                    if saveFailed { Button("重试保存设置", action: save) }
                }
                Section("本地缓存") {
                    Button("清理未使用的文章缓存") { cacheKind = "article" }
                    Button("清理词典缓存") { cacheKind = "dictionary" }
                    Text("阅读历史、未完成周期、生词、笔记、收藏、稍后阅读和个人导入都保留。词典缓存可从内置 MDX 重建。").font(.footnote)
                    if let message { Text(message).font(.footnote) }
                }
                Section("关于与许可") {
                    NavigationLink("关于词光") { AboutLexiDawnView(licenseText: licenseText) }.accessibilityIdentifier("about-lexidawn")
                    NavigationLink("内容与词典许可") { SourceLicensesView(bundledNotices: licenseText) }
                }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("我的").task { load() }
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { InputComposition.dismissKeyboard(); save() } } }
                .onChange(of: signature) { _, _ in scheduleSave() }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in save() }
                .onChange(of: scenePhase) { _, phase in if phase != .active { saveTask?.cancel(); save() } }
                .onDisappear { saveTask?.cancel(); save() }
                .confirmationDialog("确认清理可重新取得的缓存？", isPresented: Binding(get: { cacheKind != nil }, set: { if !$0 { cacheKind = nil } })) {
                    if cacheKind == "article" { Button("确认清理文章缓存", role: .destructive) { clearCache(kind: "article") } }
                    else { Button("确认清理词典缓存", role: .destructive) { clearCache(kind: "dictionary") } }
                    Button("取消", role: .cancel) { cacheKind = nil }
                }
        }
    }
    private var licenseText: String { guard let url = Bundle.main.url(forResource: "CONTENT-LICENSES", withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return "许可资源读取失败，请核对安装包。" }; return text }
    private func clearCache(kind: String) {
        do {
            let count = try kind == "article" ? learning.content.clearUnusedArticleCache() : learning.dictionary.clearCaches()
            message = "已清理 \(count) 项可重新取得的缓存；学习记录保留。"; learning.changed()
        } catch { message = error.localizedDescription }
        cacheKind = nil
    }
    private func load() {
        do {
            let prefs = try dependencies.preferencesRepository.load()
            name = prefs.displayName; age = prefs.ageRange ?? ""; goal = prefs.learningGoal; topics = prefs.interestTopics.joined(separator: ", ")
            fontSize = prefs.readerFontSize; lineSpacing = prefs.readerLineSpacing; theme = prefs.readerTheme
            autoAdd = prefs.autoAddOnWordTap; dailyLimit = prefs.dailyReviewLimit; timezonePolicy = prefs.timeZonePolicy; fixedTimezone = prefs.fixedTimeZoneID ?? "Asia/Shanghai"
            savedSignature = signature; loaded = true
            if FileManager.default.fileExists(atPath: draftURL.path) {
                let draft = try JSONDecoder().decode(SettingsDraft.self, from: Data(contentsOf: draftURL))
                if draft.base == savedSignature { apply(draft); message = "已恢复未保存设置"; scheduleSave() }
                else { draftConflict = draft; message = "设置草稿等待核对" }
            }
        } catch { message = error.localizedDescription }
    }
    private var signature: String {
        [name, age, goal, topics, String(fontSize), String(lineSpacing), theme, String(autoAdd), String(dailyLimit), timezonePolicy, fixedTimezone].joined(separator: "|\u{001f}|")
    }
    private var draftURL: URL { URL.applicationSupportDirectory.appendingPathComponent("LexiDawn/settings-draft.json") }
    private func apply(_ draft: SettingsDraft) {
        name = draft.name; age = draft.age; goal = draft.goal; topics = draft.topics
        fontSize = draft.fontSize; lineSpacing = draft.lineSpacing; theme = draft.theme; autoAdd = draft.autoAdd
        dailyLimit = draft.dailyLimit; timezonePolicy = draft.timezonePolicy; fixedTimezone = draft.fixedTimezone
    }
    private func checkpoint() {
        guard draftConflict == nil else { return }
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let draft = SettingsDraft(base: savedSignature, name: name, age: age, goal: goal, topics: topics, fontSize: fontSize, lineSpacing: lineSpacing, theme: theme, autoAdd: autoAdd, dailyLimit: dailyLimit, timezonePolicy: timezonePolicy, fixedTimezone: fixedTimezone)
            try JSONEncoder().encode(draft).write(to: draftURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { message = "设置草稿尚未保存：" + error.localizedDescription }
    }
    private func resolveConflict(restore: Bool) {
        guard let draft = draftConflict else { return }
        do {
            let archive = draftURL.deletingPathExtension().appendingPathExtension("conflict-" + UUID().uuidString + ".json")
            try FileManager.default.copyItem(at: draftURL, to: archive)
            try FileManager.default.removeItem(at: draftURL)
            draftConflict = nil
            if restore { apply(draft); save() } else { message = "已保留当前设置，旧草稿已存档" }
        } catch { message = "草稿仍保留：" + error.localizedDescription }
    }
    private func scheduleSave() {
        guard loaded, draftConflict == nil, signature != savedSignature else { return }
        checkpoint()
        saveFailed = false
        saveTask?.cancel()
        saveTask = Task {
            do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation(); save() } catch { }
        }
    }
    private func save() {
        guard loaded, draftConflict == nil, signature != savedSignature else { return }
        checkpoint()
        guard !InputComposition.hasMarkedText else { return }
        do {
            guard name.count <= 80, goal.count <= 200, topics.count <= 500 else { throw LearningError.invalid("昵称、目标或主题过长。") }
            let prefs = try dependencies.preferencesRepository.load()
            prefs.displayName = name; prefs.ageRange = age.isEmpty ? nil : age; prefs.learningGoal = goal
            prefs.interestTopics = topics.components(separatedBy: CharacterSet(charactersIn: ",，")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            prefs.readerFontSize = fontSize; prefs.readerLineSpacing = lineSpacing; prefs.readerTheme = theme; prefs.autoAddOnWordTap = autoAdd
            prefs.dailyReviewLimit = dailyLimit; prefs.timeZonePolicy = timezonePolicy; prefs.fixedTimeZoneID = timezonePolicy == "fixed" ? fixedTimezone : nil
            try dependencies.preferencesRepository.save(prefs); savedSignature = signature; learning.changed(); message = "已自动保存"; saveFailed = false
            if FileManager.default.fileExists(atPath: draftURL.path) { try FileManager.default.removeItem(at: draftURL) }
        } catch { message = error.localizedDescription; saveFailed = true }
    }
}


struct AboutLexiDawnView: View {
    let licenseText: String
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sunrise.fill").font(.largeTitle).foregroundStyle(LexiDawnColor.dawn500)
                    Text("LexiDawn · 词光").font(.system(.title, design: .serif).bold())
                    Text("在真实阅读里，慢慢积累自己的词汇。").foregroundStyle(.secondary)
                }.padding(.vertical, 16)
            }
            Section {
                LabeledContent("开发者", value: "Why Haoyu").accessibilityIdentifier("about-developer")
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知")
                LabeledContent("构建", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知")
            }
            Section { NavigationLink("内容与词典许可") { SourceLicensesView(bundledNotices: licenseText) } }
        }.navigationTitle("关于词光").navigationBarTitleDisplayMode(.inline)
    }
}
