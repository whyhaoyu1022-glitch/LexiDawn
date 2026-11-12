import XCTest
import SwiftData
import AVFoundation
@testable import LexiDawn

@MainActor final class MDXDictionaryTests: XCTestCase {
    func testActualCompiledAppContainsApprovedMDX() throws {
        let resource = try XCTUnwrap(Bundle.main.url(forResource: "BundledDictionary", withExtension: "mdx"))
        XCTAssertEqual(try resource.resourceValues(forKeys: [.fileSizeKey]).fileSize, 38_774_534)
        XCTAssertNil(Bundle.main.url(forResource: "cedict-reverse", withExtension: "json"))
        XCTAssertNil(Bundle.main.url(forResource: "dic_data-package-001", withExtension: "zip"))
    }
    func testRealMDXNodHasMultiplePartsChineseAndPairedExamples() async throws {
        let values = try await BundledMDXDictionaryProvider().lookup("nod")
        let chinese = values.filter(BilingualMeaningPolicy.trusted)
        XCTAssertTrue(chinese.contains { $0.partOfSpeech == "noun" })
        XCTAssertTrue(chinese.contains { $0.partOfSpeech == "verb" })
        XCTAssertGreaterThan(chinese.count, 2)
        XCTAssertTrue(chinese.contains { !($0.examples ?? []).isEmpty })
        XCTAssertTrue(chinese.allSatisfy { ($0.examples ?? []).count == ($0.exampleTranslations ?? []).count })
        XCTAssertTrue(chinese.contains { $0.ipa?.contains("nɒd") == true })
        XCTAssertTrue(chinese.contains { $0.sectionKind == "phrasalVerb" })
    }
    func testRealMDXMonthAndModalKeepSeparateIdentities() async throws {
        let provider = BundledMDXDictionaryProvider()
        let month = try await provider.lookup("May"), modal = try await provider.lookup("may")
        XCTAssertTrue(month.contains { $0.zh.contains("五月") && $0.partOfSpeech == "noun" })
        XCTAssertFalse(month.contains { $0.partOfSpeech == "modal verb" })
        XCTAssertTrue(modal.contains { $0.partOfSpeech == "modal verb" && BilingualMeaningPolicy.trusted($0) })
        XCTAssertTrue(Set(month.map(\.id)).isDisjoint(with: modal.map(\.id)))
    }
    func testRealMDXHomonymMarkersAreNotPartOfTheLexicalHeadword() async throws {
        let values = try await BundledMDXDictionaryProvider().lookup("do")
        let main = values.filter { $0.sectionKind == nil }
        XCTAssertFalse(main.isEmpty)
        XCTAssertTrue(main.allSatisfy { $0.lexicalHeadword == "do" })
        XCTAssertTrue(main.contains { $0.partOfSpeech == "verb" })
    }
    func testRealOfflineServiceNormalizesUsersAndVisitsWithoutNetworkProviders() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        XCTAssertFalse(learning.dictionary.onlineEnabled)
        let users = try await learning.dictionary.lookup("users", context: "The users read articles.")
        let visits = try await learning.dictionary.lookup("visits", context: "She visits us every week.")
        XCTAssertEqual(users.headword, "user"); XCTAssertEqual(visits.headword, "visit")
        XCTAssertFalse(users.reliableChinese.isEmpty); XCTAssertFalse(visits.reliableChinese.isEmpty)
        XCTAssertEqual(visits.quickSenses.first?.partOfSpeech, "verb")
        XCTAssertTrue(visits.senses.contains { $0.partOfSpeech == "noun" })
        let nounVisits = try await learning.dictionary.lookup("visits", context: "Her visits are usually short.")
        XCTAssertEqual(nounVisits.headword, "visit")
        XCTAssertEqual(nounVisits.quickSenses.first?.partOfSpeech, "noun")
        let agreement = try await learning.dictionary.lookup("nod", context: "We nod when we agree.")
        XCTAssertEqual(agreement.quickSenses.first?.partOfSpeech, "verb")
        XCTAssertTrue(agreement.quickSenses.first?.zh.contains("点头") == true)
        XCTAssertEqual(Set(users.versions.keys), [BundledMDXDictionaryProvider.sourceName])
    }
    func testRealMDXConcurrentRapidQueriesAndCacheKeepStableSenseIDs() async throws {
        let provider = BundledMDXDictionaryProvider()
        let first = try await provider.lookup("user")
        let ids = try await withThrowingTaskGroup(of: [String].self) { group in
            for _ in 0..<20 { group.addTask { try await provider.lookup("user").map(\.id) } }
            var values: [[String]] = []
            for try await value in group { values.append(value) }
            return values
        }
        XCTAssertEqual(ids.count, 20); XCTAssertTrue(ids.allSatisfy { $0 == first.map(\.id) })
        let hits = await provider.cacheHits
        XCTAssertGreaterThanOrEqual(hits, 20)
    }
    func testCancellationIsNotAnEmptySuccessfulLookup() async {
        let provider = BundledMDXDictionaryProvider()
        let task = Task { try await provider.lookup("user") }; task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
    func testMissingAndCorruptMDXHaveDistinctErrors() async throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do { _ = try await BundledMDXDictionaryProvider(resource: missing).lookup("user"); XCTFail("Missing resource must fail") }
        catch { XCTAssertEqual(error as? MDXDictionaryError, .missingResource) }
        let corrupt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Explicit corrupt MDX fixture".utf8).write(to: corrupt)
        defer { do { try FileManager.default.removeItem(at: corrupt) } catch { XCTFail("Fixture cleanup failed") } }
        do { _ = try await BundledMDXDictionaryProvider(resource: corrupt).lookup("user"); XCTFail("Corrupt resource must fail") }
        catch { XCTAssertEqual(error as? MDXDictionaryError, .identityMismatch) }
    }
    func testEnglishOnlyDOMFixtureIsFoundButDoesNotLockPersonalChinese() throws {
        let html = "<div class='entry' data-hkoup-entry='explicit-fixture'><span class='t-h'>fixture</span><span class='t-pos'>noun</span><div class='t-def'><span class='t-eng'>Original English-only test definition</span></div></div>"
        let values = try MDXEntryParser.parse(html, requested: "fixture", recordID: "fixture")
        XCTAssertEqual(values.count, 1); XCTAssertTrue(values[0].zh.isEmpty)
        XCTAssertFalse(BilingualMeaningPolicy.trusted(values[0]))
        XCTAssertTrue(BilingualMeaningPolicy.permitsPersonal(senses: values, knownReliableChinese: false, availability: .noChinese))
    }
    func testRealMDXEnglishOnlyContractionAndPersonalCreationEligibility() async throws {
        let app = try AppDependencies.makeLearningInMemory()
        let learning = try XCTUnwrap(app.learning)
        let straight = try await learning.dictionary.lookup("don't")
        let curly = try await learning.dictionary.lookup("don’t")
        XCTAssertEqual(straight.senses.map(\.id), curly.senses.map(\.id))
        XCTAssertTrue(straight.hasMDXEntry)
        XCTAssertTrue(straight.senses.contains { $0.en.contains("do not") })
        XCTAssertTrue(straight.usableSenses.isEmpty)
        XCTAssertTrue(try learning.vocabulary.personalEditingAllowed(headword: straight.headword))
        let saved = try learning.vocabulary.addDictionaryEntry(headword: straight.headword, surface: "don’t", requiresPersonalEligibility: true, at: Date())
        try learning.vocabulary.savePersonalSenses(entryID: saved.entryID, senses: [.init(partOfSpeech: "other", chinese: "不要", confirmed: true)], at: Date())
        XCTAssertEqual(try learning.vocabulary.find(surface: "don't")?.personalSenses?.first?.chinese, "不要")
        let afterSave = try await learning.dictionary.lookup("don't")
        XCTAssertTrue(afterSave.reliableChinese.isEmpty)
        XCTAssertEqual(afterSave.quickSenses.map(\.zh), ["不要"])
        XCTAssertEqual(afterSave.quickSenses.map(\.originKind), ["personal"])
        _ = try await learning.dictionary.lookup("user")
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(headword: "user"))
        XCTAssertThrowsError(try learning.vocabulary.addDictionaryEntry(headword: "user", requiresPersonalEligibility: true, at: Date()))
        XCTAssertNil(try learning.vocabulary.find(surface: "user"), "A locked creation must not insert a vocabulary entry")
    }
    func testRepositoryRequiresSuccessfulMDXBeforePersonalWriteAndRejectsChinese() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let article = try learning.content.importArticle(.init(title: "MDX policy original fixture", body: "A user reads lexidawnuniquepersonalfixture.", source: "Original XCTest author", rightsConfirmed: true), at: Date())
        let personal = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "lexidawnuniquepersonalfixture", range: NSRange(location: 13, length: 29), sentence: "A user reads lexidawnuniquepersonalfixture."), articleID: article, autoAdd: false, explicit: true, at: Date()))
        let senses = [PersonalDictionarySense(partOfSpeech: "noun", chinese: "明确的原创个人词义", confirmed: true)]
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: personal.entryID, senses: senses, at: Date()))
        let absent = try await learning.dictionary.lookup("lexidawnuniquepersonalfixture")
        XCTAssertTrue(absent.senses.isEmpty)
        try learning.vocabulary.savePersonalSenses(entryID: personal.entryID, senses: senses, at: Date())
        let user = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "user", range: NSRange(location: 2, length: 4), sentence: "A user reads lexidawnuniquepersonalfixture."), articleID: article, autoAdd: false, explicit: true, at: Date()))
        _ = try await learning.dictionary.lookup("user")
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(entryID: user.entryID))
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: user.entryID, senses: senses, at: Date()))
        XCTAssertThrowsError(try learning.vocabulary.annotate(entryID: user.entryID, meaning: "不可覆盖", notes: "", at: Date()))
        try learning.vocabulary.saveNotes(entryID: user.entryID, notes: "独立笔记", at: Date())
        XCTAssertEqual(try learning.vocabulary.entries().first { $0.id == user.entryID }?.notes, "独立笔记")
    }
    func testRetiredProviderCacheCannotBecomeMDXEvidence() throws {
        let app = try AppDependencies.makeLearningInMemory(), context = ModelContext(app.modelContainer)
        let old = DictionarySense(id: "legacy", en: "old", zh: "旧来源保留", line: "Explicit historical fixture", sources: ["Wiktionary"])
        context.insert(DictionaryProviderCacheRecord(lemma: "user", provider: "Wiktionary", version: "bilingual-action-schema-7", data: try JSONEncoder().encode([old]), at: Date()))
        try context.save()
        let cache = DictionaryCacheRepository(context: context)
        XCTAssertTrue(try cache.load("user", at: Date()).senses.isEmpty)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<DictionaryProviderCacheRecord>()), 1)
        XCTAssertThrowsError(try cache.save("user", senses: [old], successful: ["Wiktionary"], at: Date()))
    }
    func testSystemPronunciationStartsOrReportsUnavailableAndStopsWithoutQueueing() {
        let service = SystemPronunciation()
        let available = AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix("en-") }
        service.toggle(headword: "user")
        XCTAssertEqual(service.state, available ? .speaking : .unavailable)
        service.stop(); XCTAssertEqual(service.state, available ? .stopped : .unavailable)
        service.toggle(headword: "visit"); service.stop()
        XCTAssertNotEqual(service.state, .speaking)
    }
    func testRealResourceFailureRevokesEditingPermissionWithoutLosingPersonalData() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let article = try learning.content.importArticle(.init(title: "Original fault recovery fixture", body: "A lexidawnfaultword appears here.", source: "Original XCTest author", rightsConfirmed: true), at: Date())
        let entry = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "lexidawnfaultword", range: NSRange(location: 2, length: 17), sentence: "A lexidawnfaultword appears here."), articleID: article, autoAdd: false, explicit: true, at: Date()))
        _ = try await learning.dictionary.lookup("lexidawnfaultword")
        let senses = [PersonalDictionarySense(partOfSpeech: "noun", chinese: "资源恢复测试词", confirmed: true)]
        try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: senses, at: Date())
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let failed = DictionaryLookupService(context: ModelContext(app.modelContainer), provider: BundledMDXDictionaryProvider(resource: missing))
        do { _ = try await failed.lookup("lexidawnfaultword"); XCTFail("Missing resource must remain a resource error") }
        catch { XCTAssertEqual(error as? MDXDictionaryError, .missingResource) }
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(entryID: entry.entryID))
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: [], at: Date()))
        try learning.vocabulary.saveNotes(entryID: entry.entryID, notes: "故障期间保留笔记", at: Date())
        XCTAssertEqual(try learning.vocabulary.entries().first?.personalSenses, senses)
        _ = try await learning.dictionary.lookup("lexidawnfaultword")
        XCTAssertTrue(try learning.vocabulary.personalEditingAllowed(entryID: entry.entryID))
    }
    func testPersonalHistoryPreservesDeletedSenseAndPairedExampleNotesAcrossContexts() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let article = try learning.content.importArticle(.init(title: "Original revision fixture", body: "A lexidawnrevisionword appears here.", source: "Original XCTest author", rightsConfirmed: true), at: Date())
        let added = try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "lexidawnrevisionword", range: NSRange(location: 2, length: 20), sentence: "A lexidawnrevisionword appears here."), articleID: article, autoAdd: false, explicit: true, at: Date()))
        try learning.dictionary.recordEmptyEligibilityFixture("lexidawnrevisionword", at: Date())
        var sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "第一版中文", confirmed: true)
        sense.examples = [.init(english: "An original example.", chinese: "配对译文", notes: "例句备注")]
        sense.grammar = "countable"; sense.collocations = ["original collocation"]; sense.idioms = ["original idiom"]
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: Date())
        sense.chinese = "第二版中文"
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: Date())
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [], at: Date())
        let reopened = VocabularyRepository(context: ModelContext(app.modelContainer))
        let item = try XCTUnwrap(reopened.entries().first)
        XCTAssertEqual(item.personalSenses, [])
        XCTAssertEqual(item.personalHistory?.count, 2)
        XCTAssertEqual(item.personalHistory?.first?.senses.first?.chinese, "第一版中文")
        XCTAssertEqual(item.personalHistory?.last?.senses.first?.chinese, "第二版中文")
        XCTAssertEqual(item.personalHistory?.first?.senses.first?.examples.first?.notes, "例句备注")
        XCTAssertEqual(item.personalHistory?.first?.senses.first?.collocations, ["original collocation"])
        XCTAssertTrue(String(decoding: try reopened.export(.csv, at: Date()), as: UTF8.self).contains("personalMeaningHistoryJSON"))
    }
    func testStandalonePersonalWordUsesItsOwnExampleAndDoesNotCreateAnArticle() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        _ = try await learning.dictionary.lookup("lexidawnstandaloneword")
        let first = try learning.vocabulary.addDictionaryEntry(headword: "lexidawnstandaloneword", at: Date())
        let second = try learning.vocabulary.addDictionaryEntry(headword: "lexidawnstandaloneword", at: Date())
        XCTAssertTrue(first.created); XCTAssertFalse(second.created); XCTAssertEqual(first.entryID, second.entryID)
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ArticleRecord>()), 0)
        let sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "独立个人词条", examples: [.init(english: "A lexidawnstandaloneword belongs to this personal example.", chinese: "配对的个人译文")], confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: first.entryID, senses: [sense], at: Date())
        _ = try learning.content.importArticle(.init(title: "Original daily task fixture", body: "This independent original article does not supply the personal example.", source: "Original XCTest author", rightsConfirmed: true), at: Date())
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: Date(), timeZone: .current, calendar: .current) else { return XCTFail("Expected real daily cycle") }
        let value = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: Date())
        let session = try XCTUnwrap(value)
        XCTAssertEqual(session.cloze.first?.contextOrigin, "personal-example")
        XCTAssertEqual(session.cloze.first?.context, sense.examples[0].english)
        XCTAssertEqual(session.matching.first?.meaning?.originKind, "personal")
        XCTAssertEqual(session.matching.first?.senseID, session.cloze.first?.senseID)
        XCTAssertNotNil(session.cloze.first?.maskSeed); XCTAssertFalse(session.cloze.first?.maskIndices?.isEmpty ?? true)
    }
    func testPersonalRevisionHistorySurvivesClosingAndReopeningARealDiskStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { do { try FileManager.default.removeItem(at: folder) } catch { XCTFail("Disk fixture cleanup failed: \(error)") } }
        let url = folder.appendingPathComponent("personal.store")
        var id = ""
        do {
            let app = AppDependencies(modelContainer: try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url)), learningEnabled: true)
            let learning = try XCTUnwrap(app.learning)
            try learning.dictionary.recordEmptyEligibilityFixture("lexidawndiskword", at: Date())
            let entry = try learning.vocabulary.addDictionaryEntry(headword: "lexidawndiskword", at: Date()); id = entry.entryID
            var sense = PersonalDictionarySense(partOfSpeech: "verb", chinese: "磁盘第一版", examples: [.init(english: "I lexidawndiskword this example.", chinese: "磁盘译文", notes: "磁盘备注")], confirmed: true)
            try learning.vocabulary.savePersonalSenses(entryID: id, senses: [sense], at: Date())
            sense.chinese = "磁盘第二版"
            try learning.vocabulary.savePersonalSenses(entryID: id, senses: [sense], at: Date())
            try learning.vocabulary.saveNotes(entryID: id, notes: "独立学习笔记", at: Date())
        }
        for _ in 0..<2 {
            let container = try AppDependencies.openPersistentStore(configuration: ModelConfiguration(url: url))
            let context = ModelContext(container), repository = VocabularyRepository(context: context)
            let item = try XCTUnwrap(repository.entries().first)
            XCTAssertEqual(item.id, id); XCTAssertEqual(item.notes, "独立学习笔记")
            XCTAssertEqual(item.personalSenses?.first?.chinese, "磁盘第二版")
            XCTAssertEqual(item.personalHistory?.first?.senses.first?.chinese, "磁盘第一版")
            XCTAssertEqual(item.personalSenses?.first?.examples.first?.chinese, "磁盘译文")
            XCTAssertEqual(item.personalSenses?.first?.examples.first?.notes, "磁盘备注")
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ArticleRecord>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewStateRecord>()), 1)
        }
    }
    func testMonthMaySpellingRetainsRequiredCaseWhileModalMayStaysLowercase() {
        let month = ClozeContext.make(lemma: "May", surfaces: ["May"], sentence: "We travel in May.")
        XCTAssertEqual(month.answer, "May")
        XCTAssertFalse(SpellingAnswerPolicy.accepts("may", expected: month.answer, alternatives: ["May"]))
        XCTAssertTrue(SpellingAnswerPolicy.accepts("May", expected: month.answer, alternatives: ["May"]))
        XCTAssertEqual(SpellingAnswerPolicy.variants(answer: "May", lemma: "May", senses: []), ["May"])
        XCTAssertEqual(ClozeContext.make(lemma: "may", surfaces: ["may"], sentence: "We may travel.").answer, "may")
    }
    func testRealMDXPhraseAliasIsScopedToItsOwnSenses() async throws {
        let senses = try await BundledMDXDictionaryProvider().lookup("take off")
        XCTAssertFalse(senses.filter(BilingualMeaningPolicy.trusted).isEmpty)
        XCTAssertTrue(senses.allSatisfy { $0.lexicalHeadword == "take off" && $0.sectionKind == "phrasalVerb" })
        XCTAssertTrue(senses.allSatisfy { $0.ipa == nil }, "Do not assign the parent word take's IPA to the phrase take off")
    }
    func testRealMDXIdiomsKeepTheirOwnExamplesAndReopenThroughNativeRecordHints() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let parent = try await learning.dictionary.lookup("nod")
        let idioms = parent.senses.filter { $0.sectionKind == "idiom" }
        XCTAssertTrue(idioms.contains { $0.lexicalHeadword == "get the nod" && $0.zh.contains("许可") })
        XCTAssertFalse(parent.quickSenses.contains { $0.sectionKind != nil })
        XCTAssertTrue(idioms.allSatisfy { $0.ipa == nil && $0.entryGroupID != nil })
        let child = try await learning.dictionary.subentry("get the nod", from: parent)
        XCTAssertTrue(child.quickSenses.contains { $0.zh.contains("许可") })
        XCTAssertFalse(child.reliableChinese.isEmpty)
        XCTAssertTrue(child.senses.allSatisfy { $0.lexicalHeadword == "get the nod" && $0.sectionKind == "idiom" })
        XCTAssertEqual(Set(child.senses.map(\.id)), Set(parent.senses.filter { $0.lexicalHeadword == "get the nod" }.map(\.id)), "Parent detail, internal link and review must share the same sense identity")
        XCTAssertTrue(child.senses.contains { $0.examples?.contains(where: { $0.contains("team manager") }) == true })
        let fresh = DictionaryLookupService(context: ModelContext(app.modelContainer))
        let reopened = try await fresh.lookup("get the nod")
        XCTAssertEqual(reopened.senses.map(\.id), child.senses.map(\.id))
        _ = try learning.dictionary.clearCaches()
        let afterClear = try await DictionaryLookupService(context: ModelContext(app.modelContainer)).lookup("get the nod")
        XCTAssertEqual(afterClear.senses.map(\.id), child.senses.map(\.id), "Clearing definition caches must preserve the SHA-bound subentry index; content is read from MDX again")
        XCTAssertTrue(parent.senses.allSatisfy { ($0.examples ?? []).count == ($0.exampleCollocations ?? []).count })
    }
    func testRepeatedArticleWordsFreezeTheTappedOccurrenceAndRejectAmbiguousPersonalExamples() {
        let sentence = "We visit and visit."
        let body = sentence + "\n\n" + sentence
        let absolute = (body as NSString).range(of: "visit", options: .backwards).location
        let relative = ClozeContext.relativeLocation(sentence: sentence, in: body, absoluteLocation: absolute)
        XCTAssertEqual(relative, 13)
        let value = ClozeContext.make(lemma: "visit", surfaces: ["visit"], sentence: sentence, preferredLocation: relative)
        XCTAssertEqual(value.targetRange, NSRange(location: 13, length: 5))
        XCTAssertEqual(ClozeContext.mask(sentence, answer: value.answer, targetRange: value.targetRange), "We visit and _____.")
        XCTAssertNil(ClozeContext.make(lemma: "visit", surfaces: ["visit"], sentence: sentence).sentence)
        XCTAssertFalse(ClozeContext.validates(NSRange(location: 3, length: 100), answer: "visit", sentence: sentence))
    }
    func testPreviousParserCacheSuppliesOnlyRecordHintAndCannotUnlockKnownChinese() async throws {
        let parent = try await BundledMDXDictionaryProvider().lookup("nod")
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let context = ModelContext(app.modelContainer)
        let obsolete = parent.filter { $0.lexicalHeadword == "get the nod" }.map { sense in
            DictionarySense(id: sense.id, en: sense.en, zh: "旧缓存不能直接展示", line: "明确历史派生缓存测试数据", partOfSpeech: sense.partOfSpeech,
                sources: [BundledMDXDictionaryProvider.sourceName], sourceRevision: BundledMDXDictionaryProvider.sourceSHA + "-html-1", originKind: "mdx")
        }
        XCTAssertFalse(obsolete.isEmpty)
        context.insert(DictionaryProviderCacheRecord(lemma: "get the nod", provider: BundledMDXDictionaryProvider.sourceName, version: BundledMDXDictionaryProvider.sourceSHA + "-html-1", data: try JSONEncoder().encode(obsolete), at: Date()))
        try context.save()
        XCTAssertTrue(try DictionaryCacheRepository(context: context).load("get the nod", at: Date()).senses.isEmpty)
        let actual = try await learning.dictionary.lookup("get the nod")
        XCTAssertTrue(actual.senses.contains { $0.zh.contains("许可") })
        XCTAssertFalse(actual.senses.contains { $0.zh == "旧缓存不能直接展示" })
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<DictionaryProviderCacheRecord>()), 2, "Preserve old derived data as history")
        let entry = try learning.vocabulary.addDictionaryEntry(headword: "get the nod", at: Date())
        try DictionaryCacheRepository(context: context).save("get the nod", senses: [], successful: [BundledMDXDictionaryProvider.sourceName], at: Date())
        XCTAssertFalse(try learning.vocabulary.personalEditingAllowed(entryID: entry.entryID))
        XCTAssertThrowsError(try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: [.init(partOfSpeech: "noun", chinese: "不可绕过", confirmed: true)], at: Date()))
    }
    func testRealMDXUsageNotesAndCrossReferencesKeepBilingualPairs() async throws {
        let provider = BundledMDXDictionaryProvider()
        let month = try await provider.lookup("May")
        let notes = month.flatMap { $0.usageNotes ?? [] }
        XCTAssertTrue(notes.contains { $0.english.contains("April") && $0.chinese.contains("April") })
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let parent = try await learning.dictionary.lookup("user")
        XCTAssertTrue(parent.senses.flatMap { $0.seeAlso ?? [] }.contains("end user"))
        let related = try await learning.dictionary.subentry("end user", from: parent)
        XCTAssertEqual(related.headword, "end user"); XCTAssertFalse(related.reliableChinese.isEmpty)
    }
    func testRealMDXLinkedUsageBoxIsReadFromTheSameDictionaryAndKeepsExamplePairs() async throws {
        let values = try await BundledMDXDictionaryProvider().lookup("hospital")
        XCTAssertEqual(values.flatMap { $0.sourceWarnings ?? [] }, [])
        let notes = values.flatMap { $0.usageNotes ?? [] }
        XCTAssertTrue(notes.contains { $0.english.contains("to hospital") && $0.chinese.contains("英式英语") })
        XCTAssertTrue(notes.contains { $0.label == "例句" && $0.english.contains("two weeks") && $0.chinese.contains("两周") })
        XCTAssertEqual(Set(notes.map(\.id)).count, notes.count)
        let references = values.flatMap { $0.seeAlso ?? [] }
        XCTAssertTrue(references.contains("ambulance"))
        XCTAssertTrue(references.contains("inpatient"))
        XCTAssertFalse(references.contains("hospital"))
    }
    func testSelectedPersonalSenseCannotBorrowAnotherSenseExampleAndFreezesExampleIdentity() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        _ = try await learning.dictionary.lookup("lexidawnselectedexample")
        let entry = try learning.vocabulary.addDictionaryEntry(headword: "lexidawnselectedexample", at: Date())
        let first = PersonalDictionarySense(partOfSpeech: "noun", chinese: "第一义", examples: [.init(english: "A lexidawnselectedexample is in the first sense.")], confirmed: true)
        var selected = PersonalDictionarySense(partOfSpeech: "verb", chinese: "第二义", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: [first, selected], at: Date())
        try learning.vocabulary.confirmReviewMeaning(entryID: entry.entryID, sourceSenseID: selected.dictionarySense(entryID: entry.entryID).id)
        _ = try learning.content.importArticle(.init(title: "Original sense isolation fixture", body: "This original article establishes a cycle without supplying the target word.", source: "Original XCTest author", rightsConfirmed: true), at: Date())
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: Date(), timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        do { _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: Date()); XCTFail("Selected sense has no example") }
        catch let issue as ReviewMeaningIssue { XCTAssertEqual(issue.entryID, entry.entryID); XCTAssertTrue(issue.canEditPersonal) }
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewExerciseRecord>()), 0)
        selected.examples = [.init(english: "We lexidawnselectedexample the second sense.", chinese: "第二义的配对例句")]
        try learning.vocabulary.savePersonalSenses(entryID: entry.entryID, senses: [first, selected], at: Date())
        try learning.vocabulary.confirmReviewMeaning(entryID: entry.entryID, sourceSenseID: selected.dictionarySense(entryID: entry.entryID).id)
        let prepared = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: Date())
        let session = try XCTUnwrap(prepared)
        XCTAssertEqual(session.matching.first?.answer, "第二义")
        XCTAssertEqual(session.cloze.first?.context, selected.examples[0].english)
        XCTAssertEqual(session.cloze.first?.sourceExampleID, selected.examples[0].id)
        XCTAssertNotNil(session.cloze.first?.sourceRange)
        let damaged = ModelContext(app.modelContainer)
        let question = try XCTUnwrap(damaged.fetch(FetchDescriptor<ReviewExerciseRecord>()).first { $0.stage == "cloze" })
        question.sourceRangeLength = 1000; try damaged.save()
        XCTAssertThrowsError(try learning.review.session(cycleID: cycle.cycleID)) { error in
            guard let failure = error as? PersistenceError, case .integrity = failure else { return XCTFail("Corrupt range must remain a typed integrity error: \(error)") }
        }
        XCTAssertEqual(try ModelContext(app.modelContainer).fetchCount(FetchDescriptor<ReviewExerciseRecord>()), 2, "Do not erase the damaged session to manufacture recovery")
    }
    func testExtraPreflightDeferralPersistsWithoutAnswerOrFSRSUpdate() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let now = Date()
        let article = try learning.content.importArticle(.init(title: "Original extra deferral fixture", body: "This original article establishes the current learning cycle.", source: "Original XCTest author", rightsConfirmed: true), at: now)
        guard case let .cycle(cycle, _) = try app.cycleService.ensureCurrentCycle(now: now, timeZone: .current, calendar: .current) else { return XCTFail("Expected cycle") }
        _ = try await learning.review.prepare(cycleID: cycle.cycleID, dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        try learning.reader.complete(articleID: article, cycleID: cycle.cycleID, manualConfirmation: true, at: now)
        _ = try await learning.dictionary.lookup("lexidawnextradeferral")
        let entry = try learning.vocabulary.addDictionaryEntry(headword: "lexidawnextradeferral", at: now)
        let before = try learning.cycles.fetchAll()
        var problem: ReviewMeaningIssue?
        do { _ = try await learning.review.prepareExtra(dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now); XCTFail("Missing Chinese must block practice") }
        catch let issue as ReviewMeaningIssue { problem = issue }
        let issue = try XCTUnwrap(problem)
        XCTAssertEqual(issue.entryID, entry.entryID); XCTAssertTrue(issue.canEditPersonal)
        XCTAssertEqual(try learning.review.remainingExtraPreparationCount(at: now), 1)
        try learning.review.deferExtraEntry(issue: issue, at: now)
        let recovered = ReviewQueueService(context: ModelContext(app.modelContainer), cycles: learning.cycles, dictionary: learning.dictionary)
        let prepared = try await recovered.prepareExtra(dailyLimit: 1, pairCount: 1, clozeCount: 1, at: now)
        XCTAssertNil(prepared); XCTAssertEqual(try recovered.remainingExtraPreparationCount(at: now), 0)
        XCTAssertEqual(try learning.cycles.fetchAll(), before)
        let context = ModelContext(app.modelContainer)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLogRecord>()), 0)
        let state = try XCTUnwrap(context.fetch(FetchDescriptor<ReviewStateRecord>()).first)
        XCTAssertEqual(state.repetitions, 0); XCTAssertNil(state.lastReviewedAt); XCTAssertEqual(state.dueAt, now)
        XCTAssertEqual(try learning.vocabulary.entries().first?.id, entry.entryID)
    }
    func testFrozenRound3ArchiveMappingPreservesFullHistoricalCandidate() throws {
        let now = Date(), raw = "The original historical paragraph remains intact."
        let record = FrozenRound3Schema.ArticleRecord(articleID: "archive-fixture", canonicalURL: "https://example.com/original", originalTitle: "Original title", displayTitle: "Display title", sourceID: "original-source", publishedAt: now, fetchedAt: now, licenseID: "original-license", licenseVerified: true, bodyText: raw, bodyHash: fingerprint(raw), wordCount: 7, estimatedReadMinutes: 1, topicTags: ["Science"], difficulty: "advanced", imageURL: "https://example.com/image.png", imageAttribution: "Original photographer", contentStatus: "available", createdAt: now, updatedAt: now)
        record.cachePermissionData = try JSONEncoder().encode(ArticleCachePermission.persistent)
        record.sourceAttribution = "Original author"; record.fullTextDisplayAllowed = true
        record.imageLicenseID = "image-license"; record.imageLicenseVerified = true
        let archive = try FrozenRound3Schema.ArticleHistoryArchiveRecord(article: record, at: now)
        let value = try JSONDecoder().decode(ArticleCandidate.self, from: archive.candidateData)
        XCTAssertEqual(value.id, record.articleID); XCTAssertEqual(value.bodyText, raw)
        XCTAssertEqual(value.title, record.originalTitle); XCTAssertEqual(value.displayTitle, record.displayTitle)
        XCTAssertEqual(value.cachePermission, .persistent); XCTAssertEqual(value.sourceAttribution, record.sourceAttribution)
        XCTAssertEqual(value.imageLicenseID, record.imageLicenseID); XCTAssertTrue(value.imageLicenseVerified)
        XCTAssertEqual(value.topicTags, record.topicTags); XCTAssertEqual(value.publishedAt, now)
        record.cachePermissionData = Data("corrupt".utf8)
        XCTAssertThrowsError(try record.candidate())
        record.cachePermissionData = nil; record.contentStatus = "invalid"
        XCTAssertThrowsError(try record.candidate())
    }
}
