import XCTest
import SwiftData
@testable import LexiDawn

@MainActor final class Round4Tests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_798_300_000)
    func testEnglishOnlyDoesNotLockPersonalChineseDefinitions() {
        let english = DictionarySense(id: "en", en: "Explicit English fixture definition", zh: "", line: "Fixture", sources: [BundledMDXDictionaryProvider.sourceName], sourceRevision: BundledMDXDictionaryProvider.sourceVersion, originKind: "mdx")
        XCTAssertFalse(BilingualMeaningPolicy.trusted(english))
        XCTAssertTrue(BilingualMeaningPolicy.permitsPersonal(senses: [english], knownReliableChinese: false, availability: .noChinese))
        XCTAssertTrue(BilingualMeaningPolicy.displaySenses([english]).isEmpty)
    }
    func testTrustedChineseLocksButReverseIndexDoesNot() {
        let trusted = DictionarySense(id: "trusted", en: "", zh: "明确原创中文义项夹具", line: "Fixture", sources: [BundledMDXDictionaryProvider.sourceName], sourceRevision: BundledMDXDictionaryProvider.sourceVersion, originKind: "mdx")
        let reverse = DictionarySense(id: "reverse", en: "", zh: "反向候选", line: "Fixture", sources: ["CC-CEDICT"])
        XCTAssertTrue(BilingualMeaningPolicy.trusted(trusted))
        XCTAssertFalse(BilingualMeaningPolicy.permitsPersonal(senses: [trusted], knownReliableChinese: false, availability: .noChinese))
        XCTAssertTrue(BilingualMeaningPolicy.permitsPersonal(senses: [reverse], knownReliableChinese: false, availability: .noChinese))
        XCTAssertFalse(BilingualMeaningPolicy.permitsPersonal(senses: [], knownReliableChinese: true, availability: .notFound))
    }
    func testChineseWiktionaryParserScopesEnglishAndPreservesPartOfSpeech() throws {
        let html = "<h2>法語</h2><h3>名詞</h3><ol><li>错误语言夹具</li></ol><h2>英語</h2><h3>名詞</h3><ol><li>明确原创名词义项</li></ol><h3>動詞</h3><ol><li>明确原创动词义项</li></ol><h2>德語</h2><h3>名詞</h3><ol><li>另一个错误语言夹具</li></ol>"
        let values = try WiktionaryBilingualParser.parse(html, revision: "fixture-7")
        XCTAssertEqual(values.map(\.zh), ["明确原创名词义项", "明确原创动词义项"])
        XCTAssertEqual(values.map(\.partOfSpeech), ["noun", "verb"])
        XCTAssertTrue(values.allSatisfy { $0.sourceRevision == "fixture-7" && !BilingualMeaningPolicy.trusted($0) })
    }
    func testChineseParserRejectsOtherLanguageAndEnglishOnly() throws {
        XCTAssertTrue(try WiktionaryBilingualParser.parse("<h2>法語</h2><h3>名詞</h3><ol><li>不属于英语</li></ol>", revision: "1").isEmpty)
        XCTAssertTrue(try WiktionaryBilingualParser.parse("<h2>英語</h2><h3>名詞</h3><ol><li>English only fixture</li></ol>", revision: "1").isEmpty)
    }
    func testPersonalSenseRetainsExamplesAndReadiness() throws {
        var sense = PersonalDictionarySense()
        sense.chinese = "用户明确输入的中文"
        XCTAssertFalse(sense.reviewReady)
        sense.partOfSpeech = "noun"; sense.confirmed = true
        sense.examples = [.init(english: "An explicit fixture sentence.", chinese: "用户例句译文")]
        XCTAssertTrue(sense.reviewReady)
        let decoded = try JSONDecoder().decode(PersonalDictionarySense.self, from: JSONEncoder().encode(sense))
        XCTAssertEqual(decoded, sense)
        XCTAssertEqual(decoded.dictionarySense(entryID: "test").exampleTranslations, ["用户例句译文"])
        XCTAssertEqual(decoded.dictionarySense(entryID: "test").originKind, "personal")
    }
    func testSeededMaskIsStableDistributedAndRetainsSeparators() {
        let a = SpellingMaskPolicy.mask("take into account", seed: "session-a")
        XCTAssertEqual(a.text, SpellingMaskPolicy.mask("take into account", seed: "session-a").text)
        XCTAssertEqual(a.indices, SpellingMaskPolicy.mask("take into account", seed: "session-a").indices)
        XCTAssertEqual(Array(a.text)[4], " "); XCTAssertEqual(Array(a.text)[9], " ")
        let masks = (0..<20).map { SpellingMaskPolicy.mask("provide", seed: "seed-\($0)").indices }
        XCTAssertTrue(masks.contains { $0.contains(0) })
        XCTAssertTrue(masks.contains { $0.contains(3) })
        XCTAssertTrue(masks.contains { $0.contains(6) })
        XCTAssertTrue(SpellingMaskPolicy.mask("an", seed: "short").indices.isEmpty)
        for word in ["provide", "information", "long-term", "take into account", "May", "user", "visits"] {
            for seed in 0..<64 {
                let value = SpellingMaskPolicy.mask(word, seed: "fixed-corpus-\(seed)")
                let characters = Array(word), letters = characters.filter(\.isLetter).count
                let ratio = Double(value.indices.count) / Double(letters)
                XCTAssertGreaterThanOrEqual(ratio, 0.25); XCTAssertLessThanOrEqual(ratio, 0.45)
                for index in value.indices { XCTAssertTrue(characters[index].isLetter) }
                XCTAssertEqual(value.indices, SpellingMaskPolicy.mask(word, seed: "fixed-corpus-\(seed)").indices)
            }
        }
    }
    func testCanonicalFormsKeepMonthModalAndNonPluralS() {
        XCTAssertEqual(EnglishTokenizer.lemma("users"), "user")
        XCTAssertEqual(EnglishTokenizer.lemma("visits"), "visit")
        XCTAssertEqual(EnglishTokenizer.lemma("May"), "May")
        XCTAssertEqual(EnglishTokenizer.lemma("may"), "may")
        XCTAssertEqual(EnglishTokenizer.lemma("US"), "US")
        XCTAssertEqual(EnglishTokenizer.lemma("news"), "news")
    }
    private func entry(_ learning: LearningServices) throws -> VocabularyAddition {
        let id = try learning.content.importArticle(.init(title: "Explicit Round 4 fixture", body: "A lexidawnfixtureword appears in this original test sentence.", source: "Original XCTest fixture", rightsConfirmed: true), at: now)
        let addition = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "lexidawnfixtureword", range: NSRange(location: 2, length: 18), sentence: "A lexidawnfixtureword appears in this original test sentence."), articleID: id, autoAdd: false, explicit: true, at: now))
        // Explicit eligibility fixture, not evidence that the native MDX reader ran.
        try learning.dictionary.recordEmptyEligibilityFixture("lexidawnfixtureword", at: now)
        return addition
    }
    func testPersonalSensesPersistAndNotesRemainIndependent() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        let sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "明确原创的个人词义", examples: [.init(english: "A first lexidawnfixtureword appears.", chinese: "第一条例句译文"), .init(english: "A second lexidawnfixtureword appears.", chinese: "第二条例句译文")], confirmed: true)
        let verb = PersonalDictionarySense(partOfSpeech: "verb", chinese: "明确原创的动词义", examples: [.init(english: "We lexidawnfixtureword the first idea.", chinese: "动词义例句译文")], confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense, verb], at: now)
        try learning.vocabulary.saveNotes(entryID: added.entryID, notes: "独立笔记", at: now)
        let restored = try XCTUnwrap(learning.vocabulary.entries().first)
        XCTAssertEqual(restored.personalSenses, [sense, verb]); XCTAssertEqual(restored.notes, "独立笔记")
        XCTAssertEqual(restored.personalSenses?.first?.dictionarySense(entryID: added.entryID).exampleTranslations, ["第一条例句译文", "第二条例句译文"])
        var duplicate = sense; duplicate.examples[1].id = duplicate.examples[0].id
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [duplicate, verb], at: now))
        XCTAssertEqual(try learning.vocabulary.entries().first?.personalSenses, [sense, verb])
        let annotation = VocabularyAnnotationModel(item: restored, learning: learning)
        annotation.notes = "新的独立笔记"; annotation.senses[0].chinese += "（新修订）"; annotation.changed(); annotation.flush()
        XCTAssertEqual(annotation.state, "已自动保存")
        annotation.changed() // SwiftUI may observe the read-back revision after a successful flush.
        XCTAssertEqual(annotation.state, "已自动保存")
        XCTAssertEqual(try learning.vocabulary.entries().first?.notes, "新的独立笔记")
    }
    func testRepositoryRejectsPersonalWriteAfterReliableChineseArrivesAndCacheClear() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        let sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "旧个人义", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: now)
        let word = try XCTUnwrap(learning.vocabulary.entries().first?.lemma)
        let trusted = DictionarySense(id: "explicit-trusted-fixture", en: "", zh: "可靠英中原创夹具", line: "Explicit fixture", partOfSpeech: "noun", sources: [BundledMDXDictionaryProvider.sourceName], sourceRevision: BundledMDXDictionaryProvider.sourceVersion, originKind: "mdx")
        try DictionaryCacheRepository(context: ModelContext(app.modelContainer)).save(word, senses: [trusted], successful: [BundledMDXDictionaryProvider.sourceName], at: now)
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(entryID: added.entryID))
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [], at: now))
        XCTAssertThrowsError(try learning.vocabulary.annotate(entryID: added.entryID, meaning: "禁止覆盖", notes: "", at: now))
        _ = try learning.dictionary.clearCaches()
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(entryID: added.entryID))
        try learning.vocabulary.saveNotes(entryID: added.entryID, notes: "可靠词仍可记笔记", at: now)
        XCTAssertEqual(try learning.vocabulary.entries().first?.personalSenses, [sense])
    }
    func testStructuredWriteFailureLeavesNoPartialMeaning() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        let failing = VocabularyRepository(context: ModelContext(app.modelContainer), saveContext: { _ in throw LearningError.invalid("Explicit save fault") })
        XCTAssertThrowsError(try failing.savePersonalSenses(entryID: added.entryID, senses: [.init(partOfSpeech: "verb", chinese: "不得部分保存", examples: [.init(english: "A fixture.")], confirmed: true)], at: now))
        XCTAssertNil(try learning.vocabulary.entries().first?.personalSenses)
        XCTAssertNil(try learning.vocabulary.entries().first?.meaning)
    }
    func testRevealRequiresPersistedCorrectionAndSchedulesAgainExactlyOnce() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [.init(partOfSpeech: "noun", chinese: "明确原创个人测试词", confirmed: true)], at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        let session = try XCTUnwrap(prepared)
        try learning.review.submit(cycleID: cycle.cycleID, questionID: session.matching[0].id, answer: session.matching[0].senseID, at: now)
        let question = session.cloze[0]
        XCTAssertFalse(try learning.review.submit(cycleID: cycle.cycleID, questionID: question.id, answer: "", reveal: true, at: now))
        let restored = try XCTUnwrap(learning.review.session(cycleID: cycle.cycleID))
        XCTAssertTrue(restored.cloze[0].revealed); XCTAssertFalse(restored.cloze[0].completed)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        XCTAssertFalse(try learning.review.submit(cycleID: cycle.cycleID, questionID: question.id, answer: "wrong", at: now))
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: question.id, answer: question.answer, at: now))
        XCTAssertTrue(try learning.review.submit(cycleID: cycle.cycleID, questionID: question.id, answer: question.answer, at: now))
        let logs = try ModelContext(app.modelContainer).fetch(FetchDescriptor<ReviewLogRecord>())
        XCTAssertEqual(logs.count, 1); XCTAssertEqual(logs.first?.grade, "again")
        XCTAssertEqual(try learning.vocabulary.entries().first?.repetitions, 1)
    }
    func testMissingMeaningPreflightAndExplicitDeferralAreNotEmptyQueueOrAnswer() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        var issue: ReviewMeaningIssue?
        do { _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now); XCTFail("Missing meaning must block") }
        catch let value as ReviewMeaningIssue { issue = value }
        let problem = try XCTUnwrap(issue)
        XCTAssertEqual(problem.entryID, added.entryID)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewExerciseRecord>()), 0)
        XCTAssertNil(try learning.cycles.fetch(by: cycle.cycleID)?.reviewEvidence)
        try learning.review.deferEntry(cycleID: cycle.cycleID, issue: problem, at: now)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        XCTAssertNil(prepared)
        XCTAssertTrue(try learning.cycles.fetch(by: cycle.cycleID)?.reviewEvidence?.isUserDeferral == true)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        XCTAssertEqual(try learning.vocabulary.entries().count, 1)
        XCTAssertEqual(try learning.vocabulary.entries().first?.repetitions, 0)
        XCTAssertFalse(try learning.cycles.fetch(by: cycle.cycleID)?.isComplete == true)
    }
    func testPersonalRevisionDoesNotRewriteFrozenReviewMeaningAndMask() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        var sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "第一次明确的个人义", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        sense.chinese = "后来改过的义"; sense.revision += 1
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: now)
        let restored = try learning.review.session(cycleID: cycle.cycleID)
        XCTAssertEqual(restored?.matching.first?.answer, "第一次明确的个人义")
        XCTAssertEqual(restored?.cloze.first?.prompt, prepared?.cloze.first?.prompt)
        XCTAssertEqual(restored?.matching.first?.meaning?.id, restored?.cloze.first?.meaning?.id)
    }
    func testMediaFallbackExcludedWithoutDeletingJavaScriptReporting() throws {
        let html = "<article><p>A real report about JavaScript and HTML5.</p><video>To view this video please enable JavaScript.</video><p>The original final paragraph.</p></article>"
        let document = try ArticleHTMLExtractor.extract(html)
        XCTAssertTrue(document.text.contains("A real report about JavaScript and HTML5."))
        XCTAssertTrue(document.text.contains("The original final paragraph."))
        XCTAssertFalse(document.text.contains("To view this video"))
    }
    func testCanonicalAliasMigrationKeepsNotesIDsContextsAndReviewLogs() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let id = try learning.content.importArticle(.init(title: "Explicit legacy identity fixture", body: "A user visits users.", source: "Original XCTest fixture", rightsConfirmed: true), at: now)
        let context = ModelContext(app.modelContainer)
        let singular = VocabularyEntryRecord(lemma: "user", surface: "user", type: "word", at: now, from: id, token: "singular")
        singular.notes = "原单数笔记"; singular.deletedAt = now
        let plural = VocabularyEntryRecord(lemma: "users", surface: "users", type: "word", at: now, from: id, token: "plural")
        plural.notes = "原复数笔记"; plural.userMeaning = "旧个人义"
        for record in [singular, plural] {
            context.insert(record); context.insert(ReviewStateRecord(entryID: record.entryID, at: now))
            context.insert(VocabularySourceContextRecord(entryID: record.entryID, articleID: id, surface: record.lemma, sentence: "A user visits users.", tokenLocation: record === singular ? 2 : 14, at: now))
            context.insert(ReviewLogRecord(sessionID: record.entryID, entryID: record.entryID, grade: "good", at: now, previousDueAt: now, nextDueAt: now.addingTimeInterval(86400)))
        }
        try context.save()
        let values = try learning.vocabulary.entries(), value = try XCTUnwrap(values.first)
        XCTAssertEqual(values.count, 1); XCTAssertEqual(value.id, plural.entryID); XCTAssertEqual(value.lemma, "user")
        XCTAssertEqual(value.notes, "原复数笔记"); XCTAssertEqual(value.legacyAnnotations?.first?.notes, "原单数笔记")
        XCTAssertEqual(Set(value.surfaces), Set(["user", "users"])); XCTAssertEqual(value.contexts.count, 2)
        let rows = try ModelContext(app.modelContainer).fetch(FetchDescriptor<VocabularyEntryRecord>())
        XCTAssertEqual(rows.count, 2); XCTAssertEqual(Set(rows.map(\.normalizedKey)).count, 2)
        XCTAssertEqual(rows.first { $0.entryID == singular.entryID }?.canonicalEntryID, plural.entryID)
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: learning.vocabulary.export(.json, at: now)) as? [String: Any])
        XCTAssertEqual((exported["reviewLogs"] as? [[String: Any]])?.count, 2)
        try learning.vocabulary.normalizeIdentities()
        XCTAssertEqual(try learning.vocabulary.entries(), values)
    }
    func testCanonicalMigrationSaveFailureRollsBackEveryAlias() throws {
        let app = try AppDependencies.makeLearningInMemory(), context = ModelContext(app.modelContainer)
        let record = VocabularyEntryRecord(lemma: "users", surface: "users", type: "word", at: now, from: "explicit-fixture", token: "test")
        context.insert(record); try context.save()
        let repository = VocabularyRepository(context: ModelContext(app.modelContainer)) { _ in throw LearningError.invalid("Explicit migration fault") }
        XCTAssertThrowsError(try repository.normalizeIdentities())
        let restored = try XCTUnwrap(ModelContext(app.modelContainer).fetch(FetchDescriptor<VocabularyEntryRecord>()).first)
        XCTAssertEqual(restored.lemma, "users"); XCTAssertEqual(restored.normalizedKey, "en|word|users"); XCTAssertNil(restored.canonicalEntryID)
    }
    func testRound3RealDiskSchemaUpgradePreservesOriginalsAndLearningRelationsTwice() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("round3.store"), articleID = UUID().uuidString
        let raw = "A user reads a complete original article.\n\nThe final paragraph remains unchanged."
        let document = ArticleDocumentNormalizer.plainText(raw)
        let originalStructuredData = try JSONEncoder().encode(document)
        let cycle = try DailyStudyCycle(assignedLocalDate: "2026-11-06", assignedTimeZoneID: "Asia/Shanghai", articleID: articleID, createdAtUTC: now, updatedAtUTC: now, assignmentReason: "explicit-Round3-disk-fixture")
        var entryID = "", sessionID = ""
        do {
            let container = try ModelContainer(for: FrozenRound3Schema.schema, configurations: [ModelConfiguration(url: url)])
            let context = ModelContext(container)
            let article = FrozenRound3Schema.ArticleRecord(articleID: articleID, canonicalURL: "lexidawn-local://article/" + articleID, originalTitle: "Historical complete original", sourceID: "user-import", fetchedAt: now, licenseID: "user-declared-local-use", licenseVerified: true, bodyText: raw, bodyHash: fingerprint(raw), wordCount: EnglishTokenizer.tokens(in: raw).count, estimatedReadMinutes: 1, topicTags: ["个人阅读"], contentStatus: "available", createdAt: now, updatedAt: now)
            article.structuredBody = originalStructuredData; article.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.persistent)
            article.sourceAttribution = "Original XCTest author"; article.fullTextDisplayAllowed = true; article.isFavorite = true; article.readLater = true
            article.fullTextRightsEvidenceID = "user-confirmed-original"; article.extractionVersion = ArticleDocument.extractionVersion; article.completenessVerifiedAt = now
            context.insert(article); context.insert(try FrozenRound3Schema.DailyStudyCycleRecord(cycle: cycle))
            context.insert(FrozenRound3Schema.ContentGrantRecord(articleID: articleID, sourceID: "user-import", bodyHash: fingerprint(raw), scope: "user-local", evidenceURL: "local-user-confirmation", originalURL: nil, acceptedAt: now, eligibleForDaily: true))
            let progress = FrozenRound3Schema.ArticleProgressRecord(articleID: articleID, cycleID: cycle.cycleID, bodyHash: fingerprint(raw), at: now)
            progress.readingPercent = 0.42; progress.characterOffset = 12; context.insert(progress)
            let entry = FrozenRound3Schema.VocabularyEntryRecord(lemma: "users", surface: "users", type: "word", at: now, from: articleID, token: "old-token")
            entry.notes = "真迁移保留笔记"; entry.userMeaning = "历史个人义"; entryID = entry.entryID; context.insert(entry)
            context.insert(FrozenRound3Schema.VocabularySourceContextRecord(entryID: entryID, articleID: articleID, surface: "user", sentence: "A user reads.", tokenLocation: 2, at: now))
            let state = FrozenRound3Schema.ReviewStateRecord(entryID: entryID, at: now)
            state.stability = 3.7145; state.difficulty = 5.1618; state.repetitions = 2; state.goodCount = 2; state.dueAt = now.addingTimeInterval(86400); context.insert(state)
            let session = FrozenRound3Schema.ReviewSessionRecord(cycleID: cycle.cycleID, entries: [entryID], at: now, limit: 12); sessionID = session.sessionID; context.insert(session)
            context.insert(FrozenRound3Schema.ReviewExerciseRecord(sessionID: sessionID, entryID: entryID, stage: "matching", position: 0, prompt: "users", answer: "历史个人义", senseID: "user"))
            let cloze = FrozenRound3Schema.ReviewExerciseRecord(sessionID: sessionID, entryID: entryID, stage: "cloze", position: 0, prompt: "us___", answer: "users", senseID: "user")
            cloze.sourceContext = "A user reads."; cloze.attempts = 1; cloze.usedHint = true; context.insert(cloze)
            let preferences = FrozenRound3Schema.UserPreferencesRecord(); preferences.displayName = "Historical reader"; preferences.readerTheme = "paper"; context.insert(preferences)
            try context.save()
        }
        for _ in 0..<2 {
            let container = try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url))
            let context = ModelContext(container), content = ContentRepository(context: context), vocabulary = VocabularyRepository(context: context)
            try content.migrateRound3(at: now)
            let value = try XCTUnwrap(vocabulary.entries().first)
            XCTAssertEqual(value.id, entryID); XCTAssertEqual(value.lemma, "user"); XCTAssertEqual(value.notes, "真迁移保留笔记"); XCTAssertEqual(value.meaning, "历史个人义")
            XCTAssertEqual(value.personalSenses?.first?.originalOrigin, "legacyPersonal"); XCTAssertFalse(value.personalSenses?.first?.reviewReady ?? true)
            XCTAssertEqual(value.stability, 3.7145); XCTAssertEqual(value.repetitions, 2)
            XCTAssertEqual(try content.read(articleID: articleID, at: now).body, raw)
            let article = try XCTUnwrap(context.fetch(FetchDescriptor<ArticleRecord>()).first)
            XCTAssertEqual(article.structuredBody, originalStructuredData); XCTAssertTrue(article.isFavorite); XCTAssertTrue(article.readLater)
            let exercises = try context.fetch(FetchDescriptor<ReviewExerciseRecord>())
            XCTAssertEqual(exercises.count, 2); XCTAssertEqual(exercises.first { $0.stage == "cloze" }?.prompt, "us___")
            XCTAssertEqual(exercises.first { $0.stage == "cloze" }?.attempts, 1); XCTAssertNil(exercises.first?.meaningSnapshot)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewSessionRecord>()).first?.sessionID, sessionID)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ArticleProgressRecord>()).first?.readingPercent, 0.42)
            XCTAssertEqual(try context.fetch(FetchDescriptor<UserPreferencesRecord>()).first?.readerTheme, "paper")
            XCTAssertFalse(try XCTUnwrap(StudyCycleRepository(context: context).fetchAll().first).isComplete)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("before-round4").path))
    }

    func testBilingualMergeNeverSeparatesExamplesFromTheirTranslations() {
        let a = DictionarySense(id: "a", en: "", zh: "相同中文义", line: "Original fixture A", partOfSpeech: "noun", examples: ["Zebra fixture."], sources: ["Wiktionary"], exampleTranslations: ["甲例句译文"])
        let b = DictionarySense(id: "b", en: "", zh: "相同中文义", line: "Original fixture B", partOfSpeech: "noun", examples: ["Apple fixture."], sources: ["Oxford"], exampleTranslations: ["乙例句译文"])
        let merged = DictionaryAggregator.merge([b, a])
        XCTAssertEqual(merged.count, 1); XCTAssertEqual(merged[0].examples, ["Zebra fixture.", "Apple fixture."])
        XCTAssertEqual(merged[0].exampleTranslations, ["甲例句译文", "乙例句译文"])
        XCTAssertEqual(merged[0].sources, ["Oxford", "Wiktionary"])
    }
    func testLegacyUnconfirmedQuestionSetIsArchivedVerbatimBeforeNewPreflight() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        let context = ModelContext(app.modelContainer)
        let saved = ReviewSessionRecord(cycleID: cycle.cycleID, entries: [added.entryID], at: now, limit: 1)
        context.insert(saved)
        let key = "cedict-reverse-v1|lexidawnfixtureword|unconfirmed"
        let matching = ReviewExerciseRecord(sessionID: saved.sessionID, entryID: added.entryID, stage: "matching", position: 0, prompt: "lexidawnfixtureword", answer: "未经用户确认的旧反向索引义", senseID: key)
        matching.attempts = 2; context.insert(matching)
        let cloze = ReviewExerciseRecord(sessionID: saved.sessionID, entryID: added.entryID, stage: "cloze", position: 0, prompt: "lexidawnfixture____", answer: "lexidawnfixtureword", senseID: key)
        cloze.usedHint = true; context.insert(cloze); try context.save()
        do { _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now); XCTFail("Unconfirmed meaning must block") }
        catch let issue as ReviewMeaningIssue { XCTAssertEqual(issue.entryID, added.entryID) }
        let reopened = ModelContext(app.modelContainer)
        let archive = try XCTUnwrap(reopened.fetch(FetchDescriptor<ReviewSessionRecord>()).first)
        XCTAssertEqual(archive.sessionID, saved.sessionID); XCTAssertEqual(archive.purpose, "archived"); XCTAssertEqual(archive.archivedCycleID, cycle.cycleID.uuidString)
        let questions = try reopened.fetch(FetchDescriptor<ReviewExerciseRecord>())
        XCTAssertEqual(questions.count, 2); XCTAssertEqual(questions.first { $0.stage == "matching" }?.attempts, 2)
        XCTAssertTrue(questions.first { $0.stage == "cloze" }?.usedHint == true)
        XCTAssertEqual(questions.first { $0.stage == "matching" }?.answer, "未经用户确认的旧反向索引义")
        XCTAssertNil(try learning.review.session(cycleID: cycle.cycleID)); XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        XCTAssertEqual(try learning.cycles.fetch(by: cycle.cycleID)?.reviewTaskStatus, .ready)
    }
    func testDWLegacyPlayerProjectionPreservesRawTextAndUTF16TokenOffsets() {
        let raw = "An original paragraph.\n\nTo view this video please enable JavaScript, and consider upgrading to a web browser that supports HTML5 video.\n\nThe final original paragraph."
        let projection = ReaderTextProjection(raw: raw, sourceID: "dw")
        XCTAssertFalse(projection.text.contains("To view this video")); XCTAssertTrue(projection.text.contains("The final original paragraph."))
        let displayRange = (projection.text as NSString).range(of: "final")
        XCTAssertEqual((raw as NSString).substring(with: projection.rawRange(displayRange)), "final")
        XCTAssertEqual(projection.displayOffset(projection.rawOffset(displayRange.location)), displayRange.location)
        XCTAssertTrue(ReaderTextProjection(raw: raw, sourceID: "nasa").text.contains("To view this video"))
        let player = "To view this video please enable JavaScript, and consider upgrading to a web browser that supports HTML5 video."
        let document = ArticleDocument(blocks: [
            .init(kind: .heading, text: "Media technology"),
            .init(kind: .paragraph, text: player),
            .init(kind: .quotation, text: "A real explanation of JavaScript and HTML5."),
            .init(kind: .caption, text: "📷 Caption"),
            .init(kind: .listItem, text: "Final item", listOrdinal: 3),
            .init(kind: .paragraph, text: player),
        ])
        let wrapped = document.text.replacingOccurrences(of: "JavaScript, and", with: "JavaScript,\r\n and")
        let projected = ReaderTextProjection(raw: wrapped, document: document, sourceID: "dw")
        XCTAssertEqual(projected.document?.blocks.map(\.kind), [.heading, .quotation, .caption, .listItem])
        XCTAssertEqual(projected.document?.blocks.last?.listOrdinal, 3)
        XCTAssertTrue(projected.text.contains("A real explanation of JavaScript and HTML5."))
        let final = (projected.text as NSString).range(of: "item")
        XCTAssertEqual((wrapped as NSString).substring(with: projected.rawRange(final)), "item")
    }

    func testVocabularyDisplayGroupsPreserveDistinctSentencesAndSeparateDictionaryEvidence() {
        let url = "https://www.dw.com/en/example/a-1234"
        let first = VocabularyContextItem(id: "first", articleID: "a", sentence: "Readers need context.", title: "A complete article", attribution: "Original publisher metadata", originalURL: url, originKind: "reader", displaySourceName: "Deutsche Welle")
        let repeated = VocabularyContextItem(id: "repeat", articleID: "a", sentence: first.sentence, title: first.title, attribution: first.attribution, originalURL: url, originKind: "reader")
        let another = VocabularyContextItem(id: "another", articleID: "a", sentence: "People need a real example.", title: first.title, attribution: first.attribution, originalURL: url, originKind: "reader")
        let oldLink = VocabularyContextItem(id: "url", articleID: "a", sentence: url, title: first.title, attribution: first.attribution, originalURL: url)
        let dictionary = VocabularyContextItem(id: "dict", articleID: "a", sentence: first.sentence, title: "词典释义：need", attribution: "内置 MDX", originalURL: nil, originKind: "dictionary")
        let evidence = [first, repeated, another, oldLink, dictionary]
        let groups = VocabularyContextGroup.displayGroups(evidence)
        XCTAssertEqual(groups.map(\.title), ["A complete article", "词典释义：need"])
        XCTAssertEqual(groups.first?.sourceName, "Deutsche Welle")
        XCTAssertEqual(groups.first?.contexts.map(\.id), ["first", "another"])
        XCTAssertEqual(groups.last?.contexts.map(\.id), ["dict"])
        XCTAssertEqual(evidence.first(where: { $0.id == "url" })?.originalURL, url)
    }

    func testEnglishTranslationTablesKeepChineseLanguageAndPartBoundaries() throws {
        let html = "<h2>English</h2><h3>Noun</h3><h4>Translations</h4><div class='NavFrame'><div class='NavHead'>Original fixture head movement</div><div><span lang='zh'>点头</span><span lang='ja'>除外漢字</span><span lang='cmn'>示意</span></div></div><h3>Verb</h3><h4>Translations</h4><div class='NavFrame'><div class='NavHead'>Original fixture agree</div><div><span lang='zh'>同意</span></div></div><h2>French</h2><h3>Noun</h3><div class='NavFrame'><span lang='zh'>错误语言</span></div>"
        let values = try WiktionaryChineseTranslationParser.parse(html, revision: "original-9")
        XCTAssertEqual(values.map(\.partOfSpeech), ["noun", "verb"])
        XCTAssertEqual(values.map(\.zh), ["点头；示意", "同意"])
        XCTAssertTrue(values.allSatisfy { !BilingualMeaningPolicy.trusted($0) }); XCTAssertTrue(values.allSatisfy { $0.sourceRevision == "original-9" })
        XCTAssertTrue(try WiktionaryChineseTranslationParser.parse("<h2>French</h2><h3>Noun</h3><div class='NavFrame'><span lang='zh'>错误语言</span></div>", revision: "0").isEmpty)
    }

    func testRichBilingualFixtureFlowsThroughLookupModelAndDurableCache() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let article = try learning.content.importArticle(.init(title: "Original lookup model fixture", body: "We nod when we agree.", source: "Original XCTest author", rightsConfirmed: true), at: now)
        let direct = try await Round4DictionaryFixture(mode: "rich", source: "Wiktionary").lookup("nod")
        XCTAssertEqual(direct.count, 2)
        try learning.dictionary.configureDictionaryEvidence(providers: [("Wiktionary", Round4DictionaryFixture(mode: "rich", source: "Wiktionary")), ("Free Dictionary API", Round4DictionaryFixture(mode: "rich", source: "Free Dictionary API"))])
        let model = WordLookupModel(token: .init(surface: "nod", range: NSRange(location: 3, length: 3), sentence: "We nod when we agree."), articleID: article, autoAdd: true, learning: learning)
        await model.begin()
        XCTAssertNil(model.error); XCTAssertFalse(model.loading)
        XCTAssertEqual(model.result?.headword, "nod"); XCTAssertEqual(model.result?.reliableChinese.count, 2)
        XCTAssertEqual(try learning.vocabulary.entries().first?.reliableChineseKnown, true)
        XCTAssertEqual(try DictionaryCacheRepository(context: ModelContext(app.modelContainer)).load("nod", at: Date()).senses.filter(BilingualMeaningPolicy.trusted).count, 2)
    }

}

