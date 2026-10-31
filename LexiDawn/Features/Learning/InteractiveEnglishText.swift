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
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false; view.isSelectable = false; view.delegate = context.coordinator
        view.alwaysBounceVertical = true; view.adjustsFontForContentSizeCategory = true
        view.isScrollEnabled = scrollable
        view.accessibilityIdentifier = "reader-body"; view.isAccessibilityElement = false
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.cancelsTouchesInView = false; view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard !scrollable, let width = proposal.width else { return nil }
        return CGSize(width: width, height: uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
    func updateUIView(_ view: UITextView, context: Context) {
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
        if !coordinator.restored {
            DispatchQueue.main.async { [weak view, weak coordinator] in
                guard let view, let coordinator, view.bounds.height > 0, !coordinator.restored else { return }
                view.layoutManager.ensureLayout(for: view.textContainer)
                let length = (text as NSString).length
                var offset = min(max(0, restore.offset), max(0, length - 1))
                if restore.contentChanged { offset = ReadingAnchors.offset(for: restore.anchor, in: text) ?? 0 }
                if offset > 0 {
                    let glyph = view.layoutManager.glyphIndexForCharacter(at: offset)
                    let rect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
                    view.setContentOffset(CGPoint(x: 0, y: max(0, min(rect.minY, view.contentSize.height - view.bounds.height))), animated: false)
                }
                coordinator.restored = true; coordinator.updateAccessibility()
            }
        }
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InteractiveEnglishText
        weak var view: UITextView?
        var tokens: [EnglishToken] = []
        var renderKey = ""
        var renderedText = ""
        var restored = false
        var lastAccessibilityUpdate = Date.distantPast
        init(_ parent: InteractiveEnglishText) { self.parent = parent }
        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view, restored else { return }
            let local = recognizer.location(in: view)
            let point = CGPoint(x: local.x - view.textContainerInset.left, y: local.y - view.textContainerInset.top)
            let manager = view.layoutManager
            let glyph = manager.glyphIndex(for: point, in: view.textContainer)
            guard glyph < manager.numberOfGlyphs else { return }
            let rect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
            guard rect.contains(point), let token = EnglishTokenizer.token(at: manager.characterIndexForGlyph(at: glyph), tokens: tokens) else { return }
            parent.onWord(token)
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
            guard let view else { return }
            lastAccessibilityUpdate = Date()
            let visible = CGRect(origin: CGPoint(x: 0, y: max(0, view.contentOffset.y - view.textContainerInset.top)), size: view.bounds.size)
            let glyphs = view.layoutManager.glyphRange(forBoundingRect: visible, in: view.textContainer)
            let chars = view.layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            var elements: [UIAccessibilityElement] = []
            for token in tokens where NSIntersectionRange(token.range, chars).length > 0 {
                let element = WordAccessibilityElement(accessibilityContainer: view)
                element.accessibilityLabel = token.surface; element.accessibilityTraits = .button
                element.accessibilityIdentifier = "word-\(token.surface)"
                element.accessibilityHint = "查看词义；根据偏好加入生词本"
                var rect = view.layoutManager.boundingRect(forGlyphRange: view.layoutManager.glyphRange(forCharacterRange: token.range, actualCharacterRange: nil), in: view.textContainer)
                rect.origin.x += view.textContainerInset.left; rect.origin.y += view.textContainerInset.top
                element.accessibilityFrameInContainerSpace = rect
                element.action = { [weak self] in self?.parent.onWord(token) }
                elements.append(element)
            }
            view.accessibilityElements = elements
        }
    }
}
private final class WordAccessibilityElement: UIAccessibilityElement {
    var action: (() -> Void)?
    override func accessibilityActivate() -> Bool { action?(); return action != nil }
}
