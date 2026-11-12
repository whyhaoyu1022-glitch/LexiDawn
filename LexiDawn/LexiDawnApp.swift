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
            if scenario.hasPrefix("round4-"), let id = UUID(uuidString: ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"] ?? "") { return try round4Fixture(scenario, storeID: id) }
            if scenario == "round3-reader-structure", let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-structure-\(storeID).store")
                let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if try app.articleRepository.allArticleIDs().isEmpty, let learning = app.learning {
                    let paragraphs = (1...8).map { "<p>Original fixture paragraph \($0). Reading complete documents helps people understand complicated ideas. Every original sentence and the final paragraph remain preserved in this structured local article.</p>" }.joined()
                    let html = "<article><h1>Original structured fixture</h1><h2>Headings and quotation</h2><blockquote><p>This quotation discusses JavaScript and HTML5 in an original fixture.</p></blockquote><video>To view this video please enable JavaScript.</video><h2>An ordered list</h2><ol><li>First original list item.</li><li>Second original list item.</li></ol>" + paragraphs + "</article>"
                    let document = try ArticleHTMLExtractor.extract(html)
                    _ = try learning.content.importArticle(.init(title: "明确原创夹具：标题、引用与列表", body: document.text, source: "Explicit original UI fixture author", rightsConfirmed: true), document: document, at: Date())
                }
                return app
            }
            if (["round3-history-gate", "round3-extra-review", "round3-explore-catalog", "round3-version-change"].contains(scenario) || scenario.hasPrefix("round3-recommendations-")), let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                // Explicit gate fixture, distinct from the genuinely empty live cold-start test.
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-gate-\(storeID).store")
                let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if try app.articleRepository.allArticleIDs().isEmpty, let learning = app.learning {
                    let previous = scenario == "round3-history-gate" ? Date().addingTimeInterval(-86400) : Date()
                    try learning.content.installBundledRFC(at: previous)
                    if case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: previous, timeZone: .current, calendar: .current) {
                        // Seed a historical completed cycle with auditable domain evidence, never fake raw statuses.
                        var completed = cycle
                        try completed.resolveEmptyReview(ReviewQueueEvidence.evaluate(cycleID: cycle.cycleID, reader: learning.review, at: previous))
                        try learning.cycles.save(completed)
                        try learning.reader.complete(articleID: cycle.articleID, cycleID: cycle.cycleID, manualConfirmation: true, at: previous)
                    }
                    try learning.content.setLibraryFlags(articleID: SourceRegistry.rfc.id, favorite: true, readLater: true)
                    if scenario == "round3-extra-review" {
                        for (surface, meaning) in [("Internet", "互联网（额外复习夹具）"), ("document", "文档（额外复习夹具）")] {
                            let addition = try learning.vocabulary.add(token: .init(surface: surface, range: NSRange(location: 0, length: surface.count), sentence: "Explicit original context fixture: the \(surface) supports learning."), articleID: SourceRegistry.rfc.id, autoAdd: true, at: Date())
                            if let addition { try learning.dictionary.recordEmptyEligibilityFixture(EnglishTokenizer.lemma(surface), at: Date()); try learning.vocabulary.savePersonalSenses(entryID: addition.entryID, senses: [.init(partOfSpeech: "noun", chinese: meaning, confirmed: true)], at: Date()); try learning.vocabulary.saveNotes(entryID: addition.entryID, notes: "Explicit extra-review fixture, not a live cold start.", at: Date()) }
                        }
                    } else if scenario == "round3-history-gate" {
                        _ = try learning.content.importArticle(.init(title: "Explicit original current-task fixture", body: "A new original task remains unfinished. Only this task article can be opened until its cycle is complete.", source: "Explicit UI fixture author", rightsConfirmed: true), at: Date())
                        _ = try app.cycleService.ensureCurrentCycle(now: Date(), timeZone: .current, calendar: .current)
                    } else {
                        let scienceID = try learning.content.importArticle(.init(title: "Explicit science exploration fixture", body: "Cooperation and architecture support thoughtful investigation. This complete original fixture discusses scientific collaboration and responsible communication. The final original sentence remains available in the native reader.", source: "Explicit original UI fixture author", topic: "Science", rightsConfirmed: true, eligibleForDaily: false), at: Date())
                        _ = try learning.content.importArticle(.init(title: "Explicit city exploration fixture", body: "Transportation and administration shape communities. This complete original fixture discusses city planning and practical education. The final original paragraph is preserved for native exploration testing.", source: "Explicit original UI fixture author", topic: "Cities", rightsConfirmed: true, eligibleForDaily: false), at: Date())
                        if scenario.hasPrefix("round3-recommendations-") { try DictionaryEvidenceProvider.install(mode: scenario.replacingOccurrences(of: "round3-recommendations-", with: ""), learning: learning) }
                        if scenario == "round3-version-change" {
                            let old = try learning.content.read(articleID: scienceID, at: Date())
                            try learning.reader.save(articleID: scienceID, cycleID: nil, position: .init(percent: 0.4, anchor: fingerprint(old.body), offset: 12), at: Date())
                            try learning.content.updateOriginal(articleID: scienceID, draft: .init(title: "Explicit updated science fixture", body: "An explicit new original introduction.\n\n" + old.body, source: "Explicit original UI fixture author", topic: "Science", rightsConfirmed: true, eligibleForDaily: false), at: Date())
                        }
                    }
                }
                if scenario == "round3-extra-review", let learning = app.learning { try DictionaryEvidenceProvider.install(mode: "empty", learning: learning) }
                return app
            }
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
                    if scenario == "gallery-review" || scenario == "gallery-review-save-failure" || scenario == "gallery-round3-review" || scenario == "gallery-missing-state" {
                        let article = try learning.content.read(articleID: SourceRegistry.rfc.id, at: now)
                        let pairs = scenario == "gallery-round3-review" ? [("Internet", "互联网（个人释义）"), ("document", "文档（个人释义）"), ("book", "书（个人释义）")] : ["gallery-review", "gallery-review-save-failure"].contains(scenario) ? [("Internet", "互联网（个人释义）"), ("document", "文档（个人释义）")] : [("Internet", "互联网（个人释义）")]
                        for (index, pair) in pairs.enumerated() {
                            if let token = EnglishTokenizer.tokens(in: article.body).first(where: { $0.surface == pair.0 }) ?? (scenario == "gallery-round3-review" && pair.0 == "book" ? EnglishToken(surface: "book", range: NSRange(location: 0, length: 4), sentence: "Explicit test fixture: read a book.") : nil),
                               let added = try learning.vocabulary.add(token: token, articleID: article.id, autoAdd: true, at: now.addingTimeInterval(Double(index) * 0.001)) {
                                try learning.dictionary.recordEmptyEligibilityFixture(EnglishTokenizer.lemma(pair.0), at: Date())
                                try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [.init(partOfSpeech: "noun", chinese: pair.1, confirmed: true)], at: Date()); try learning.vocabulary.saveNotes(entryID: added.entryID, notes: "Explicit screenshot fixture; actual RFC context or labeled original book example", at: Date())
                            }
                        }
                        if scenario == "gallery-missing-state" {
                            let context = ModelContext(dependencies.modelContainer)
                            for state in try context.fetch(FetchDescriptor<ReviewStateRecord>()) { context.delete(state) }
                            try context.save()
                        }
                    }
                }
                if scenario == "gallery-review-save-failure" { dependencies.learning?.injectReviewSaveFailureForEvidence() }
                if ["gallery-review", "gallery-review-save-failure", "gallery-round3-review", "gallery-missing-state"].contains(scenario), let learning = dependencies.learning {
                    try DictionaryEvidenceProvider.install(mode: "empty", learning: learning)
                }
                return dependencies
            }
            if scenario == "round3-phrases", let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-phrases-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if let learning = dependencies.learning {
                    let body = "Yesterday I took a book home. I have taken the time to look into this question.\n\nThe team will carry out a careful study. We take into account every result. Clear examples play a role in learning.\n\nThis complete text is explicit original UI fixture writing. It is never presented as a publisher article or production dictionary content."
                    _ = try learning.content.importArticle(ArticleImportDraft(title: "明确原创夹具：词形与短语", body: body, source: "Explicit original UI fixture author", rightsConfirmed: true), at: Date())
                }
                return dependencies
            }
            if ["round3-storage-vocabulary", "round3-storage-note"].contains(scenario), let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-storage-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if let learning = dependencies.learning {
                    try learning.content.installBundledRFC(at: Date())
                    if scenario == "round3-storage-note" { learning.injectNoteSaveFailureForEvidence() }
                    else { learning.injectVocabularySaveFailureForEvidence() }
                }
                return dependencies
            }
            if scenario.hasPrefix("round3-dictionary-"), let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-dictionary-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if let learning = dependencies.learning {
                    try learning.content.installBundledRFC(at: Date())
                    try DictionaryEvidenceProvider.install(mode: scenario.replacingOccurrences(of: "round3-dictionary-", with: ""), learning: learning)
                }
                return dependencies
            }
            if scenario.hasPrefix("round3-import-"), let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-import-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                if let learning = dependencies.learning {
                    let content: ContentRepository?
                    if scenario == "round3-import-save-failed" {
                        content = ContentRepository(context: ModelContext(dependencies.modelContainer)) { context in
                            if try context.fetchCount(FetchDescriptor<ArticleRecord>()) > 0 { throw LearningError.invalid("Explicit original fixture: full-text database commit failed") }
                            try context.save()
                        }
                    } else { content = nil }
                    Round3ScreenshotTransport.install(in: learning, content: content)
                }
                return dependencies
            }
            if scenario == "round3-network-all", let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-network-all-\(storeID.uuidString).store")
                return AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
            }
            if scenario == "round3-network", let rawID = ProcessInfo.processInfo.environment["LEXIDAWN_UI_STORE_ID"], let storeID = UUID(uuidString: rawID) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("round3-network-\(storeID.uuidString).store")
                let dependencies = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
                dependencies.learning?.productionNetworking = true
                if let learning = dependencies.learning { learning.setDiscoveryForUITesting(ArticleDiscoveryService(content: learning.content, sourceIDs: ["wikipedia"])) }
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


