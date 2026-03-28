import SwiftUI

//
//  StockSearchView.swift
//  OpenClawTrader
//
//  功能：股票搜索，支持快速添加持仓
//

// ============================================
// MARK: - Stock Search View
// ============================================

struct StockSearchView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradingService = TradingService.shared
    @State private var searchText = ""
    @State private var selectedStock: Stock?
    @State private var showingAddHolding = false

    private var filteredStocks: [Stock] {
        if searchText.isEmpty {
            return Stock.realStocks
        }
        return Stock.realStocks.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(colors.textTertiary)

                    TextField("搜索股票代码或名称", text: $searchText)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(colors.textTertiary)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.small)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

                // 搜索结果
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(filteredStocks) { stock in
                            StockSearchRow(stock: stock) {
                                selectedStock = stock
                                showingAddHolding = true
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(colors.background)
            .navigationTitle("搜索股票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.accent)
                }
            }
            .sheet(isPresented: $showingAddHolding) {
                if let stock = selectedStock {
                    QuickAddHoldingView(stock: stock)
                }
            }
        }
    }
}

// ============================================
// MARK: - Stock Search Row
// ============================================

struct StockSearchRow: View {
    @Environment(\.appColors) private var colors
    let stock: Stock
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stock.symbol)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)
                    Text(stock.name)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                }

                Text("¥\(String(format: "%.2f", stock.currentPrice))")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }

            Spacer()

            // 涨跌幅
            HStack(spacing: 4) {
                Image(systemName: stock.dayChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(String(format: "%.2f", stock.dayChangePercent))%")
                    .font(AppFonts.monoCaption())
            }
            .foregroundColor(stock.dayChangePercent >= 0 ? AppColors.success : AppColors.error)

            // 添加按钮
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(colors.accent)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }
}

// ============================================
// MARK: - Quick Add Holding View
// ============================================

struct QuickAddHoldingView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradingService = TradingService.shared

    let stock: Stock
    @State private var shares: String = ""
    @State private var averageCost: String = ""

    private var isValid: Bool {
        guard let sharesInt = Int(shares), sharesInt > 0 else { return false }
        guard let cost = Double(averageCost), cost > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                // 股票信息
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stock.symbol)
                            .font(AppFonts.title2())
                            .foregroundColor(colors.textPrimary)
                        Text(stock.name)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥\(String(format: "%.2f", stock.currentPrice))")
                            .font(AppFonts.monoTitle())
                            .foregroundColor(colors.textPrimary)
                        HStack(spacing: 4) {
                            Image(systemName: stock.dayChangePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(String(format: "%.2f", stock.dayChangePercent))%")
                                .font(AppFonts.monoCaption())
                        }
                        .foregroundColor(stock.dayChangePercent >= 0 ? AppColors.success : AppColors.error)
                    }
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)

                // 输入表单
                VStack(spacing: AppSpacing.md) {
                    // 股数
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("持股数量")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                        TextField("输入股数", text: $shares)
                            .keyboardType(.numberPad)
                            .font(AppFonts.body())
                            .padding(AppSpacing.sm)
                            .background(colors.backgroundSecondary)
                            .cornerRadius(AppRadius.small)
                    }

                    // 成本
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("平均成本 (¥)")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                        TextField("输入成本价", text: $averageCost)
                            .keyboardType(.decimalPad)
                            .font(AppFonts.body())
                            .padding(AppSpacing.sm)
                            .background(colors.backgroundSecondary)
                            .cornerRadius(AppRadius.small)
                    }
                }

                Spacer()

                // 确认按钮
                Button(action: addHolding) {
                    Text("确认添加")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(isValid ? colors.background : colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isValid ? colors.accent : colors.backgroundTertiary)
                        .cornerRadius(AppRadius.small)
                }
                .disabled(!isValid)
            }
            .padding(AppSpacing.md)
            .background(colors.background)
            .navigationTitle("添加持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addHolding() {
        guard let sharesInt = Int(shares),
              let cost = Double(averageCost) else { return }

        tradingService.importHolding(
            symbol: stock.symbol,
            shares: sharesInt,
            averageCost: cost,
            currentPrice: stock.currentPrice,
            name: stock.name
        )
        dismiss()
    }
}
