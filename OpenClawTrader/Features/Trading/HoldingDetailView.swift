import SwiftUI

//
//  HoldingDetailView.swift
//  OpenClawTrader
//
//  功能：持仓详情页面，展示持仓信息和盈亏分析
//

// ============================================
// MARK: - Holding Detail View
// ============================================

struct HoldingDetailView: View {
    @Environment(\.appColors) private var colors
    let holding: Holding
    @StateObject private var service = TradingService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header Card
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holding.symbol)
                                .font(AppFonts.title1())
                                .foregroundColor(colors.textPrimary)

                            Text(holding.name)
                                .font(AppFonts.body())
                                .foregroundColor(colors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("¥ \(formatNumber(holding.marketValue))")
                                .font(AppFonts.monoTitle())
                                .foregroundColor(colors.textPrimary)

                            HStack(spacing: 4) {
                                Image(systemName: holding.dayChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(String(format: "%.2f", holding.dayChangePercent))%")
                                    .font(AppFonts.monoCaption())
                            }
                            .foregroundColor(holding.dayChangePercent >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)

                // Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                    DetailCard(title: "持股数量", value: "\(holding.shares)")
                    DetailCard(title: "持仓成本", value: "¥ \(String(format: "%.2f", holding.averageCost))")
                    DetailCard(title: "当前价格", value: "¥ \(String(format: "%.2f", holding.currentPrice))")
                    DetailCard(title: "今日涨跌", value: "\(String(format: "%.2f", holding.dayChangePercent))%",
                              valueColor: holding.dayChangePercent >= 0 ? AppColors.success : AppColors.error)
                    DetailCard(title: "总收益", value: "\(String(format: "%.2f", holding.profitLossPercent))%",
                              valueColor: holding.profitLoss >= 0 ? AppColors.success : AppColors.error)
                    DetailCard(title: "市值", value: "¥ \(formatNumber(holding.marketValue))")
                }

                // Actions
                VStack(spacing: AppSpacing.sm) {
                    SecondaryButton(title: "设置价格提醒") {
                        // Set price alert
                    }

                    SecondaryButton(title: "删除持仓") {
                        service.deleteHolding(holding)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// ============================================
// MARK: - Detail Card
// ============================================

struct DetailCard: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String
    var valueColor: Color = Color(hex: "FFFFFF")

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)

            Text(value)
                .font(AppFonts.monoBody())
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.small)
    }
}
