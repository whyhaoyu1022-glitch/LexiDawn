import Foundation
import SwiftData
import Combine

@MainActor
final class AppDependencies: ObservableObject {
    let modelContainer: ModelContainer
    let cycleRepository: StudyCycleRepository
    let articleRepository: ArticleRepository
    let preferencesRepository: PreferencesRepository
    let cycleService: DailyCycleService
    let calendar: Calendar
    let timeZone: TimeZone

    init(
        modelContainer: ModelContainer,
        candidateProvider: ArticleCandidateProvider? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        cycleService: DailyCycleService? = nil
    ) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.cycleRepository = StudyCycleRepository(context: context)
        self.articleRepository = ArticleRepository(context: context)
        self.preferencesRepository = PreferencesRepository(context: context)
        self.cycleService = cycleService ?? DailyCycleService(
                cycleStore: cycleRepository,
                candidateProvider: candidateProvider ?? EmptyArticleCandidateProvider()
            )
        self.calendar = calendar
        self.timeZone = timeZone
    }

    static func makeProduction() throws -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        return AppDependencies(modelContainer: try openPersistentStore(configuration: configuration))
    }

    /// Additive optional-field lightweight migration, with an untouched cold-start backup.
    /// Never delete/recreate the original database on migration/open failure.
    static func openPersistentStore(configuration: ModelConfiguration) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: configuration.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupBeforeUpgrade(at: configuration.url)
        return try ModelContainer(for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, configurations: configuration)
    }

    static func backupBeforeUpgrade(at storeURL: URL) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: storeURL.path) else { return }
        let backup = storeURL.appendingPathExtension("before-r2")
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
}
