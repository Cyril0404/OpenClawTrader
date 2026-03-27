import SwiftUI

// ============================================
// MARK: - Data Dashboard View
// ============================================

struct DataDashboardView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var tradingService = TradingService.shared
    @State private var performanceData: [PerformanceDataPoint] = []

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "数据")

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if let performance = tradingService.performance {
                        // Performance Summary
                        performanceSummaryCard(performance: performance)

                        // Chart
                        chartSection

                        // Key Metrics
                        keyMetricsSection(performance: performance)

                        // Win/Loss
                        winLossSection(performance: performance)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .onAppear {
            performanceData = PerformanceDataPoint.generatePreviewData(days: 30)
        }
    }

    // MARK: - Performance Summary Card

    private func performanceSummaryCard(performance: PerformanceReport) -> some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Text("总收益率")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text("vs 基准 +3.20%")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.success)
            }

            Text("\(String(format: "%.2f", performance.totalReturnPercent))%")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(performance.totalReturn >= 0 ? AppColors.success : AppColors.error)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日")
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)

                    Text("\(String(format: "%.2f", performance.dayReturnPercent))%")
                        .font(AppFonts.monoCaption())
                        .foregroundColor(performance.dayReturn >= 0 ? AppColors.success : AppColors.error)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("本周")
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)

                    Text("\(String(format: "%.2f", performance.weekReturnPercent))%")
                        .font(AppFonts.monoCaption())
                        .foregroundColor(performance.weekReturn >= 0 ? AppColors.success : AppColors.error)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("本月")
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)

                    Text("\(String(format: "%.2f", performance.monthReturnPercent))%")
                        .font(AppFonts.monoCaption())
                        .foregroundColor(performance.monthReturn >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "收益曲线 (30天)")

            ChartView(data: performanceData)
                .frame(height: 200)
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Key Metrics Section

    private func keyMetricsSection(performance: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "关键指标")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                MetricCard(title: "夏普比率", value: String(format: "%.2f", performance.sharpeRatio), subtitle: nil)
                MetricCard(title: "最大回撤", value: "\(String(format: "%.1f", performance.maxDrawdownPercent))%", subtitle: nil)
                MetricCard(title: "盈利因子", value: String(format: "%.2f", performance.profitFactor), subtitle: nil)
                MetricCard(title: "总交易", value: "\(performance.totalTrades)", subtitle: nil)
            }
        }
    }

    // MARK: - Win/Loss Section

    private func winLossSection(performance: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "胜率统计")

            VStack(spacing: 0) {
                HStack {
                    Text("胜率")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    Text("\(Int(performance.winRate * 100))%")
                        .font(AppFonts.monoTitle())
                        .foregroundColor(colors.textPrimary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.error.opacity(0.3))
                            .frame(width: geometry.size.width * (1 - performance.winRate))

                        Rectangle()
                            .fill(AppColors.success.opacity(0.3))
                            .frame(width: geometry.size.width * performance.winRate)
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)

                HStack {
                    Text("盈利 \(performance.winningTrades) 笔")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.success)

                    Spacer()

                    Text("亏损 \(performance.losingTrades) 笔")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.error)
                }

                HStack {
                    Text("平均盈利")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    Text("¥ \(formatNumber(performance.averageWin))")
                        .font(AppFonts.monoCaption())
                        .foregroundColor(AppColors.success)
                }

                HStack {
                    Text("平均亏损")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    Text("¥ \(formatNumber(performance.averageLoss))")
                        .font(AppFonts.monoCaption())
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// ============================================
// MARK: - Chart View
// ============================================

struct ChartView: View {
    @Environment(\.appColors) private var colors
    let data: [PerformanceDataPoint]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            let minValue = data.map { $0.portfolioValue }.min() ?? 0
            let maxValue = data.map { $0.portfolioValue }.max() ?? 1
            let range = maxValue - minValue

            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5) { _ in
                        Spacer()
                        Rectangle()
                            .fill(colors.border)
                            .frame(height: 0.5)
                    }
                }

                // Line
                Path { path in
                    guard !data.isEmpty else { return }

                    let stepX = width / CGFloat(max(data.count - 1, 1))

                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (point.portfolioValue - minValue) / range : 0.5
                        let y = height - (normalizedY * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(colors.accent, lineWidth: 2)

                // Benchmark line (if available)
                if let firstBenchmark = data.first?.benchmarkValue {
                    Path { path in
                        let stepX = width / CGFloat(max(data.count - 1, 1))

                        for (index, point) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let benchmarkMin = data.map { $0.benchmarkValue ?? 0 }.min() ?? 0
                            let benchmarkMax = data.map { $0.benchmarkValue ?? 0 }.max() ?? 1
                            let benchmarkRange = benchmarkMax - benchmarkMin
                            let normalizedY = benchmarkRange > 0 ? ((point.benchmarkValue ?? firstBenchmark) - benchmarkMin) / benchmarkRange : 0.5
                            let y = height - (normalizedY * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(colors.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
    }
}

// ============================================
// MARK: - Metric Card
// ============================================

struct MetricCard: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)

            Text(value)
                .font(AppFonts.monoTitle())
                .foregroundColor(colors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppFonts.small())
                    .foregroundColor(colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }
}
