import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("今日", systemImage: "sun.max") }
            ExploreView().tabItem { Label("探索", systemImage: "safari") }
            ReviewView().tabItem { Label("复习", systemImage: "rectangle.stack") }
            LibraryView().tabItem { Label("生词本", systemImage: "book") }
            ProfileView().tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Color.accentColor)
    }
}

struct TodayView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "今日", symbol: "sun.max", detail: "M0 导航骨架已就绪") } } }
struct ExploreView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "探索", symbol: "safari", detail: "文章探索将在 M3 实现") } } }
struct ReviewView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "复习", symbol: "rectangle.stack", detail: "间隔复习将在 M5 实现") } } }
struct LibraryView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "生词本", symbol: "book", detail: "本地词汇库将在 M5 实现") } } }
struct ProfileView: View { var body: some View { NavigationStack { ContentPlaceholder(title: "我的", symbol: "person", detail: "资料与偏好将在 M1/M7 实现") } } }

struct ContentPlaceholder: View {
    let title: String; let symbol: String; let detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(.tint)
            Text(title).font(.largeTitle.bold())
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding().navigationTitle(title)
    }
}