/// Isolated original business-rule fixtures; never real-MDX parsing evidence.
private struct OriginalReviewDictionaryFixture: DictionaryProvider {
    let values: [String: [DictionarySense]]
    func lookup(_ headword: String) async throws -> [DictionarySense] { values[headword] ?? [] }
}
@MainActor func annotateOriginalFixture(_ learning: LearningServices, entryID: String, meaning: String, notes: String, at now: Date) throws {
    let item = try XCTUnwrap(learning.vocabulary.entries().first { $0.id == entryID })
    try learning.dictionary.recordEmptyEligibilityFixture(item.lemma, at: now)
    try learning.vocabulary.annotate(entryID: entryID, meaning: meaning, notes: notes, at: now)
}
@MainActor func confirmOriginalReviewFixtures(_ learning: LearningServices, at now: Date) throws {
    let items = try learning.vocabulary.entries()
    var values: [String: [DictionarySense]] = [:]
    for item in items { values[item.lemma] = item.dictionarySenses }
    try learning.dictionary.configureDictionaryEvidence(providers: [("explicit-MDX-business-fixture", OriginalReviewDictionaryFixture(values: values))])
    for item in items where item.personalSenses?.contains(where: \.reviewReady) != true && item.reviewMeaningSenseID == nil {
        let chinese = item.meaning ?? "原创测试义：" + item.lemma
        let sense = PersonalDictionarySense(partOfSpeech: item.lemma == "take" ? "verb" : "noun", chinese: chinese,
            examples: [.init(english: "This original fixture includes " + item.lemma + ".")], confirmed: true)
        try learning.dictionary.recordEmptyEligibilityFixture(item.lemma, at: now)
        try learning.vocabulary.savePersonalSenses(entryID: item.id, senses: [sense], at: now)
    }
}

/// Source-policy fixture only; never counts as successful native MDX parsing.
func markMDXFixture(_ sense: DictionarySense) -> DictionarySense {
    var value = sense
    value.sources = [BundledMDXDictionaryProvider.sourceName]
    value.sourceRevision = BundledMDXDictionaryProvider.sourceVersion
    value.originKind = "mdx"; value.line = "Explicit source-policy fixture · " + value.line
    return value
}
