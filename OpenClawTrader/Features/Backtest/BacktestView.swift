import SwiftUI
import Charts

//
//  BacktestView.swift
//  OpenClawTrader
//
//  功能：策略回测页面
//

// ============================================
// MARK: - Backtest View
// ============================================

struct BacktestView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = BacktestService.shared

    @State private var showConfig = false
    @State private var showStockPicker = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 配置区域
                configSection

                // 运行回测按钮
                runButton

                // 结果展示
                if let result = service.result {
                    resultSection(result: result)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle("策略回测")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConfig) {
            BacktestConfigSheet(params: $service.params)
        }
        .sheet(isPresented: $showStockPicker) {
            StockPickerSheet(searchText: $searchText) { stock in
                service.params.stockCode = stock.id
                service.params.stockName = stock.name
            }
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        VStack(spacing: AppSpacing.md) {
            // 股票选择
            HStack {
                Text("股票")
                    .foregroundColor(colors.textSecondary)
                Spacer()
                Button(action: { showStockPicker = true }) {
                    HStack {
                        Text("\(service.params.stockName) (\(service.params.stockCode))")
                            .foregroundColor(colors.textPrimary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(colors.textTertiary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)

            // 策略选择
            HStack {
                Text("策略")
                    .foregroundColor(colors.textSecondary)
                Spacer()
                Menu {
                    ForEach(StrategyType.allCases) { strategy in
                        Button(strategy.rawValue) {
                            service.params.strategy = strategy
                        }
                    }
                } label: {
                    HStack {
                        Text(service.params.strategy.rawValue)
                            .foregroundColor(colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .foregroundColor(colors.textTertiary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)

            // 策略说明
            Text(service.params.strategy.description)
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 初始资金
            HStack {
                Text("初始资金")
                    .foregroundColor(colors.textSecondary)
                Spacer()
                Text("¥\(Int(service.params.initialCapital))")
                    .foregroundColor(colors.textPrimary)
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)

            // 时间范围
            HStack {
                Text("回测区间")
                    .foregroundColor(colors.textSecondary)
                Spacer()
                Text("\(formatDate(service.params.startDate)) - \(formatDate(service.params.endDate))")
                    .foregroundColor(colors.textPrimary)
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Run Button

    private var runButton: some View {
        Button(action: {
            Task {
                await service.runBacktest()
            }
        }) {
            HStack {
                if service.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.background))
                } else {
                    Image(systemName: "play.fill")
                    Text("运行回测")
                }
            }
            .font(AppFonts.body())
            .foregroundColor(colors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(colors.accent)
            .cornerRadius(AppRadius.small)
        }
        .disabled(service.isLoading)
    }

    // MARK: - Result Section

    private func resultSection(result: BacktestResult) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // 收益曲线
            equityCurveSection(result: result)

            // 收益统计
            returnStatsSection(result: result)

            // 风险统计
            riskStatsSection(result: result)

            // 交易统计
            tradeStatsSection(result: result)
        }
    }

    private func equityCurveSection(result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("收益曲线")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            Chart {
                // 策略收益
                ForEach(result.equityCurve) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("策略", point.value)
                    )
                    .foregroundStyle(colors.accent)
                }

                // 基准收益
                ForEach(result.equityCurve) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("基准", point.benchmark)
                    )
                    .foregroundStyle(colors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .frame(height: 200)
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func returnStatsSection(result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("收益统计")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                StatCard(title: "总收益", value: String(format: "%.2f%%", result.totalReturn),
                        color: result.totalReturn >= 0 ? colors.accent : AppColors.error)
                StatCard(title: "年化收益", value: String(format: "%.2f%%", result.annualizedReturn),
                        color: result.annualizedReturn >= 0 ? colors.accent : AppColors.error)
                StatCard(title: "基准收益", value: String(format: "%.2f%%", result.benchmarkReturn),
                        color: colors.textSecondary)
                StatCard(title: "超额收益", value: String(format: "%.2f%%", result.totalReturn - result.benchmarkReturn),
                        color: (result.totalReturn - result.benchmarkReturn) >= 0 ? colors.accent : AppColors.error)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func riskStatsSection(result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("风险统计")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                StatCard(title: "最大回撤", value: String(format: "%.2f%%", result.maxDrawdown),
                        color: AppColors.error)
                StatCard(title: "夏普比率", value: String(format: "%.2f", result.sharpeRatio),
                        color: result.sharpeRatio >= 1 ? colors.accent : colors.textSecondary)
                StatCard(title: "波动率", value: String(format: "%.2f%%", result.volatility),
                        color: colors.textSecondary)
                StatCard(title: "盈亏比", value: String(format: "%.2f", result.winTrades > 0 ? Double(result.winTrades) / Double(max(1, result.lossTrades)) : 0),
                        color: colors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func tradeStatsSection(result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("交易统计")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                StatCard(title: "总交易次数", value: "\(result.totalTrades)", color: colors.textPrimary)
                StatCard(title: "盈利次数", value: "\(result.winTrades)", color: colors.accent)
                StatCard(title: "亏损次数", value: "\(result.lossTrades)", color: AppColors.error)
                StatCard(title: "胜率", value: String(format: "%.1f%%", result.winRate),
                        color: result.winRate >= 50 ? colors.accent : AppColors.error)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Helper

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// ============================================
// MARK: - Stat Card
// ============================================

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
            Text(value)
                .font(AppFonts.body())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(colors.backgroundTertiary)
        .cornerRadius(AppRadius.small)
    }
}

// ============================================
// MARK: - Backtest Config Sheet
// ============================================

struct BacktestConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var params: BacktestParams

    var body: some View {
        NavigationStack {
            Form {
                Section("时间范围") {
                    DatePicker("开始日期", selection: $params.startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $params.endDate, displayedComponents: .date)
                }

                Section("资金设置") {
                    TextField("初始资金", value: $params.initialCapital, format: .number)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("回测配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