#if DEBUG && targetEnvironment(simulator)
extension AppStartup {
    /// Original, explicitly identified test content; never used by production or Release.
    static func round4Fixture(_ scenario: String, storeID: UUID) throws -> AppDependencies {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("round4-fixture-\(storeID).store")
        let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
        guard let learning = app.learning else { return app }
        if try app.articleRepository.allArticleIDs().isEmpty {
            let first = "We nod when we agree. A book helps us learn. Clear examples provide useful context. A luminora appears in this original fixture sentence."
            let firstParagraph = scenario == "round4-mdx-contexts" ? "We nod when we agree. They nod to say hello." : first
            let paragraphs = (1...12).map { "Original fixture paragraph \($0). A complete reading experience should keep every sentence available. Careful practice turns unfamiliar words into lasting knowledge." }.joined(separator: "\n\n")
            let title = scenario == "round4-reader" ? "A complete original English title that must wrap naturally on a small phone and remain readable after every rotation without hiding the article below it" : "Explicit Round 4 original UI fixture"
            let sourceURL = scenario == "round4-mdx-contexts" ? "https://example.com/owned-round4-contexts" : ""
            let id = try learning.content.importArticle(.init(title: title, body: firstParagraph + "\n\n" + paragraphs, source: "Original UI test author · fixture", originalURL: sourceURL, topic: "Science", rightsConfirmed: true), at: Date())
            if ["round4-review", "round4-missing", "round4-note-failed"].contains(scenario) {
                let body = try learning.content.read(articleID: id, at: Date()).body
                let words = scenario == "round4-review" ? [("nod", "点头", "verb"), ("book", "书", "noun"), ("provide", "提供", "verb")] : [("luminora", "个人测试词", "noun")]
                for (index, value) in words.enumerated() {
                    guard let token = EnglishTokenizer.tokens(in: body).first(where: { $0.surface == value.0 }),
                          let added = try learning.vocabulary.add(token: token, articleID: id, autoAdd: false, explicit: true, at: Date().addingTimeInterval(Double(index) * 0.001)) else { continue }
                    if scenario != "round4-missing" {
                        try learning.dictionary.recordEmptyEligibilityFixture(EnglishTokenizer.lemma(token.surface), at: Date())
                        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [.init(partOfSpeech: value.2, chinese: value.1, examples: [.init(english: token.sentence)], confirmed: true)], at: Date())
                    }
                }
            }
            if scenario == "round4-library" {
                _ = try learning.content.importArticle(.init(title: "Culture and stories: explicit original fixture", body: paragraphs, source: "Original fixture author", topic: "Culture", rightsConfirmed: true, eligibleForDaily: false), at: Date())
                _ = try learning.content.importArticle(.init(title: "Technology and learning: explicit original fixture", body: first + paragraphs, source: "Original fixture author", topic: "Technology", rightsConfirmed: true, eligibleForDaily: false), at: Date())
            }
        }
        let mode = scenario.replacingOccurrences(of: "round4-", with: "")
        if scenario == "round4-mdx-missing" || scenario == "round4-mdx-corrupt" {
            let resource = FileManager.default.temporaryDirectory.appendingPathComponent("explicit-mdx-fault-" + storeID.uuidString + ".mdx")
            if scenario == "round4-mdx-corrupt" { try Data("Explicit corrupt resource fixture".utf8).write(to: resource) }
            learning.dictionary.configureMDXResourceForEvidence(resource)
        } else if !scenario.hasPrefix("round4-mdx-") {
            try learning.dictionary.configureDictionaryEvidence(providers: [("explicit-layout", Round4DictionaryFixture(mode: mode, source: "Wiktionary"))])
        }
        if scenario == "round4-note-failed" { learning.injectVocabularySaveFailureForEvidence() }
        return app
    }
}
struct Round4DictionaryFixture: DictionaryProvider {
    let mode: String, source: String
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        if mode == "loading" { try await Task.sleep(for: .seconds(30)) }
        if mode == "all-failed" || mode == "partial" && source == "Free Dictionary API" { throw URLError(.notConnectedToInternet) }
        if ["empty", "review", "missing", "note-failed", "library", "reader"].contains(mode) { return [] }
        if source == "Free Dictionary API" || mode == "english-only" {
            return [DictionarySense(id: source + "|round4-en-only", en: "Explicit English-only fixture, excluded from bilingual meanings.", zh: "", line: "Original Round 4 metadata fixture; not a live API result", partOfSpeech: "verb", ipa: "/nɒd/", sources: [source], licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/")]
        }
        guard headword == "nod" else { return [] }
        return [
            DictionarySense(id: "wiktionary|round4-noun", en: "", zh: "点头；点头的动作（原创测试义项）", line: "Original Round 4 bilingual layout fixture · not production dictionary content", partOfSpeech: "noun", ipa: "BrE /nɒd/ · AmE /nɑd/", examples: ["A nod can express agreement.", "She answered with a nod."], synonyms: ["agreement"], forms: ["复数 nods"], sources: [source], exampleTranslations: ["点头可以表达同意。", "她点头作答。"], usageLabels: ["动作"]),
            DictionarySense(id: "wiktionary|round4-verb", en: "", zh: "点头示意（原创测试义项）", line: "Original Round 4 bilingual layout fixture · not production dictionary content", partOfSpeech: "verb", examples: ["We nod when we agree.", "He nodded to his friend."], forms: ["过去式 nodded · 现在分词 nodding"], sources: [source], exampleTranslations: ["同意时，我们会点头。", "他向朋友点头示意。"], relatedPhrases: ["nod off · 打盹（原创测试短语）"])
        ]
    }
}
#endif
