import Foundation

enum ArticleHTMLExtractor {
    private static let standardEntities: [String: String] = {
        guard let url = Bundle.main.url(forResource: "html-entities", withExtension: "json"), let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }()
    /// A bounded tokenizer with quoted-attribute and comment handling. It never executes HTML.
    /// Source adapters must independently attest that the response is a complete article.
    static func extract(_ html: String) throws -> ArticleDocument {
        guard html.utf8.count <= 4_000_000 else { throw FullTextImportError.parsing }
        var cursor = html.startIndex, buffer = "", blocks: [ArticleDocument.Block] = []
        var kind = ArticleDocument.Block.Kind.paragraph, level = 0, suppressed: [String] = []
        var styles: [(String, ArticleDocument.Block.Kind, Int)] = []
        var lists: [(ordered: Bool, ordinal: Int)] = []
        let excluded: Set<String> = ["script", "style", "nav", "button", "video", "audio", "noscript", "iframe"]
        let boundaries: Set<String> = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "figcaption", "tr", "section", "article", "main", "pre"]
        func flush() throws {
            let value = try decodeEntities(buffer).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !value.isBlank { blocks.append(.init(kind: kind, text: value, level: level, listOrdinal: kind == .listItem && lists.last?.ordered == true ? lists.last?.ordinal : nil)) }; buffer = ""
        }
        while cursor < html.endIndex {
            if html[cursor] != "<" {
                if suppressed.isEmpty { buffer.append(html[cursor]) }; cursor = html.index(after: cursor); continue
            }
            if html[cursor...].hasPrefix("<!--") {
                guard let end = html.range(of: "-->", range: cursor..<html.endIndex) else { throw FullTextImportError.parsing }
                cursor = end.upperBound; continue
            }
            var end = html.index(after: cursor), quote: Character?
            while end < html.endIndex {
                let char = html[end]
                if let current = quote { if char == current { quote = nil } }
                else if char == "\"" || char == "'" { quote = char }
                else if char == ">" { break }
                end = html.index(after: end)
            }
            guard end < html.endIndex else { throw FullTextImportError.parsing }
            let tag = html[html.index(after: cursor)..<end].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let closing = tag.hasPrefix("/")
            let name = tag.drop(while: { $0 == "/" || $0.isWhitespace }).prefix(while: { $0.isLetter || $0.isNumber })
            let key = String(name)
            if excluded.contains(key) {
                if closing { if suppressed.last == key { suppressed.removeLast() } }
                else if !tag.hasSuffix("/") { suppressed.append(key) }
            } else if suppressed.isEmpty {
                if key == "ol" || key == "ul" {
                    try flush()
                    if closing { if !lists.isEmpty { lists.removeLast() } }
                    else { lists.append((key == "ol", 0)) }
                }
                if boundaries.contains(key) {
                    try flush()
                    if !closing {
                        styles.append((key, kind, level))
                        if key == "li", !lists.isEmpty { lists[lists.count - 1].ordinal += 1 }
                        kind = key.hasPrefix("h") && key.count == 2 ? .heading : key == "li" ? .listItem : key == "blockquote" ? .quotation : key == "figcaption" ? .caption : [.quotation, .listItem].contains(kind) ? kind : .paragraph
                        level = kind == .heading ? Int(key.suffix(1)) ?? 0 : 0
                    } else if let index = styles.lastIndex(where: { $0.0 == key }) {
                        kind = styles[index].1; level = styles[index].2; styles.removeSubrange(index...)
                    } else { kind = .paragraph; level = 0 }
                } else if ["br", "td", "th", "hr"].contains(key) { buffer += " " }
            }
            cursor = html.index(after: end)
        }
        guard suppressed.isEmpty else { throw FullTextImportError.parsing }
        try flush()
        guard !blocks.isEmpty else { throw FullTextImportError.incomplete }
        return ArticleDocument(blocks: blocks)
    }
    static func decodeEntities(_ text: String) throws -> String {
        let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "hellip": "…", "bull": "•", "middot": "·", "copy": "©", "reg": "®", "deg": "°", "times": "×", "minus": "−", "prime": "′", "Prime": "″", "thinsp": " ", "ensp": " ", "emsp": " ", "shy": "\u{00ad}", "le": "≤", "ge": "≥", "pound": "£", "euro": "€", "cent": "¢", "alpha": "α", "beta": "β", "pi": "π"]
        let regex = try NSRegularExpression(pattern: "&(#x[0-9A-Fa-f]+|#[0-9]+|[A-Za-z]+);")
        let ns = text as NSString; var result = text
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let entity = ns.substring(with: match.range(at: 1)); let value: String
            if entity.hasPrefix("#") {
                let number = entity.hasPrefix("#x") ? UInt32(entity.dropFirst(2), radix: 16) : UInt32(entity.dropFirst())
                guard let number, let scalar = UnicodeScalar(number) else { throw FullTextImportError.parsing }; value = String(scalar)
            } else {
                // Unknown named references are literal text in HTML, not permission to delete characters.
                guard let decoded = named[entity] ?? standardEntities[entity] else { continue }; value = decoded
            }
            guard let range = Range(match.range, in: result) else { throw FullTextImportError.parsing }; result.replaceSubrange(range, with: value)
        }
        return result
    }
    static func jsonLD(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        func body(_ object: Any) -> String? {
            if let array = object as? [Any] { return array.compactMap(body).first }
            guard let dictionary = object as? [String: Any] else { return nil }
            if let type = dictionary["@type"] as? String, ["Article", "NewsArticle", "BlogPosting"].contains(type), let text = dictionary["articleBody"] as? String { return text }
            if let graph = dictionary["@graph"] { return body(graph) }; return nil
        }
        guard let text = body(object), !text.isBlank else { throw FullTextImportError.parsing }; return text
    }
}
