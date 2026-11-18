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
    /// The article supplies an absolute UTF-16 offset. Search only windows
    /// containing that occurrence, bounded by two words on either side.
    static func adjacent(to tapped: EnglishToken, in text: String) -> [EnglishToken] {
        let source = text as NSString
        guard tapped.range.location >= 0, tapped.range.location < source.length,
              tapped.range.length > 0, tapped.range.length <= source.length - tapped.range.location else { return [] }
        let paragraph = source.paragraphRange(for: tapped.range)
        let excerpt = source.substring(with: paragraph)
        let words = EnglishTokenizer.tokens(in: excerpt)
        guard let center = words.firstIndex(where: {
            $0.range.location + paragraph.location == tapped.range.location && $0.surface == tapped.surface
        }) else { return [] }
        var matches: [(length: Int, token: EnglishToken)] = []
        for start in max(0, center - 2)...center {
            for end in center...min(words.count - 1, center + 2) where end > start {
                let group = words[start...end]
                guard group.allSatisfy({ $0.sentence == words[center].sentence }),
                      zip(group, group.dropFirst()).allSatisfy({ left, right in
                          let gap = NSRange(location: NSMaxRange(left.range) + paragraph.location,
                                            length: right.range.location - NSMaxRange(left.range))
                          return source.substring(with: gap).allSatisfy(\.isWhitespace)
                      }) else { continue }
                let span = NSRange(location: words[start].range.location + paragraph.location,
                                   length: NSMaxRange(words[end].range) - words[start].range.location)
                matches.append((end - start + 1, EnglishToken(surface: source.substring(with: span), range: span, sentence: tapped.sentence)))
            }
        }
        return matches.sorted { ($0.length, -$0.token.id) > ($1.length, -$1.token.id) }.map(\.token)
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
