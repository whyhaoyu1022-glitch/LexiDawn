import SwiftUI
import UIKit

/// TextKit lays out one native, selectable-for-accessibility document. Tokens are parsed once per body version.
struct InteractiveEnglishText: UIViewRepresentable {
    let text: String
    let fontSize: Double
    let lineSpacing: Double
    let theme: String
    let restore: ReaderPosition
    let onPosition: (ReaderPosition) -> Void
    let onWord: (EnglishToken) -> Void
    var scrollable: Bool = true
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> EnglishTextContainer {
        let container = EnglishTextContainer()
        let view = container.textView
        view.isEditable = false; view.isSelectable = false; view.delegate = context.coordinator
        view.alwaysBounceVertical = true; view.adjustsFontForContentSizeCategory = true
        view.isScrollEnabled = scrollable
        container.accessibilityIdentifier = "reader-body"
        container.isAccessibilityElement = false; container.accessibilityContainerType = .semanticGroup
        view.accessibilityElementsHidden = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.cancelsTouchesInView = false; view.addGestureRecognizer(tap)
        context.coordinator.view = view; context.coordinator.accessibilityContainer = container
        container.onLayout = { [weak coordinator = context.coordinator] in coordinator?.restorePosition(); coordinator?.updateAccessibility() }
        return container
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: EnglishTextContainer, context: Context) -> CGSize? {
        guard !scrollable, let width = proposal.width else { return nil }
        return CGSize(width: width, height: uiView.textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
    func updateUIView(_ container: EnglishTextContainer, context: Context) {
        let view = container.textView
        let coordinator = context.coordinator; coordinator.parent = self
        let key = "\(fontSize)|\(lineSpacing)|\(theme)|\(view.traitCollection.preferredContentSizeCategory.rawValue)|\(view.traitCollection.userInterfaceStyle.rawValue)"
        let width = max(20, (view.bounds.width - 720) / 2)
        view.textContainerInset = UIEdgeInsets(top: 20, left: width, bottom: 40, right: width)
        if key != coordinator.renderKey || text != coordinator.renderedText {
            let oldOffset = view.contentOffset
            if text != coordinator.renderedText { coordinator.tokens = EnglishTokenizer.tokens(in: text); coordinator.renderedText = text }
            coordinator.renderKey = key
            let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: "Georgia", size: CGFloat(fontSize)) ?? .systemFont(ofSize: CGFloat(fontSize)))
            let paragraph = NSMutableParagraphStyle(); paragraph.lineHeightMultiple = CGFloat(lineSpacing); paragraph.paragraphSpacing = 10
            let foreground: UIColor = theme == "dark" ? .init(white: 0.9, alpha: 1) : theme == "paper" ? .init(red: 0.19, green: 0.16, blue: 0.12, alpha: 1) : theme == "light" ? .black : .label
            view.backgroundColor = theme == "dark" ? .init(white: 0.08, alpha: 1) : theme == "paper" ? .init(red: 0.97, green: 0.94, blue: 0.87, alpha: 1) : theme == "light" ? .white : .systemBackground
            view.attributedText = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: foreground])
            view.setContentOffset(oldOffset, animated: false)
        }
        DispatchQueue.main.async { [weak coordinator] in coordinator?.restorePosition(); coordinator?.updateAccessibility() }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InteractiveEnglishText
        weak var view: UITextView?
        weak var accessibilityContainer: EnglishTextContainer?
        private var restoring = false
        var tokens: [EnglishToken] = []
        var renderKey = ""
        var renderedText = ""
        var restored = false
        var lastAccessibilityUpdate = Date.distantPast
        init(_ parent: InteractiveEnglishText) { self.parent = parent }
        func restorePosition() {
            guard !restored, !restoring, let view, view.bounds.height > 0, view.bounds.width > 0, !parent.text.isEmpty else { return }
            restoring = true
            defer { restoring = false }
            view.layoutManager.ensureLayout(for: view.textContainer)
            let length = (parent.text as NSString).length
            var offset = min(max(0, parent.restore.offset), max(0, length - 1))
            if parent.restore.contentChanged { offset = ReadingAnchors.offset(for: parent.restore.anchor, in: parent.text) ?? 0 }
            if offset > 0 {
                let glyph = view.layoutManager.glyphIndexForCharacter(at: offset)
                let rect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
                view.setContentOffset(CGPoint(x: 0, y: max(0, min(rect.minY, view.contentSize.height - view.bounds.height))), animated: false)
            }
            restored = true
        }
        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view, let token = token(at: recognizer.location(in: view)) else { return }
            parent.onWord(token)
        }
        func token(at local: CGPoint) -> EnglishToken? {
            guard let view, restored else { return nil }
            let point = CGPoint(x: local.x - view.textContainerInset.left, y: local.y - view.textContainerInset.top)
            let manager = view.layoutManager
            let glyph = manager.glyphIndex(for: point, in: view.textContainer)
            guard glyph < manager.numberOfGlyphs else { return nil }
            let rect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
            guard rect.contains(point) else { return nil }
            return EnglishTokenizer.token(at: manager.characterIndexForGlyph(at: glyph), tokens: tokens)
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard restored, let view else { return }
            let textLength = (parent.text as NSString).length
            guard textLength > 0, view.contentSize.height > 0 else { return }
            let point = CGPoint(x: 1, y: max(0, view.contentOffset.y))
            let offset = min(textLength - 1, view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil))
            let range = (parent.text as NSString).paragraphRange(for: NSRange(location: offset, length: 0))
            let percent = min(1, max(0, (view.contentOffset.y + view.bounds.height - view.textContainerInset.bottom) / view.contentSize.height))
            parent.onPosition(ReaderPosition(percent: percent, anchor: fingerprint((parent.text as NSString).substring(with: range)), offset: offset))
            if Date().timeIntervalSince(lastAccessibilityUpdate) > 0.3 { updateAccessibility() }
        }
        func updateAccessibility() {
            guard restored, let view, let accessibilityContainer else { return }
            lastAccessibilityUpdate = Date()
            let visible = CGRect(origin: CGPoint(x: 0, y: max(0, view.contentOffset.y - view.textContainerInset.top)), size: view.bounds.size)
            let glyphs = view.layoutManager.glyphRange(forBoundingRect: visible, in: view.textContainer)
            let chars = view.layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            var elements: [UIAccessibilityElement] = []
            for token in tokens where NSIntersectionRange(token.range, chars).length > 0 {
                let element = WordAccessibilityElement(accessibilityContainer: accessibilityContainer)
                element.accessibilityLabel = token.surface; element.accessibilityTraits = .button
                element.accessibilityIdentifier = "word-\(token.surface)"
                element.accessibilityValue = "\(token.range.location)"
                element.accessibilityHint = "查看词义；根据偏好加入生词本"
                var rect = view.layoutManager.boundingRect(forGlyphRange: view.layoutManager.glyphRange(forCharacterRange: token.range, actualCharacterRange: nil), in: view.textContainer)
                rect.origin.x += view.textContainerInset.left; rect.origin.y += view.textContainerInset.top
                element.accessibilityFrameInContainerSpace = view.convert(rect, to: accessibilityContainer)
                element.action = { [weak self] in self?.parent.onWord(token) }
                elements.append(element)
            }
            accessibilityContainer.accessibilityElements = elements
        }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateAccessibility() }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { updateAccessibility() } }
    }
}
private final class WordAccessibilityElement: UIAccessibilityElement {
    var action: (() -> Void)?
    override func accessibilityActivate() -> Bool { action?(); return action != nil }
}

