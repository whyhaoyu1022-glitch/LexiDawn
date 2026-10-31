import Foundation
import SwiftData
import Combine

@MainActor
final class AppDependencies: ObservableObject {
    let modelContainer: ModelContainer
    let cycleRepository: StudyCycleRepository
    let articleRepository: ArticleRepository
    let preferencesRepository: PreferencesRepository
    let learning: LearningServices?
    let cycleService: DailyCycleService
    let calendar: Calendar
    let timeZone: TimeZone

    init(
        modelContainer: ModelContainer,
        candidateProvider: ArticleCandidateProvider? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        cycleService: DailyCycleService? = nil,
        learningEnabled: Bool = false
    ) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.cycleRepository = StudyCycleRepository(context: context)
        self.articleRepository = ArticleRepository(context: context)
        self.preferencesRepository = PreferencesRepository(context: context)
        let learning = learningEnabled ? LearningServices(container: modelContainer, cycles: cycleRepository) : nil
        self.learning = learning
        let selectedProvider: any ArticleCandidateProvider
        if let candidateProvider { selectedProvider = candidateProvider }
        else if let learning { selectedProvider = learning.content }
        else { selectedProvider = EmptyArticleCandidateProvider() }
        self.cycleService = cycleService ?? DailyCycleService(
                cycleStore: cycleRepository,
                candidateProvider: selectedProvider,
                reviewQueue: learning?.review, readerAvailable: learningEnabled, reviewSessions: learning?.review
            )
        self.calendar = calendar
        self.timeZone = timeZone
    }

    static func makeProduction() throws -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        let dependencies = AppDependencies(modelContainer: try openPersistentStore(configuration: configuration), learningEnabled: true)
        if try !dependencies.articleRepository.allArticleIDs().contains(SourceRegistry.rfc.id) { try dependencies.learning?.content.installBundledRFC(at: Date()) }
        return dependencies
    }

    /// Additive optional-field lightweight migration, with an untouched cold-start backup.
    /// Never delete/recreate the original database on migration/open failure.
    static func openPersistentStore(configuration: ModelConfiguration) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupBeforeUpgrade(at: configuration.url)
        // Separate backup generation: the earlier before-r2 backup belongs to Round 1 remediation.
        try backupBeforeUpgrade(at: configuration.url, suffix: "before-round2-features")
        return try LearningSchema.container(configuration: configuration)
    }

    static func backupBeforeUpgrade(at storeURL: URL, suffix: String = "before-r2") throws {
        let files = FileManager.default
        guard files.fileExists(atPath: storeURL.path) else { return }
        let backup = storeURL.appendingPathExtension(suffix)
        guard !files.fileExists(atPath: backup.path) else { return }
        let staging = storeURL.appendingPathExtension("backup-\(UUID().uuidString)")
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        // This executes before any container is opened. Cross-process writers are unsupported.
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            if files.fileExists(atPath: source.path) {
                try files.copyItem(at: source, to: staging.appendingPathComponent(storeURL.lastPathComponent + suffix))
            }
        }
        try files.moveItem(at: staging, to: backup)
    }

    static func makeInMemory(candidateProvider: ArticleCandidateProvider? = nil) throws -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
            configurations: configuration
        )
        return AppDependencies(modelContainer: container, candidateProvider: candidateProvider)
    }
    static func makeLearningInMemory() throws -> AppDependencies {
        AppDependencies(modelContainer: try LearningSchema.container(configuration: ModelConfiguration(isStoredInMemoryOnly: true)), learningEnabled: true)
    }

}
