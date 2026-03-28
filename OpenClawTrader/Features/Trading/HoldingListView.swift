import SwiftUI

//
//  HoldingListView.swift
//  OpenClawTrader
//
//  功能：持仓明细列表，支持搜索和排序
//

// ============================================
// MARK: - Holding List View
// ============================================

struct HoldingListView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @State private var searchText = ""
    @State private var sortOption: SortOption = .value

    enum SortOption: String, CaseIterable {
        case value = "市值"
        case profit = "收益"
        case change = "日涨跌"
    }

    private var filteredHoldings: [Holding] {
        guard let portfolio = service.portfolio else { return [] }
        var holdings = portfolio.holdings

        if !searchText.isEmpty {
            holdings = holdings.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .value:
            holdings.sort { $0.marketValue > $1.marketValue }
        case .profit:
            holdings.sort { $0.profitLossPercent > $1.profitLossPercent }
        case .change:
            holdings.sort { $0.dayChangePercent > $1.dayChangePercent }
        }

        return holdings
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "持仓明细")

            VStack(spacing: AppSpacing.md) {
                SearchBar(text: $searchText)

                HStack {
                    Text("\(filteredHoldings.count) 只股票")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { sortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("排序: \(sortOption.rawValue)")
                                .font(AppFonts.caption())
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(colors.textSecondary)
                    }
                }

                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(filteredHoldings) { holding in
                            NavigationLink(destination: HoldingDetailView(holding: holding)) {
                                HoldingRow(holding: holding)
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
// MARK: - Holding Row
// ============================================

struct HoldingRow: View {
    @Environment(\.appColors) private var colors
    let holding: Holding

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(holding.symbol)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)
                    Text(holding.name)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                }

                Text("¥\(String(format: "%.2f", holding.currentPrice))")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("¥ \(formatNumber(holding.marketValue))")
                    .font(AppFonts.monoBody())
                    .foregroundColor(colors.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: holding.dayChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(String(format: "%.2f", holding.dayChangePercent))%")
                        .font(AppFonts.monoCaption())
                }
                .foregroundColor(holding.dayChangePercent >= 0 ? AppColors.success : AppColors.error)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
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
}
