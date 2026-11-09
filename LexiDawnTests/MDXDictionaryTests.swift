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
    func testRealOfflineServiceNormalizesUsersAndVisitsWithoutNetworkProviders() async throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        XCTAssertFalse(learning.dictionary.onlineEnabled)
        let users = try await learning.dictionary.lookup("users", context: "The users read articles.")
        let visits = try await learning.dictionary.lookup("visits", context: "She visits us every week.")
        XCTAssertEqual(users.headword, "user"); XCTAssertEqual(visits.headword, "visit")
        XCTAssertFalse(users.reliableChinese.isEmpty); XCTAssertFalse(visits.reliableChinese.isEmpty)
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
