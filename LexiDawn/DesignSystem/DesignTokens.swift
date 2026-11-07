import SwiftUI

enum LexiDawnColor {
    static let ink950 = Color(red: 0.07, green: 0.08, blue: 0.12)
    static let ink800 = Color(red: 0.18, green: 0.20, blue: 0.27)
    static let dawn500 = Color(red: 0.73, green: 0.24, blue: 0.14)
    static let sky500 = Color(red: 0.22, green: 0.55, blue: 0.90)
    static let lavender400 = Color(red: 0.63, green: 0.53, blue: 0.90)
    static let paperWarm = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let paper50 = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
}

enum LexiDawnSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}


/// Stable palettes with dark endpoints for readable white text across the whole card.
enum ReadingPalette {
    static func colors(topic: String) -> [Color] {
        let value = topic.lowercased()
        if ["科学", "science", "space", "宇宙", "太空"].contains(where: value.contains) { return [Color(red: 0.12, green: 0.19, blue: 0.38), Color(red: 0.13, green: 0.35, blue: 0.43)] }
        if ["文化", "culture", "history", "历史", "艺术"].contains(where: value.contains) { return [Color(red: 0.32, green: 0.16, blue: 0.32), Color(red: 0.43, green: 0.24, blue: 0.31)] }
        if ["technology", "科技", "computing"].contains(where: value.contains) { return [Color(red: 0.12, green: 0.26, blue: 0.27), Color(red: 0.15, green: 0.34, blue: 0.32)] }
        return [Color(red: 0.28, green: 0.21, blue: 0.24), Color(red: 0.45, green: 0.27, blue: 0.2)]
    }
}
