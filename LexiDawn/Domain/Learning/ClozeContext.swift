import Foundation

enum SpellingAnswerPolicy {
    /// Accept only an explicit spelling relation in the original provider definition.
    /// A different tense or plural form is never inferred as an alternative answer.
    static func variants(answer: String, lemma: String, senses: [DictionarySense]) -> [String] {
        if ["May", "US"].contains(answer) { return [answer] }
        let expected = EnglishTokenizer.normalized(answer)
        guard expected == EnglishTokenizer.normalized(lemma), !expected.contains(" ") else { return [expected] }
        var values: Set<String> = [expected]
        let pattern = #"\b(?:alternative|British|American)\s+spelling\s+of\s+[\"'“‘]?([A-Za-z]+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [expected] }
        for sense in senses {
            let text = sense.en as NSString
            for match in regex.matches(in: sense.en, range: NSRange(location: 0, length: text.length)) {
                values.insert(EnglishTokenizer.normalized(text.substring(with: match.range(at: 1))))
            }
        }
        return values.sorted()
    }
    static func accepts(_ input: String, expected: String, alternatives: [String]) -> Bool {
        if ["May", "US"].contains(expected) { return input.trimmingCharacters(in: .whitespacesAndNewlines) == expected }
        let value = EnglishTokenizer.normalized(input)
        return value == EnglishTokenizer.normalized(expected) || alternatives.contains { EnglishTokenizer.normalized($0) == value }
    }
}

enum ClozeContext {
    struct Projection: Equatable, Sendable {
        let answer: String
        let sentence: String?
        var targetRange: NSRange? = nil
    }
    static func make(lemma: String, surfaces: [String], sentence: String?, preferredLocation: Int? = nil) -> Projection {
        guard let sentence, !sentence.isBlank else { return Projection(answer: lemma, sentence: nil) }
        for surface in surfaces where EnglishTokenizer.lemma(surface) == lemma && !surface.isBlank {
            let matches = ranges(in: sentence, answer: surface)
            let selected = preferredLocation.flatMap { location in matches.first { $0.location == location } } ?? (matches.count == 1 ? matches.first : nil)
            if let selected { return Projection(answer: ["May", "US"].contains(lemma) ? lemma : EnglishTokenizer.normalized(surface), sentence: sentence, targetRange: selected) }
            if matches.count > 1 { return Projection(answer: lemma, sentence: nil) }
        }
        if !lemma.contains(where: \.isWhitespace) {
            let tokens = EnglishTokenizer.tokens(in: sentence).filter { EnglishTokenizer.lemma($0.surface, context: sentence) == lemma }
            let token = preferredLocation.flatMap { location in tokens.first { $0.range.location == location } } ?? (tokens.count == 1 ? tokens.first : nil)
            if let token { return Projection(answer: ["May", "US"].contains(lemma) ? lemma : EnglishTokenizer.normalized(token.surface), sentence: sentence, targetRange: token.range) }
        }
        let matches = ranges(in: sentence, answer: lemma)
        if matches.count == 1, let range = matches.first { return Projection(answer: lemma, sentence: sentence, targetRange: range) }
        return Projection(answer: lemma, sentence: nil)
    }
    /// Preserve the occurrence the reader actually tapped, including when the
    /// same sentence appears more than once in an article.
    static func relativeLocation(sentence: String, in body: String, absoluteLocation: Int) -> Int? {
        guard !sentence.isEmpty else { return nil }
        var search = body.startIndex..<body.endIndex, candidates: [Int] = []
        while let found = body.range(of: sentence, range: search) {
            let range = NSRange(found, in: body)
            if NSLocationInRange(absoluteLocation, range) { candidates.append(absoluteLocation - range.location) }
            search = found.upperBound..<body.endIndex
        }
        return candidates.count == 1 ? candidates.first : nil
    }
    private static func ranges(in sentence: String, answer: String) -> [NSRange] {
        guard !answer.isEmpty else { return [] }
        func wordEdge(_ character: Character) -> Bool { character.isLetter || character.isNumber || "_'’‐-".contains(character) }
        let options: String.CompareOptions = ["May", "US"].contains(answer) ? [] : [.caseInsensitive]
        var result: [NSRange] = [], search = sentence.startIndex..<sentence.endIndex
        while let found = sentence.range(of: answer, options: options, range: search) {
            let left = found.lowerBound == sentence.startIndex || !wordEdge(sentence[sentence.index(before: found.lowerBound)])
            let right = found.upperBound == sentence.endIndex || !wordEdge(sentence[found.upperBound])
            if left && right { result.append(NSRange(found, in: sentence)) }
            search = found.upperBound..<sentence.endIndex
        }
        return result
    }
    static func validates(_ range: NSRange, answer: String, sentence: String) -> Bool { ranges(in: sentence, answer: answer).contains(range) }
    static func safeSentence(_ sentence: String?, answer: String) -> String? {
        guard let sentence, mask(sentence, answer: answer) != sentence else { return nil }; return sentence
    }
    static func mask(_ sentence: String, answer: String, targetRange: NSRange? = nil) -> String {
        guard !answer.isBlank else { return sentence }
        let matches = ranges(in: sentence, answer: answer).filter { targetRange == nil || $0 == targetRange }
        let result = NSMutableString(string: sentence)
        for range in matches.reversed() {
            let surface = (sentence as NSString).substring(with: range)
            let hidden = surface.map { $0.isLetter || $0.isNumber ? "_" : String($0) }.joined()
            result.replaceCharacters(in: range, with: hidden)
        }
        return result as String
    }
}
