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
    var document: ArticleDocument? = nil
    var onWordAnchor: ((CGPoint, CGSize) -> Void)? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var sourceID: String? = nil
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
        container.backgroundColor = view.backgroundColor
        let coordinator = context.coordinator; coordinator.parent = self
        let key = "\(fontSize)|\(lineSpacing)|\(theme)|\(view.traitCollection.preferredContentSizeCategory.rawValue)|\(view.traitCollection.userInterfaceStyle.rawValue)"
        let width = max(20, (view.bounds.width - 720) / 2)
        container.configureHeading(title: title, subtitle: subtitle, theme: theme)
        view.textContainerInset = UIEdgeInsets(top: container.headingHeight, left: width, bottom: 40, right: width)
        if key != coordinator.renderKey || text != coordinator.renderedText {
            let oldOffset = view.contentOffset
            if text != coordinator.renderedText {
                coordinator.projection = ReaderTextProjection(raw: text, document: document, sourceID: sourceID)
                coordinator.tokens = EnglishTokenizer.tokens(in: coordinator.projection.tokenizationText); coordinator.renderedText = text
            }
            coordinator.restored = false
            coordinator.renderKey = key
            let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: "Georgia", size: CGFloat(fontSize)) ?? .systemFont(ofSize: CGFloat(fontSize)))
            let paragraph = NSMutableParagraphStyle(); paragraph.lineHeightMultiple = CGFloat(lineSpacing); paragraph.paragraphSpacing = 10
            let foreground: UIColor = theme == "dark" ? .init(white: 0.9, alpha: 1) : theme == "paper" ? .init(red: 0.19, green: 0.16, blue: 0.12, alpha: 1) : theme == "light" ? .black : .label
            view.backgroundColor = theme == "dark" ? .init(white: 0.08, alpha: 1) : theme == "paper" ? .init(red: 0.97, green: 0.94, blue: 0.87, alpha: 1) : theme == "light" ? .white : .systemBackground
            let attributed = NSMutableAttributedString(string: coordinator.projection.text, attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: foreground])
            if let document = coordinator.projection.document {
                let ns = attributed.string as NSString
                var cursor = 0
                for block in document.blocks {
                    let range = ns.range(of: block.text, range: NSRange(location: cursor, length: ns.length - cursor))
                    guard range.location != NSNotFound else { continue }
                    if block.kind == .heading {
                        attributed.addAttribute(.font, value: UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: CGFloat(fontSize + 3), weight: .bold)), range: range)
                    } else if block.kind == .caption {
                        attributed.addAttribute(.font, value: UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: CGFloat(max(12, fontSize - 3)))), range: range)
                    } else if block.kind == .quotation || block.kind == .listItem {
                        let indented = NSMutableParagraphStyle(); indented.setParagraphStyle(paragraph)
                        indented.headIndent = 16; indented.firstLineHeadIndent = 16
                        if block.kind == .listItem { indented.headIndent = 28; indented.firstLineHeadIndent = 14 }
                        attributed.addAttribute(.paragraphStyle, value: indented, range: ns.paragraphRange(for: range))
                    }
                    cursor = NSMaxRange(range)
                }
            }
            view.attributedText = attributed
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
        var projection = ReaderTextProjection(raw: "")
        var restored = false
        var lastAccessibilityUpdate = Date.distantPast
        var lastBounds: CGSize = .zero
        var rotationOffset: Int?
        private var wordElements: [Int: WordAccessibilityElement] = [:]
        init(_ parent: InteractiveEnglishText) { self.parent = parent; projection = ReaderTextProjection(raw: parent.text, document: parent.document, sourceID: parent.sourceID) }
        func restorePosition() {
            if let view, view.bounds.size != lastBounds, view.bounds.width > 0, view.bounds.height > 0 {
                if lastBounds != .zero, restored { rotationOffset = parent.restore.offset; restored = false }
                lastBounds = view.bounds.size
                let margin = max(18, (view.bounds.width - 720) / 2)
                accessibilityContainer?.configureHeading(title: parent.title, subtitle: parent.subtitle, theme: parent.theme)
                view.textContainerInset = UIEdgeInsets(top: accessibilityContainer?.headingHeight ?? 12, left: margin, bottom: 24, right: margin)
            }
            guard !restored, !restoring, let view, view.bounds.height > 0, view.bounds.width > 0, !projection.text.isEmpty else { return }
            restoring = true
            defer { restoring = false }
            view.layoutManager.ensureLayout(for: view.textContainer)
            let length = (parent.text as NSString).length
            var offset = min(max(0, rotationOffset ?? parent.restore.offset), max(0, length - 1))
            if parent.restore.contentChanged { offset = ReadingAnchors.offset(for: parent.restore.anchor, in: parent.text) ?? 0 }
            if offset > 0 {
                let glyph = view.layoutManager.glyphIndexForCharacter(at: projection.displayOffset(offset))
                let rect = view.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
                view.setContentOffset(CGPoint(x: 0, y: max(0, min(rect.minY + view.textContainerInset.top, view.contentSize.height - view.bounds.height))), animated: false)
            }
            rotationOffset = nil; restored = true
        }
        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view, let token = token(at: recognizer.location(in: view)) else { return }
            if let container = accessibilityContainer {
                parent.onWordAnchor?(view.convert(recognizer.location(in: view), to: container), container.bounds.size)
            }
            parent.onWord(EnglishToken(surface: token.surface, range: projection.rawRange(token.range), sentence: token.sentence))
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
            guard restored, let view, view.bounds.size == lastBounds else { return }
            let textLength = (parent.text as NSString).length
            guard textLength > 0, view.contentSize.height > 0 else { return }
            let point = CGPoint(x: 1, y: max(0, view.contentOffset.y - view.textContainerInset.top))
            let offset = min(textLength - 1, projection.rawOffset(view.layoutManager.characterIndex(for: point, in: view.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)))
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
            if let title = parent.title, view.contentOffset.y < accessibilityContainer.headingHeight {
                let heading = UIAccessibilityElement(accessibilityContainer: accessibilityContainer)
                heading.accessibilityLabel = title + ". " + (parent.subtitle ?? "")
                heading.accessibilityTraits = .header
                heading.accessibilityFrameInContainerSpace = view.convert(accessibilityContainer.headingLabel.frame, to: accessibilityContainer)
                elements.append(heading)
            }
            var retained: [Int: WordAccessibilityElement] = [:]
            for token in tokens where NSIntersectionRange(token.range, chars).length > 0 {
                let sourceOffset = projection.rawOffset(token.range.location)
                let element = wordElements[sourceOffset] ?? WordAccessibilityElement(accessibilityContainer: accessibilityContainer)
                retained[sourceOffset] = element
                element.accessibilityLabel = token.surface; element.accessibilityTraits = .button; element.accessibilityLanguage = "en-US"
                element.accessibilityIdentifier = "word-\(token.surface)"
                element.accessibilityValue = "\(projection.rawOffset(token.range.location))"
                element.accessibilityHint = "查看词义；根据偏好加入生词本"
                var rect = view.layoutManager.boundingRect(forGlyphRange: view.layoutManager.glyphRange(forCharacterRange: token.range, actualCharacterRange: nil), in: view.textContainer)
                rect.origin.x += view.textContainerInset.left; rect.origin.y += view.textContainerInset.top
                element.accessibilityFrameInContainerSpace = view.convert(rect, to: accessibilityContainer)
                element.action = { [weak self, weak element, weak accessibilityContainer] in
                    guard let self, let element, let accessibilityContainer else { return }
                    let rect = element.accessibilityFrameInContainerSpace
                    self.parent.onWordAnchor?(CGPoint(x: rect.midX, y: rect.midY), accessibilityContainer.bounds.size)
                    self.parent.onWord(EnglishToken(surface: token.surface, range: self.projection.rawRange(token.range), sentence: token.sentence))
                }
                elements.append(element)
            }
            wordElements = retained
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
    let headingLabel = UILabel()
    let subtitleLabel = UILabel()
    private(set) var headingHeight: CGFloat = 12
    func configureHeading(title: String?, subtitle: String?, theme: String) {
        guard let title else { headingLabel.isHidden = true; subtitleLabel.isHidden = true; headingHeight = 12; return }
        if headingLabel.superview == nil { textView.addSubview(headingLabel); textView.addSubview(subtitleLabel) }
        headingLabel.isHidden = false; subtitleLabel.isHidden = false
        headingLabel.numberOfLines = 0; subtitleLabel.numberOfLines = 0
        headingLabel.text = title; subtitleLabel.text = subtitle
        headingLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: UIFont(name: "Georgia-Bold", size: 26) ?? .boldSystemFont(ofSize: 26))
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        headingLabel.textColor = theme == "dark" ? .init(white: 0.92, alpha: 1) : theme == "paper" ? .init(red: 0.19, green: 0.16, blue: 0.12, alpha: 1) : .label
        subtitleLabel.textColor = theme == "dark" ? .lightGray : .secondaryLabel
        let margin = max(18, (bounds.width - 720) / 2), width = max(1, bounds.width - 2 * margin)
        let height = headingLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        headingLabel.frame = CGRect(x: margin, y: 12, width: width, height: height)
        let subHeight = subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        subtitleLabel.frame = CGRect(x: margin, y: height + 22, width: width, height: subHeight)
        headingHeight = height + subHeight + 46
    }
    override init(frame: CGRect) { super.init(frame: frame); addSubview(textView) }
    required init?(coder: NSCoder) { super.init(coder: coder); addSubview(textView) }
    override func layoutSubviews() { super.layoutSubviews(); textView.frame = bounds; onLayout?() }
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard textView.isScrollEnabled, textView.bounds.height > 0 else { return false }
        let sign: CGFloat
        switch direction {
        case .up, .left, .next: sign = 1
        case .down, .right, .previous: sign = -1
        default: return false
        }
        let limit = max(0, textView.contentSize.height - textView.bounds.height)
        let next = min(limit, max(0, textView.contentOffset.y + sign * textView.bounds.height * 0.8))
        guard abs(next - textView.contentOffset.y) > 1 else { return false }
        textView.setContentOffset(CGPoint(x: 0, y: next), animated: false); onLayout?()
        let percent = Int(min(1, max(0, (next + textView.bounds.height) / max(1, textView.contentSize.height))) * 100)
        UIAccessibility.post(notification: .pageScrolled, argument: "阅读进度 \(percent)%")
        return true
    }
}

/// Short dictionary passages use native attributed links so List row accessibility does not
/// flatten a UIKit container. Tokenisation and lookup actions are shared with the long reader.
struct InlineEnglishText: View {
    let text: String
    let onWord: (EnglishToken) -> Void
    var emphasized = false
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
        Text(linkedText).font(.system(.body, design: .serif).weight(emphasized ? .medium : .regular)).lineSpacing(4).tint(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "lexidawn-word", let offset = Int(url.lastPathComponent),
                      let token = EnglishTokenizer.token(at: offset, tokens: tokens) else { return .discarded }
                onWord(token); return .handled
            })
    }
}

