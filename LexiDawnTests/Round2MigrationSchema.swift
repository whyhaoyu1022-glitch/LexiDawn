import Foundation
import SwiftData

// Frozen stored properties and constructors from remote main 93b4253, before Round 3.
// Used only to create a real historical disk store, never as production data.
enum FrozenRound2Schema {
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
    var fullTextDisplayAllowed: Bool?
    var imageLicenseVerified: Bool?
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
        self.fullTextDisplayAllowed = nil
        self.imageLicenseVerified = nil
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

@Model final class ContentGrantRecord {
    @Attribute(.unique) var articleID: String
    var sourceID: String
    var bodyHash: String
    var scope: String
    var evidenceURL: String
    var originalURL: String?
    var acceptedAt: Date
    var accessHighWater: Date
    var eligibleForDaily: Bool
    init(articleID: String, sourceID: String, bodyHash: String, scope: String, evidenceURL: String,
         originalURL: String?, acceptedAt: Date, eligibleForDaily: Bool) {
        self.articleID = articleID; self.sourceID = sourceID; self.bodyHash = bodyHash
        self.scope = scope; self.evidenceURL = evidenceURL; self.originalURL = originalURL
        self.acceptedAt = acceptedAt; accessHighWater = acceptedAt; self.eligibleForDaily = eligibleForDaily
    }
}

@Model final class SourceAcquisitionRecord {
    @Attribute(.unique) var sourceID: String
    var lastAttempt: Date?
    var lastSuccess: Date?
    var lastError: String?
    var retryAfter: Date?
    var enabled: Bool
    init(sourceID: String) { self.sourceID = sourceID; enabled = true }
}

@Model final class ArticleProgressRecord {
    @Attribute(.unique) var progressID: String
    var articleID: String
    var cycleID: String?
    var mode: String
    var status: String
    var readingPercent: Double
    var anchor: String?
    var characterOffset: Int
    var bodyHash: String
    var startedAt: Date
    var lastReadAt: Date
    var completedAt: Date?
    init(articleID: String, cycleID: UUID?, bodyHash: String, at: Date) {
        progressID = Self.key(articleID, cycleID); self.articleID = articleID; self.cycleID = cycleID?.uuidString
        mode = cycleID == nil ? "explore" : "daily"; status = "inProgress"; readingPercent = 0
        characterOffset = 0; self.bodyHash = bodyHash; startedAt = at; lastReadAt = at
    }
    static func key(_ articleID: String, _ cycleID: UUID?) -> String { "\(cycleID?.uuidString ?? "explore")|\(articleID)" }
}

@Model final class VocabularyEntryRecord {
    @Attribute(.unique) var entryID: String
    @Attribute(.unique) var normalizedKey: String
    var lemma: String
    var surfaceForms: [String]
    var entryType: String
    var languageCode: String
    var addedAt: Date
    var addedFrom: String
    var dictionaryEntryID: String?
    var deletedAt: Date?
    var lastOpenedAt: Date
    var notes: String?
    var userMeaning: String?
    var creationToken: String
    var revision: Int
    init(lemma: String, surface: String, type: String, at: Date, from: String, token: String) {
        entryID = UUID().uuidString; normalizedKey = "en|\(type)|\(lemma)"; self.lemma = lemma
        surfaceForms = [surface]; entryType = type; languageCode = "en"; addedAt = at; addedFrom = from
        lastOpenedAt = at; creationToken = token; revision = 1
    }
}

@Model final class VocabularySourceContextRecord {
    @Attribute(.unique) var contextID: String
    var entryID: String
    var articleID: String
    var surface: String
    var sentence: String
    var tokenLocation: Int
    var createdAt: Date
    init(entryID: String, articleID: String, surface: String, sentence: String, tokenLocation: Int, at: Date) {
        contextID = "\(entryID)|\(articleID)|\(tokenLocation)"; self.entryID = entryID; self.articleID = articleID
        self.surface = surface; self.sentence = sentence; self.tokenLocation = tokenLocation; createdAt = at
    }
}

@Model final class DictionaryEntryRecord {
    @Attribute(.unique) var entryID: String
    var headword: String
    var provider: String
    var sourceURL: String
    var licenseURL: String
    var updatedAt: Date
    init(headword: String, at: Date) {
        entryID = "cedict-reverse-v1|\(headword)"; self.headword = headword; provider = "CC-CEDICT reverse index"
        sourceURL = "https://www.mdbg.net/chinese/dictionary?page=cc-cedict"
        licenseURL = "https://creativecommons.org/licenses/by-sa/4.0/"; updatedAt = at
    }
}

@Model final class DictionarySenseRecord {
    @Attribute(.unique) var senseID: String
    var entryID: String
    var english: String
    var chinese: String
    var partOfSpeech: String?
    var sourceLine: String
    init(senseID: String, entryID: String, english: String, chinese: String, sourceLine: String) {
        self.senseID = senseID; self.entryID = entryID; self.english = english; self.chinese = chinese; self.sourceLine = sourceLine
    }
}

@Model final class ReviewStateRecord {
    @Attribute(.unique) var entryID: String
    var dueAt: Date
    var intervalDays: Int
    var repetitions: Int
    var lapses: Int
    var algorithmVersion: String
    var lastReviewedAt: Date?
    init(entryID: String, at: Date) {
        self.entryID = entryID; dueAt = at; intervalDays = 0; repetitions = 0; lapses = 0
        algorithmVersion = BasicReviewScheduler.version
    }
}

@Model final class ReviewSessionRecord {
    @Attribute(.unique) var sessionID: String
    @Attribute(.unique) var cycleID: String
    var selectedEntryIDs: [String]
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var revision: Int
    var dailyLimit: Int
    var algorithmVersion: String
    init(cycleID: UUID, entries: [String], at: Date, limit: Int) {
        sessionID = UUID().uuidString; self.cycleID = cycleID.uuidString; selectedEntryIDs = entries
        createdAt = at; updatedAt = at; revision = 0; dailyLimit = limit; algorithmVersion = BasicReviewScheduler.version
    }
}

@Model final class ReviewExerciseRecord {
    @Attribute(.unique) var exerciseID: String
    var sessionID: String
    var entryID: String
    var stage: String
    var position: Int
    var prompt: String
    var answer: String
    var senseID: String
    var attempts: Int
    var usedHint: Bool
    var revealed: Bool
    var firstTryCorrect: Bool
    var completedAt: Date?
    init(sessionID: String, entryID: String, stage: String, position: Int, prompt: String, answer: String, senseID: String) {
        exerciseID = "\(sessionID)|\(stage)|\(entryID)"; self.sessionID = sessionID; self.entryID = entryID
        self.stage = stage; self.position = position; self.prompt = prompt; self.answer = answer; self.senseID = senseID
        attempts = 0; usedHint = false; revealed = false; firstTryCorrect = false
    }
}

@Model final class ReviewLogRecord {
    @Attribute(.unique) var eventID: String
    var entryID: String
    var sessionID: String
    var grade: String
    var reviewedAt: Date
    var previousDueAt: Date
    var nextDueAt: Date
    var algorithmVersion: String
    init(sessionID: String, entryID: String, grade: String, at: Date, previousDueAt: Date, nextDueAt: Date) {
        eventID = "\(sessionID)|\(entryID)"; self.sessionID = sessionID; self.entryID = entryID; self.grade = grade
        reviewedAt = at; self.previousDueAt = previousDueAt; self.nextDueAt = nextDueAt; algorithmVersion = BasicReviewScheduler.version
    }
}
    @MainActor static var schema: Schema { Schema([ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self, ContentGrantRecord.self, SourceAcquisitionRecord.self, ArticleProgressRecord.self, VocabularyEntryRecord.self, VocabularySourceContextRecord.self, DictionaryEntryRecord.self, DictionarySenseRecord.self, ReviewStateRecord.self, ReviewSessionRecord.self, ReviewExerciseRecord.self, ReviewLogRecord.self]) }
}
