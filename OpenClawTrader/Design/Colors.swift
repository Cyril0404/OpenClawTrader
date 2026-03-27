import SwiftUI

// ============================================
// MARK: - Theme Manager
// ============================================

enum ThemeMode: String, CaseIterable {
    case system = "跟随系统"
    case light = "日间模式"
    case dark = "深色模式"
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "theme_mode")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "theme_mode"),
           let themeMode = ThemeMode(rawValue: saved) {
            self.mode = themeMode
        } else {
            self.mode = .system
        }
    }

    var colorScheme: ColorScheme? {
        switch mode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// ============================================
// MARK: - App Colors (Environment-aware)
// ============================================

struct AdaptiveColors {
    let colorScheme: ColorScheme

    // Background
    var background: Color {
        colorScheme == .dark ? Color(hex: "000000") : Color.white
    }

    var backgroundSecondary: Color {
        colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F5")
    }

    var backgroundTertiary: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "EBEBEB")
    }

    // Border
    var border: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color(hex: "E0E0E0")
    }

    var borderLight: Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "D0D0D0")
    }

    // Text
    var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8A8A8A") : Color(hex: "666666")
    }

    var textTertiary: Color {
        colorScheme == .dark ? Color(hex: "4A4A4A") : Color(hex: "999999")
    }

    // Accent
    var accent: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    var accentMuted: Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "C0C0C0")
    }

    var accentSubtle: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "E8E8E8")
    }

    // Functional (same for both modes)
    let success = Color(hex: "2ECC71")
    let warning = Color(hex: "F39C12")
    let error = Color(hex: "E74C3C")
    let info = Color(hex: "3498DB")
}

// ============================================
// MARK: - Environment Key
// ============================================

private struct AdaptiveColorsKey: EnvironmentKey {
    static let defaultValue: AdaptiveColors = AdaptiveColors(colorScheme: .dark)
}

extension EnvironmentValues {
    var appColors: AdaptiveColors {
        get { self[AdaptiveColorsKey.self] }
        set { self[AdaptiveColorsKey.self] = newValue }
    }
}

// ============================================
// MARK: - AppColors (Legacy static accessor - deprecated)
// ============================================

@available(*, deprecated, message: "Use @Environment(\\appColors) instead")
enum AppColors {
    // Dark mode colors (legacy - for backwards compatibility)
    static let background = Color(hex: "000000")
    static let backgroundSecondary = Color(hex: "0A0A0A")
    static let backgroundTertiary = Color(hex: "141414")
    static let border = Color(hex: "1A1A1A")
    static let borderLight = Color(hex: "2A2A2A")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8A8A8A")
    static let textTertiary = Color(hex: "4A4A4A")
    static let accent = Color.white
    static let accentMuted = Color(hex: "3A3A3A")
    static let accentSubtle = Color(hex: "1F1F1F")

    // Functional (same for both modes)
    static let success = Color(hex: "2ECC71")
    static let warning = Color(hex: "F39C12")
    static let error = Color(hex: "E74C3C")
    static let info = Color(hex: "3498DB")
}

// ============================================
// MARK: - Color Extension
// ============================================

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// ============================================
// MARK: - Theme Modifier
// ============================================

struct AdaptiveColorsModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.appColors, AdaptiveColors(colorScheme: colorScheme))
    }
}

extension View {
    func withAdaptiveColors() -> some View {
        modifier(AdaptiveColorsModifier())
    }
}
