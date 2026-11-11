import Foundation
import CryptoKit

enum MDXDictionaryError: Error, LocalizedError, Equatable {
    case missingResource
    case identityMismatch
    case invalidStructure(String)
    case invalidEntry(String)
    var errorDescription: String? {
        switch self {
        case .missingResource: return "内置 MDX 资源缺失。请重试；若仍失败，请使用包含完整词典的构建覆盖安装，保留学习数据。"
        case .identityMismatch: return "内置 MDX 校验失败，词典不可用。个人内容与学习数据保留，请重试或恢复完整构建。"
        case .invalidStructure(let detail): return "MDX 解析失败：" + detail
        case .invalidEntry(let detail): return "MDX 词条解析失败：" + detail
        }
    }
}

enum MDXEntryIdentity {
    /// An old parser revision may supply a record number as an index hint, never
    /// definitions. The native reader validates the file and reads it again.
    static func recordNumber(_ sense: DictionarySense) -> Int? {
        guard sense.originKind == "mdx", sense.sources == [BundledMDXDictionaryProvider.sourceName],
              sense.sourceRevision?.hasPrefix(BundledMDXDictionaryProvider.sourceSHA + "-html-") == true else { return nil }
        let fields = sense.id.split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count >= 5, fields[0] == "mdx", fields[1] == BundledMDXDictionaryProvider.sourceSHA,
              let number = Int(fields[2]), number >= 0 else { return nil }
        return number
    }
}

