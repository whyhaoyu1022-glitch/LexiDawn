import Foundation

/// Whitespace-only layout with monotone UTF-16 source mapping. Stored progress remains in raw text.
struct ReaderTextProjection {
    let text: String
    private let displayToRaw: [Int]
    init(raw: String, document: ArticleDocument? = nil, sourceID: String? = nil) {
        var document = document ?? ArticleDocumentNormalizer.plainText(raw)
        guard ArticleDocumentNormalizer.preservesOriginal(raw, document: document) else {
            text = raw; displayToRaw = Array(0...(raw as NSString).length); return
        }
        let ns = raw as NSString
        let unwanted = sourceID == "dw" ? document.blocks.filter { block in
            let value = block.text.lowercased()
            return value.hasPrefix("to view this video please enable javascript") && value.contains("html5 video")
        } : []
        let hidden = unwanted.map { ns.range(of: $0.text) }.filter { $0.location != NSNotFound }
        if !hidden.isEmpty { document = ArticleDocument(blocks: document.blocks.filter { !unwanted.contains($0) }) }
        text = document.text
        let original = Array(raw.utf16), displayed = Array(text.utf16)
        var cursor = 0, offsets: [Int] = []
        func whitespace(_ unit: UInt16) -> Bool { UnicodeScalar(unit).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false }
        for unit in displayed {
            if whitespace(unit) { offsets.append(min(cursor, original.count)); continue }
            while cursor < original.count && (whitespace(original[cursor]) || hidden.contains(where: { NSLocationInRange(cursor, $0) })) { cursor += 1 }
            offsets.append(min(cursor, original.count)); cursor += 1
        }
        offsets.append(original.count); displayToRaw = offsets
    }
    func rawOffset(_ display: Int) -> Int { displayToRaw[min(max(0, display), displayToRaw.count - 1)] }
    func displayOffset(_ raw: Int) -> Int {
        var low = 0, high = displayToRaw.count
        while low < high { let middle = (low + high) / 2; if displayToRaw[middle] < raw { low = middle + 1 } else { high = middle } }
        return min(low, max(0, displayToRaw.count - 2))
    }
    func rawRange(_ range: NSRange) -> NSRange {
        let start = rawOffset(range.location), end = rawOffset(NSMaxRange(range))
        return NSRange(location: start, length: max(0, end - start))
    }
}
