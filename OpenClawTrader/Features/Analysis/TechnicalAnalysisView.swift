import SwiftUI
import Charts

//
//  TechnicalAnalysisView.swift
//  OpenClawTrader
//
//  功能：技术分析页面，K线图和技术指标展示
//

// ============================================
// MARK: - Technical Analysis View
// ============================================

struct TechnicalAnalysisView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var dataService = StockDataService.shared

    @State private var searchText = ""
    @State private var showStockPicker = false
    @State private var selectedCandle: KLineData?
    @State private var tooltipPosition: CGPoint = .zero

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // 股票信息
                    if let stock = dataService.currentStock {
                        stockInfoSection(stock: stock)
                    }

                    // K线图
                    klineChartSection

                    // 技术指标
                    if !dataService.selectedIndicators.isEmpty {
                        indicatorsSection
                    }

                    // 周期选择
                    periodSelector
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .navigationTitle("技术分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                indicatorSelector
            }
        }
        .sheet(isPresented: $showStockPicker) {
            StockPickerSheet(searchText: $searchText) { stock in
                Task {
                    await dataService.fetchKLineData(stockCode: stock.id)
                }
            }
        }
        .onAppear {
            if dataService.currentStock == nil {
                Task {
                    await dataService.fetchKLineData(stockCode: "000001")
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        Button(action: { showStockPicker = true }) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colors.textTertiary)

                if let stock = dataService.currentStock {
                    Text("\(stock.id) \(stock.name)")
                        .foregroundColor(colors.textPrimary)
                } else {
                    Text("搜索股票")
                        .foregroundColor(colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(colors.textTertiary)
            }
            .padding(AppSpacing.sm)
            .background(colors.backgroundSecondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Stock Info Section

    private func stockInfoSection(stock: StockInfo) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(stock.name)
                .font(AppFonts.title2())
                .foregroundColor(colors.textPrimary)

            Text(stock.id)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - K线图 Section

    private var klineChartSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // K线图
            if dataService.isLoading {
                ProgressView()
                    .frame(height: 300)
            } else if dataService.klineData.isEmpty {
                Text("暂无数据")
                    .foregroundColor(colors.textSecondary)
                    .frame(height: 300)
            } else {
                ZStack(alignment: .topLeading) {
                    KLineChartView(data: dataService.klineData) { candle, position in
                        selectedCandle = candle
                        tooltipPosition = position
                    }
                    .frame(height: 300)

                    // 选中蜡烛详情提示
                    if let candle = selectedCandle {
                        CandleTooltip(candle: candle)
                            .padding(AppSpacing.sm)
                            .background(colors.background.opacity(0.9))
                            .cornerRadius(AppRadius.small)
                            .shadow(radius: 4)
                            .padding(AppSpacing.sm)
                            .onTapGesture {
                                selectedCandle = nil
                            }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Indicators Section

    private var indicatorsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Array(dataService.selectedIndicators), id: \.self) { indicator in
                indicatorView(indicator)
            }
        }
    }

    @ViewBuilder
    private func indicatorView(_ indicator: IndicatorType) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(indicator.rawValue)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            switch indicator {
            case .ma:
                MAChartView(
                    data: dataService.klineData,
                    ma5: dataService.indicators.ma5,
                    ma10: dataService.indicators.ma10,
                    ma20: dataService.indicators.ma20
                )
                .frame(height: 120)

            case .macd:
                MACDChartView(data: dataService.indicators.macd)
                    .frame(height: 100)

            case .kdj:
                KDJChartView(data: dataService.indicators.kdj)
                    .frame(height: 100)

            case .rsi:
                RSIChartView(data: dataService.indicators.rsi)
                    .frame(height: 100)

            case .boll:
                BollingerChartView(
                    data: dataService.klineData,
                    boll: dataService.indicators.boll
                )
                .frame(height: 120)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(KLinePeriod.allCases) { period in
                Button(action: {
                    dataService.selectedPeriod = period
                    if let stock = dataService.currentStock {
                        Task {
                            await dataService.fetchKLineData(stockCode: stock.id, period: period)
                        }
                    }
                }) {
                    Text(period.rawValue)
                        .font(AppFonts.caption())
                        .foregroundColor(dataService.selectedPeriod == period ? colors.background : colors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(dataService.selectedPeriod == period ? colors.accent : colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Indicator Selector

    private var indicatorSelector: some View {
        Menu {
            ForEach(IndicatorType.allCases) { indicator in
                Button(action: {
                    if dataService.selectedIndicators.contains(indicator) {
                        dataService.selectedIndicators.remove(indicator)
                    } else {
                        dataService.selectedIndicators.insert(indicator)
                    }
                }) {
                    HStack {
                        Text(indicator.rawValue)
                        if dataService.selectedIndicators.contains(indicator) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(colors.accent)
        }
    }
}

// ============================================
// MARK: - K线详情提示
// ============================================

struct CandleTooltip: View {
    let candle: KLineData
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(candle.date))
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            HStack(spacing: 12) {
                tooltipItem(title: "开", value: candle.open)
                tooltipItem(title: "高", value: candle.high)
                tooltipItem(title: "低", value: candle.low)
                tooltipItem(title: "收", value: candle.close)
            }

            Text("涨跌: \(candle.isBullish ? "+" : "")\(String(format: "%.2f", candle.close - candle.open))")
                .font(AppFonts.small())
                .foregroundColor(candle.isBullish ? colors.accent : AppColors.error)
        }
        .padding(AppSpacing.sm)
    }

    private func tooltipItem(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(colors.textTertiary)
            Text(String(format: "%.2f", value))
                .font(AppFonts.small())
                .foregroundColor(colors.textPrimary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// ============================================
// MARK: - K线图 View
// ============================================

struct KLineChartView: View {
    let data: [KLineData]
    var onSelect: ((KLineData, CGPoint) -> Void)?
    @Environment(\.appColors) private var colors

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let candleWidth = width / CGFloat(data.count)

            let minPrice = data.map { $0.low }.min() ?? 0
            let maxPrice = data.map { $0.high }.max() ?? 100
            let priceRange = maxPrice - minPrice

            ZStack {
                // 价格网格
                priceGrid(minPrice: minPrice, maxPrice: maxPrice, height: height, width: width)

                // K线
                ForEach(Array(data.enumerated()), id: \.element.id) { index, candle in
                    let x = CGFloat(index) * candleWidth + candleWidth / 2
                    let yHigh = (1 - (candle.high - minPrice) / priceRange) * height
                    let yLow = (1 - (candle.low - minPrice) / priceRange) * height
                    let yOpen = (1 - (candle.open - minPrice) / priceRange) * height
                    let yClose = (1 - (candle.close - minPrice) / priceRange) * height

                    let color = candle.isBullish ? colors.accent : AppColors.error

                    // 上影线
                    Rectangle()
                        .fill(color)
                        .frame(width: 1, height: yLow - yHigh)
                        .position(x: x, y: (yHigh + yLow) / 2)

                    // 下影线
                    Rectangle()
                        .fill(color)
                        .frame(width: 1, height: yClose - yOpen)
                        .position(x: x, y: (yClose + yOpen) / 2)

                    // 实体
                    let bodyTop = min(yOpen, yClose)
                    let bodyBottom = max(yOpen, yClose)
                    let bodyHeight = max(1, bodyBottom - bodyTop)
                    Rectangle()
                        .fill(color)
                        .frame(width: max(2, candleWidth * 0.6), height: bodyHeight)
                        .position(x: x, y: bodyTop + bodyHeight / 2)
                        .onTapGesture {
                            onSelect?(candle, CGPoint(x: x, y: yHigh))
                        }
                }
            }
        }
    }

    private func priceGrid(minPrice: Double, maxPrice: Double, height: CGFloat, width: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5) { i in
                let price = minPrice + (maxPrice - minPrice) * Double(4 - i) / 4
                let y = height * CGFloat(i) / 4

                HStack {
                    Text(String(format: "%.2f", price))
                        .font(.system(size: 8))
                        .foregroundColor(colors.textTertiary)
                    Spacer()
                }
                .position(x: width / 2, y: y)

                Path { path in
                    path.move(to: CGPoint(x: 40, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(colors.textTertiary.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

// ============================================
// MARK: - MA 均线图
// ============================================

struct MAChartView: View {
    let data: [KLineData]
    let ma5: [Double?]
    let ma10: [Double?]
    let ma20: [Double?]
    @Environment(\.appColors) private var colors

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            let closes = data.map { $0.close }
            let minPrice = closes.min() ?? 0
            let maxPrice = closes.max() ?? 100
            let priceRange = maxPrice - minPrice

            Chart {
                ForEach(Array(ma5.enumerated()), id: \.offset) { index, value in
                    if let v = value {
                        LineMark(
                            x: .value("index", index),
                            y: .value("MA5", v)
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }

                ForEach(Array(ma10.enumerated()), id: \.offset) { index, value in
                    if let v = value {
                        LineMark(
                            x: .value("index", index),
                            y: .value("MA10", v)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }

                ForEach(Array(ma20.enumerated()), id: \.offset) { index, value in
                    if let v = value {
                        LineMark(
                            x: .value("index", index),
                            y: .value("MA20", v)
                        )
                        .foregroundStyle(.yellow)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 8))
                }
            }
        }
    }
}

// ============================================
// MARK: - MACD 图
// ============================================

struct MACDChartView: View {
    let data: MACDData?
    @Environment(\.appColors) private var colors

    var body: some View {
        if let data = data {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                let allValues = (data.dif + data.dea + data.histogram).compactMap { $0 }
                let maxVal = allValues.max() ?? 1
                let minVal = allValues.min() ?? -1
                let range = maxVal - minVal

                ZStack {
                    // 零轴
                    let zeroY = height / 2
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: zeroY))
                        path.addLine(to: CGPoint(x: width, y: zeroY))
                    }
                    .stroke(colors.textTertiary.opacity(0.5), lineWidth: 0.5)

                    // DIF线
                    Path { path in
                        let points = data.dif.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.dif.count) * width
                            let y = height / 2 - (v / range) * (height / 2)
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 1)

                    // DEA线
                    Path { path in
                        let points = data.dea.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.dea.count) * width
                            let y = height / 2 - (v / range) * (height / 2)
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.orange, lineWidth: 1)

                    // 柱状图
                    ForEach(Array(data.histogram.enumerated()), id: \.offset) { index, value in
                        if let v = value {
                            let x = CGFloat(index) / CGFloat(data.histogram.count) * width
                            let barHeight = abs(v) / range * (height / 2)
                            let y = v >= 0 ? height / 2 - barHeight : height / 2

                            Rectangle()
                                .fill(v >= 0 ? AppColors.error : colors.accent)
                                .frame(width: 2, height: barHeight)
                                .position(x: x, y: y + barHeight / 2)
                        }
                    }
                }
            }
        } else {
            Text("暂无数据")
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - KDJ 图
// ============================================

struct KDJChartView: View {
    let data: KDJData?
    @Environment(\.appColors) private var colors

    var body: some View {
        if let data = data {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack {
                    // 80超买线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.2))
                        path.addLine(to: CGPoint(x: width, y: height * 0.2))
                    }
                    .stroke(colors.textTertiary.opacity(0.3), lineWidth: 0.5)

                    // 20超卖线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.8))
                        path.addLine(to: CGPoint(x: width, y: height * 0.8))
                    }
                    .stroke(colors.textTertiary.opacity(0.3), lineWidth: 0.5)

                    // K线
                    Path { path in
                        let points = data.k.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.k.count) * width
                            let y = height - (v / 100) * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.pink, lineWidth: 1)

                    // D线
                    Path { path in
                        let points = data.d.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.d.count) * width
                            let y = height - (v / 100) * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.purple, lineWidth: 1)
                }
            }
        } else {
            Text("暂无数据")
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - RSI 图
// ============================================

struct RSIChartView: View {
    let data: RSIData?
    @Environment(\.appColors) private var colors

    var body: some View {
        if let data = data {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack {
                    // 70超买线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.3))
                        path.addLine(to: CGPoint(x: width, y: height * 0.3))
                    }
                    .stroke(colors.textTertiary.opacity(0.3), lineWidth: 0.5)

                    // 30超卖线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.7))
                        path.addLine(to: CGPoint(x: width, y: height * 0.7))
                    }
                    .stroke(colors.textTertiary.opacity(0.3), lineWidth: 0.5)

                    // RSI6线
                    Path { path in
                        let points = data.rsi6.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.rsi6.count) * width
                            let y = height - (v / 100) * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.red, lineWidth: 1)

                    // RSI12线
                    Path { path in
                        let points = data.rsi12.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(data.rsi12.count) * width
                            let y = height - (v / 100) * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 1)
                }
            }
        } else {
            Text("暂无数据")
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - 布林带图
// ============================================

struct BollingerChartView: View {
    let data: [KLineData]
    let boll: BollingerBandsData?
    @Environment(\.appColors) private var colors

    var body: some View {
        if let boll = boll {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                let closes = data.map { $0.close }
                let minPrice = closes.min() ?? 0
                let maxPrice = closes.max() ?? 100
                let priceRange = maxPrice - minPrice

                ZStack {
                    // 价格线
                    Path { path in
                        let points = closes.enumerated().map { index, value -> CGPoint in
                            let x = CGFloat(index) / CGFloat(closes.count) * width
                            let y = height - (value - minPrice) / priceRange * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(colors.textPrimary, lineWidth: 1)

                    // 上轨
                    Path { path in
                        let points = boll.upper.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(boll.upper.count) * width
                            let y = height - (v - minPrice) / priceRange * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.red.opacity(0.5), lineWidth: 0.5)

                    // 下轨
                    Path { path in
                        let points = boll.lower.enumerated().compactMap { index, value -> CGPoint? in
                            guard let v = value else { return nil }
                            let x = CGFloat(index) / CGFloat(boll.lower.count) * width
                            let y = height - (v - minPrice) / priceRange * height
                            return CGPoint(x: x, y: y)
                        }
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.green.opacity(0.5), lineWidth: 0.5)
                }
            }
        } else {
            Text("暂无数据")
                .foregroundColor(colors.textSecondary)
        }
    }
}

// ============================================
// MARK: - Stock Picker Sheet
// ============================================

struct StockPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColors) private var colors
    @Binding var searchText: String
    let onSelect: (StockInfo) -> Void

    @StateObject private var dataService = StockDataService.shared

    private var filteredStocks: [StockInfo] {
        if searchText.isEmpty {
            return [
                StockInfo(id: "000001", name: "平安银行", market: "深交所"),
                StockInfo(id: "000002", name: "万科A", market: "深交所"),
                StockInfo(id: "600000", name: "浦发银行", market: "上交所"),
                StockInfo(id: "600519", name: "贵州茅台", market: "上交所"),
                StockInfo(id: "000858", name: "五粮液", market: "深交所")
            ]
        } else {
            return dataService.searchStocks(keyword: searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredStocks) { stock in
                Button(action: {
                    onSelect(stock)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stock.name)
                                .foregroundColor(colors.textPrimary)
                            Text(stock.id)
                                .font(AppFonts.caption())
                                .foregroundColor(colors.textSecondary)
                        }
                        Spacer()
                        Text(stock.market)
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textTertiary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索股票代码或名称")
            .navigationTitle("选择股票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
