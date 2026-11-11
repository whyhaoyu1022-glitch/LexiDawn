import Foundation

struct RecommendedVocabulary: Identifiable {
    var id: String { candidate.id }
    let candidate: VocabularyRecommendationCandidate
    let result: DictionaryResult
}
@MainActor final class VocabularyRecommendationService {
    private let content: ContentRepository
    private let dictionary: DictionaryLookupService
    private let vocabulary: VocabularyRepository
    private let allowed: @MainActor () throws -> Bool
    init(content: ContentRepository, dictionary: DictionaryLookupService, vocabulary: VocabularyRepository, allowed: @escaping @MainActor () throws -> Bool) {
        self.content = content; self.dictionary = dictionary; self.vocabulary = vocabulary; self.allowed = allowed
    }
    func discover(limit: Int = 8, onResult: @MainActor (RecommendedVocabulary) -> Void) async throws -> Int {
        guard (1...24).contains(limit) else { throw LearningError.invalid("推荐数量无效。") }
        guard try allowed() else { throw LearningError.invalid("请先完成当前必做任务，再查看词汇推荐。") }
        let saved = Set(try vocabulary.entries().map(\.lemma))
        let originals = try content.library().filter(\.readable).prefix(5).map { try content.read(articleID: $0.id, at: Date()) }
        let candidates = VocabularyRecommendationRules.candidates(in: originals, excluding: saved)
        var count = 0, failures = 0
        for candidate in candidates {
            try Task.checkCancellation()
            guard try allowed() else { throw LearningError.invalid("任务状态已变化，请先继续当前学习。") }
            do {
                let result = try await dictionary.lookup(candidate.lemma, context: candidate.sentence)
                try Task.checkCancellation()
                guard !result.reliableChinese.isEmpty else { continue }
                // Discovery and detail viewing do not call VocabularyRepository.add.
                onResult(RecommendedVocabulary(candidate: candidate, result: result)); count += 1
                if count >= limit { break }
            } catch is CancellationError { throw CancellationError() }
            catch { failures += 1 }
        }
        if count == 0 && failures > 0 { throw LearningError.invalid("推荐词典暂时不可用；生词本与学习记录保留，请重试。") }
        return count
    }
}
