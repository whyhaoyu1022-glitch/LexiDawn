import Foundation

/// Extracts only configured article-body subtrees or an explicit schema.org articleBody.
/// No JavaScript, browser, login, proxy, challenge solving or subscription bypass is used.
enum ArticleWebPageExtractor {
    private struct Element {
        let name: String, attributes: [String: String], start: Int, contentStart: Int, parent: Int?
        var end: Int?, contentEnd: Int?
    }
    struct Result: Sendable {
        let title: String, author: String, canonicalURL: String
        let publishedAt: Date?
        let document: ArticleDocument
    }
    private static func regex(_ pattern: String) throws -> NSRegularExpression { try NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) }
    private static func attributes(_ tag: String) throws -> [String: String] {
        let pattern = #"([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        let text = tag as NSString
        var values: [String: String] = [:]
        for match in try regex(pattern).matches(in: tag, range: NSRange(location: 0, length: text.length)) {
            let key = text.substring(with: match.range(at: 1)).lowercased()
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                values[key] = try ArticleHTMLExtractor.decodeEntities(text.substring(with: match.range(at: index))); break
            }
        }
        return values
    }
    private static func elements(_ html: String) throws -> [Element] {
        let text = html as NSString
        let tags = try regex(#"<!--[\s\S]*?-->|<![^>]*>|</?[a-z][a-z0-9:-]*(?:\s+(?:[^>"']|"[^"]*"|'[^']*')*)?\s*/?>"#)
        let void: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]
        var nodes: [Element] = [], stack: [Int] = []
        for match in tags.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: match.range)
            if tag.hasPrefix("<!") { continue }
            let closing = tag.hasPrefix("</")
            let name = tag.dropFirst(closing ? 2 : 1).prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == ":" }.lowercased()
            if closing {
                if let position = stack.lastIndex(where: { nodes[$0].name == name }) {
                    let index = stack[position]; nodes[index].contentEnd = match.range.location; nodes[index].end = NSMaxRange(match.range)
                    stack.removeSubrange(position...)
                }
            } else {
                let index = nodes.count
                nodes.append(.init(name: name, attributes: try attributes(tag), start: match.range.location, contentStart: NSMaxRange(match.range), parent: stack.last))
                if void.contains(name) || tag.hasSuffix("/>") { nodes[index].end = NSMaxRange(match.range); nodes[index].contentEnd = NSMaxRange(match.range) }
                else { stack.append(index) }
            }
        }
        return nodes
    }
    private static func cleanPage(_ html: String) throws -> (String, [[String: Any]]) {
        let text = html as NSString
        let scripts = try regex(#"<script\b[^>]*>[\s\S]*?</script\s*>"#)
        var articles: [[String: Any]] = []
        func collect(_ value: Any) {
            if let array = value as? [Any] { array.forEach(collect); return }
            guard let object = value as? [String: Any] else { return }
            let types = (object["@type"] as? [String]) ?? (object["@type"] as? String).map { [$0] } ?? []
            if types.contains(where: { ["Article", "NewsArticle", "ReportageNewsArticle", "BlogPosting", "ScholarlyArticle"].contains($0) }) { articles.append(object) }
            if let graph = object["@graph"] { collect(graph) }
        }
        let matches = scripts.matches(in: html, range: NSRange(location: 0, length: text.length))
        for match in matches {
            let script = text.substring(with: match.range)
            guard script.lowercased().contains("application/ld+json"), let first = script.firstIndex(of: ">"), let last = script.range(of: "</script", options: [.caseInsensitive, .backwards])?.lowerBound else { continue }
            let json = String(script[script.index(after: first)..<last])
            if let data = json.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) { collect(object) }
        }
        var page = html
        for match in matches.reversed() { if let range = Range(match.range, in: page) { page.replaceSubrange(range, with: "") } }
        page = try regex(#"<style\b[^>]*>[\s\S]*?</style\s*>|<!--[\s\S]*?-->"#).stringByReplacingMatches(in: page, range: NSRange(location: 0, length: (page as NSString).length), withTemplate: "")
        return (page, articles)
    }
    static func links(_ data: Data, source: PublisherArticleSource) throws -> [ArticleDiscoveryItem] {
        guard let html = String(data: data, encoding: .utf8) else { throw FullTextImportError.parsing }
        let (page, _) = try cleanPage(html)
        let text = page as NSString
        var seen = Set<String>(), result: [ArticleDiscoveryItem] = []
        for node in try elements(page) where node.name == "a" {
            guard let href = node.attributes["href"], let url = URL(string: href, relativeTo: URL(string: source.discoveryURL))?.absoluteURL,
                  accepts(url, source: source), seen.insert(ArticleCandidate.normalizeCanonicalURL(url.absoluteString)).inserted,
                  let end = node.contentEnd, end > node.contentStart else { continue }
            let fragment = text.substring(with: NSRange(location: node.contentStart, length: end - node.contentStart))
            guard let title = try? ArticleHTMLExtractor.extract(fragment).text, !title.isBlank else { continue }
            result.append(.init(sourceID: source.id, title: title, url: url.absoluteString, revision: nil))
            if result.count == 20 { break }
        }
        print("ARTICLE_DISCOVERY_DIAGNOSTIC sourceID=\(source.id) code=link-scan nodes=\((try? elements(page).count) ?? 0) articles=\(result.count)")
        return result
    }
    static func accepts(_ url: URL, source: PublisherArticleSource) -> Bool {
        url.scheme == "https" && source.hosts.contains(url.host ?? "") && url.user == nil && url.password == nil &&
        url.path.range(of: source.articlePathPattern, options: .regularExpression) != nil
    }
    static func extract(_ data: Data, candidate: ArticleDiscoveryItem, source: PublisherArticleSource) throws -> Result {
        guard data.count <= 4_000_000, let html = String(data: data, encoding: .utf8),
              html.range(of: "</html", options: .caseInsensitive) != nil else {
            print("ARTICLE_EXTRACTION_DIAGNOSTIC sourceID=\(source.id) code=missing-complete-html bytes=\(data.count)")
            throw FullTextImportError.incomplete
        }
        let (page, articles) = try cleanPage(html)
        let lower = page.lowercased()
        guard !["verify you are human", "complete the captcha", "enable javascript and cookies to continue", "subscribe to continue reading", "sign in to continue reading", "please enable js and disable any ad blocker"].contains(where: lower.contains) else { throw FullTextImportError.incomplete }
        if articles.contains(where: { ($0["isAccessibleForFree"] as? Bool) == false || ($0["isAccessibleForFree"] as? String)?.lowercased() == "false" }) { throw FullTextImportError.incomplete }
        let nodes = try elements(page), text = page as NSString
        let metadata = Dictionary(nodes.filter { $0.name == "meta" }.compactMap { node -> (String, String)? in
            guard let key = node.attributes["property"] ?? node.attributes["name"], let value = node.attributes["content"] else { return nil }; return (key.lowercased(), value)
        }, uniquingKeysWith: { first, _ in first })
        var selected = Set<Int>(), blocks: [ArticleDocument.Block] = []
        for (index, node) in nodes.enumerated() {
            let values = [node.attributes["class"], node.attributes["id"], node.attributes["data-component"], node.attributes["data-testid"], node.attributes["data-gu-name"], node.attributes["itemprop"]].compactMap { $0 }
            let matches = (["nasa", "bbc"].contains(source.id) && node.name == "article") || node.attributes["itemprop"] == "articleBody" || values.contains { value in source.bodyMarkers.contains { marker in value.split(whereSeparator: \.isWhitespace).contains { String($0).caseInsensitiveCompare(marker) == .orderedSame || (marker.count > 4 && $0.lowercased().hasPrefix(marker.lowercased() + "__")) } } }
            guard matches else { continue }
            var parent = node.parent, nested = false
            while let current = parent { if selected.contains(current) { nested = true; break }; parent = nodes[current].parent }
            if nested { continue }
            guard let end = node.end else { throw FullTextImportError.incomplete }
            selected.insert(index)
            let fragment = text.substring(with: NSRange(location: node.start, length: end - node.start))
            blocks += try ArticleHTMLExtractor.extract(fragment).blocks
        }
        var document = ArticleDocument(blocks: blocks)
        let article = articles.max { (($0["articleBody"] as? String)?.count ?? 0) < (($1["articleBody"] as? String)?.count ?? 0) }
        if let raw = article?["articleBody"] as? String, !raw.isBlank {
            let jsonDocument: ArticleDocument
            if raw.range(of: "<(p|div|br|h[1-6])\\b", options: [.regularExpression, .caseInsensitive]) != nil { jsonDocument = try ArticleHTMLExtractor.extract(raw) }
            else { jsonDocument = ArticleDocumentNormalizer.plainText(try ArticleHTMLExtractor.decodeEntities(raw)) }
            if jsonDocument.text.count > document.text.count { document = jsonDocument }
        }
        let words = document.text.split(whereSeparator: \.isWhitespace).count
        print("ARTICLE_EXTRACTION_DIAGNOSTIC sourceID=\(source.id) code=body-check roots=\(selected.count) blocks=\(document.blocks.count) words=\(words) jsonArticles=\(articles.count)")
        guard words >= 80, document.blocks.count >= 2 else { throw FullTextImportError.incomplete }
        if let expected = article?["wordCount"] as? Int, expected > 0, words < Int(Double(expected) * 0.90) { throw FullTextImportError.truncated }
        let title = article?["headline"] as? String ?? metadata["og:title"] ?? candidate.title
        let authorObject = article?["author"]
        let objectName = (authorObject as? [String: Any])?["name"] as? String
        let arrayName = (authorObject as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ")
        let author = objectName ?? arrayName ?? (authorObject as? String) ?? metadata["author"] ?? source.name
        let dateText = article?["datePublished"] as? String ?? metadata["article:published_time"]
        let date = dateText.flatMap { ISO8601DateFormatter().date(from: $0) }
        var canonical = candidate.url
        if let link = nodes.first(where: { $0.name == "link" && $0.attributes["rel"]?.lowercased() == "canonical" })?.attributes["href"], let url = URL(string: link), accepts(url, source: source) { canonical = link }
        guard let url = URL(string: canonical), accepts(url, source: source) else { throw FullTextImportError.incomplete }
        return .init(title: title, author: author, canonicalURL: canonical, publishedAt: date, document: document)
    }
}
