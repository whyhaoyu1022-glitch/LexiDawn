import Foundation
import CryptoKit

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

    /// The conservative default is used when the task kind is unknown.
    /// Call `isSatisfied(for:)` for a cycle task so article and review rules
    /// cannot be accidentally conflated.
    var isSatisfied: Bool { self == .completed }

    func isSatisfied(for task: DailyTask) -> Bool {
        switch task {
        case .article:
            return self == .completed
        case .review, .matching, .cloze:
            return self == .completed
        }
    }
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
        if target == .deferred { throw TaskStatusError.verifiedEvidenceRequired }
        return target
    }
}

enum TaskStatusError: Error, Equatable, LocalizedError {
    case invalidTransition(from: TaskStatus, to: TaskStatus)
    case deferredReasonRequired
    case articleCannotBeDeferred
    case verifiedEvidenceRequired
    case invalidState(String)
    case capabilityUnavailable

    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            return "不允许将任务从 \(from.displayName)变更为\(to.displayName)"
        case .deferredReasonRequired:
            return "标记为无需执行时必须记录原因"
        case .verifiedEvidenceRequired: return "完成或无需执行必须提供经验证的业务证据"
        case let .invalidState(reason): return "学习状态无效：\(reason)"
        case .capabilityUnavailable: return "阅读器或真实复习队列尚未接入，无法确认完成或空队列"
        case .articleCannotBeDeferred:
            return "必做文章必须真实完成，不能标记为无需执行"
        }
    }
}

enum ArticleContentStatus: String, Codable, Sendable {
    case available
    case partial
    case unavailable
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
    let displayTitle: String?
    let difficulty: String?
    let imageURL: String?
    let imageAttribution: String?
    let publishedAt: Date?
    let licenseID: String?
    let licenseVerified: Bool
    let bodyText: String?
    let contentStatus: ArticleContentStatus
    let topicTags: [String]
    let cachePermission: ArticleCachePermission?
    let imageLicenseID: String?
    let sourceAttribution: String?

    init(
        id: String,
        canonicalURL: String,
        title: String,
        sourceID: String,
        displayTitle: String? = nil,
        difficulty: String? = nil,
        imageURL: String? = nil,
        imageAttribution: String? = nil,
        publishedAt: Date? = nil,
        licenseID: String? = nil,
        licenseVerified: Bool = false,
        bodyText: String? = nil,
        contentStatus: ArticleContentStatus = .unavailable,
        topicTags: [String] = [],
        cachePermission: ArticleCachePermission? = nil,
        imageLicenseID: String? = nil,
        sourceAttribution: String? = nil
    ) {
        self.id = id
        self.canonicalURL = Self.normalizeCanonicalURL(canonicalURL)
        self.title = title
        self.sourceID = sourceID
        self.displayTitle = displayTitle
        self.difficulty = difficulty
        self.imageURL = imageURL
        self.imageAttribution = imageAttribution
        self.publishedAt = publishedAt
        self.licenseID = licenseID
        self.licenseVerified = licenseVerified
        self.bodyText = bodyText
        self.contentStatus = contentStatus
        self.topicTags = topicTags
        self.cachePermission = cachePermission
        self.imageLicenseID = imageLicenseID
        self.sourceAttribution = sourceAttribution
    }

