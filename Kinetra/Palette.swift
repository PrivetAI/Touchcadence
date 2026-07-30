import SwiftUI

/// Resolved colour set for one theme. Built from the bundled `themes.json`.
struct Palette {
    var theme: Theme
    var isDark: Bool
    var background: Color
    var surface: Color
    var elevated: Color
    var text: Color
    var secondaryText: Color
    var primary: Color
    var accent: Color
    var success: Color
    var warning: Color
    var error: Color
    var field: Color
    var grid: Color

    /// Always explicit so the app never follows the device appearance.
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    var separator: Color { grid }

    func rankColor(_ rank: Rank) -> Color {
        switch rank {
        case .d: return secondaryText
        case .c: return text.opacity(0.75)
        case .b: return primary
        case .a: return accent
        case .s: return success
        case .ss: return warning
        case .sss: return error
        }
    }

    func categoryColor(_ category: TrainingCategory) -> Color {
        switch category {
        case .speed: return primary
        case .reaction: return accent
        case .precision: return success
        case .rhythm: return warning
        case .control: return primary.opacity(0.75)
        case .trajectory: return accent.opacity(0.75)
        case .endurance: return error
        case .combined: return text.opacity(0.7)
        }
    }

    static func map(from data: [Catalog.PaletteData]) -> [Theme: Palette] {
        var out: [Theme: Palette] = [:]
        for d in data {
            guard let theme = Theme(rawValue: d.theme) else { continue }
            out[theme] = Palette(theme: theme,
                                 isDark: d.dark,
                                 background: Color(hex: d.background),
                                 surface: Color(hex: d.surface),
                                 elevated: Color(hex: d.elevated),
                                 text: Color(hex: d.text),
                                 secondaryText: Color(hex: d.secondaryText),
                                 primary: Color(hex: d.primary),
                                 accent: Color(hex: d.accent),
                                 success: Color(hex: d.success),
                                 warning: Color(hex: d.warning),
                                 error: Color(hex: d.error),
                                 field: Color(hex: d.field),
                                 grid: Color(hex: d.grid))
        }
        if out.isEmpty { out[.dark] = builtInDark }
        return out
    }

    /// Compiled-in fallback matching the design spec, used if the resource is unreadable.
    static let builtInDark = Palette(theme: .dark, isDark: true,
                                    background: Color(hex: "121212"),
                                    surface: Color(hex: "1E1E1E"),
                                    elevated: Color(hex: "262626"),
                                    text: Color(hex: "FFFFFF"),
                                    secondaryText: Color(hex: "B0B0B0"),
                                    primary: Color(hex: "3A86FF"),
                                    accent: Color(hex: "00E5FF"),
                                    success: Color(hex: "4CAF50"),
                                    warning: Color(hex: "FFC107"),
                                    error: Color(hex: "F44336"),
                                    field: Color(hex: "171717"),
                                    grid: Color(hex: "2C2C2C"))
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Design tokens

struct Metrics {
    static let cornerSmall: CGFloat = 10
    static let cornerMedium: CGFloat = 16
    static let cornerLarge: CGFloat = 24
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let targetShadow: CGFloat = 6
    static let animation: Double = 0.25
}

extension Font {
    static let kTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let kHeadline = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let kBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let kCaption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let kNumber = Font.system(size: 34, weight: .bold, design: .rounded)
}

/// Palette handed down the view tree.
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .builtInDark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
