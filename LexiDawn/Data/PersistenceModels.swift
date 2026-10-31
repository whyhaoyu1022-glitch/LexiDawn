import Foundation
import SwiftData

@Model
final class ArticleRecord {
    @Attribute(.unique) var articleID: String
    var canonicalURL: String
    var originalTitle: String
    var displayTitle: String?
    var sourceID: String
    var publishedAt: Date?
    var fetchedAt: Date
    var licenseID: String?
    var licenseVerified: Bool
    var bodyText: String?
    var bodyHash: String?
    var cachePermissionData: Data?
    var imageLicenseID: String?
    var sourceAttribution: String?
    var wordCount: Int
    var estimatedReadMinutes: Int
    var topicTags: [String]
    var difficulty: String?
    var imageURL: String?
    var imageAttribution: String?
    var contentStatus: String
    var createdAt: Date
    var updatedAt: Date

    init(
        articleID: String,
        canonicalURL: String,
        originalTitle: String,
        displayTitle: String? = nil,
        sourceID: String,
        publishedAt: Date? = nil,
        fetchedAt: Date,
        licenseID: String? = nil,
        licenseVerified: Bool = false,
        bodyText: String? = nil,
        bodyHash: String? = nil,
        wordCount: Int = 0,
        estimatedReadMinutes: Int = 0,
        topicTags: [String] = [],
        difficulty: String? = nil,
        imageURL: String? = nil,
        imageAttribution: String? = nil,
        contentStatus: String = "unavailable",
        createdAt: Date,
        updatedAt: Date
    ) {
        self.articleID = articleID
        self.canonicalURL = canonicalURL
        self.originalTitle = originalTitle
        self.displayTitle = displayTitle
        self.sourceID = sourceID
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.licenseID = licenseID
        self.licenseVerified = licenseVerified
        self.bodyText = bodyText
        self.bodyHash = bodyHash
        self.cachePermissionData = nil
        self.imageLicenseID = nil
        self.sourceAttribution = nil
        self.wordCount = wordCount
        self.estimatedReadMinutes = estimatedReadMinutes
        self.topicTags = topicTags
        self.difficulty = difficulty
        self.imageURL = imageURL
        self.imageAttribution = imageAttribution
        self.contentStatus = contentStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyStudyCycleRecord {
    @Attribute(.unique) var cycleID: String
    var assignedLocalDate: String
    var assignedTimeZoneID: String
    var articleID: String
    var articleTaskStatusRaw: String
    var reviewTaskStatusRaw: String
    var matchingStageStatusRaw: String
    var clozeStageStatusRaw: String
    var createdAtUTC: Date
    var updatedAtUTC: Date
    var completedAtUTC: Date?
    var carryOverCount: Int
    var assignmentReason: String
    var isCurrent: Bool
    var completionReason: String?
    var lastCarryOverLocalDate: String?
    var articleTaskReason: String?
    var reviewTaskReason: String?
    var matchingStageReason: String?
    var clozeStageReason: String?
    var readingEvidenceData: Data?
    var reviewEvidenceData: Data?
    var reviewProgressData: Data?
    var recoveryArchiveData: Data?

    init(cycle: DailyStudyCycle) throws {
        try cycle.validate()
        self.cycleID = cycle.cycleID.uuidString
        self.assignedLocalDate = cycle.assignedLocalDate
        self.assignedTimeZoneID = cycle.assignedTimeZoneID
        self.articleID = cycle.articleID
        self.articleTaskStatusRaw = cycle.articleTaskStatus.rawValue
        self.reviewTaskStatusRaw = cycle.reviewTaskStatus.rawValue
        self.matchingStageStatusRaw = cycle.matchingStageStatus.rawValue
        self.clozeStageStatusRaw = cycle.clozeStageStatus.rawValue
        self.createdAtUTC = cycle.createdAtUTC
        self.updatedAtUTC = cycle.updatedAtUTC
        self.completedAtUTC = cycle.completedAtUTC
        self.carryOverCount = cycle.carryOverCount
        self.assignmentReason = cycle.assignmentReason
        self.isCurrent = cycle.isCurrent
        self.completionReason = cycle.completionReason
        self.lastCarryOverLocalDate = cycle.lastCarryOverLocalDate
        self.articleTaskReason = cycle.articleTaskReason
        self.reviewTaskReason = cycle.reviewTaskReason
        self.matchingStageReason = cycle.matchingStageReason
        self.clozeStageReason = cycle.clozeStageReason
        self.readingEvidenceData = try cycle.readingEvidence.map { try JSONEncoder().encode($0) }
        self.reviewEvidenceData = try cycle.reviewEvidence.map { try JSONEncoder().encode($0) }
        self.reviewProgressData = try cycle.reviewProgress.map { try JSONEncoder().encode($0) }
        self.recoveryArchiveData = nil
    }

    func apply(_ cycle: DailyStudyCycle) throws {
        try cycle.validate()
        reviewProgressData = try cycle.reviewProgress.map { try JSONEncoder().encode($0) }
        readingEvidenceData = try cycle.readingEvidence.map { try JSONEncoder().encode($0) }
        reviewEvidenceData = try cycle.reviewEvidence.map { try JSONEncoder().encode($0) }
        assignedLocalDate = cycle.assignedLocalDate
        assignedTimeZoneID = cycle.assignedTimeZoneID
        articleID = cycle.articleID
        articleTaskStatusRaw = cycle.articleTaskStatus.rawValue
        reviewTaskStatusRaw = cycle.reviewTaskStatus.rawValue
        matchingStageStatusRaw = cycle.matchingStageStatus.rawValue
        clozeStageStatusRaw = cycle.clozeStageStatus.rawValue
        createdAtUTC = cycle.createdAtUTC
        updatedAtUTC = cycle.updatedAtUTC
        completedAtUTC = cycle.completedAtUTC
        carryOverCount = cycle.carryOverCount
        assignmentReason = cycle.assignmentReason
        isCurrent = cycle.isCurrent
        completionReason = cycle.completionReason
        lastCarryOverLocalDate = cycle.lastCarryOverLocalDate
        articleTaskReason = cycle.articleTaskReason
        reviewTaskReason = cycle.reviewTaskReason
        matchingStageReason = cycle.matchingStageReason
        clozeStageReason = cycle.clozeStageReason
    }

    func domain() throws -> DailyStudyCycle {
        let rawCycleID = self.cycleID
        guard let cycleID = UUID(uuidString: rawCycleID),
              let articleStatus = TaskStatus(rawValue: articleTaskStatusRaw),
              let reviewStatus = TaskStatus(rawValue: reviewTaskStatusRaw),
              let matchingStatus = TaskStatus(rawValue: matchingStageStatusRaw),
              let clozeStatus = TaskStatus(rawValue: clozeStageStatusRaw) else {
            throw PersistenceError.invalidCycleRecord(rawCycleID)
        }
        return try DailyStudyCycle(
            cycleID: cycleID,
            assignedLocalDate: assignedLocalDate,
            assignedTimeZoneID: assignedTimeZoneID,
            articleID: articleID,
            articleTaskStatus: articleStatus,
            reviewTaskStatus: reviewStatus,
            matchingStageStatus: matchingStatus,
            clozeStageStatus: clozeStatus,
            createdAtUTC: createdAtUTC,
            updatedAtUTC: updatedAtUTC,
            completedAtUTC: completedAtUTC,
            carryOverCount: carryOverCount,
            assignmentReason: assignmentReason,
            isCurrent: isCurrent,
            completionReason: completionReason,
            lastCarryOverLocalDate: lastCarryOverLocalDate,
            articleTaskReason: articleTaskReason,
            reviewTaskReason: reviewTaskReason,
            matchingStageReason: matchingStageReason,
            clozeStageReason: clozeStageReason,
            readingEvidence: try readingEvidenceData.map { try JSONDecoder().decode(ReadingCompletionEvidence.self, from: $0) },
            reviewEvidence: try reviewEvidenceData.map { try JSONDecoder().decode(ReviewQueueEvidence.self, from: $0) },
            reviewProgress: try reviewProgressData.map { try JSONDecoder().decode(ReviewSessionResult.self, from: $0) }
        )
    }
}

@Model
final class UserPreferencesRecord {
    @Attribute(.unique) var preferencesID: String
    var schemaVersion: Int
    var ageRange: String?
    var displayName: String
    var learningGoal: String
    var interestTopics: [String]
    var dailyReadingReminderEnabled: Bool
    var dailyReadingReminderHour: Int
    var dailyReadingReminderMinute: Int
    var dailyReviewReminderEnabled: Bool
    var dailyReviewReminderHour: Int
    var dailyReviewReminderMinute: Int
    var timeZonePolicy: String
    var fixedTimeZoneID: String?
    var autoAddOnWordTap: Bool
    var defaultPronunciation: String
    var readerFontSize: Double
    var readerLineSpacing: Double
    var readerTheme: String
    var showChineseSummary: Bool
    var dailyReviewLimit: Int
    var matchingPairCount: Int
    var clozeQuestionCount: Int
    var clozeDifficulty: String
    var aiEnabled: Bool
    var aiResponseLanguage: String
    var aiResponseLength: String
    var lastUpdatedAt: Date

    init(
        preferencesID: String = "default",
        schemaVersion: Int = 1,
        displayName: String = "",
        ageRange: String? = nil,
        learningGoal: String = "提升英文阅读能力",
        interestTopics: [String] = [],
        dailyReadingReminderEnabled: Bool = true,
        dailyReadingReminderHour: Int = 6,
        dailyReadingReminderMinute: Int = 20,
        dailyReviewReminderEnabled: Bool = true,
        dailyReviewReminderHour: Int = 21,
        dailyReviewReminderMinute: Int = 20,
        timeZonePolicy: String = "device",
        fixedTimeZoneID: String? = nil,
        autoAddOnWordTap: Bool = true,
        defaultPronunciation: String = "system",
        readerFontSize: Double = 19,
        readerLineSpacing: Double = 1.5,
        readerTheme: String = "system",
        showChineseSummary: Bool = true,
        dailyReviewLimit: Int = 12,
        matchingPairCount: Int = 6,
        clozeQuestionCount: Int = 4,
        clozeDifficulty: String = "adaptive",
        aiEnabled: Bool = false,
        aiResponseLanguage: String = "zh-Hans",
        aiResponseLength: String = "concise",
        lastUpdatedAt: Date = Date()
    ) {
        self.preferencesID = preferencesID
        self.schemaVersion = schemaVersion
        self.displayName = displayName
        self.ageRange = ageRange
        self.learningGoal = learningGoal
        self.interestTopics = interestTopics
        self.dailyReadingReminderEnabled = dailyReadingReminderEnabled
        self.dailyReadingReminderHour = dailyReadingReminderHour
        self.dailyReadingReminderMinute = dailyReadingReminderMinute
        self.dailyReviewReminderEnabled = dailyReviewReminderEnabled
        self.dailyReviewReminderHour = dailyReviewReminderHour
        self.dailyReviewReminderMinute = dailyReviewReminderMinute
        self.timeZonePolicy = timeZonePolicy
        self.fixedTimeZoneID = fixedTimeZoneID
        self.autoAddOnWordTap = autoAddOnWordTap
        self.defaultPronunciation = defaultPronunciation
        self.readerFontSize = readerFontSize
        self.readerLineSpacing = readerLineSpacing
        self.readerTheme = readerTheme
        self.showChineseSummary = showChineseSummary
        self.dailyReviewLimit = dailyReviewLimit
        self.matchingPairCount = matchingPairCount
        self.clozeQuestionCount = clozeQuestionCount
        self.clozeDifficulty = clozeDifficulty
        self.aiEnabled = aiEnabled
        self.aiResponseLanguage = aiResponseLanguage
        self.aiResponseLength = aiResponseLength
        self.lastUpdatedAt = lastUpdatedAt
    }
}

enum PersistenceError: Error, Equatable, LocalizedError {
    case invalidCycleRecord(String)
    case missingPreferences
    case duplicateAssignedDate(String)
    case duplicateCanonicalURL(String)
    case integrity(String)

    var errorDescription: String? {
        switch self {
        case let .integrity(reason): return "数据一致性检查失败：\(reason)。原记录保留，请勿删除数据库。"
        case let .invalidCycleRecord(id): return "学习周期数据无效：\(id)"
        case .missingPreferences: return "未找到用户偏好设置"
        case let .duplicateAssignedDate(date): return "本地学习日期已有周期：\(date)"
        case let .duplicateCanonicalURL(url): return "文章 canonicalURL 重复：\(url)"
        }
    }
}

/// A lossless archive of cycle scalar fields before a conservative legacy repair.
struct CycleRecoveryArchive: Codable {
    let cycleID: String
    let articleID: String
    let assignedLocalDate: String
    let assignedTimeZoneID: String
    let statuses: [String]
    let reasons: [String?]
    let createdAtUTC: Date
    let updatedAtUTC: Date
    let completedAtUTC: Date?
    let carryOverCount: Int
    let lastCarryOverLocalDate: String?
    let assignmentReason: String
    let completionReason: String?
    let isCurrent: Bool
    let readingEvidenceData: Data?
    let reviewEvidenceData: Data?
    let repairedAt: Date

    init(_ record: DailyStudyCycleRecord, at timestamp: Date) {
        cycleID = record.cycleID; articleID = record.articleID
        assignedLocalDate = record.assignedLocalDate; assignedTimeZoneID = record.assignedTimeZoneID
        statuses = [record.articleTaskStatusRaw, record.reviewTaskStatusRaw, record.matchingStageStatusRaw, record.clozeStageStatusRaw]
        reasons = [record.articleTaskReason, record.reviewTaskReason, record.matchingStageReason, record.clozeStageReason]
        createdAtUTC = record.createdAtUTC; updatedAtUTC = record.updatedAtUTC; completedAtUTC = record.completedAtUTC
        carryOverCount = record.carryOverCount; lastCarryOverLocalDate = record.lastCarryOverLocalDate
        assignmentReason = record.assignmentReason; completionReason = record.completionReason; isCurrent = record.isCurrent
        readingEvidenceData = record.readingEvidenceData; reviewEvidenceData = record.reviewEvidenceData; repairedAt = timestamp
    }
}

extension DailyStudyCycleRecord {
    /// Only known legacy defects are repaired. Unknown enums, malformed proof data,
    /// invalid identity/time fields and missing articles stop recovery without deleting data.
    func repairKnownLegacyState(at timestamp: Date) throws -> Bool {
        if (try? domain()) != nil { return false }
        let raws = [articleTaskStatusRaw, reviewTaskStatusRaw, matchingStageStatusRaw, clozeStageStatusRaw]
        guard raws.allSatisfy({ TaskStatus(rawValue: $0) != nil }),
              readingEvidenceData == nil, reviewEvidenceData == nil, reviewProgressData == nil else {
            throw PersistenceError.invalidCycleRecord(cycleID)
        }
        let archive = try JSONEncoder().encode(CycleRecoveryArchive(self, at: timestamp))
        let explanation = "历史状态缺少可验证的完成依据，原始状态已保留；功能接入前尚不能恢复学习"
        if articleTaskStatusRaw == "deferred" || articleTaskStatusRaw == "completed" || articleTaskStatusRaw == "locked" {
            articleTaskStatusRaw = "blocked"; articleTaskReason = explanation
        }
        if reviewTaskStatusRaw == "deferred" || reviewTaskStatusRaw == "completed" {
            reviewTaskStatusRaw = "blocked"; reviewTaskReason = explanation
        }
        if matchingStageStatusRaw == "deferred" || matchingStageStatusRaw == "completed" {
            matchingStageStatusRaw = "blocked"; matchingStageReason = explanation
        }
        if clozeStageStatusRaw == "deferred" || clozeStageStatusRaw == "completed" {
            clozeStageStatusRaw = "blocked"; clozeStageReason = explanation
        }
        if ["blocked", "failed"].contains(articleTaskStatusRaw), articleTaskReason?.isBlank ?? true { articleTaskReason = explanation }
        if ["blocked", "failed"].contains(reviewTaskStatusRaw), reviewTaskReason?.isBlank ?? true { reviewTaskReason = explanation }
        if ["blocked", "failed"].contains(matchingStageStatusRaw), matchingStageReason?.isBlank ?? true { matchingStageReason = explanation }
        if ["blocked", "failed"].contains(clozeStageStatusRaw), clozeStageReason?.isBlank ?? true { clozeStageReason = explanation }
        if ["ready", "inProgress"].contains(articleTaskStatusRaw) { articleTaskReason = nil }
        if ["ready", "inProgress"].contains(reviewTaskStatusRaw) { reviewTaskReason = nil }
        if ["ready", "inProgress"].contains(matchingStageStatusRaw) { matchingStageReason = nil }
        if ["ready", "inProgress"].contains(clozeStageStatusRaw) { clozeStageReason = nil }
        completedAtUTC = nil; completionReason = nil
        // Preserve chronology and the user's assignment; original completion/progress remains in the archive.
        updatedAtUTC = max(updatedAtUTC, timestamp)
        if recoveryArchiveData == nil { recoveryArchiveData = archive }
        _ = try domain()
        return true
    }
}
