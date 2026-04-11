import SwiftUI

//
//  TradeProfileView.swift
//  OpenClawTrader
//
//  用户投资画像展示页
//

struct TradeProfileView: View {
    @StateObject private var viewModel = TradeProfileViewModel()
    @State private var showTradeImport = false
    @State private var showHoldings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("分析中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let profile = viewModel.profile {
                    // 头部：一句话定位
                    headerSection(profile)

                    // 雷达图
                    radarChartSection(profile)

                    // 基础指标
                    statsSection(profile)

                    // 关键洞察
                    insightsSection(profile)

                    // 风险预警
                    if !profile.riskWarnings.isEmpty {
                        warningsSection(profile)
                    }

                    // 个性化建议
                    if !profile.personalizedAdvice.isEmpty {
                        adviceSection(profile)
                    }

                    // 操作按钮
                    actionButtons

                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("投资画像")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadProfile()
        }
        .sheet(isPresented: $showTradeImport) {
            TradeImportView(onComplete: {
                Task { await viewModel.loadProfile() }
            })
        }
        .sheet(isPresented: $showHoldings) {
            HoldingsListView()
        }
        .task {
            await viewModel.loadProfile()
        }
    }

    // MARK: - Header Section

    private func headerSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("你的投资画像")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                ConfidenceBadge(confidence: profile.confidence)
            }

            Text(profile.oneLiner.isEmpty ? "暂无足够数据" : profile.oneLiner)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 性格标签
            if !profile.personalityTags.primary.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(profile.personalityTags.primary, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Radar Chart Section

    private func radarChartSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("能力雷达")
                .font(.headline)

            CapabilityRadarView(dimensions: profile.capabilityRadar)
                .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Stats Section

    private func statsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基础指标")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "交易笔数", value: "\(profile.totalTrades)", icon: "chart.bar.fill", color: .blue)
                StatCard(title: "胜率", value: "\(Int(profile.winRate * 100))%", icon: "checkmark.circle.fill", color: .green)
                StatCard(title: "平均持股", value: "\(String(format: "%.1f", profile.avgHoldingDays))天", icon: "calendar", color: .orange)
                StatCard(title: "撤单率", value: "\(Int(profile.cancelRate * 100))%", icon: "xmark.circle.fill", color: profile.cancelRate > 0.2 ? .red : .gray)
                StatCard(title: "买入", value: "\(profile.buyCount)", icon: "arrow.up.circle.fill", color: .red)
                StatCard(title: "卖出", value: "\(profile.sellCount)", icon: "arrow.down.circle.fill", color: .purple)
            }

            Divider()

            HStack {
                Text("风险等级")
                    .foregroundColor(.secondary)
                Spacer()
                RiskLevelBadge(level: profile.riskLevel)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Insights Section

    private func insightsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("关键洞察")
                    .font(.headline)
            }

            ForEach(profile.insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Text(insight)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            if !profile.topStocks.isEmpty {
                Divider()

                Text("重点交易股票")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(profile.topStocks, id: \.self) { stock in
                        Text(stock)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Warnings Section

    private func warningsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("风险预警")
                    .font(.headline)
            }

            ForEach(profile.riskWarnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 10) {
                    Text(warning)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Advice Section

    private func adviceSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.blue)
                Text("个性化建议")
                    .font(.headline)
            }

            ForEach(profile.personalizedAdvice.indices, id: \.self) { index in
                let advice = profile.personalizedAdvice[index]
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(advice.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        PriorityBadge(priority: advice.priority)
                    }

                    Text(advice.content)
                        .font(.body)

                    Text("为什么：\(advice.why)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showTradeImport = true
            } label: {
                Label("上传委托单", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button {
                showHoldings = true
            } label: {
                Label("查看持仓", systemImage: "chart.pie.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }

            Button {
                Task { await viewModel.regenerateProfile() }
            } label: {
                Label("重新分析", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("暂无投资画像")
                .font(.title2)
                .fontWeight(.semibold)

            Text("上传您的委托单，开始生成专属投资画像")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showTradeImport = true
            } label: {
                Label("上传委托单", systemImage: "doc.viewfinder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
}

// MARK: - ViewModel

@MainActor
class TradeProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = TradeProfileService.shared

    func loadProfile() async {
        isLoading = true
        profile = service.getProfile() ?? service.generateProfile()
        isLoading = false
    }

    func regenerateProfile() async {
        isLoading = true
        profile = service.generateProfile()
        isLoading = false
    }
}

// MARK: - Supporting Views

struct ConfidenceBadge: View {
    let confidence: String

    var color: Color {
        switch confidence {
        case "高": return .green
        case "中": return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(confidence)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct RiskLevelBadge: View {
    let level: String

    var color: Color {
        switch level {
        case "高": return .red
        case "中高": return .orange
        case "中": return .yellow
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < riskLevelIndex ? color : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            Text(level)
                .font(.caption)
                .foregroundColor(color)
        }
    }

    private var riskLevelIndex: Int {
        switch level {
        case "高": return 5
        case "中高": return 4
        case "中": return 3
        case "中低": return 2
        default: return 1
        }
    }
}

struct PriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "高": return .red
        case "中": return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(priority)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CapabilityRadarView: View {
    let dimensions: [String: CapabilityDimension]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) / 2 - 30

            ZStack {
                // 背景圆
                ForEach(1..<5) { i in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: maxRadius * 2 * CGFloat(i) / 4, height: maxRadius * 2 * CGFloat(i) / 4)
                        .position(center)
                }

                // 轴线
                let dimensionKeys = Array(dimensions.keys).sorted()
                let angleStep = 2 * .pi / Double(max(dimensionKeys.count, 1))

                ForEach(0..<dimensionKeys.count, id: \.self) { i in
                    let angle = Double(i) * angleStep - .pi / 2
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + maxRadius * cos(angle),
                            y: center.y + maxRadius * sin(angle)
                        ))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }

                // 数据区域
                Path { path in
                    for (i, key) in dimensionKeys.enumerated() {
                        let dimension = dimensions[key] ?? CapabilityDimension()
                        let score = Double(dimension.score) / 5.0
                        let angle = Double(i) * angleStep - .pi / 2
                        let point = CGPoint(
                            x: center.x + maxRadius * score * cos(angle),
                            y: center.y + maxRadius * score * sin(angle)
                        )
                        if i == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()
                }
                .fill(Color.blue.opacity(0.3))
                .stroke(Color.blue, lineWidth: 2)

                // 标签
                ForEach(0..<dimensionKeys.count, id: \.self) { i in
                    let key = dimensionKeys[i]
                    let angle = Double(i) * angleStep - .pi / 2
                    let labelRadius = maxRadius + 20

                    Text(key)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(CGPoint(
                            x: center.x + labelRadius * cos(angle),
                            y: center.y + labelRadius * sin(angle)
                        ))
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Trade Import View

struct TradeImportView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var ocrText = ""
    @State private var parsedTrades: [Trade] = []
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("上传委托单截图，OCR识别后自动解析")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    showImagePicker = true
                } label: {
                    Label("选择图片", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                if !ocrText.isEmpty {
                    Text("识别结果：")
                        .font(.headline)
                    Text(ocrText)
                        .font(.caption)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("导入交易记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Holdings List View

struct HoldingsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = TradeProfileService.shared
    @State private var holdings: [Holding] = []
    @State private var showAddHolding = false

    var body: some View {
        NavigationStack {
            List {
                if holdings.isEmpty {
                    Text("暂无持仓数据")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(holdings) { holding in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(holding.name)
                                    .fontWeight(.semibold)
                                Text(holding.code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(holding.quantity)股")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("当前持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                holdings = service.getHoldings().holdings
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TradeProfileView()
    }
}
