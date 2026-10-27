import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        TabView {
            TodayView(dependencies: dependencies)
                .tabItem { Label("今日", systemImage: "sun.max") }
            ExploreView()
                .tabItem { Label("探索", systemImage: "safari") }
            VocabularyView()
                .tabItem { Label("词汇", systemImage: "text.book.closed") }
            ReviewView()
                .tabItem { Label("复习", systemImage: "rectangle.stack") }
            ProfileView()
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(LexiDawnColor.dawn500)
    }
}

struct ExploreView: View {
    var body: some View {
        NavigationStack { ContentPlaceholder(title: "探索", symbol: "safari", detail: "文章探索将在后续文章来源模块接入") }
    }
}

struct VocabularyView: View {
    var body: some View {
        NavigationStack { ContentPlaceholder(title: "词汇", symbol: "text.book.closed", detail: "高级词汇与短语推荐将在后续词汇模块接入") }
    }
}

struct ReviewView: View {
    var body: some View {
        NavigationStack { ContentPlaceholder(title: "复习", symbol: "rectangle.stack", detail: "复习题目将在后续复习模块接入；今日页会保留当前周期状态") }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack { ContentPlaceholder(title: "我的", symbol: "person", detail: "资料与偏好持久化模型已就绪，设置界面将在后续模块接入") }
    }
}

struct ContentPlaceholder: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(spacing: LexiDawnSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(LexiDawnColor.dawn500)
            Text(title).font(.largeTitle.bold())
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(LexiDawnSpacing.lg)
        .navigationTitle(title)
    }
}
