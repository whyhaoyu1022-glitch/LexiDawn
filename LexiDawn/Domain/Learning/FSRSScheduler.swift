import Foundation

/// FSRS-4.5 DSR equations, fixed published default parameters, retention 0.9, no fuzz.
/// Reference: open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm (FSRS-4.5/v4).
/// Learning-step policy is LexiDawn's daily-session policy; it is not Anki's minute-step policy.
enum FSRSScheduler {
    static let version = "fsrs-4.5-lexidawn-1"
    static let weights: [Double] = [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755]
    struct State: Equatable { let stability: Double, difficulty: Double, intervalDays: Int, retrievability: Double }
    static func retrievability(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + (19.0 / 81.0) * max(0, elapsedDays) / max(0.01, stability), -0.5)
    }
    static func schedule(stability: Double?, difficulty: Double?, elapsedDays: Double, grade: BasicReviewScheduler.Grade) throws -> State {
        guard elapsedDays.isFinite, elapsedDays >= 0,
              stability.map({ $0.isFinite && $0 > 0 }) ?? true,
              difficulty.map({ $0.isFinite && (1...10).contains($0) }) ?? true else { throw LearningError.invalid("复习记忆状态无效，原排程保留。") }
        let rating = grade == .again ? 1 : grade == .hard ? 2 : 3
        let w = weights
        let initialDifficulty = min(10, max(1, w[4] - Double(rating - 3) * w[5]))
        guard let s = stability, let d = difficulty else {
            let s = w[rating - 1]
            return State(stability: s, difficulty: initialDifficulty, intervalDays: max(1, Int(s.rounded())), retrievability: 1)
        }
        let r = retrievability(elapsedDays: elapsedDays, stability: s)
        let newD = min(10, max(1, w[7] * w[4] + (1 - w[7]) * (d - w[6] * Double(rating - 3))))
        let newS: Double
        if grade == .again {
            newS = min(s, w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r)))
        } else {
            newS = s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * (grade == .hard ? w[15] : 1))
        }
        let bounded = min(3650, max(0.01, newS))
        guard bounded.isFinite else { throw LearningError.invalid("复习排程计算失败，原状态保留。") }
        return State(stability: bounded, difficulty: newD, intervalDays: min(3650, max(1, Int(bounded.rounded()))), retrievability: r)
    }
}
