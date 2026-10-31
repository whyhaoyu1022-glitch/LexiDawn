import Foundation
import SwiftData

// Round 2 adds entities without renaming/removing any Round 1 stored property.
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

@MainActor enum LearningSchema {
    static var schema: Schema { Schema([ArticleRecord.self, DailyStudyCycleRecord.self, UserPreferencesRecord.self,
        ContentGrantRecord.self, SourceAcquisitionRecord.self, ArticleProgressRecord.self, VocabularyEntryRecord.self,
        VocabularySourceContextRecord.self, DictionaryEntryRecord.self, DictionarySenseRecord.self, ReviewStateRecord.self,
        ReviewSessionRecord.self, ReviewExerciseRecord.self, ReviewLogRecord.self]) }
    static func container(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [configuration])
    }
}
