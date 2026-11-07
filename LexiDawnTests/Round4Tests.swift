import XCTest
import SwiftData
@testable import LexiDawn

@MainActor final class Round4Tests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_798_300_000)
    func testEnglishOnlyDoesNotLockPersonalChineseDefinitions() {
        let english = DictionarySense(id: "en", en: "Explicit English fixture definition", zh: "", line: "Fixture", sources: ["Wiktionary"])
        XCTAssertFalse(BilingualMeaningPolicy.trusted(english))
        XCTAssertTrue(BilingualMeaningPolicy.permitsPersonal(senses: [english], knownReliableChinese: false))
        XCTAssertTrue(BilingualMeaningPolicy.displaySenses([english]).isEmpty)
    }
    func testTrustedChineseLocksButReverseIndexDoesNot() {
        let trusted = DictionarySense(id: "trusted", en: "", zh: "明确原创中文义项夹具", line: "Fixture", sources: ["Wiktionary"])
        let reverse = DictionarySense(id: "reverse", en: "", zh: "反向候选", line: "Fixture", sources: ["CC-CEDICT"])
        XCTAssertTrue(BilingualMeaningPolicy.trusted(trusted))
        XCTAssertFalse(BilingualMeaningPolicy.permitsPersonal(senses: [trusted], knownReliableChinese: false))
        XCTAssertTrue(BilingualMeaningPolicy.permitsPersonal(senses: [reverse], knownReliableChinese: false))
        XCTAssertFalse(BilingualMeaningPolicy.permitsPersonal(senses: [], knownReliableChinese: true))
    }
    func testChineseWiktionaryParserScopesEnglishAndPreservesPartOfSpeech() throws {
        let html = "<h2>法語</h2><h3>名詞</h3><ol><li>错误语言夹具</li></ol><h2>英語</h2><h3>名詞</h3><ol><li>明确原创名词义项</li></ol><h3>動詞</h3><ol><li>明确原创动词义项</li></ol><h2>德語</h2><h3>名詞</h3><ol><li>另一个错误语言夹具</li></ol>"
        let values = try WiktionaryBilingualParser.parse(html, revision: "fixture-7")
        XCTAssertEqual(values.map(\.zh), ["明确原创名词义项", "明确原创动词义项"])
        XCTAssertEqual(values.map(\.partOfSpeech), ["noun", "verb"])
        XCTAssertTrue(values.allSatisfy { $0.sourceRevision == "fixture-7" && BilingualMeaningPolicy.trusted($0) })
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
        return try XCTUnwrap(learning.vocabulary.add(token: .init(surface: "lexidawnfixtureword", range: NSRange(location: 2, length: 18), sentence: "A lexidawnfixtureword appears in this original test sentence."), articleID: id, autoAdd: false, explicit: true, at: now))
    }
    func testPersonalSensesPersistAndNotesRemainIndependent() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        let sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "明确原创的个人词义", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: now)
        try learning.vocabulary.saveNotes(entryID: added.entryID, notes: "独立笔记", at: now)
        let restored = try XCTUnwrap(learning.vocabulary.entries().first)
        XCTAssertEqual(restored.personalSenses, [sense]); XCTAssertEqual(restored.notes, "独立笔记")
    }
    func testRepositoryRejectsPersonalWriteAfterReliableChineseArrivesAndCacheClear() throws {
        let app = try AppDependencies.makeLearningInMemory(), learning = try XCTUnwrap(app.learning)
        let added = try entry(learning)
        let sense = PersonalDictionarySense(partOfSpeech: "noun", chinese: "旧个人义", confirmed: true)
        try learning.vocabulary.savePersonalSenses(entryID: added.entryID, senses: [sense], at: now)
        let word = try XCTUnwrap(learning.vocabulary.entries().first?.lemma)
        let trusted = DictionarySense(id: "explicit-trusted-fixture", en: "", zh: "可靠英中原创夹具", line: "Explicit fixture", partOfSpeech: "noun", sources: ["Wiktionary"])
        try DictionaryCacheRepository(context: ModelContext(app.modelContainer)).save(word, senses: [trusted], successful: ["Wiktionary"], at: now)
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
}
