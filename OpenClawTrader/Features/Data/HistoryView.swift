import SwiftUI

//
//  HistoryView.swift
//  OpenClawTrader
//
//  功能：历史交易记录列表，支持买卖筛选
//

// ============================================
// MARK: - History View
// ============================================

struct HistoryView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @State private var filterType: Trade.TradeType? = nil

    private var filteredTrades: [Trade] {
        if let type = filterType {
            return service.trades.filter { $0.type == type }
        }
        return service.trades
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "历史交易")

            VStack(spacing: AppSpacing.md) {
                // Filter
                HStack(spacing: AppSpacing.xs) {
                    FilterChip(title: "全部", isSelected: filterType == nil) {
                        filterType = nil
                    }
                    FilterChip(title: "买入", isSelected: filterType == .buy) {
                        filterType = .buy
                    }
                    FilterChip(title: "卖出", isSelected: filterType == .sell) {
                        filterType = .sell
                    }
                }

                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        if filteredTrades.isEmpty {
                            EmptyState(
                                icon: "clock.arrow.circlepath",
                                title: "暂无交易记录",
                                subtitle: "您的交易记录将显示在这里"
                            )
                        } else {
                            ForEach(filteredTrades) { trade in
                                TradeRow(trade: trade)
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
// MARK: - Trade Row
// ============================================

struct TradeRow: View {
    @Environment(\.appColors) private var colors
    let trade: Trade

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: trade.type == .buy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(trade.type == .buy ? AppColors.success : AppColors.error)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(trade.symbol)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    Text(trade.type.rawValue)
                        .font(AppFonts.caption())
                        .foregroundColor(trade.type == .buy ? AppColors.success : AppColors.error)
                }

                Text("\(trade.shares) 股 @ ¥ \(String(format: "%.2f", trade.price))")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("¥ \(formatNumber(trade.totalAmount))")
                    .font(AppFonts.monoBody())
                    .foregroundColor(colors.textPrimary)

                Text(formatDate(trade.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
