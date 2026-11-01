import Foundation

enum ClozeContext {
    struct Projection: Equatable, Sendable { let answer: String; let sentence: String? }
    static func make(lemma: String, surfaces: [String], sentence: String?) -> Projection {
        guard let sentence, !sentence.isBlank else { return Projection(answer: lemma, sentence: nil) }
        for surface in surfaces where EnglishTokenizer.lemma(surface) == lemma && !surface.isBlank {
            if mask(sentence, answer: surface) != sentence { return Projection(answer: EnglishTokenizer.normalized(surface), sentence: sentence) }
        }
        if !lemma.contains(where: \.isWhitespace), let token = EnglishTokenizer.tokens(in: sentence).first(where: { EnglishTokenizer.lemma($0.surface) == lemma }) {
            return Projection(answer: EnglishTokenizer.normalized(token.surface), sentence: sentence)
        }
        return Projection(answer: lemma, sentence: safeSentence(sentence, answer: lemma))
    }
    static func safeSentence(_ sentence: String?, answer: String) -> String? {
        guard let sentence, mask(sentence, answer: answer) != sentence else { return nil }; return sentence
    }
    static func mask(_ sentence: String, answer: String) -> String {
        guard !answer.isBlank else { return sentence }
        let edge = #"[\p{L}\p{N}_'’‐\-]"#
        let pattern = "(?<!" + edge + ")" + NSRegularExpression.escapedPattern(for: answer) + "(?!" + edge + ")"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return sentence }
        let result = NSMutableString(string: sentence)
        for match in regex.matches(in: sentence, range: NSRange(location: 0, length: (sentence as NSString).length)).reversed() {
            let surface = (sentence as NSString).substring(with: match.range)
            let hidden = surface.map { $0.isLetter || $0.isNumber ? "_" : String($0) }.joined()
            result.replaceCharacters(in: match.range, with: hidden)
        }
        return result as String
    }
}
