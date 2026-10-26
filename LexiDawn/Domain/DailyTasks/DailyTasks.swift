import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case locked
    case ready
    case inProgress
    case completed
    case deferred
    case blocked
    case failed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .locked: return "已锁定"
        case .ready: return "待开始"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .deferred: return "无需执行"
        case .blocked: return "被阻塞"
        case .failed: return "执行失败"
        }
    }

    var isSatisfied: Bool { self == .completed || self == .deferred }
    var canContinue: Bool { self == .ready || self == .inProgress || self == .blocked || self == .failed }

    func canTransition(to target: TaskStatus) -> Bool {
        if self == target { return true }
        switch self {
        case .locked: return [.ready, .blocked, .deferred].contains(target)
        case .ready: return [.inProgress, .completed, .deferred, .blocked, .failed].contains(target)
        case .inProgress: return [.completed, .deferred, .blocked, .failed].contains(target)
        case .blocked: return [.ready, .inProgress, .failed, .deferred].contains(target)
        case .failed: return [.ready, .inProgress, .completed, .deferred, .blocked].contains(target)
        case .completed, .deferred: return false
        }
    }

    func transitioned(to target: TaskStatus, reason: String? = nil) throws -> TaskStatus {
        guard canTransition(to: target) else {
            throw TaskStatusError.invalidTransition(from: self, to: target)
        }
        if target == .deferred && (reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            throw TaskStatusError.deferredReasonRequired
        }
        return target
    }
}

enum TaskStatusError: Error, Equatable, LocalizedError {
    case invalidTransition(from: TaskStatus, to: TaskStatus)
    case deferredReasonRequired

    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            return "不允许将任务从 \(from.displayName)变更为\(to.displayName)"
        case .deferredReasonRequired:
            return "标记为无需执行时必须记录原因"
        }
    }
}

enum DailyTask: String, CaseIterable, Sendable {
    case article
    case review
    case matching
    case cloze
}

struct ArticleCandidate: Equatable, Sendable {
    let id: String
    let canonicalURL: String
    let title: String
    let sourceID: String

    init(id: String, canonicalURL: String, title: String, sourceID: String) {
        self.id = id
        self.canonicalURL = canonicalURL
        self.title = title
        self.sourceID = sourceID
    }
}

protocol ArticleCandidateProvider {
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate]
}

protocol ArticleStore {
    func allArticleIDs() throws -> Set<String>
    func save(candidate: ArticleCandidate, fetchedAt: Date) throws
}

protocol StudyCycleStore {
    func fetchAll() throws -> [DailyStudyCycle]
    func fetchEarliestIncomplete() throws -> DailyStudyCycle?
    func fetch(by cycleID: UUID) throws -> DailyStudyCycle?
    func fetchByAssignedLocalDate(_ localDate: String) throws -> DailyStudyCycle?
    func save(_ cycle: DailyStudyCycle) throws
}

struct DailyStudyCycle: Equatable, Sendable {
    let cycleID: UUID
    let assignedLocalDate: String
    let assignedTimeZoneID: String
    let articleID: String
    var articleTaskStatus: TaskStatus
    var reviewTaskStatus: TaskStatus
    var matchingStageStatus: TaskStatus
    var clozeStageStatus: TaskStatus
    let createdAtUTC: Date
    var updatedAtUTC: Date
    var completedAtUTC: Date?
    var carryOverCount: Int
    let assignmentReason: String
    var isCurrent: Bool
    var lastCarryOverLocalDate: String?
    var articleTaskReason: String?
    var reviewTaskReason: String?
    var matchingStageReason: String?
    var clozeStageReason: String?

    init(
        cycleID: UUID = UUID(),
        assignedLocalDate: String,
        assignedTimeZoneID: String,
        articleID: String,
        articleTaskStatus: TaskStatus = .ready,
        reviewTaskStatus: TaskStatus = .ready,
        matchingStageStatus: TaskStatus = .ready,
        clozeStageStatus: TaskStatus = .ready,
        createdAtUTC: Date,
        updatedAtUTC: Date,
        completedAtUTC: Date? = nil,
        carryOverCount: Int = 0,
        assignmentReason: String,
        isCurrent: Bool = true,
        lastCarryOverLocalDate: String? = nil,
        articleTaskReason: String? = nil,
        reviewTaskReason: String? = nil,
        matchingStageReason: String? = nil,
        clozeStageReason: String? = nil
    ) {
        self.cycleID = cycleID
        self.assignedLocalDate = assignedLocalDate
        self.assignedTimeZoneID = assignedTimeZoneID
        self.articleID = articleID
        self.articleTaskStatus = articleTaskStatus
        self.reviewTaskStatus = reviewTaskStatus
        self.matchingStageStatus = matchingStageStatus
        self.clozeStageStatus = clozeStageStatus
        self.createdAtUTC = createdAtUTC
        self.updatedAtUTC = updatedAtUTC
        self.completedAtUTC = completedAtUTC
        self.carryOverCount = carryOverCount
        self.assignmentReason = assignmentReason
        self.isCurrent = isCurrent
        self.lastCarryOverLocalDate = lastCarryOverLocalDate
        self.articleTaskReason = articleTaskReason
        self.reviewTaskReason = reviewTaskReason
        self.matchingStageReason = matchingStageReason
        self.clozeStageReason = clozeStageReason
    }

