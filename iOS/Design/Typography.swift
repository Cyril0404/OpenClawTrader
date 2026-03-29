import SwiftUI

//
//  Typography.swift
//  OpenClawTrader
//
//  功能：字体系统，统一管理App内所有字体样式
//

// ============================================
// MARK: - App Fonts
// ============================================

struct AppFonts {
    // Titles
    static func largeTitle() -> Font { .system(size: 34, weight: .bold) }
    static func title1() -> Font { .system(size: 28, weight: .bold) }
    static func title2() -> Font { .system(size: 22, weight: .semibold) }
    static func title3() -> Font { .system(size: 17, weight: .semibold) }

    // Body
    static func body() -> Font { .system(size: 15, weight: .regular) }
    static func bodyMedium() -> Font { .system(size: 15, weight: .medium) }

    // Caption
    static func caption() -> Font { .system(size: 13, weight: .regular) }
    static func captionMedium() -> Font { .system(size: 13, weight: .medium) }

    // Small
    static func small() -> Font { .system(size: 11, weight: .regular) }
    static func smallMedium() -> Font { .system(size: 11, weight: .medium) }

    // Monospace
    static func monoLarge() -> Font { .system(size: 34, weight: .bold, design: .monospaced) }
    static func monoTitle() -> Font { .system(size: 22, weight: .semibold, design: .monospaced) }
    static func monoBody() -> Font { .system(size: 17, weight: .regular, design: .monospaced) }
    static func monoCaption() -> Font { .system(size: 13, weight: .regular, design: .monospaced) }
    static func monoSmall() -> Font { .system(size: 11, weight: .regular, design: .monospaced) }
}

// ============================================
// MARK: - App Spacing
// ============================================

struct AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// ============================================
// MARK: - App Radius
// ============================================

struct AppRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let full: CGFloat = 9999
}
