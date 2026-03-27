import SwiftUI

//
//  Extensions.swift
//  OpenClawTrader
//
//  功能：SwiftUI扩展，提供通用视图修饰符
//

// ============================================
// MARK: - View Extensions
// ============================================

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// ============================================
// MARK: - Date Extensions
// ============================================

extension Date {
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }

    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// ============================================
// MARK: - Number Extensions
// ============================================

extension Double {
    func formatted(decimals: Int = 2) -> String {
        return String(format: "%.\(decimals)f", self)
    }

    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: self)) ?? "¥\(self)"
    }

    var percentFormatted: String {
        return "\(String(format: "%.2f", self))%"
    }
}

extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
