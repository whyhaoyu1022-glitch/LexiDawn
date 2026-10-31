import Foundation
import SwiftData
@testable import LexiDawn

// Frozen stored properties from public Git commits; keep these schemas unchanged.
// Source: c13906ae66515c29cb9a602da061caf810a62ade, LexiDawn/Data/PersistenceModels.swift
enum LegacyRound1Schema {
@Model
final class ArticleRecord {
    @Attribute(.unique) var articleID: String
    var canonicalURL: String
    var originalTitle: String
    var sourceID: String
    var publishedAt: Date?
    var fetchedAt: Date
    var licenseID: String?
    var licenseVerified: Bool
    var bodyText: String?
    var bodyHash: String?
    var wordCount: Int
    var estimatedReadMinutes: Int
    var topicTags: [String]
    var contentStatus: String
    var createdAt: Date
    var updatedAt: Date

    init(
        articleID: String,
        canonicalURL: String,
        originalTitle: String,
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
        contentStatus: String = "unavailable",
        createdAt: Date,
        updatedAt: Date
    ) {
        self.articleID = articleID
        self.canonicalURL = canonicalURL
        self.originalTitle = originalTitle
        self.sourceID = sourceID
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.licenseID = licenseID
        self.licenseVerified = licenseVerified
        self.bodyText = bodyText
        self.bodyHash = bodyHash
        self.wordCount = wordCount
        self.estimatedReadMinutes = estimatedReadMinutes
        self.topicTags = topicTags
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
    var lastCarryOverLocalDate: String?
    var articleTaskReason: String?
    var reviewTaskReason: String?
    var matchingStageReason: String?
    var clozeStageReason: String?

    init(cycle: DailyStudyCycle) {
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
        self.lastCarryOverLocalDate = cycle.lastCarryOverLocalDate
        self.articleTaskReason = cycle.articleTaskReason
        self.reviewTaskReason = cycle.reviewTaskReason
        self.matchingStageReason = cycle.matchingStageReason
        self.clozeStageReason = cycle.clozeStageReason
    }

}

@Model
final class UserPreferencesRecord {
    @Attribute(.unique) var preferencesID: String
    var schemaVersion: Int
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
        readerFontSize: Double = 18,
        readerLineSpacing: Double = 1.2,
        readerTheme: String = "system",
        showChineseSummary: Bool = true,
        dailyReviewLimit: Int = 20,
        matchingPairCount: Int = 5,
        clozeQuestionCount: Int = 5,
        clozeDifficulty: String = "adaptive",
        aiEnabled: Bool = false,
        aiResponseLanguage: String = "zh-Hans",
        aiResponseLength: String = "concise",
        lastUpdatedAt: Date = Date()
    ) {
        self.preferencesID = preferencesID
        self.schemaVersion = schemaVersion
        self.displayName = displayName
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

}

// Source: b894bdacadbee3a52073f6c300ab043c7e43caa8, LexiDawn/Data/PersistenceModels.swift
enum LegacyRemediatedSchema {
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

    init(cycle: DailyStudyCycle) {
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
    }

}

@Model
final class UserPreferencesRecord {
    @Attribute(.unique) var preferencesID: String
    var schemaVersion: Int
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
        readerFontSize: Double = 18,
        readerLineSpacing: Double = 1.2,
        readerTheme: String = "system",
        showChineseSummary: Bool = true,
        dailyReviewLimit: Int = 20,
        matchingPairCount: Int = 5,
        clozeQuestionCount: Int = 5,
        clozeDifficulty: String = "adaptive",
        aiEnabled: Bool = false,
        aiResponseLanguage: String = "zh-Hans",
        aiResponseLength: String = "concise",
        lastUpdatedAt: Date = Date()
    ) {
        self.preferencesID = preferencesID
        self.schemaVersion = schemaVersion
        self.displayName = displayName
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

}

