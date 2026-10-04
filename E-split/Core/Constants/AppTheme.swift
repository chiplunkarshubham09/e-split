import SwiftUI

enum AppTheme {
    /// Primary brand blue `#1E64D8`.
    static let primary = Color.accentColor
    /// Secondary brand grey `#595959`.
    static let secondary = Color("AppSecondary")
    static let canvas = Color("AppCanvas")
    static let primarySoft = Color("AppPrimarySoft")
    static let onPrimary = Color.white
    static let cardFill = Color(.secondarySystemGroupedBackground)
    static let cardStroke = secondary.opacity(0.22)

    static let owe = secondary
    static let owed = primary
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension View {
    func appTinted() -> some View {
        tint(AppTheme.primary)
    }
}