/// UIView owns the word-level AX container. UITextView's built-in paragraph AX implementation
/// otherwise ignores a custom accessibilityElements array on the text view itself.
final class EnglishTextContainer: UIView {
    let textView = UITextView(usingTextLayoutManager: false)
    var onLayout: (() -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addSubview(textView) }
    required init?(coder: NSCoder) { super.init(coder: coder); addSubview(textView) }
    override func layoutSubviews() { super.layoutSubviews(); textView.frame = bounds; onLayout?() }
}

/// Short dictionary passages use native attributed links so List row accessibility does not
/// flatten a UIKit container. Tokenisation and lookup actions are shared with the long reader.
struct InlineEnglishText: View {
    let text: String
    let onWord: (EnglishToken) -> Void
    private var tokens: [EnglishToken] { EnglishTokenizer.tokens(in: text) }
    private var linkedText: AttributedString {
        var value = AttributedString(text)
        for token in tokens {
            guard let range = Range(token.range, in: text),
                  let start = AttributedString.Index(range.lowerBound, within: value),
                  let end = AttributedString.Index(range.upperBound, within: value) else { continue }
            value[start..<end].link = URL(string: "lexidawn-word://token/\(token.range.location)")
        }
        return value
    }
    var body: some View {
        Text(linkedText).font(.system(.body, design: .serif)).lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "lexidawn-word", let offset = Int(url.lastPathComponent),
                      let token = EnglishTokenizer.token(at: offset, tokens: tokens) else { return .discarded }
                onWord(token); return .handled
            })
    }
}
