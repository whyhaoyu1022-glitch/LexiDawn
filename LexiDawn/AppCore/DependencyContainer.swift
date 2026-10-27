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
        candidateProvider: ArticleCandidateProvider = EmptyArticleCandidateProvider(),
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
                candidateProvider: candidateProvider,
                articleStore: articleRepository
            )
        self.calendar = calendar
        self.timeZone = timeZone
    }

    static func makeProduction() throws -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(
            for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
            configurations: configuration
        )
        return AppDependencies(modelContainer: container)
    }

    static func makeInMemory(candidateProvider: ArticleCandidateProvider = EmptyArticleCandidateProvider()) throws -> AppDependencies {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
            configurations: configuration
        )
        return AppDependencies(modelContainer: container, candidateProvider: candidateProvider)
    }
}
