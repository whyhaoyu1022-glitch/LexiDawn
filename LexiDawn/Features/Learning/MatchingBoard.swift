import SwiftUI

private struct MatchAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

struct MatchingBoard: View {
    let session: ReviewSessionView
    @Binding var selected: String?
    let submit: (String, String) -> Void
    let noSelection: () -> Void
    private var left: [ReviewQuestion] { session.matching.sorted { fingerprint(session.id + "left" + $0.id) < fingerprint(session.id + "left" + $1.id) } }
    private var right: [ReviewQuestion] { session.matching.sorted { fingerprint(session.id + "right" + $0.id) < fingerprint(session.id + "right" + $1.id) } }
    var body: some View {
        HStack(alignment: .top, spacing: 52) {
            VStack(spacing: 16) {
                ForEach(left) { question in
                    Button { selected = question.id } label: {
                        Label(question.prompt, systemImage: question.completed ? "checkmark.circle.fill" : selected == question.id ? "circle.inset.filled" : "circle")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(MatchingOptionStyle(completed: question.completed, selected: selected == question.id))
                        .disabled(question.completed).accessibilityIdentifier("match-word-\(question.prompt)")
                        .accessibilityValue(question.completed ? "已配对" : selected == question.id ? "已选择" : "未配对")
                        .anchorPreference(key: MatchAnchors.self, value: .bounds) { ["left|" + question.id: $0] }
                }
            }.frame(maxWidth: .infinity)
            VStack(spacing: 16) {
                ForEach(right) { option in
                    Button { if let selected { submit(selected, option.senseID) } else { noSelection() } } label: {
                        VStack { Text(option.answer); if option.completed { Image(systemName: "checkmark.circle.fill") } }.frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(MatchingOptionStyle(completed: option.completed, selected: false)).disabled(option.completed).accessibilityIdentifier("match-meaning-\(option.answer)")
                        .accessibilityValue(option.completed ? "已配对" : "选择此释义进行配对")
                        .anchorPreference(key: MatchAnchors.self, value: .bounds) { ["right|" + option.id: $0] }
                }
            }.frame(maxWidth: .infinity)
        }
        .overlayPreferenceValue(MatchAnchors.self) { anchors in
            GeometryReader { geometry in
                Canvas { context, _ in
                    for question in session.matching where question.completed {
                        if let start = anchors["left|" + question.id], let end = anchors["right|" + question.id] {
                            let a = geometry[start], b = geometry[end]
                            var path = Path(); path.move(to: CGPoint(x: a.maxX + 2, y: a.midY))
                            let middle = (a.maxX + b.minX) / 2
                            path.addCurve(to: CGPoint(x: b.minX - 2, y: b.midY), control1: CGPoint(x: middle, y: a.midY), control2: CGPoint(x: middle, y: b.midY))
                            context.stroke(path, with: .color(Color(red: 0.1, green: 0.52, blue: 0.3)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        }
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("matching-board")
        .accessibilityLabel("连线题，\(session.matching.filter(\.completed).count)条连接已保存")
    }
}

private struct MatchingOptionStyle: ButtonStyle {
    let completed: Bool, selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(completed ? Color.primary : selected ? Color.orange : Color.accentColor)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(completed ? Color.green.opacity(0.12) : selected ? Color.orange.opacity(0.16) : Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(completed ? Color.green : selected ? Color.orange : Color.accentColor.opacity(0.25), lineWidth: selected || completed ? 2 : 1) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
