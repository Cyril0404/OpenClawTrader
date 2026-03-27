import SwiftUI

// ============================================
// MARK: - Suggestion List View
// ============================================

struct SuggestionListView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @State private var filterPriority: TradingSuggestion.Priority? = nil

    private var filteredSuggestions: [TradingSuggestion] {
        if let priority = filterPriority {
            return service.suggestions.filter { $0.priority == priority }
        }
        return service.suggestions
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "AI 建议")

            VStack(spacing: AppSpacing.md) {
                // Filter
                HStack(spacing: AppSpacing.xs) {
                    FilterChip(title: "全部", isSelected: filterPriority == nil) {
                        filterPriority = nil
                    }
                    FilterChip(title: "高优先级", isSelected: filterPriority == .high) {
                        filterPriority = .high
                    }
                    FilterChip(title: "中优先级", isSelected: filterPriority == .medium) {
                        filterPriority = .medium
                    }
                }

                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(filteredSuggestions) { suggestion in
                            NavigationLink(destination: SuggestionDetailView(suggestion: suggestion)) {
                                SuggestionRow(suggestion: suggestion)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.lg)
                }
            }
        }
        .background(colors.background)
    }
}

// ============================================
// MARK: - Filter Chip
// ============================================

struct FilterChip: View {
    @Environment(\.appColors) private var colors
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(isSelected ? colors.background : colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? colors.accent : colors.backgroundSecondary)
                .cornerRadius(AppRadius.full)
        }
    }
}

// ============================================
// MARK: - Suggestion Row
// ============================================

struct SuggestionRow: View {
    @Environment(\.appColors) private var colors
    let suggestion: TradingSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: iconForCategory(suggestion.category))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: suggestion.priority.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                Text(suggestion.description)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(2)

                HStack {
                    Text(suggestion.category.rawValue)
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)

                    Spacer()

                    Text(formatTime(suggestion.timestamp))
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func iconForCategory(_ category: TradingSuggestion.Category) -> String {
        switch category {
        case .仓位: return "chart.pie"
        case .止损: return "flag"
        case .分散: return "square.grid.2x2"
        case .时机: return "clock"
        case .习惯: return "person"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
