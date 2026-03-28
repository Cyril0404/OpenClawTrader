import SwiftUI

//
//  SentimentAnalysisView.swift
//  OpenClawTrader
//
//  功能：舆情分析页面
//

// ============================================
// MARK: - Sentiment Analysis View
// ============================================

struct SentimentAnalysisView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = SentimentService.shared

    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showStockPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab选择
            Picker("", selection: $selectedTab) {
                Text("舆情榜单").tag(0)
                Text("个股舆情").tag(1)
                Text("热门帖子").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    switch selectedTab {
                    case 0:
                        rankingSection
                    case 1:
                        stockSentimentSection
                    case 2:
                        hotPostsSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .navigationTitle("舆情分析")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStockPicker) {
            StockPickerSheet(searchText: $searchText) { stock in
                Task {
                    await service.fetchSentiment(stockCode: stock.id, stockName: stock.name)
                }
            }
        }
        .onAppear {
            Task {
                await service.fetchRankings()
                await service.fetchHotPosts()
            }
        }
    }

    // MARK: - Ranking Section

    private var rankingSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // 标题
            HStack {
                Text("热门股票舆情榜")
                    .font(AppFonts.title2())
                    .foregroundColor(colors.textPrimary)
                Spacer()
                Text("更新时间: \(formatTime(service.stockSentiment?.lastUpdated ?? Date()))")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }

            // 榜单
            ForEach(service.rankings) { item in
                RankingRow(ranking: item)
            }
        }
    }

    // MARK: - Stock Sentiment Section

    private var stockSentimentSection: some View {
        VStack(spacing: AppSpacing.md) {
            // 搜索/选择股票
            Button(action: { showStockPicker = true }) {
                HStack {
                    if let sentiment = service.stockSentiment {
                        Text("\(sentiment.stockName) (\(sentiment.stockCode))")
                            .foregroundColor(colors.textPrimary)
                    } else {
                        Text("选择股票查看舆情")
                            .foregroundColor(colors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(colors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
            }
            .buttonStyle(.plain)

            // 舆情详情
            if let sentiment = service.stockSentiment {
                sentimentDetailCard(sentiment: sentiment)

                // 关键词
                keywordsSection(keywords: sentiment.keywords)
            } else {
                emptyStateView
            }
        }
    }

    private func sentimentDetailCard(sentiment: SentimentData) -> some View {
        VStack(spacing: AppSpacing.md) {
            // 舆情评分
            HStack {
                VStack(alignment: .leading) {
                    Text("舆情评分")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                    Text(String(format: "%.1f", sentiment.sentimentScore))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(sentimentColor(sentiment.sentimentScore))
                }

                Spacer()

                // 唱多/唱空比例
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text(sentiment.sentimentLabel.rawValue)
                            .font(AppFonts.body())
                            .foregroundColor(sentimentColor(sentiment.sentimentScore))
                    }
                    Text("较昨日 \(sentiment.trend >= 0 ? "+" : "")\(String(format: "%.1f", sentiment.trend))%")
                        .font(AppFonts.caption())
                        .foregroundColor(sentiment.trend >= 0 ? colors.accent : AppColors.error)
                }
            }

            // 比例条
            SentimentBar(
                bullish: sentiment.bullishPercent,
                neutral: sentiment.neutralPercent,
                bearish: sentiment.bearishPercent
            )

            // 统计数据
            HStack(spacing: AppSpacing.lg) {
                VStack {
                    Text("\(sentiment.discussionCount)")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                    Text("讨论数")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                VStack {
                    Text(String(format: "%.1f%%", sentiment.bullishPercent))
                        .font(AppFonts.body())
                        .foregroundColor(colors.accent)
                    Text("唱多")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                VStack {
                    Text(String(format: "%.1f%%", sentiment.bearishPercent))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.error)
                    Text("唱空")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private func keywordsSection(keywords: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("热门关键词")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - Hot Posts Section

    private var hotPostsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(service.hotPosts) { post in
                PostCard(post: post)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(colors.textTertiary)
            Text("选择股票查看舆情")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Helper

    private func sentimentColor(_ score: Double) -> Color {
        if score >= 30 { return colors.accent }
        if score <= -30 { return AppColors.error }
        return colors.textSecondary
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// ============================================
// MARK: - Ranking Row
// ============================================

struct RankingRow: View {
    let ranking: SentimentRanking
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 排名
            Text("\(ranking.rank)")
                .font(AppFonts.title2())
                .foregroundColor(rankingColor)
                .frame(width: 30)

            // 股票信息
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.stockName)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                Text(ranking.stockCode)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            // 舆情评分
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", ranking.sentimentScore))
                    .font(AppFonts.body())
                    .foregroundColor(rankingColor)
                Text("\(ranking.discussionCount)讨论")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private var rankingColor: Color {
        if ranking.rank <= 3 { return colors.accent }
        return colors.textPrimary
    }
}

// ============================================
// MARK: - Sentiment Bar
// ============================================

struct SentimentBar: View {
    let bullish: Double
    let neutral: Double
    let bearish: Double

    var body: some View {
        GeometryReader { geometry in
            let total = bullish + neutral + bearish
            let bullishWidth = geometry.size.width * bullish / total
            let neutralWidth = geometry.size.width * neutral / total
            let bearishWidth = geometry.size.width * bearish / total

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: bullishWidth)
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: neutralWidth)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: bearishWidth)
            }
        }
        .frame(height: 8)
        .cornerRadius(4)
    }
}

// ============================================
// MARK: - Post Card
// ============================================

struct PostCard: View {
    let post: SocialPost
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 头部
            HStack {
                // 平台标签
                Text(post.platform.rawValue)
                    .font(AppFonts.caption())
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(platformColor)
                    .cornerRadius(4)

                Text(post.author)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text(timeAgo(post.postedAt))
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }

            // 内容
            Text(post.content)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)
                .lineLimit(3)

            // 舆情标签
            HStack {
                Text(post.sentiment.rawValue)
                    .font(AppFonts.caption())
                    .foregroundColor(sentimentColor)

                Spacer()

                // 互动数据
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                        Text("\(post.likes)")
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                        Text("\(post.comments)")
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.up")
                        Text("\(post.shares)")
                    }
                }
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private var platformColor: Color {
        switch post.platform {
        case .twitter: return .blue
        case .xueqiu: return .green
        case .guba: return .orange
        case .weibo: return .red
        }
    }

    private var sentimentColor: Color {
        switch post.sentiment {
        case .bullish: return colors.accent
        case .neutral: return colors.textSecondary
        case .bearish: return AppColors.error
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

// ============================================
// MARK: - Flow Layout
// ============================================

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
