import SwiftUI

// ============================================
// MARK: - Model List View
// ============================================

struct ModelListView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "模型管理")

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Token Usage
                    if let workspace = service.currentWorkspace {
                        tokenUsageCard(usage: workspace.tokenUsage)
                    }

                    // Models List
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "可用模型")

                        VStack(spacing: 0) {
                            ForEach(service.models) { model in
                                NavigationLink(destination: ModelDetailView(model: model)) {
                                    ModelDetailRow(model: model)
                                }

                                if model.id != service.models.last?.id {
                                    AppDivider()
                                }
                            }
                        }
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
    }

    private func tokenUsageCard(usage: Workspace.TokenUsage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Token 使用")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text("\(formatNumber(usage.usedToday)) / \(formatNumber(usage.limit))")
                    .font(AppFonts.monoCaption())
                    .foregroundColor(colors.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(colors.backgroundTertiary)
                        .frame(height: 6)
                        .cornerRadius(3)

                    let progress = min(Double(usage.usedToday) / Double(usage.limit), 1.0)
                    Rectangle()
                        .fill(progress > 0.8 ? AppColors.warning : colors.accent)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// ============================================
// MARK: - Model Detail Row
// ============================================

struct ModelDetailRow: View {
    @Environment(\.appColors) private var colors
    let model: AIModel

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(model.status == .active ? AppColors.success : colors.textTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                Text("\(model.provider) · v\(model.version)")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatNumber(model.usageStats.totalCalls)) 调用")
                    .font(AppFonts.monoCaption())
                    .foregroundColor(colors.textSecondary)

                if model.isDefault {
                    StatusBadge(text: "默认", color: AppColors.info)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
        }
        .padding(AppSpacing.md)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

// ============================================
// MARK: - Model Detail View
// ============================================

struct ModelDetailView: View {
    @Environment(\.appColors) private var colors
    let model: AIModel
    @StateObject private var service = OpenClawService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Status Card
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        Circle()
                            .fill(model.status == .active ? AppColors.success : colors.textTertiary)
                            .frame(width: 12, height: 12)

                        Text(model.status == .active ? "运行中" : "空闲")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)

                        Spacer()

                        if model.isDefault {
                            StatusBadge(text: "默认模型", color: AppColors.info)
                        }
                    }

                    HStack {
                        Text("提供商")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                        Spacer()
                        Text(model.provider)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }

                    HStack {
                        Text("版本")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                        Spacer()
                        Text(model.version)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)

                // Usage Stats
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "使用统计")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                        StatItem(title: "总调用", value: "\(model.usageStats.totalCalls)")
                        StatItem(title: "成功调用", value: "\(model.usageStats.successfulCalls)")
                        StatItem(title: "失败调用", value: "\(model.usageStats.failedCalls)")
                        StatItem(title: "总 Tokens", value: formatTokens(model.usageStats.totalTokens))
                        StatItem(title: "平均响应", value: String(format: "%.1fs", model.usageStats.avgResponseTime))
                        StatItem(title: "成功率", value: String(format: "%.1f%%", Double(model.usageStats.successfulCalls) / Double(max(model.usageStats.totalCalls, 1)) * 100))
                    }
                }

                // Config
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "模型配置")

                    VStack(spacing: 0) {
                        ConfigRow(title: "Temperature", value: String(format: "%.1f", model.config.temperature))
                        AppDivider()
                        ConfigRow(title: "Max Tokens", value: "\(model.config.maxTokens)")
                        AppDivider()
                        ConfigRow(title: "Top P", value: String(format: "%.1f", model.config.topP))
                        AppDivider()
                        ConfigRow(title: "Frequency Penalty", value: String(format: "%.1f", model.config.frequencyPenalty))
                        AppDivider()
                        ConfigRow(title: "Presence Penalty", value: String(format: "%.1f", model.config.presencePenalty))
                    }
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.medium)
                }

                // Actions
                if !model.isDefault {
                    SecondaryButton(title: "设为默认模型") {
                        service.setDefaultModel(model)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

struct StatItem: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)

            Text(value)
                .font(AppFonts.monoBody())
                .foregroundColor(colors.textPrimary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.small)
    }
}

struct ConfigRow: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFonts.monoBody())
                .foregroundColor(colors.textPrimary)
        }
        .padding(AppSpacing.md)
    }
}
