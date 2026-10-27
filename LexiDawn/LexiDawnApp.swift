import SwiftUI
import SwiftData

@main
struct LexiDawnApp: App {
    private let modelContainer: ModelContainer?
    private let dependencies: AppDependencies?
    private let startupError: String?

    init() {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
                configurations: configuration
            )
            modelContainer = container
            dependencies = AppDependencies(modelContainer: container)
            startupError = nil
        } catch {
            // Storage errors must be visible and recoverable. Keep the app
            // alive so a future repair or user action can be added without
            // silently deleting an existing database.
            modelContainer = nil
            dependencies = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                RootTabView()
                    .environmentObject(dependencies)
            } else {
                StorageUnavailableView(message: startupError ?? "未知存储错误")
            }
        }
    }
}

private struct StorageUnavailableView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("本地学习数据暂时不可用")
                .font(.title2.bold())
            Text("应用没有清空或覆盖已有数据。请重启应用；如果问题持续，请检查设备存储空间。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
