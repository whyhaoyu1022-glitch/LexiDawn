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

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var state: TodayLoadState = .idle

    private let dependencies: AppDependencies
    private let now: () -> Date
    private var pendingSave: PendingTaskUpdate?
    private var selectedTimeZone: TimeZone?

    private struct PendingTaskUpdate {
        let cycleID: UUID
        let task: DailyTask
        let status: TaskStatus
        let reason: String?
    }

    init(dependencies: AppDependencies, now: @escaping () -> Date = Date.init) {
        self.dependencies = dependencies
        self.now = now
    }

    func load() {
        state = .loading
        let timestamp = now()
        do {
            let preferences = try dependencies.preferencesRepository.load()
            if preferences.timeZonePolicy == "fixed" {
                guard let zone = TimeZone(identifier: preferences.fixedTimeZoneID ?? "") else { throw DailyCycleServiceError.invalidTimeZone(preferences.fixedTimeZoneID ?? "") }
                selectedTimeZone = zone
            } else { selectedTimeZone = dependencies.timeZone }
            try dependencies.cycleRepository.recoverLegacyRecords(at: timestamp)
            // Round 1 has no reader or exercise screen yet. If an older build
            // left a task in progress, make the blocked state explicit instead of leaving a task permanently in progress.
            _ = try dependencies.cycleService.recoverUnavailableInProgressTasks(at: timestamp)
            let result = try dependencies.cycleService.ensureCurrentCycle(
                now: timestamp,
                timeZone: selectedTimeZone ?? dependencies.timeZone,
                calendar: dependencies.calendar
            )
            switch result {
            case let .cycle(cycle, _):
                let localDate = DailyCycleService.studyDate(for: timestamp, calendar: calendarForCurrentTimeZone())
                let article = try dependencies.articleRepository.fetch(articleID: cycle.articleID)
                let title = article?.displayTitle ?? article?.originalTitle
                state = .loaded(TodayCycleSnapshot(cycle: cycle, articleTitle: title, isOverdue: cycle.isOverdue(on: localDate)))
            case .noCandidate:
                state = .noCandidate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() {
        if case .saveFailed = state, let pendingSave {
            perform(pendingSave)
        } else {
            load()
        }
    }

    func start(task: DailyTask) {
        // The actual reader and review flows belong to later milestones. Do
        // not persist `.inProgress` until a screen can complete or resume it.
        // The view renders these controls disabled with an explicit reason.
        _ = task
    }

    /// Internal write seam for a real reader/review flow. Keeping the pending
    /// operation here makes the retry action repeat the failed write itself;
    /// the unavailable Round 1 buttons never call this seam.
    func update(task: DailyTask, to status: TaskStatus, reason: String? = nil) {
        guard case let .loaded(snapshot) = state else { return }
        perform(PendingTaskUpdate(
            cycleID: snapshot.cycle.cycleID,
            task: task,
            status: status,
            reason: reason
        ))
    }

    private func perform(_ operation: PendingTaskUpdate) {
        do {
            _ = try dependencies.cycleService.updateTask(
                cycleID: operation.cycleID,
                task: operation.task,
                to: operation.status,
                reason: operation.reason,
                at: now()
            )
            pendingSave = nil
            load()
        } catch {
            pendingSave = operation
            state = .saveFailed(error.localizedDescription)
        }
    }

    private func calendarForCurrentTimeZone() -> Calendar {
        var calendar = dependencies.calendar
        calendar.timeZone = selectedTimeZone ?? dependencies.timeZone
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in viewModel.load() }
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
            EmptyStateCard(title: "保存失败", detail: message, actionTitle: "重试保存") { viewModel.retry() }
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

            TaskStatusRow(title: "阅读任务", status: snapshot.cycle.articleTaskStatus, reason: snapshot.cycle.articleTaskReason, task: .article)
            TaskStatusRow(title: "复习任务", status: snapshot.cycle.reviewTaskStatus, reason: snapshot.cycle.reviewTaskReason, task: .review)
            TaskStatusRow(title: "连线阶段", status: snapshot.cycle.matchingStageStatus, reason: snapshot.cycle.matchingStageReason, task: .matching)
            TaskStatusRow(title: "拼写补全阶段", status: snapshot.cycle.clozeStageStatus, reason: snapshot.cycle.clozeStageReason, task: .cloze)

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

    private func actionButtons(_ cycle: DailyStudyCycle) -> some View {
        VStack(alignment: .leading, spacing: LexiDawnSpacing.sm) {
            ForEach(DailyTask.allCases, id: \.rawValue) { task in
                Button(buttonTitle(task)) { viewModel.start(task: task) }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .accessibilityIdentifier("unavailable-\(task.rawValue)")
                    .accessibilityHint("功能尚未接入，不会改变任务状态")
            }
            Text("阅读器和复习功能尚未接入，当前尚不能恢复学习；任务和原文章将继续保留。")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("unavailable-explanation")
            Button("重新读取已保存状态") { viewModel.load() }
                .accessibilityIdentifier("reload-cycle")
        }
    }

    private func buttonTitle(_ task: DailyTask) -> String {
        switch task {
        case .article: return "开始阅读（未接入）"
        case .review: return "开始复习（未接入）"
        case .matching: return "开始连线阶段（未接入）"
        case .cloze: return "开始拼写补全（未接入）"
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
    let reason: String?
    let task: DailyTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(status.displayName).foregroundStyle(.secondary)
                    .accessibilityIdentifier("status-\(task.rawValue)")
            }
            if let reason {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("reason-\(task.rawValue)")
            }
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
