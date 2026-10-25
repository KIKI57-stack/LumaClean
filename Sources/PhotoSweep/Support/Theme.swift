import SwiftUI

enum Theme {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.047)
    static let surface = Color.white.opacity(0.055)
    static let surfaceStrong = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.10)

    static let accent = Color(red: 0.29, green: 0.87, blue: 0.63)
    static let accentSoft = Color(red: 0.29, green: 0.87, blue: 0.63).opacity(0.16)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let warningSoft = Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.16)
    static let danger = Color(red: 1.00, green: 0.42, blue: 0.42)
    static let info = Color(red: 0.42, green: 0.68, blue: 1.00)
    static let infoSoft = Color(red: 0.42, green: 0.68, blue: 1.00).opacity(0.16)
    static let purple = Color(red: 0.66, green: 0.55, blue: 1.00)
    static let purpleSoft = Color(red: 0.66, green: 0.55, blue: 1.00).opacity(0.16)
    static let wechat = Color(red: 0.027, green: 0.757, blue: 0.376)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.56)
    static let textTertiary = Color.white.opacity(0.34)

    static let cardRadius: CGFloat = 18
}