/// A single local source. The C reader retains only the headword index and one
/// decompressed record block, never the complete 270 MB uncompressed dictionary.
/// Actor isolation serializes FILE access; initialization/HTML parsing is off MainActor.
actor BundledMDXDictionaryProvider: DictionaryProvider {
    static let sourceName = "内置 MDX"
    static let sourceSHA = "095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443"
    static let sourceVersion = sourceSHA + "-html-8"
    private let resource: URL?
    private var reader: OpaquePointer?
    private var index: [String: [Int]] = [:]
    private var folded: [String: [String]] = [:]
    private var cache: [String: [DictionarySense]] = [:]
    private var recent: [String] = []
    private(set) var cacheHits = 0
    init(resource: URL? = Bundle.main.url(forResource: "BundledDictionary", withExtension: "mdx")) { self.resource = resource }
    deinit { if let reader { ld_mdx_close(reader) } }

    private static func foldedKey(_ key: String) -> String {
        key.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private func initialize() throws {
        if reader != nil { return }
        try Task.checkCancellation()
        guard let resource, FileManager.default.fileExists(atPath: resource.path) else { throw MDXDictionaryError.missingResource }
        let stream = try FileHandle(forReadingFrom: resource)
        var hasher = SHA256(), size = 0
        do {
            while let data = try stream.read(upToCount: 1024 * 1024), !data.isEmpty {
                try Task.checkCancellation(); size += data.count; hasher.update(data: data)
            }
            try stream.close()
        } catch { try stream.close(); throw error }
        let sha = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard size == 38_774_534, sha == Self.sourceSHA else { throw MDXDictionaryError.identityMismatch }
        var error = [CChar](repeating: 0, count: 512)
        guard let opened = resource.path.withCString({ ld_mdx_open($0, &error, 512) }) else {
            throw MDXDictionaryError.invalidStructure(String(cString: error))
        }
        do {
            var exact: [String: [Int]] = [:], insensitive: [String: [String]] = [:]
            for number in 0..<Int(ld_mdx_count(opened)) {
                if number % 512 == 0 { try Task.checkCancellation() }
                guard let pointer = ld_mdx_key(opened, number), let key = String(validatingUTF8: pointer) else { throw MDXDictionaryError.invalidStructure("无效 UTF-8 词头") }
                if exact[key] == nil { insensitive[Self.foldedKey(key), default: []].append(key) }
                exact[key, default: []].append(number)
            }
            index = exact; folded = insensitive; reader = opened
        } catch { ld_mdx_close(opened); throw error }
    }
    func lookup(_ headword: String) async throws -> [DictionarySense] {
        try initialize(); try Task.checkCancellation()
        if let value = cache[headword] { cacheHits += 1; touch(headword); return value }
        // Exact spelling wins: May never merges the modal may or the hawthorn noun.
        let keys = index[headword] != nil ? [headword] : folded[Self.foldedKey(headword)] ?? []
        let parsed = try parseRecords(keys.flatMap { index[$0] ?? [] }, headword: headword, subentryOnly: false)
        let direct = parsed.filter { $0.sectionKind == nil && $0.lexicalHeadword == headword }
        let equivalent = direct.isEmpty ? parsed.filter {
            $0.sectionKind == nil && $0.lexicalHeadword.map(Self.foldedKey) == Self.foldedKey(headword)
        } : direct
        let groups = Set(equivalent.compactMap(\.entryGroupID))
        // Some index keys include both a true headword and adjacent variants.
        // Keep the actual headword's groups, including their nested phrases.
        let values = groups.isEmpty ? parsed : parsed.filter { $0.entryGroupID.map(groups.contains) ?? false }
        remember(values, headword: headword)
        return values
    }
    /// Cache supplies record numbers only as an index hint. Definitions are
    /// re-read from the SHA-verified MDX and scoped to the requested subentry.
    func lookupSubentry(_ headword: String, recordHints: [Int]) async throws -> [DictionarySense] {
        try initialize(); try Task.checkCancellation()
        let values = try parseRecords(recordHints, headword: headword, subentryOnly: true)
        guard !values.isEmpty else { throw MDXDictionaryError.invalidEntry("内部词条链接没有可验证内容") }
        remember(values, headword: headword); return values
    }
    private func parseRecords(_ numbers: [Int], headword: String, subentryOnly: Bool) throws -> [DictionarySense] {
        var values: [DictionarySense] = [], seen = Set<String>()
        for number in numbers {
                for (target, html) in try records(number, path: []) {
                    try Task.checkCancellation()
                    for var sense in try MDXEntryParser.parse(html, requested: headword, recordID: target, subentryOnly: subentryOnly) where seen.insert(sense.id).inserted {
                        let selfKeys = Set([Self.foldedKey(headword), Self.foldedKey(sense.lexicalHeadword ?? headword)])
                        var references = (sense.seeAlso ?? []).filter { !selfKeys.contains(Self.foldedKey($0)) }
                        var referenceIDs = Set(references.map(Self.foldedKey))
                        if let links = sense.supplementLinks, !links.isEmpty {
                            var notes = sense.usageNotes ?? []
                            var noteIDs = Set(notes.map(\.id))
                            var warnings: [String] = []
                            for link in links {
                                try Task.checkCancellation()
                                do {
                                    let targets = index[link] ?? (folded[Self.foldedKey(link)] ?? []).flatMap { index[$0] ?? [] }
                                    guard !targets.isEmpty else { throw MDXDictionaryError.invalidEntry("补充用法页未收录") }
                                    for number in targets {
                                        for (noteRecord, noteHTML) in try records(number, path: []) {
                                            let supplement = try MDXEntryParser.supplement(noteHTML, recordID: noteRecord)
                                            notes.append(contentsOf: supplement.notes.filter { noteIDs.insert($0.id).inserted })
                                            references.append(contentsOf: supplement.references.filter {
                                                let key = Self.foldedKey($0)
                                                return !selfKeys.contains(key) && referenceIDs.insert(key).inserted
                                            })
                                        }
                                    }
                                } catch is CancellationError { throw CancellationError() }
                                catch { warnings.append(error.localizedDescription) }
                            }
                            sense.usageNotes = notes.isEmpty ? nil : notes
                            sense.sourceWarnings = warnings.isEmpty ? nil : warnings
                        }
                        sense.seeAlso = references.isEmpty ? nil : references
                        values.append(sense)
                    }
                }
        }
        try Task.checkCancellation(); return values
    }
    private func remember(_ values: [DictionarySense], headword: String) {
        cache[headword] = values; touch(headword)
        while recent.count > 128 { let oldest = recent.removeFirst(); cache.removeValue(forKey: oldest) }
    }
    private func touch(_ key: String) { recent.removeAll { $0 == key }; recent.append(key) }
    private func records(_ number: Int, path: Set<Int>) throws -> [(String, String)] {
        try Task.checkCancellation()
        guard let reader, path.count < 16, !path.contains(number) else { throw MDXDictionaryError.invalidEntry("循环或过深的内部链接") }
        var bytes: UnsafeMutablePointer<UInt8>?, count = 0
        var error = [CChar](repeating: 0, count: 512)
        guard ld_mdx_record(reader, number, &bytes, &count, &error, 512) != 0, let bytes else { throw MDXDictionaryError.invalidEntry(String(cString: error)) }
        defer { ld_mdx_free(bytes) }
        guard let text = String(data: Data(bytes: bytes, count: count), encoding: .utf8) else { throw MDXDictionaryError.invalidEntry("无效 UTF-8 正文") }
        let html = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0\r\n"))
        if html.hasPrefix("@@@LINK=") {
            let target = String(html.dropFirst(8))
            guard let destinations = index[target], !destinations.isEmpty else { throw MDXDictionaryError.invalidEntry("内部链接目标缺失") }
            return try destinations.flatMap { try records($0, path: path.union([number])) }
        }
        guard html.contains("<") else { throw MDXDictionaryError.invalidEntry("预期 HTML 词条") }
        return [(String(number), html)]
    }
}

/// DOM traversal uses the system libxml2 HTML parser. Only source classes are
/// interpreted; scripts, remote CSS, audio/image references are never executed.
enum MDXEntryParser {
    private struct Node {
        let pointer: UnsafeMutableRawPointer
        var text: String {
            guard let value = ld_html_text(pointer) else { return "" }
            defer { ld_html_free(value) }
            return String(cString: value).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        var headword: String? {
            guard let value = ld_html_headword(pointer) else { return nil }
            defer { ld_html_free(value) }
            return String(cString: value).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        func attribute(_ key: String) -> String {
            guard let value = key.withCString({ ld_html_attribute(pointer, $0) }) else { return "" }
            defer { ld_html_free(value) }; return String(cString: value)
        }
        func has(_ name: String) -> Bool { attribute("class").split(separator: " ").contains(Substring(name)) }
        var children: [Node] {
            var values: [Node] = [], next = ld_html_child(pointer)
            while let child = next { values.append(Node(pointer: child)); next = ld_html_next(child) }
            return values
        }
        func descendants(_ name: String) -> [Node] {
            var values: [Node] = [], pending = children.reversed().map { $0 }
            while let node = pending.popLast() {
                if node.has(name) { values.append(node) }
                pending.append(contentsOf: node.children.reversed())
            }
            return values
        }
        func ancestor(_ classes: Set<String>) -> Node? {
            var next = ld_html_parent(pointer)
            while let parent = next {
                let node = Node(pointer: parent)
                if classes.contains(where: node.has) { return node }
                next = ld_html_parent(parent)
            }
            return nil
        }
        var entryTargets: [String] {
            var pending = [self], values: [String] = []
            while let node = pending.popLast() {
                let href = node.attribute("href")
                if href.hasPrefix("entry://") {
                    let raw = String(href.dropFirst(8)).components(separatedBy: "#")[0]
                    if let decoded = raw.removingPercentEncoding, !decoded.isEmpty { values.append(decoded) }
                }
                pending.append(contentsOf: node.children.reversed())
            }
            return values
        }
        var referenceLabel: String {
            var child = self, next = ld_html_parent(pointer)
            while let pointer = next {
                let parent = Node(pointer: pointer)
                let preceding = parent.children.prefix { $0.pointer != child.pointer }
                if let label = preceding.last(where: { $0.has("t-xrlabel") }) { return label.text }
                if parent.has("entry") { break }
                child = parent; next = ld_html_parent(pointer)
            }
            return ""
        }
        func notePairs(prefix: String, label: String) -> [DictionaryTextNote] {
            var pending = children.reversed().map { $0 }, values: [DictionaryTextNote] = []
            while let node = pending.popLast() {
                if node.has("t-trans-g") || node.has("t-x") {
                    let en = node.descendants("t-eng").map(\.text).joined(separator: " ")
                    let zh = node.descendants("t-chn").map(\.text).joined(separator: " ")
                    if !en.isEmpty || !zh.isEmpty { values.append(DictionaryTextNote(id: prefix + "|" + fingerprint(en + "|" + zh), label: node.has("t-x") ? "例句" : label, english: en, chinese: zh)) }
                } else { pending.append(contentsOf: node.children.reversed()) }
            }
            return values
        }
    }
    private static func plainHeadword(_ value: String) -> String {
        value.replacingOccurrences(of: "ˌ", with: "").replacingOccurrences(of: "ˈ", with: "").replacingOccurrences(of: "↔", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    static func supplement(_ html: String, recordID: String) throws -> (notes: [DictionaryTextNote], references: [String]) {
        let data = Array(html.utf8)
        guard let document = data.withUnsafeBytes({ ld_html_parse($0.baseAddress?.assumingMemoryBound(to: CChar.self), $0.count) }) else { throw MDXDictionaryError.invalidEntry("补充用法页无法解析") }
        defer { ld_html_close(document) }
        guard let root = ld_html_root(document) else { throw MDXDictionaryError.invalidEntry("补充用法页结构缺失") }
        let node = Node(pointer: root), groups = node.descendants("t-unbox")
        guard !groups.isEmpty else { throw MDXDictionaryError.invalidEntry("补充用法页缺少原始内容结构") }
        let prefix = "mdx-note|" + BundledMDXDictionaryProvider.sourceSHA + "|" + recordID
        let notes = groups.flatMap { $0.notePairs(prefix: prefix, label: "用法补充") }
        let references = groups.filter { $0.attribute("type") == "wordfinder" }
            .flatMap { $0.descendants("t-ndv").flatMap(\.entryTargets) }
        guard !notes.isEmpty || !references.isEmpty else { throw MDXDictionaryError.invalidEntry("补充用法页没有可展示的内容") }
        return (notes, references)
    }
    static func parse(_ html: String, requested: String, recordID: String, subentryOnly: Bool = false) throws -> [DictionarySense] {
        let data = Array(html.utf8)
        guard let document = data.withUnsafeBytes({ raw in ld_html_parse(raw.baseAddress?.assumingMemoryBound(to: CChar.self), raw.count) }) else { throw MDXDictionaryError.invalidEntry("HTML 无法解析") }
        defer { ld_html_close(document) }
        guard let pointer = ld_html_root(document) else { throw MDXDictionaryError.invalidEntry("HTML 根节点缺失") }
        let root = Node(pointer: pointer)
        let entries = root.has("entry") ? [root] : root.descendants("entry")
        guard !entries.isEmpty else { throw MDXDictionaryError.invalidEntry("词条结构缺失") }
        var senses: [DictionarySense] = [], requiresSubentry = false, matchedEntry = false
        for entry in entries {
            let head: String
            if let node = entry.descendants("t-h").first {
                guard let value = node.headword, !value.isEmpty else { throw MDXDictionaryError.invalidEntry("词头内容无法读取") }
                head = value
            } else { head = requested }
            let part = entry.descendants("t-pos").first?.text
            let phonetics = entry.descendants("t-pron-gs").first?.descendants("t-pron-g-blk").compactMap { block -> String? in
                guard let ipa = block.descendants("t-phon").first?.text, !ipa.isEmpty else { return nil }
                let accent = block.descendants("t-brelabel").first?.text ?? block.descendants("t-namelabel").first?.text ?? ""
                return accent + " /" + ipa + "/"
            } ?? []
            let forms = entry.descendants("t-vp").map(\.text)
            let originalDefinitions = entry.descendants("t-def")
            var definitions = originalDefinitions
            // Phrase aliases can point at their parent page. Isolate matching
            // phrase/idiom subtrees instead of assigning all parent senses to it.
            if plainHeadword(head).lowercased() != requested.lowercased() && (requested.contains(" ") || subentryOnly) {
                requiresSubentry = true
                let phraseGroups = entry.descendants("t-pv-g") + entry.descendants("t-idm-g") + entry.descendants("t-id-g")
                let selected = phraseGroups.filter { group in
                    (group.descendants("t-pv") + group.descendants("t-idm") + group.descendants("t-id")).contains { plainHeadword($0.text).lowercased() == requested.lowercased() }
                }
                definitions = selected.flatMap { $0.descendants("t-def") }
                if definitions.isEmpty { continue }
                matchedEntry = true
            } else { matchedEntry = true }
            for definition in definitions {
                guard let ordinal = originalDefinitions.firstIndex(where: { $0.pointer == definition.pointer }) else { throw MDXDictionaryError.invalidEntry("原始义项位置缺失") }
                let scope = definition.ancestor(["t-sn-g", "t-licontent", "t-sn-blk-nolist", "t-sn-blk", "t-pv-g", "t-idm-g", "t-id-g"]) ?? definition
                let chinese = definition.descendants("t-chn").map(\.text).joined(separator: "；")
                let english = definition.descendants("t-eng").map(\.text).joined(separator: " ")
                let examples = scope.descendants("t-x").filter { $0.ancestor(["t-un", "t-unbox"]) == nil }.map { node in
                    (node.descendants("t-eng").map(\.text).joined(separator: " "), node.descendants("t-chn").map(\.text).joined(separator: " "),
                     node.ancestor(["t-x-g-blk"])?.descendants("t-cf").map(\.text).joined(separator: " · ") ?? "")
                }.filter { !$0.0.isEmpty }
                let phrase = definition.ancestor(["t-pv-g", "t-idm-g", "t-id-g"])
                let phraseHead = phrase.flatMap { ($0.descendants("t-pv") + $0.descendants("t-idm") + $0.descendants("t-id")).first?.text }
                let localLabels = ["t-label", "t-gram", "t-reg", "t-geo", "t-use"].flatMap { scope.descendants($0).map(\.text) }
                let groupLabels = phrase?.children.first(where: { $0.has("t-top-g") }).map { top in
                    ["t-label", "t-gram", "t-reg", "t-geo", "t-use"].flatMap { top.descendants($0).map(\.text) }
                } ?? []
                let labels = Array(NSOrderedSet(array: localLabels + groupLabels)) as? [String] ?? []
                let pairedCollocations = Set(examples.flatMap { $0.2.components(separatedBy: " · ") }.filter { !$0.isEmpty })
                let collocations = scope.descendants("t-cf").map(\.text).filter { !pairedCollocations.contains($0) }
                let sourceID = entry.attribute("data-hkoup-entry")
                var sense = DictionarySense(id: "mdx|" + BundledMDXDictionaryProvider.sourceSHA + "|" + recordID + "|" + sourceID + "|" + String(ordinal),
                    en: english, zh: chinese, line: BundledMDXDictionaryProvider.sourceName,
                    partOfSpeech: phrase != nil ? "phrase" : part, ipa: phrase != nil || phonetics.isEmpty ? nil : phonetics.joined(separator: " · "),
                    examples: examples.map(\.0), forms: forms.isEmpty ? nil : Array(NSOrderedSet(array: forms)) as? [String],
                    sources: [BundledMDXDictionaryProvider.sourceName], exampleTranslations: examples.map(\.1),
                    usageLabels: labels.isEmpty ? nil : labels, relatedPhrases: collocations.isEmpty ? nil : collocations,
                    sourceRevision: BundledMDXDictionaryProvider.sourceVersion, originKind: "mdx")
                sense.lexicalHeadword = phraseHead.map(plainHeadword) ?? head
                sense.sectionKind = phrase?.has("t-pv-g") == true ? "phrasalVerb" : phrase != nil ? "idiom" : nil
                sense.policyVersion = BilingualMeaningPolicy.version
                sense.entryGroupID = recordID + "|" + sourceID
                sense.exampleCollocations = examples.map(\.2)
                var noteGroups = scope.descendants("t-un")
                if ordinal == 0 {
                    noteGroups += entry.descendants("t-un").filter { $0.ancestor(["t-sn-g", "t-licontent"]) == nil }
                    noteGroups += entry.descendants("t-unbox")
                }
                var noteIDs = Set<String>()
                let notes = noteGroups.flatMap { $0.notePairs(prefix: sense.id, label: $0.has("t-unbox") ? "用法补充" : "用法提示") }.filter { noteIDs.insert($0.id).inserted }
                sense.usageNotes = notes.isEmpty ? nil : notes
                var supplementNodes = scope.descendants("t-unboxlink")
                if ordinal == 0 { supplementNodes += entry.descendants("t-unboxlink").filter { $0.ancestor(["t-sn-g", "t-licontent", "t-pv-g", "t-idm-g"]) == nil } }
                let links = Array(NSOrderedSet(array: supplementNodes.flatMap(\.entryTargets))) as? [String] ?? []
                guard links.count <= 100 else { throw MDXDictionaryError.invalidEntry("补充用法链接数量异常") }
                sense.supplementLinks = links.isEmpty ? nil : links
                var referenceNodes = scope.descendants("t-xr-g")
                if ordinal == 0 { referenceNodes += entry.descendants("t-xr-g").filter { $0.ancestor(["t-sn-g", "t-licontent", "t-pv-g", "t-idm-g"]) == nil } }
                var synonyms: [String] = [], antonyms: [String] = [], references: [String] = []
                for reference in referenceNodes {
                    let labels = reference.referenceLabel
                    let heads = reference.descendants("t-xh").flatMap(\.entryTargets)
                    if labels.split(whereSeparator: \.isWhitespace).contains("SYN") { synonyms += heads }
                    else if labels.split(whereSeparator: \.isWhitespace).contains("OPP") { antonyms += heads }
                    else { references += heads }
                }
                sense.synonyms = synonyms.isEmpty ? nil : Array(NSOrderedSet(array: synonyms)) as? [String]
                sense.antonyms = antonyms.isEmpty ? nil : Array(NSOrderedSet(array: antonyms)) as? [String]
                sense.seeAlso = references.isEmpty ? nil : Array(NSOrderedSet(array: references)) as? [String]
                senses.append(sense)
            }
            // Some real MDX records are index/help pages. They are successful
            // records with no Chinese senses, distinct from parser/resource errors.
        }
        if requiresSubentry && !matchedEntry { throw MDXDictionaryError.invalidEntry("该短语链接未能对应原词条，请重试完整词头") }
        return senses
    }
}
