import SwiftUI

// ============================================
// MARK: - Suggestion Detail View
// ============================================

struct SuggestionDetailView: View {
    @Environment(\.appColors) private var colors
    let suggestion: TradingSuggestion
    @StateObject private var service = TradingService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: iconForCategory(suggestion.category))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: suggestion.priority.color))

                        Spacer()

                        StatusBadge(
                            text: priorityText,
                            color: Color(hex: suggestion.priority.color)
                        )
                    }

                    Text(suggestion.title)
                        .font(AppFonts.title1())
                        .foregroundColor(colors.textPrimary)

                    Text(suggestion.description)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                        .lineSpacing(4)
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)

                // Impact
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "预期效果")

                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.success)

                        Text(suggestion.potentialImpact)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.medium)
                }

                // Category Info
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "建议类型")

                    HStack {
                        Text("类型")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        Spacer()

                        Text(suggestion.category.rawValue)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.medium)
                }

                // Actions
                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "采纳建议") {
                        service.markSuggestionRead(suggestion)
                    }

                    SecondaryButton(title: "稍后处理") {
                        service.markSuggestionRead(suggestion)
                    }

                    TextButton(title: "关闭建议") {
                        service.dismissSuggestion(suggestion)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle("建议详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var priorityText: String {
        switch suggestion.priority {
        case .high: return "高优先级"
        case .medium: return "中优先级"
        case .low: return "低优先级"
        }
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
}
