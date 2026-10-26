import Foundation
import SwiftUI

struct TodayCycleSnapshot: Equatable {
    let cycle: DailyStudyCycle
    let articleTitle: String?
    let isOverdue: Bool
}

enum TodayLoadState: Equatable {
    case idle
    case loading
    case noCandidate
    case loaded(TodayCycleSnapshot)
    case failed(String)
    case saveFailed(String)
}

final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayLoadState = .idle

    private let dependencies: AppDependencies
    private let now: () -> Date

    init(dependencies: AppDependencies, now: @escaping () -> Date = Date.init) {
        self.dependencies = dependencies
        self.now = now
    }

    func load() {
        state = .loading
        let timestamp = now()
        do {
            let result = try dependencies.cycleService.ensureCurrentCycle(
                now: timestamp,
                timeZone: dependencies.timeZone,
                calendar: dependencies.calendar
            )
            switch result {
            case let .cycle(cycle, _):
                let localDate = DailyCycleService.studyDate(for: timestamp, calendar: calendarForCurrentTimeZone())
                let title = try dependencies.articleRepository.fetch(articleID: cycle.articleID)?.originalTitle
                state = .loaded(TodayCycleSnapshot(cycle: cycle, articleTitle: title, isOverdue: cycle.isOverdue(on: localDate)))
            case .noCandidate:
                state = .noCandidate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() { load() }

    func start(task: DailyTask) {
        guard case let .loaded(snapshot) = state else { return }
        do {
            _ = try dependencies.cycleService.updateTask(
                cycleID: snapshot.cycle.cycleID,
                task: task,
                to: .inProgress,
                at: now()
            )
            load()
        } catch {
            state = .saveFailed(error.localizedDescription)
        }
    }

    private func calendarForCurrentTimeZone() -> Calendar {
        var calendar = dependencies.calendar
        calendar.timeZone = dependencies.timeZone
        return calendar
    }
}

struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel

    init(dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: TodayViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LexiDawnSpacing.md) {
                    greeting
                    stateContent
                }
                .padding(LexiDawnSpacing.md)
            }
            .navigationTitle("今日")
            .task { viewModel.load() }
            .refreshable { viewModel.load() }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: LexiDawnSpacing.xs) {
            Text("词光 LexiDawn").font(.title2.bold())
            Text("继续完成今天真正需要完成的任务").foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("正在读取学习周期…")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, LexiDawnSpacing.xl)
        case .noCandidate:
            EmptyStateCard(
                title: "暂时没有可分配文章",
                detail: "文章候选池没有返回合法内容。应用不会生成占位文章，请稍后重试。",
                actionTitle: "重试"
            ) { viewModel.retry() }
        case let .failed(message):
            EmptyStateCard(title: "读取失败", detail: message, actionTitle: "重新读取") { viewModel.retry() }
        case let .saveFailed(message):
            EmptyStateCard(title: "保存失败", detail: message, actionTitle: "重试") { viewModel.retry() }
        case let .loaded(snapshot):
            cycleCard(snapshot)
        }
    }

    private func cycleCard(_ snapshot: TodayCycleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: LexiDawnSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LexiDawnSpacing.xs) {
                    Text("当前必做文章").font(.headline)
                    Text(snapshot.articleTitle ?? "文章 ID：\(snapshot.cycle.articleID)")
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                StatusBadge(status: snapshot.cycle.articleTaskStatus)
            }

            Text("原始分配日期：\(snapshot.cycle.assignedLocalDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if snapshot.isOverdue {
                Label("该周期已逾期，仍将优先保留", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(LexiDawnColor.warning)
                    .font(.subheadline)
            }

            TaskStatusRow(title: "阅读任务", status: snapshot.cycle.articleTaskStatus)
            TaskStatusRow(title: "复习任务", status: snapshot.cycle.reviewTaskStatus)
            TaskStatusRow(title: "连线阶段", status: snapshot.cycle.matchingStageStatus)
            TaskStatusRow(title: "拼写补全阶段", status: snapshot.cycle.clozeStageStatus)

            if snapshot.cycle.isComplete {
                Label("本周期已完成", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(LexiDawnColor.success)
                    .font(.headline)
            } else {
                actionButtons(snapshot.cycle)
            }
        }
        .padding(LexiDawnSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.secondary.opacity(0.2)))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actionButtons(_ cycle: DailyStudyCycle) -> some View {
        VStack(alignment: .leading, spacing: LexiDawnSpacing.sm) {
            if cycle.articleTaskStatus == .ready {
                Button("开始阅读") { viewModel.start(task: .article) }
                    .buttonStyle(.borderedProminent)
            } else if cycle.articleTaskStatus == .inProgress {
                Text("阅读器尚未接入；当前状态已保存为进行中。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if cycle.reviewTaskStatus == .ready {
                Button("开始复习") { viewModel.start(task: .review) }
                    .buttonStyle(.bordered)
            }
            if cycle.matchingStageStatus == .ready {
                Button("开始连线阶段") { viewModel.start(task: .matching) }
                    .buttonStyle(.bordered)
            }
            if cycle.clozeStageStatus == .ready {
                Button("开始拼写补全") { viewModel.start(task: .cloze) }
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, LexiDawnSpacing.sm)
            .padding(.vertical, LexiDawnSpacing.xs)
            .background(statusColor.opacity(0.16), in: Capsule())
            .foregroundStyle(statusColor)
            .accessibilityLabel("状态：\(status.displayName)")
    }

    private var statusColor: Color {
        switch status {
        case .completed, .deferred: return LexiDawnColor.success
        case .blocked, .failed: return LexiDawnColor.danger
        case .inProgress: return LexiDawnColor.sky500
        case .locked: return .secondary
        case .ready: return LexiDawnColor.dawn500
        }
    }
}

private struct TaskStatusRow: View {
    let title: String
    let status: TaskStatus

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status.displayName).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

private struct EmptyStateCard: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LexiDawnSpacing.sm) {
            Label(title, systemImage: "tray")
                .font(.headline)
            Text(detail).foregroundStyle(.secondary)
            Button(actionTitle, action: action).buttonStyle(.borderedProminent)
        }
        .padding(LexiDawnSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
