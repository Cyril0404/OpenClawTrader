import SwiftUI

//
//  Components.swift
//  OpenClawTrader
//
//  功能：通用UI组件库
//  包含：PrimaryButton、SecondaryButton、ListItem、SearchBar、EmptyState等
//

// ============================================
// MARK: - Primary Button
// ============================================

struct PrimaryButton: View {
    @Environment(\.appColors) private var colors
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(colors.background)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.background))
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(colors.accent)
            .cornerRadius(AppRadius.small)
        }
        .disabled(isLoading)
    }
}

// ============================================
// MARK: - Secondary Button
// ============================================

struct SecondaryButton: View {
    @Environment(\.appColors) private var colors
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.body())
                .fontWeight(.medium)
                .foregroundColor(colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(colors.borderLight, lineWidth: 1)
                )
        }
    }
}

// ============================================
// MARK: - Text Button
// ============================================

struct TextButton: View {
    @Environment(\.appColors) private var colors
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - Icon Button
// ============================================

struct IconButton: View {
    @Environment(\.appColors) private var colors
    let icon: String
    let action: () -> Void
    var size: CGFloat = 24

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(colors.textSecondary)
                .frame(width: 44, height: 44)
        }
    }
}

// ============================================
// MARK: - Status Badge
// ============================================

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFonts.smallMedium())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(AppRadius.full)
    }
}

// ============================================
// MARK: - Info Card
// ============================================

struct InfoCard: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String
    let unit: String?
    let trend: Trend?

    enum Trend {
        case up, down, neutral

        var color: Color {
            switch self {
            case .up: return AppColors.success
            case .down: return AppColors.error
            case .neutral: return Color(hex: "4A4A4A")
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
    }

    init(title: String, value: String, unit: String? = nil, trend: Trend? = nil) {
        self.title = title
        self.value = value
        self.unit = unit
        self.trend = trend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title.uppercased())
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)
                .tracking(1)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppFonts.monoLarge())
                    .foregroundColor(colors.textPrimary)

                if let unit = unit {
                    Text(unit)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(trend.color)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }
}

// ============================================
// MARK: - List Item
// ============================================

struct ListItem: View {
    @Environment(\.appColors) private var colors
    let icon: String
    let title: String
    let subtitle: String?
    let showArrow: Bool
    var iconColor: Color = Color(hex: "8A8A8A")

    init(icon: String, title: String, subtitle: String? = nil, showArrow: Bool = true, iconColor: Color = Color(hex: "8A8A8A")) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showArrow = showArrow
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            Spacer()

            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
    }
}

// ============================================
// MARK: - Section Header
// ============================================

struct SectionHeader: View {
    @Environment(\.appColors) private var colors
    let title: String

    var body: some View {
        Text(title)
            .font(AppFonts.caption())
            .foregroundColor(colors.textSecondary)
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ============================================
// MARK: - Search Bar
// ============================================

struct SearchBar: View {
    @Environment(\.appColors) private var colors
    @Binding var text: String
    var placeholder: String = "搜索"

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colors.textTertiary)

            TextField(placeholder, text: $text)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)
                .tint(colors.textSecondary)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(height: 40)
        .background(colors.backgroundTertiary)
        .cornerRadius(AppRadius.small)
    }
}

// ============================================
// MARK: - Divider
// ============================================

struct AppDivider: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        Rectangle()
            .fill(colors.border)
            .frame(height: 0.5)
    }
}

// ============================================
// MARK: - Empty State
// ============================================

struct EmptyState: View {
    @Environment(\.appColors) private var colors
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(colors.textTertiary)

            VStack(spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textSecondary)

                Text(subtitle)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
    }
}

// ============================================
// MARK: - Loading View
// ============================================

struct LoadingView: View {
    @Environment(\.appColors) private var colors
    var message: String = "加载中..."

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: colors.textSecondary))
                .scaleEffect(1.2)

            Text(message)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - Navigation Bar
// ============================================

struct NavigationBar: View {
    @Environment(\.appColors) private var colors
    let title: String
    var subtitle: String? = nil
    var leftButton: String? = nil
    var rightButton: String? = nil
    var onLeftTap: (() -> Void)? = nil
    var onRightTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let leftButton = leftButton {
                Button(action: { onLeftTap?() }) {
                    Image(systemName: leftButton)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colors.textSecondary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppFonts.small())
                        .foregroundColor(colors.textSecondary)
                }
            }

            Spacer()

            if let rightButton = rightButton {
                Button(action: { onRightTap?() }) {
                    Image(systemName: rightButton)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

// ============================================
// MARK: - Style Tag
// ============================================

struct StyleTag: View {
    @Environment(\.appColors) private var colors
    let name: String
    let isActive: Bool

    var body: some View {
        Text(name)
            .font(AppFonts.smallMedium())
            .foregroundColor(isActive ? colors.background : colors.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(isActive ? colors.accent : colors.backgroundTertiary)
            .cornerRadius(AppRadius.full)
    }
}

// ============================================
// MARK: - Risk Bar
// ============================================

struct RiskBar: View {
    @Environment(\.appColors) private var colors
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack {
                Text(label)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(AppFonts.monoCaption())
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(colors.backgroundTertiary)
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * value, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

// ============================================
// MARK: - Suggestion Card
// ============================================

struct SuggestionCard: View {
    @Environment(\.appColors) private var colors
    let suggestion: TradingSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                StatusBadge(
                    text: suggestion.category.rawValue,
                    color: priorityColor(suggestion.priority)
                )
                Spacer()
                Text(formatTime(suggestion.timestamp))
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }

            Text(suggestion.title)
                .font(AppFonts.body())
                .fontWeight(.medium)
                .foregroundColor(colors.textPrimary)

            Text(suggestion.description)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
                .lineLimit(2)

            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(colors.accent)
                Text(suggestion.potentialImpact)
                    .font(AppFonts.small())
                    .foregroundColor(colors.accent)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func priorityColor(_ priority: TradingSuggestion.Priority) -> Color {
        switch priority {
        case .high: return AppColors.error
        case .medium: return AppColors.warning
        case .low: return Color(hex: "8A8A8A")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