    var bodyHash: String? {
        bodyText.map { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
    }

    /// English word estimate, keeping apostrophes and hyphenated compounds together.
    var wordCount: Int {
        guard let bodyText, let expression = try? NSRegularExpression(pattern: "[A-Za-z]+(?:['’‐-][A-Za-z]+)*") else { return 0 }
        return expression.numberOfMatches(in: bodyText, range: NSRange(bodyText.startIndex..., in: bodyText))
    }
    var estimatedReadMinutes: Int { max(1, Int(ceil(Double(wordCount) / 200))) }

    func validate(at timestamp: Date) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw DailyCycleServiceError.invalidCandidate(message) }
        }
        try require(!id.isBlank && !title.isBlank && !sourceID.isBlank, "缺少 ID、标题或来源")
        try require(Self.isWebURL(canonicalURL), "canonicalURL 无效")
        try require(licenseVerified && !(licenseID?.isBlank ?? true), "许可尚未核验或缺少依据")
        try require(!(sourceAttribution?.isBlank ?? true), "缺少文章来源署名")
        try require(contentStatus == .available && wordCount > 0, "正文不可用或不含英文词")
        try require(!topicTags.isEmpty && topicTags.allSatisfy { !$0.isBlank }, "缺少主题标签")
        try require(cachePermission?.permits(at: timestamp) == true, "全文缓存许可缺失或已到期")
        if let imageURL {
            try require(Self.isWebURL(imageURL), "图片 URL 无效")
            try require(!(imageAttribution?.isBlank ?? true) && !(imageLicenseID?.isBlank ?? true), "图片缺少署名或许可依据")
        }
    }

    static func isWebURL(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), let host = url.host, !host.isEmpty,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil else { return false }
        return true
    }

    static func normalizeCanonicalURL(_ value: String) -> String {
        guard var components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        components.scheme = scheme
        components.host = host
        if components.path.isEmpty { components.path = "/" }
        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        if (scheme == "http" && components.port == 80) || (scheme == "https" && components.port == 443) {
            components.port = nil
        }
        components.queryItems = components.queryItems?.filter {
            !$0.name.lowercased().hasPrefix("utm_") && !["fbclid", "gclid"].contains($0.name.lowercased())
        }.sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        components.fragment = nil
        return components.string ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
protocol ArticleCandidateProvider {
    func candidates(excluding articleIDs: Set<String>) throws -> [ArticleCandidate]
}

@MainActor
protocol ArticleStore {
    func allArticleIDs() throws -> Set<String>
    func save(candidate: ArticleCandidate, fetchedAt: Date) throws
}

@MainActor
protocol AtomicCycleCreationStore {
    func save(cycle: DailyStudyCycle, candidate: ArticleCandidate, fetchedAt: Date) throws
}

@MainActor
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
    private(set) var articleTaskStatus: TaskStatus
    private(set) var reviewTaskStatus: TaskStatus
    private(set) var matchingStageStatus: TaskStatus
    private(set) var clozeStageStatus: TaskStatus
    let createdAtUTC: Date
    private(set) var updatedAtUTC: Date
    private(set) var completedAtUTC: Date?
    private(set) var carryOverCount: Int
    let assignmentReason: String
    private(set) var readingEvidence: ReadingCompletionEvidence?
    private(set) var reviewEvidence: ReviewQueueEvidence?
    private(set) var reviewProgress: ReviewSessionResult?
    private(set) var isCurrent: Bool
    private(set) var completionReason: String?
    private(set) var lastCarryOverLocalDate: String?
    private(set) var articleTaskReason: String?
    private(set) var reviewTaskReason: String?
    private(set) var matchingStageReason: String?
    private(set) var clozeStageReason: String?

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
        completionReason: String? = nil,
        lastCarryOverLocalDate: String? = nil,
        articleTaskReason: String? = nil,
        reviewTaskReason: String? = nil,
        matchingStageReason: String? = nil,
        clozeStageReason: String? = nil,
        readingEvidence: ReadingCompletionEvidence? = nil,
        reviewEvidence: ReviewQueueEvidence? = nil,
        reviewProgress: ReviewSessionResult? = nil
    ) throws {
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
        self.completionReason = completionReason
        self.lastCarryOverLocalDate = lastCarryOverLocalDate
        self.articleTaskReason = articleTaskReason
        self.reviewTaskReason = reviewTaskReason
        self.matchingStageReason = matchingStageReason
        self.clozeStageReason = clozeStageReason
        self.readingEvidence = readingEvidence
        self.reviewEvidence = reviewEvidence
        self.reviewProgress = reviewProgress
        try validate()
    }

    var isComplete: Bool {
        articleTaskStatus == .completed && readingEvidence != nil &&
            ((reviewTaskStatus == .deferred && matchingStageStatus == .deferred && clozeStageStatus == .deferred && reviewEvidence != nil) ||
             (reviewTaskStatus == .completed && matchingStageStatus == .completed && clozeStageStatus == .completed && reviewProgress?.isComplete == true))
    }

    func validate() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw TaskStatusError.invalidState(message) }
        }
        try require(Self.civilDate(assignedLocalDate) != nil, "分配日期格式错误")
        try require(TimeZone(identifier: assignedTimeZoneID) != nil, "时区无效")
        try require(!articleID.isBlank && !assignmentReason.isBlank, "缺少文章或指派原因")
        try require(createdAtUTC <= updatedAtUTC && carryOverCount >= 0, "时间戳或跨日计数无效")
        if let lastCarryOverLocalDate {
            try require(Self.civilDate(lastCarryOverLocalDate) != nil && lastCarryOverLocalDate > assignedLocalDate, "跨日日期无效")
        }
        try require(articleTaskStatus != .deferred && articleTaskStatus != .locked, "文章不能略过或锁定")
        if let readingEvidence {
            try readingEvidence.validate(articleID: articleID, createdAt: createdAtUTC, updatedAt: updatedAtUTC)
        }
        try require((articleTaskStatus == .completed) == (readingEvidence != nil), "阅读完成证据与状态不一致")
        if articleTaskStatus == .completed { try require(articleTaskReason == "explicit-reading-confirmation", "阅读完成原因无效") }
        let reviewStatuses = [reviewTaskStatus, matchingStageStatus, clozeStageStatus]
        if let reviewProgress {
            try reviewProgress.validate(cycleID: cycleID, createdAt: createdAtUTC, updatedAt: updatedAtUTC)
            try require(reviewEvidence == nil, "复习题结果不能与空队列同时存在")
            try require((matchingStageStatus == .completed) == reviewProgress.matchingComplete, "连线结果与状态不一致")
            try require((clozeStageStatus == .completed) == reviewProgress.clozeComplete, "拼写结果与状态不一致")
            try require((reviewTaskStatus == .completed) == reviewProgress.isComplete, "复习总状态与阶段不一致")
            for (status, reason) in [(reviewTaskStatus, reviewTaskReason), (matchingStageStatus, matchingStageReason), (clozeStageStatus, clozeStageReason)] where status == .completed {
                try require(reason == "saved-review-session", "复习完成原因与会话不一致")
            }
        } else {
            try require(!reviewStatuses.contains(.completed), "复习完成缺少已保存会话结果")
        }
        if let reviewEvidence {
            try reviewEvidence.validate(cycleID: cycleID, createdAt: createdAtUTC, updatedAt: updatedAtUTC)
            try require(reviewStatuses.allSatisfy { $0 == .deferred }, "空队列必须一次性解析三个复习状态")
            try require([reviewTaskReason, matchingStageReason, clozeStageReason].allSatisfy { $0 == "no-review-items" }, "空队列原因不一致")
        } else {
            try require(!reviewStatuses.contains(.deferred), "缺少真实空队列证明")
        }
        for (status, reason) in [(articleTaskStatus, articleTaskReason), (reviewTaskStatus, reviewTaskReason), (matchingStageStatus, matchingStageReason), (clozeStageStatus, clozeStageReason)] {
            if status == .blocked || status == .failed { try require(!(reason?.isBlank ?? true), "阻塞或失败缺少原因") }
            if status == .ready || status == .inProgress { try require(reason == nil, "活动状态携带陈旧原因") }
        }
        if isComplete {
            try require(completedAtUTC != nil && completionReason == expectedCompletionReason && !isCurrent, "周期完成元数据不一致")
            if let completedAtUTC, let readingEvidence {
                let reviewTime = reviewEvidence?.evaluatedAt ?? reviewProgress?.recordedAt ?? createdAtUTC
                try require(completedAtUTC == max(readingEvidence.confirmedAt, reviewTime) && completedAtUTC <= updatedAtUTC, "完成时间必须等于最后一个有效结果时间")
            }
        } else {
            try require(completedAtUTC == nil && completionReason == nil, "未完成周期携带完成元数据")
        }
    }

    private var expectedCompletionReason: String { reviewEvidence != nil ? "completed-with-no-review-items" : "all-required-tasks-completed" }

    mutating func recordReviewProgress(_ result: ReviewSessionResult) throws {
        try result.validate(cycleID: cycleID, createdAt: createdAtUTC, updatedAt: result.recordedAt)
        guard reviewEvidence == nil else { throw TaskStatusError.verifiedEvidenceRequired }
        if let previous = reviewProgress {
            guard previous.sessionID == result.sessionID, previous.matchingQuestionIDs == result.matchingQuestionIDs,
                  previous.clozeQuestionIDs == result.clozeQuestionIDs,
                  Set(previous.matchingAnsweredIDs).isSubset(of: Set(result.matchingAnsweredIDs)),
                  Set(previous.clozeAnsweredIDs).isSubset(of: Set(result.clozeAnsweredIDs)) else { throw TaskStatusError.verifiedEvidenceRequired }
            if previous == result { return }
            guard !previous.isComplete else { throw TaskStatusError.verifiedEvidenceRequired }
        }
        var next = self
        next.reviewProgress = result
        next.matchingStageStatus = result.matchingComplete ? .completed : .inProgress
        next.clozeStageStatus = result.clozeComplete ? .completed : .inProgress
        next.reviewTaskStatus = result.isComplete ? .completed : .inProgress
        next.reviewTaskReason = result.isComplete ? "saved-review-session" : nil
        next.matchingStageReason = result.matchingComplete ? "saved-review-session" : nil
        next.clozeStageReason = result.clozeComplete ? "saved-review-session" : nil
        try next.finishMutation(at: result.recordedAt)
        self = next
    }

    mutating func completeReading(_ evidence: ReadingCompletionEvidence) throws {
        try evidence.validate(articleID: articleID, createdAt: createdAtUTC, updatedAt: evidence.confirmedAt)
        if articleTaskStatus == .completed {
            guard readingEvidence == evidence else { throw TaskStatusError.verifiedEvidenceRequired }
            return
        }
        var next = self
        _ = try articleTaskStatus.transitioned(to: .completed)
        next.articleTaskStatus = .completed
        next.articleTaskReason = "explicit-reading-confirmation"
        next.readingEvidence = evidence
        try next.finishMutation(at: evidence.confirmedAt)
        self = next
    }

    mutating func resolveEmptyReview(_ evidence: ReviewQueueEvidence) throws {
        try evidence.validate(cycleID: cycleID, createdAt: createdAtUTC, updatedAt: evidence.evaluatedAt)
        if let reviewEvidence {
            guard reviewEvidence == evidence else { throw TaskStatusError.verifiedEvidenceRequired }
            return
        }
        let statuses: [TaskStatus] = [reviewTaskStatus, matchingStageStatus, clozeStageStatus]
        for status in statuses {
            switch status {
            case .ready, .blocked, .failed, .locked: break
            default: throw TaskStatusError.verifiedEvidenceRequired
            }
        }
        var next = self
        next.reviewTaskStatus = .deferred
        next.matchingStageStatus = .deferred
        next.clozeStageStatus = .deferred
        next.reviewTaskReason = "no-review-items"
        next.matchingStageReason = "no-review-items"
        next.clozeStageReason = "no-review-items"
        next.reviewEvidence = evidence
        try next.finishMutation(at: evidence.evaluatedAt)
        self = next
    }

    private mutating func finishMutation(at timestamp: Date) throws {
        guard timestamp >= updatedAtUTC else { throw TaskStatusError.invalidState("更新不能回退时间戳") }
        updatedAtUTC = timestamp
        if isComplete {
            completedAtUTC = completedAtUTC ?? timestamp
            completionReason = expectedCompletionReason
            isCurrent = false
        }
        try validate()
    }

    var hasOutstandingWork: Bool { !isComplete }

    func isOverdue(on localDate: String) -> Bool {
        hasOutstandingWork && assignedLocalDate < localDate
    }

    mutating func update(task: DailyTask, to target: TaskStatus, reason: String? = nil, at timestamp: Date) throws {
        if task == .article && target == .deferred {
            throw TaskStatusError.articleCannotBeDeferred
        }
        guard target != .completed && target != .deferred else { throw TaskStatusError.verifiedEvidenceRequired }
        var next = self
        let current: TaskStatus
        switch task {
        case .article: current = articleTaskStatus
        case .review: current = reviewTaskStatus
        case .matching: current = matchingStageStatus
        case .cloze: current = clozeStageStatus
        }
        _ = try current.transitioned(to: target, reason: reason)

        if current == target { return }
        switch task {
        case .article: next.articleTaskStatus = target; next.articleTaskReason = reason
        case .review: next.reviewTaskStatus = target; next.reviewTaskReason = reason
        case .matching: next.matchingStageStatus = target; next.matchingStageReason = reason
        case .cloze: next.clozeStageStatus = target; next.clozeStageReason = reason
        }
        try next.finishMutation(at: timestamp)
        self = next
    }

    mutating func markCarryOverIfNeeded(for localDate: String, calendar: Calendar, at timestamp: Date) -> Bool {
        // Count traversed civil study dates, with a monotone high-water mark; DST is not 86400-second arithmetic.
        let previous = lastCarryOverLocalDate ?? assignedLocalDate
        guard hasOutstandingWork, timestamp >= updatedAtUTC,
              let start = Self.civilDate(previous), let end = Self.civilDate(localDate), end > start else { return false }
        let civilCalendar = Self.civilCalendar
        let days = civilCalendar.dateComponents([.day], from: start, to: end).day ?? 0
        carryOverCount += days
        lastCarryOverLocalDate = localDate
        updatedAtUTC = timestamp
        return true
    }

    static var civilCalendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    static func civilDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = civilCalendar
        formatter.timeZone = civilCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
}

