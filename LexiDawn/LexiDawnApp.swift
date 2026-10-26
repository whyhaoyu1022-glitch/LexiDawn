import SwiftUI
import SwiftData

@main
struct LexiDawnApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var dependencies: AppDependencies

    init() {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
                configurations: configuration
            )
            modelContainer = container
            _dependencies = StateObject(wrappedValue: AppDependencies(modelContainer: container))
        } catch {
            fatalError("Unable to create LexiDawn data container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dependencies)
        }
        .modelContainer(modelContainer)
    }
}
