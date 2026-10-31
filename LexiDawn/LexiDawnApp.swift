import SwiftUI
import SwiftData

@main
struct LexiDawnApp: App {
    @StateObject private var startup = AppStartup()
    var body: some Scene {
        WindowGroup {
            if let dependencies = startup.dependencies {
                RootTabView().environmentObject(dependencies)
            } else {
                StorageUnavailableView(message: startup.errorMessage) { startup.retry() }
            }
        }
    }
}

@MainActor
final class AppStartup: ObservableObject {
    @Published private(set) var dependencies: AppDependencies?
    @Published private(set) var errorMessage = ""
    private let factory: () throws -> AppDependencies
    init(factory: (() throws -> AppDependencies)? = nil) {
        if let factory {
            self.factory = factory
        } else {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"] == "startupRetry" {
                var attempts = 0
                self.factory = {
                    attempts += 1
                    if attempts == 1 { throw PersistenceError.integrity("UI 测试注入的一次启动失败") }
                    return try AppDependencies.makeInMemory()
                }
            } else {
                self.factory = { try AppStartup.makeDependencies() }
            }
            #else
            self.factory = { try AppStartup.makeDependencies() }
            #endif
        }
        retry()
    }
    func retry() {
        do { dependencies = try factory(); errorMessage = "" }
        catch { dependencies = nil; errorMessage = error.localizedDescription }
    }
    static func makeDependencies() throws -> AppDependencies {
        #if DEBUG && targetEnvironment(simulator)
        // Explicit opt-in UI fixture, isolated from the production disk store. Never used in Release.
        if let scenario = ProcessInfo.processInfo.environment["LEXIDAWN_UI_SCENARIO"] {
            // Screenshot scenarios use the exact production RFC bytes and repositories, with a
            // separate UUID store. Only learning state / faults are seeded, never article text.
            if scenario.hasPrefix("gallery-"), let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("gallery-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if scenario == "gallery-empty" { return dependencies }
                if try dependencies.articleRepository.allArticleIDs().isEmpty, let learning = dependencies.learning {
                    let now = Date()
                    let start = scenario == "gallery-overdue" ? now.addingTimeInterval(-3 * 86400) : now
                    try learning.content.installBundledRFC(at: start)
                    _ = try dependencies.cycleService.ensureCurrentCycle(now: start, timeZone: .current, calendar: .current)
                    if scenario == "gallery-expired" {
                        let context = ModelContext(dependencies.modelContainer)
                        if let article = try context.fetch(FetchDescriptor<ArticleRecord>()).first {
                            article.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.until(now.addingTimeInterval(-1)))
                            try context.save()
                        }
                    }
                    if scenario == "gallery-backoff" {
                        try learning.content.beginFetch(at: now)
                        try learning.content.finishFetch(error: "Screenshot fault injection: HTTP 429", retryAfter: now.addingTimeInterval(3600), at: now)
                    }
                    if scenario == "gallery-review" || scenario == "gallery-missing-state" {
                        let article = try learning.content.read(articleID: SourceRegistry.rfc.id, at: now)
                        let pairs = scenario == "gallery-review" ? [("Internet", "互联网（个人释义）"), ("document", "文档（个人释义）")] : [("Internet", "互联网（个人释义）")]
                        for (index, pair) in pairs.enumerated() {
                            if let token = EnglishTokenizer.tokens(in: article.body).first(where: { $0.surface == pair.0 }),
                               let added = try learning.vocabulary.add(token: token, articleID: article.id, autoAdd: true, at: now.addingTimeInterval(Double(index) * 0.001)) {
                                try learning.vocabulary.annotate(entryID: added.entryID, meaning: pair.1, notes: "Screenshot test seed; actual RFC context", at: Date())
                            }
                        }
                        if scenario == "gallery-missing-state" {
                            let context = ModelContext(dependencies.modelContainer)
                            for state in try context.fetch(FetchDescriptor<ReviewStateRecord>()) { context.delete(state) }
                            try context.save()
                        }
                    }
                }
                return dependencies
            }
            if scenario == "round2-disk", let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round2-ui-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if try dependencies.articleRepository.allArticleIDs().isEmpty {
                    let body = (0..<50).map { "Book and science. Reading this isolated paragraph number \($0) helps us learn about the world. Keep reading and save your progress." }.joined(separator: "\n\n")
                    _ = try dependencies.learning?.content.importArticle(ArticleImportDraft(title: "隔离 UI 阅读测试（非生产内容）", body: body, source: "Explicit UI test fixture author", rightsConfirmed: true), at: Date())
                }
                return dependencies
            }
            if scenario == "round2" { return try AppDependencies.makeLearningInMemory() }
            if scenario == "startupFailure" { throw PersistenceError.integrity("UI 测试注入的启动失败") }
            let dependencies = try AppDependencies.makeInMemory()
            if scenario == "empty" { return dependencies }
            let now = Date()
            let candidate = ArticleCandidate(id: "ui-fixture", canonicalURL: "https://example.invalid/ui-fixture",
                title: "UI 测试文章（非真实内容）", sourceID: "ui-test-only", licenseID: "fixture-not-a-real-license",
                licenseVerified: true, bodyText: "Explicit isolated UI test fixture.", contentStatus: .available,
                topicTags: ["test"], cachePermission: .persistent, sourceAttribution: "UI test fixture", fullTextDisplayAllowed: true)
            let cycle = try DailyStudyCycle(assignedLocalDate: DailyCycleService.studyDate(for: now, calendar: .current),
                assignedTimeZoneID: TimeZone.current.identifier, articleID: candidate.id,
                createdAtUTC: now, updatedAtUTC: now, assignmentReason: "ui-test-only")
            try dependencies.cycleRepository.save(cycle: cycle, candidate: candidate, fetchedAt: now)
            for task in DailyTask.allCases {
                if ["blocked", "failed", "inProgress"].contains(scenario) {
                    let status: TaskStatus = scenario == "blocked" ? .blocked : scenario == "failed" ? .failed : .inProgress
                    _ = try dependencies.cycleService.updateTask(cycleID: cycle.cycleID, task: task, to: status,
                        reason: status == .inProgress ? nil : "UI 测试：\(task.rawValue) 的真实失败原因", at: now)
                }
            }
            return dependencies
        }
        #endif
        return try AppDependencies.makeProduction()
    }
}

private struct StorageUnavailableView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 48)).foregroundStyle(.red)
            Text("本地学习数据暂时不可用").font(.title2.bold())
            Text("已有数据保持保留。请检查设备存储空间，然后重新打开存储；持续失败时需要核对备份和迁移错误。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Button("重新打开存储", action: retry).accessibilityIdentifier("retry-storage")
        }.padding(24)
    }
}