enum DailyCycleProvisioningResult: Equatable {
    case cycle(DailyStudyCycle, created: Bool)
    case noCandidate
}

enum DailyCycleServiceError: Error, Equatable, LocalizedError {
    case invalidTimeZone(String)
    case articleAlreadyUsed(String)
    case invalidCandidate(String)
    case duplicateAssignedDate(String)
    case missingCycle(UUID)

    var errorDescription: String? {
        switch self {
        case let .invalidTimeZone(identifier): return "无法识别学习时区：\(identifier)"
        case let .articleAlreadyUsed(articleID): return "文章已分配过，不能再次作为每日文章：\(articleID)"
        case let .invalidCandidate(reason): return "文章候选不可分配：\(reason)"
        case let .duplicateAssignedDate(date): return "本地学习日期已有必做周期：\(date)"
        case let .missingCycle(cycleID): return "找不到学习周期：\(cycleID.uuidString)"
        }
    }
}

@MainActor
final class DailyCycleService {
    private let cycleStore: StudyCycleStore
    private let candidateProvider: ArticleCandidateProvider
    private let reviewQueue: ReviewQueueReading
    private let readerAvailable: Bool
    private let reviewSessions: ReviewSessionReading?

    init(cycleStore: StudyCycleStore, candidateProvider: ArticleCandidateProvider, reviewQueue: ReviewQueueReading? = nil, readerAvailable: Bool = false, reviewSessions: ReviewSessionReading? = nil) {
        self.cycleStore = cycleStore
        self.candidateProvider = candidateProvider
        self.reviewQueue = reviewQueue ?? UnavailableReviewQueue()
        self.readerAvailable = readerAvailable
        self.reviewSessions = reviewSessions
    }

