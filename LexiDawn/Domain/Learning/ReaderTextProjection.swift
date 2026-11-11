import Foundation

/// Versioned display document with monotone UTF-16 mapping to unchanged stored text.
struct ReaderTextProjection {
    static let version = "reader-blocks-2"
    let text: String
    let document: ArticleDocument?
    private let displayToRaw: [Int]

    init(raw: String, document: ArticleDocument? = nil, sourceID: String? = nil) {
        let document = document ?? ArticleDocumentNormalizer.plainText(raw)
        let original = Array(raw.utf16)
        guard ArticleDocumentNormalizer.preservesOriginal(raw, document: document) else {
            text = raw; self.document = nil; displayToRaw = Array(0...original.count); return
        }
        var blocks: [ArticleDocument.Block] = []
        var cursor = 0
        var offsets: [Int] = []
        func whitespace(_ unit: UInt16) -> Bool {
            UnicodeScalar(unit).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
        }
        for block in document.blocks {
            let visible = !Self.isLegacyPlayerBlock(block, sourceID: sourceID)
            if visible && !blocks.isEmpty { offsets.append(cursor); offsets.append(cursor) }
            for unit in block.text.utf16 {
                if whitespace(unit) {
                    if visible { offsets.append(cursor) }
                    continue
                }
                while cursor < original.count && whitespace(original[cursor]) { cursor += 1 }
                guard cursor < original.count, original[cursor] == unit else {
                    // An offset projection must preserve the original code units.
                    text = raw; self.document = nil; displayToRaw = Array(0...original.count); return
                }
                if visible { offsets.append(cursor) }
                cursor += 1
            }
            if visible { blocks.append(block) }
        }
        let displayed = ArticleDocument(blocks: blocks)
        self.document = displayed
        text = displayed.text
        offsets.append(original.count)
        displayToRaw = offsets
    }

    private static func isLegacyPlayerBlock(_ block: ArticleDocument.Block, sourceID: String?) -> Bool {
        guard sourceID == "dw", block.kind == .paragraph else { return false }
        let expected = "to view this video please enable javascript, and consider upgrading to a web browser that supports html5 video"
        let actual = block.text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return actual == expected || actual == expected + "."
    }

    func rawOffset(_ display: Int) -> Int {
        displayToRaw[min(max(0, display), displayToRaw.count - 1)]
    }

    func displayOffset(_ raw: Int) -> Int {
        var low = 0, high = displayToRaw.count
        while low < high {
            let middle = (low + high) / 2
            if displayToRaw[middle] < raw { low = middle + 1 } else { high = middle }
        }
        return min(low, max(0, displayToRaw.count - 2))
    }

    func rawRange(_ range: NSRange) -> NSRange {
        let start = rawOffset(range.location)
        guard range.length > 0 else { return NSRange(location: start, length: 0) }
        let end = min(displayToRaw.last ?? start, rawOffset(NSMaxRange(range) - 1) + 1)
        return NSRange(location: start, length: max(0, end - start))
    }
}
