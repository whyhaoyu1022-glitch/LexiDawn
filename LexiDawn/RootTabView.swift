import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("今日", systemImage: "sun.max") }
            ExploreView().tabItem { Label("探索", systemImage: "safari") }
            VocabularyView().tabItem { Label("词汇", systemImage: "text.book.closed") }
            ReviewView().tabItem { Label("复习", systemImage: "rectangle.stack") }
            ProfileView().tabItem { Label("我的", systemImage: "person") }
        }
        .tint(LexiDawnColor.dawn500)
    }
}

struct TodayView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "今日", symbol: "sun.max", detail: "M0 导航骨架已就绪") } } }
struct ExploreView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "探索", symbol: "safari", detail: "文章探索将在 M3 实现") } } }
struct VocabularyView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "词汇", symbol: "text.book.closed", detail: "高级词汇与短语推荐将在 M6 实现") } } }
struct ReviewView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "复习", symbol: "rectangle.stack", detail: "间隔复习将在 M5 实现") } } }
struct ProfileView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "我的", symbol: "person", detail: "资料与偏好将在 M1/M7 实现") } } }

struct ContentPlaceholder: View {
    let title: String; let symbol: String; let detail: String
    var body: some View {
        VStack(spacing: LexiDawnSpacing.md) {
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(LexiDawnColor.dawn500)
            Text(title).font(.largeTitle.bold())
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(LexiDawnSpacing.lg).navigationTitle(title)
    }
}
