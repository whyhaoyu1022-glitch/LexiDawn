import SwiftUI

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
    var body: some View {
        NavigationStack {
            Form {
                Section("个人资料") {
                    TextField("昵称", text: $name).accessibilityIdentifier("settings-name")
                    Picker("年龄段（可选）", selection: $age) { Text("不填写").tag(""); Text("未满 18 岁").tag("under18"); Text("18–24 岁").tag("18-24"); Text("25–44 岁").tag("25-44"); Text("45 岁及以上").tag("45+") }
                    TextField("学习目标", text: $goal)
                    TextField("兴趣主题（逗号分隔）", text: $topics)
                }
                Section("阅读与查词") {
                    Stepper("字号：\(Int(fontSize)) pt", value: $fontSize, in: 14...32)
                    Slider(value: $lineSpacing, in: 1.2...2.0, step: 0.05) { Text("阅读行距") }
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
                    Button("保存设置", action: save).accessibilityIdentifier("save-settings")
                    if let message { Text(message).font(.footnote).accessibilityIdentifier("settings-message") }
                }
                Section("关于与许可") {
                    Text("通知与 AI 功能准备中，目前没有安排系统通知，也不上传阅读历史。")
                    NavigationLink("内容与词典许可") { ScrollView { Text(licenseText).font(.footnote).textSelection(.enabled).padding() }.navigationTitle("来源与许可") }
                }
            }.navigationTitle("我的").task { load() }
        }
    }
    private var licenseText: String { guard let url = Bundle.main.url(forResource: "CONTENT-LICENSES", withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return "许可资源读取失败，请核对安装包。" }; return text }
    private func load() {
        do {
            let prefs = try dependencies.preferencesRepository.load()
            name = prefs.displayName; age = prefs.ageRange ?? ""; goal = prefs.learningGoal; topics = prefs.interestTopics.joined(separator: ", ")
            fontSize = prefs.readerFontSize; lineSpacing = prefs.readerLineSpacing; theme = prefs.readerTheme
            autoAdd = prefs.autoAddOnWordTap; dailyLimit = prefs.dailyReviewLimit; timezonePolicy = prefs.timeZonePolicy; fixedTimezone = prefs.fixedTimeZoneID ?? "Asia/Shanghai"
        } catch { message = error.localizedDescription }
    }
    private func save() {
        do {
            guard name.count <= 80, goal.count <= 200, topics.count <= 500 else { throw LearningError.invalid("昵称、目标或主题过长。") }
            let prefs = try dependencies.preferencesRepository.load()
            prefs.displayName = name; prefs.ageRange = age.isEmpty ? nil : age; prefs.learningGoal = goal
            prefs.interestTopics = topics.components(separatedBy: CharacterSet(charactersIn: ",，")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            prefs.readerFontSize = fontSize; prefs.readerLineSpacing = lineSpacing; prefs.readerTheme = theme; prefs.autoAddOnWordTap = autoAdd
            prefs.dailyReviewLimit = dailyLimit; prefs.timeZonePolicy = timezonePolicy; prefs.fixedTimeZoneID = timezonePolicy == "fixed" ? fixedTimezone : nil
            try dependencies.preferencesRepository.save(prefs); learning.changed(); message = "设置已保存"
        } catch { message = error.localizedDescription }
    }
}
