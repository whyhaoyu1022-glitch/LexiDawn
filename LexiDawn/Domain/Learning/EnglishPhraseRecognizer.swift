import Foundation

enum EnglishPhraseRecognizer {
    static let patterns = ["look into", "carry out", "take into account", "play a role in"]
    /// Bind the entire phrase to the actual tapped source span, including original hard whitespace.
    /// A matching word elsewhere in the sentence cannot invent a phrase location.
    static func token(for phrase: String, around tapped: EnglishToken, sourceText: String) -> EnglishToken? {
        let source = sourceText as NSString
        guard tapped.range.location != NSNotFound, tapped.range.location >= 0, tapped.range.location <= source.length, tapped.range.length > 0, tapped.range.length <= source.length - tapped.range.location,
              EnglishTokenizer.normalized(source.substring(with: tapped.range)) == EnglishTokenizer.normalized(tapped.surface) else { return nil }
        let words = EnglishTokenizer.tokens(in: phrase).map { NSRegularExpression.escapedPattern(for: $0.surface) }
        guard words.count > 1, let regex = try? NSRegularExpression(pattern: #"\b"# + words.joined(separator: #"\s+"#) + #"\b"#, options: [.caseInsensitive]) else { return nil }
        let spans = regex.matches(in: sourceText, range: NSRange(location: 0, length: source.length)).map(\.range)
            .filter { $0.location <= tapped.range.location && NSMaxRange($0) >= NSMaxRange(tapped.range) }
        guard spans.count == 1, let span = spans.first else { return nil }
        return EnglishToken(surface: source.substring(with: span), range: span, sentence: tapped.sentence)
    }
    /// Deterministic phrase detection, not a generated definition. Results use real source spelling.
    static func phrases(around surface: String, sentence: String) -> [String] {
        let tokens = EnglishTokenizer.tokens(in: sentence)
        var found = Set<String>()
        for pattern in patterns {
            let words = pattern.split(separator: " ").map(String.init)
            guard tokens.count >= words.count else { continue }
            for start in 0...(tokens.count - words.count) {
                let group = Array(tokens[start..<(start + words.count)])
                guard group.map({ EnglishTokenizer.lemma($0.surface) }) == words,
                      group.contains(where: { EnglishTokenizer.lemma($0.surface) == EnglishTokenizer.lemma(surface) }) else { continue }
                let span = NSRange(location: group[0].range.location, length: NSMaxRange(group[group.count - 1].range) - group[0].range.location)
                found.insert((sentence as NSString).substring(with: span))
            }
        }
        return found.sorted()
    }
}
