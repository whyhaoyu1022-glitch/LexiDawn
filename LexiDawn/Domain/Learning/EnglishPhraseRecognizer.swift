import Foundation

enum EnglishPhraseRecognizer {
    static let patterns = ["look into", "carry out", "take into account", "play a role in"]
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