    func ensureCurrentCycle(
        now: Date,
        timeZone: TimeZone,
        calendar: Calendar,
        assignmentReason: String = "daily-required"
    ) throws -> DailyCycleProvisioningResult {
        var workingCalendar = Calendar(identifier: .gregorian)
        workingCalendar.timeZone = timeZone
        let studyDate = Self.studyDate(for: now, calendar: workingCalendar)

        if var incomplete = try cycleStore.fetchEarliestIncomplete() {
            if incomplete.markCarryOverIfNeeded(for: studyDate, calendar: workingCalendar, at: now) {
                try cycleStore.save(incomplete)
            }
            return .cycle(incomplete, created: false)
        }

        if let completedToday = try cycleStore.fetchByAssignedLocalDate(studyDate) {
            return .cycle(completedToday, created: false)
        }

        let usedArticleIDs = Set(try cycleStore.fetchAll().map(\.articleID))

        let candidates = try candidateProvider.candidates(excluding: usedArticleIDs)
        guard let candidate = candidates.first else { return .noCandidate }
        guard !usedArticleIDs.contains(candidate.id) else {
            throw DailyCycleServiceError.articleAlreadyUsed(candidate.id)
        }
        try candidate.validate(at: now)

        let cycle = try DailyStudyCycle(
            assignedLocalDate: studyDate,
            assignedTimeZoneID: timeZone.identifier,
            articleID: candidate.id,
            createdAtUTC: now,
            updatedAtUTC: now,
            assignmentReason: assignmentReason
        )
        if let atomicStore = cycleStore as? AtomicCycleCreationStore {
            try atomicStore.save(cycle: cycle, candidate: candidate, fetchedAt: now)
        } else {
            throw TaskStatusError.invalidState("周期存储必须支持文章与周期原子创建")
        }
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

    func recoverUnavailableInProgressTasks(at timestamp: Date) throws -> DailyStudyCycle? {
        guard var cycle = try cycleStore.fetchEarliestIncomplete() else { return nil }
        var changed = false
        let tasks: [(DailyTask, TaskStatus)] = [
            (.article, cycle.articleTaskStatus),
            (.review, cycle.reviewTaskStatus),
            (.matching, cycle.matchingStageStatus),
            (.cloze, cycle.clozeStageStatus)
        ]
        for (task, status) in tasks where status == .inProgress {
            try cycle.update(task: task, to: .blocked, reason: "功能尚未接入，未执行任何学习操作", at: timestamp)
            changed = true
        }
        guard changed else { return cycle }
        try cycleStore.save(cycle)
        return cycle
    }

    func resumeEarliestIncomplete() throws -> DailyStudyCycle? {
        try cycleStore.fetchEarliestIncomplete()
    }

    static func studyDate(for date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func completeReading(cycleID: UUID, evidence: ReadingCompletionEvidence) throws -> DailyStudyCycle {
        guard readerAvailable else { throw TaskStatusError.capabilityUnavailable }
        guard var cycle = try cycleStore.fetch(by: cycleID) else { throw DailyCycleServiceError.missingCycle(cycleID) }
        try cycle.completeReading(evidence)
        try cycleStore.save(cycle)
        return cycle
    }

    func recordReviewSession(cycleID: UUID, at timestamp: Date) throws -> DailyStudyCycle {
        guard let reviewSessions else { throw TaskStatusError.capabilityUnavailable }
        guard var cycle = try cycleStore.fetch(by: cycleID) else { throw DailyCycleServiceError.missingCycle(cycleID) }
        let result = try ReviewSessionResult.read(cycleID: cycleID, reader: reviewSessions, at: timestamp)
        try cycle.recordReviewProgress(result)
        try cycleStore.save(cycle)
        return cycle
    }

    func resolveReviewQueue(cycleID: UUID, at timestamp: Date) throws -> DailyStudyCycle {
        guard var cycle = try cycleStore.fetch(by: cycleID) else { throw DailyCycleServiceError.missingCycle(cycleID) }
        // Terminal results are immutable; duplicate requests do not reselect a queue.
        if cycle.reviewEvidence != nil { return cycle }
        let evidence = try ReviewQueueEvidence.evaluate(cycleID: cycleID, reader: reviewQueue, at: timestamp)
        try cycle.resolveEmptyReview(evidence)
        try cycleStore.save(cycle)
        return cycle
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum ArticleCachePermission: Equatable, Sendable, Codable {
    case persistent
    case until(Date)
    func permits(at timestamp: Date) -> Bool {
        switch self { case .persistent: return true; case let .until(expiry): return expiry > timestamp }
    }
}

struct ReadingCompletionEvidence: Equatable, Sendable, Codable {
    enum Confirmation: String, Codable, Sendable { case finishButton, endConfirmation, manualConfirmation }
    let articleID: String
    let bodyHash: String
    let progress: Double
    let confirmation: Confirmation
    let confirmedAt: Date

    init(articleID: String, bodyHash: String, progress: Double, confirmation: Confirmation, confirmedAt: Date) throws {
        self.articleID = articleID; self.bodyHash = bodyHash; self.progress = progress
        self.confirmation = confirmation; self.confirmedAt = confirmedAt
        try validate(articleID: articleID, createdAt: confirmedAt, updatedAt: confirmedAt)
    }

    func validate(articleID: String, createdAt: Date, updatedAt: Date) throws {
        guard self.articleID == articleID, !articleID.isBlank,
              bodyHash.count == 64, bodyHash.allSatisfy({ $0.isHexDigit }),
              progress.isFinite, (0...1).contains(progress),
              confirmation == .manualConfirmation || progress >= 0.9,
              confirmedAt >= createdAt, confirmedAt <= updatedAt else { throw TaskStatusError.verifiedEvidenceRequired }
    }
}

/// Adapter must read the complete eligible queue (including recent new words), not only due items.
/// An unavailable source throws; it MUST NOT return an empty snapshot. No production adapter in Round 1.
@MainActor
protocol ReviewQueueReading {
    func eligibleQueue(for cycleID: UUID, at timestamp: Date) throws -> ReviewQueueSnapshot
}

struct ReviewQueueSnapshot {
    let revision: String
    let eligibleEntryIDs: [String]
    let isComplete: Bool
}

struct UnavailableReviewQueue: ReviewQueueReading {
    func eligibleQueue(for cycleID: UUID, at timestamp: Date) throws -> ReviewQueueSnapshot {
        throw TaskStatusError.capabilityUnavailable
    }
}

struct ReviewQueueEvidence: Equatable, Sendable, Codable {
    let cycleID: UUID
    let sourceRevision: String
    let evaluatedAt: Date
    private let eligibleCount: Int
    private let completeSnapshot: Bool

    private init(cycleID: UUID, snapshot: ReviewQueueSnapshot, at timestamp: Date) {
        self.cycleID = cycleID; sourceRevision = snapshot.revision; evaluatedAt = timestamp
        eligibleCount = snapshot.eligibleEntryIDs.count; completeSnapshot = snapshot.isComplete
    }

    @MainActor
    static func evaluate(cycleID: UUID, reader: ReviewQueueReading, at timestamp: Date) throws -> Self {
        let snapshot = try reader.eligibleQueue(for: cycleID, at: timestamp)
        let evidence = Self(cycleID: cycleID, snapshot: snapshot, at: timestamp)
        try evidence.validate(cycleID: cycleID, createdAt: timestamp, updatedAt: timestamp)
        return evidence
    }

    func validate(cycleID: UUID, createdAt: Date, updatedAt: Date) throws {
        guard self.cycleID == cycleID, !sourceRevision.isBlank, eligibleCount == 0, completeSnapshot,
              evaluatedAt >= createdAt, evaluatedAt <= updatedAt else { throw TaskStatusError.verifiedEvidenceRequired }
    }
}

/// Result of a saved, fixed review session, never a user supplied reason.
/// M5 must supply this through its repository adapter; Round 1 has no production adapter.
struct ReviewSessionResult: Equatable, Sendable, Codable {
    let cycleID: UUID
    let sessionID: UUID
    let sourceRevision: String
    let matchingQuestionIDs: [String]
    let clozeQuestionIDs: [String]
    let matchingAnsweredIDs: [String]
    let clozeAnsweredIDs: [String]
    let recordedAt: Date
    private init(cycleID: UUID, snapshot: SavedReviewSessionSnapshot, recordedAt: Date) {
        self.cycleID = cycleID; sessionID = snapshot.sessionID; sourceRevision = snapshot.sourceRevision
        matchingQuestionIDs = snapshot.matchingQuestionIDs; clozeQuestionIDs = snapshot.clozeQuestionIDs
        matchingAnsweredIDs = snapshot.matchingAnsweredIDs; clozeAnsweredIDs = snapshot.clozeAnsweredIDs
        self.recordedAt = recordedAt
    }
    @MainActor
    static func read(cycleID: UUID, reader: ReviewSessionReading, at timestamp: Date) throws -> Self {
        let snapshot = try reader.savedSession(for: cycleID, at: timestamp)
        guard snapshot.cycleID == cycleID else { throw TaskStatusError.verifiedEvidenceRequired }
        let result = Self(cycleID: cycleID, snapshot: snapshot, recordedAt: timestamp)
        try result.validate(cycleID: cycleID, createdAt: timestamp, updatedAt: timestamp)
        return result
    }
    var matchingComplete: Bool { Set(matchingQuestionIDs) == Set(matchingAnsweredIDs) }
    var clozeComplete: Bool { Set(clozeQuestionIDs) == Set(clozeAnsweredIDs) }
    var isComplete: Bool { matchingComplete && clozeComplete }
    func validate(cycleID: UUID, createdAt: Date, updatedAt: Date) throws {
        guard self.cycleID == cycleID, !sourceRevision.isBlank,
              recordedAt >= createdAt, recordedAt <= updatedAt else { throw TaskStatusError.verifiedEvidenceRequired }
        for (questions, answers) in [(matchingQuestionIDs, matchingAnsweredIDs), (clozeQuestionIDs, clozeAnsweredIDs)] {
            guard !questions.isEmpty, questions.allSatisfy({ !$0.isBlank }), Set(questions).count == questions.count,
                  Set(answers).count == answers.count, Set(answers).isSubset(of: Set(questions)) else { throw TaskStatusError.verifiedEvidenceRequired }
        }
    }
}

@MainActor
protocol ReviewSessionReading {
    func savedSession(for cycleID: UUID, at timestamp: Date) throws -> SavedReviewSessionSnapshot
}

struct SavedReviewSessionSnapshot {
    let cycleID: UUID
    let sessionID: UUID
    let sourceRevision: String
    let matchingQuestionIDs: [String]
    let clozeQuestionIDs: [String]
    let matchingAnsweredIDs: [String]
    let clozeAnsweredIDs: [String]
}
