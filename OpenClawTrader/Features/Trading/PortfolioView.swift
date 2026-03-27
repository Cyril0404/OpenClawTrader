import SwiftUI

//
//  PortfolioView.swift
//  OpenClawTrader
//
//  功能：交易主页面，展示持仓概览、风险评估、AI建议
//

// ============================================
// MARK: - Trading Dashboard View
// ============================================

struct TradingDashboardView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @State private var searchText = ""
    @State private var showingImportSheet = false
    @State private var showingImportOrderSheet = false
    @State private var showImportMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("交易")
                    .font(AppFonts.largeTitle())
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Menu {
                    Button(action: { showingImportSheet = true }) {
                        Label("导入持仓", systemImage: "chart.bar.doc.parallel")
                    }
                    Button(action: { showingImportOrderSheet = true }) {
                        Label("导入委托", systemImage: "doc.text")
                    }
                } label: {
                    IconButton(icon: "plus.circle") {
                        showImportMenu = true
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    SearchBar(text: $searchText)
                        .padding(.horizontal, AppSpacing.md)

                    if let portfolio = service.portfolio {
                        // Portfolio Summary
                        portfolioSummaryCard(portfolio: portfolio)

                        // Holdings (持仓明细) - 移到交易风格上方
                        holdingsSection(holdings: portfolio.holdings)

                        // Trading Style
                        if let style = service.tradingStyle {
                            tradingStyleCard(style: style)
                        }

                        // Risk Assessment
                        if let risk = service.riskAssessment {
                            riskAssessmentCard(risk: risk)
                        }

                        // Active Orders (活跃委托)
                        if !service.activeOrders.isEmpty {
                            activeOrdersSection(orders: service.activeOrders)
                        }

                        // AI Suggestions
                        suggestionsSection(suggestions: service.suggestions)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showingImportSheet) {
            ImportHoldingView()
        }
        .sheet(isPresented: $showingImportOrderSheet) {
            ImportOrderView()
        }
    }

    // MARK: - Portfolio Summary Card

    private func portfolioSummaryCard(portfolio: PortfolioSummary) -> some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Text("总持仓")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                // 持仓股数
                Text("\(portfolio.stockCount) 只")
                    .font(AppFonts.small())
                    .foregroundColor(colors.textSecondary)
            }

            Text(formatCurrency(portfolio.totalValue))
                .font(AppFonts.monoLarge())
                .foregroundColor(colors.textPrimary)

            VStack(spacing: AppSpacing.xs) {
                HStack {
                    Text("今日收益")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: portfolio.dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(formatCurrency(portfolio.dayChange)) (\(String(format: "%.2f", portfolio.dayChangePercent))%)")
                            .font(AppFonts.monoCaption())
                    }
                    .foregroundColor(portfolio.dayChange >= 0 ? AppColors.success : AppColors.error)
                }

                HStack {
                    Text("总收益")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: portfolio.totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(formatCurrency(portfolio.totalProfitLoss)) (\(String(format: "%.2f", portfolio.totalProfitLossPercent))%)")
                            .font(AppFonts.monoCaption())
                    }
                    .foregroundColor(portfolio.totalProfitLoss >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Trading Style Card

    private func tradingStyleCard(style: TradingStyle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "交易风格画像")

            HStack(spacing: AppSpacing.sm) {
                StyleTag(name: style.primaryStyle.rawValue, isActive: true)
                if let secondary = style.secondaryStyle {
                    StyleTag(name: secondary.rawValue, isActive: false)
                }
                StyleTag(name: style.holdingPeriodPreference.rawValue, isActive: false)
            }

            Text("基于您过去 6 个月的 \(service.trades.count) 笔交易分析")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)

            HStack {
                Text("置信度")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text("\(Int(style.confidence * 100))%")
                    .font(AppFonts.monoCaption())
                    .foregroundColor(colors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(colors.backgroundTertiary)
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(colors.accent)
                        .frame(width: geometry.size.width * style.confidence, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Risk Assessment Card

    private func riskAssessmentCard(risk: RiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "风险评估")

                Spacer()

                Text("综合评分")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Text(String(format: "%.1f", risk.overallScore))
                    .font(AppFonts.monoTitle())
                    .foregroundColor(riskScoreColor(risk.overallScore))
            }

            VStack(spacing: AppSpacing.sm) {
                RiskBar(label: "仓位集中度", value: risk.concentrationRisk.score, color: riskColor(risk.concentrationRisk.level))
                RiskBar(label: "波动率暴露", value: risk.volatilityExposure.score, color: riskColor(risk.volatilityExposure.level))
                RiskBar(label: "杠杆使用", value: risk.leverageUsage.score, color: riskColor(risk.leverageUsage.level))
                RiskBar(label: "行业分散度", value: risk.sectorDiversification.score, color: riskColor(risk.sectorDiversification.level))
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Active Orders Section

    private func activeOrdersSection(orders: [Order]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "活跃委托")
                Spacer()
                NavigationLink(destination: OrderListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            LazyVStack(spacing: 0) {
                ForEach(orders.prefix(3)) { order in
                    OrderRow(order: order) {
                        service.cancelOrder(order)
                    }

                    if order.id != orders.prefix(3).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Holdings Section

    private func holdingsSection(holdings: [Holding]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "持仓明细")
                Spacer()
                NavigationLink(destination: HoldingListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            LazyVStack(spacing: 0) {
                ForEach(holdings.prefix(3)) { holding in
                    NavigationLink(destination: HoldingDetailView(holding: holding)) {
                        HoldingRow(holding: holding)
                    }

                    if holding.id != holdings.prefix(3).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Suggestions Section

    private func suggestionsSection(suggestions: [TradingSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "AI 优化建议")
                Spacer()
                NavigationLink(destination: SuggestionListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(suggestions.prefix(2)) { suggestion in
                    NavigationLink(destination: SuggestionDetailView(suggestion: suggestion)) {
                        SuggestionCard(suggestion: suggestion)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }

    private func riskScoreColor(_ score: Double) -> Color {
        if score < 4 { return AppColors.success }
        if score < 7 { return AppColors.warning }
        return AppColors.error
    }

    private func riskColor(_ level: RiskAssessment.RiskFactor.RiskLevel) -> Color {
        switch level {
        case .low: return AppColors.success
        case .medium: return AppColors.warning
        case .high: return AppColors.error
        }
    }
}