    var isComplete: Bool {
        articleTaskStatus.isSatisfied && reviewTaskStatus.isSatisfied &&
            matchingStageStatus.isSatisfied && clozeStageStatus.isSatisfied
    }

    var hasOutstandingWork: Bool { !isComplete }

    func isOverdue(on localDate: String) -> Bool {
        hasOutstandingWork && assignedLocalDate < localDate
    }

    mutating func update(task: DailyTask, to target: TaskStatus, reason: String? = nil, at timestamp: Date) throws {
        let current: TaskStatus
        switch task {
        case .article: current = articleTaskStatus
        case .review: current = reviewTaskStatus
        case .matching: current = matchingStageStatus
        case .cloze: current = clozeStageStatus
        }
        _ = try current.transitioned(to: target, reason: reason)

        switch task {
        case .article:
            articleTaskStatus = target
            articleTaskReason = reason ?? articleTaskReason
        case .review:
            reviewTaskStatus = target
            reviewTaskReason = reason ?? reviewTaskReason
        case .matching:
            matchingStageStatus = target
            matchingStageReason = reason ?? matchingStageReason
        case .cloze:
            clozeStageStatus = target
            clozeStageReason = reason ?? clozeStageReason
        }
        updatedAtUTC = timestamp
        completedAtUTC = isComplete ? (completedAtUTC ?? timestamp) : nil
    }

    mutating func markCarryOverIfNeeded(for localDate: String, at timestamp: Date) -> Bool {
        guard hasOutstandingWork, assignedLocalDate != localDate, lastCarryOverLocalDate != localDate else {
            return false
        }
        carryOverCount += 1
        lastCarryOverLocalDate = localDate
        updatedAtUTC = timestamp
        return true
    }
}

enum DailyCycleProvisioningResult: Equatable {
    case cycle(DailyStudyCycle, created: Bool)
    case noCandidate
}

enum DailyCycleServiceError: Error, Equatable, LocalizedError {
    case invalidTimeZone(String)
    case articleAlreadyUsed(String)
    case missingCycle(UUID)

    var errorDescription: String? {
        switch self {
        case let .invalidTimeZone(identifier): return "无法识别学习时区：\(identifier)"
        case let .articleAlreadyUsed(articleID): return "文章已分配过，不能再次作为每日文章：\(articleID)"
        case let .missingCycle(cycleID): return "找不到学习周期：\(cycleID.uuidString)"
        }
    }
}

final class DailyCycleService {
    private let cycleStore: StudyCycleStore
    private let candidateProvider: ArticleCandidateProvider
    private let articleStore: ArticleStore?

    init(cycleStore: StudyCycleStore, candidateProvider: ArticleCandidateProvider, articleStore: ArticleStore? = nil) {
        self.cycleStore = cycleStore
        self.candidateProvider = candidateProvider
        self.articleStore = articleStore
    }

    func ensureCurrentCycle(
        now: Date,
        timeZone: TimeZone,
        calendar: Calendar,
        assignmentReason: String = "daily-required"
    ) throws -> DailyCycleProvisioningResult {
        var workingCalendar = calendar
        workingCalendar.timeZone = timeZone
        let studyDate = Self.studyDate(for: now, calendar: workingCalendar)

        if var incomplete = try cycleStore.fetchEarliestIncomplete() {
            if incomplete.markCarryOverIfNeeded(for: studyDate, at: now) {
                try cycleStore.save(incomplete)
            }
            return .cycle(incomplete, created: false)
        }

        if let completedToday = try cycleStore.fetchByAssignedLocalDate(studyDate) {
            return .cycle(completedToday, created: false)
        }

        var usedArticleIDs = Set(try cycleStore.fetchAll().map(\.articleID))

        let candidates = try candidateProvider.candidates(excluding: usedArticleIDs)
        guard let candidate = candidates.first else { return .noCandidate }
        guard !usedArticleIDs.contains(candidate.id) else {
            throw DailyCycleServiceError.articleAlreadyUsed(candidate.id)
        }

        let cycle = DailyStudyCycle(
            assignedLocalDate: studyDate,
            assignedTimeZoneID: timeZone.identifier,
            articleID: candidate.id,
            createdAtUTC: now,
            updatedAtUTC: now,
            assignmentReason: assignmentReason
        )
        if let articleStore { try articleStore.save(candidate: candidate, fetchedAt: now) }
        try cycleStore.save(cycle)
        return .cycle(cycle, created: true)
    }

    func updateTask(
        cycleID: UUID,
        task: DailyTask,
        to status: TaskStatus,
        reason: String? = nil,
        at timestamp: Date
    ) throws -> DailyStudyCycle {
        guard var cycle = try cycleStore.fetch(by: cycleID) else {
            throw DailyCycleServiceError.missingCycle(cycleID)
        }
        try cycle.update(task: task, to: status, reason: reason, at: timestamp)
        try cycleStore.save(cycle)
        return cycle
    }

    func resumeEarliestIncomplete() throws -> DailyStudyCycle? {
        try cycleStore.fetchEarliestIncomplete()
    }

    static func studyDate(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
