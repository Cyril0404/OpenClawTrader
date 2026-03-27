import SwiftUI

//
//  UnifiedMeView.swift
//  OpenClawTrader
//
//  功能：合并后的「我的」页面
//  包含：个人账户 + OpenClaw连接管理 + 消息通知 + 持仓 + 设置
//

// ============================================
// MARK: - Unified Me View
// ============================================

struct UnifiedMeView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var tradingService = TradingService.shared
    @StateObject private var service = OpenClawService.shared
    @State private var notifications: [AppNotification] = AppNotification.previewList
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingThemePicker = false

    enum NotificationFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case agent = "Agent"
        case trade = "交易"
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all: return notifications
        case .unread: return notifications.filter { !$0.isRead }
        case .agent: return notifications.filter { $0.type == .agent }
        case .trade: return notifications.filter { $0.type == .trade || $0.type == .price }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // 1. Profile Header
                profileHeader

                // 2. OpenClaw 连接管理（单独版块）
                openClawSection

                // 3. 消息通知
                notificationsSection

                // 4. 持仓列表
                holdingsSection

                // 5. 设置
                settingsSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(colors.backgroundTertiary)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(colors.textTertiary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("倪子凡")
                    .font(AppFonts.title2())
                    .foregroundColor(colors.textPrimary)
                Text("在线")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.success)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - OpenClaw Section

    private var openClawSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "OpenClaw 连接")

            VStack(spacing: 0) {
                // 当前连接的 Workspace
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.currentWorkspace?.name ?? "未选择")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                        Text("OpenClaw 已连接")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                    }

                    Spacer()

                    Button(action: {}) {
                        Text("断开")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.error)
                    }
                }
                .padding(AppSpacing.md)

                AppDivider()

                // 其他可连接的 Workspace
                ForEach(service.workspaces.filter { !$0.isActive }) { workspace in
                    HStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(colors.textTertiary)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workspace.name)
                                .font(AppFonts.body())
                                .foregroundColor(colors.textPrimary)
                            Text("\(workspace.agentCount) Agents · \(workspace.workflowCount) 工作流")
                                .font(AppFonts.caption())
                                .foregroundColor(colors.textSecondary)
                        }

                        Spacer()

                        Button(action: { service.switchWorkspace(workspace) }) {
                            Text("连接")
                                .font(AppFonts.caption())
                                .foregroundColor(colors.accent)
                        }
                    }
                    .padding(AppSpacing.md)

                    if workspace.id != service.workspaces.filter({ !$0.isActive }).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)

            // 添加更多 OpenClaw
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                    Text("添加 OpenClaw")
                        .font(AppFonts.caption())
                }
                .foregroundColor(colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "消息通知")
                Spacer()
                let unread = notifications.filter { !$0.isRead }.count
                if unread > 0 {
                    Text("\(unread)条未读")
                        .font(AppFonts.small())
                        .foregroundColor(colors.accent)
                }
            }

            // Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(NotificationFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.rawValue)
                                .font(AppFonts.caption())
                                .foregroundColor(selectedFilter == filter ? colors.background : colors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == filter ? colors.accent : colors.backgroundSecondary)
                                .cornerRadius(AppRadius.full)
                        }
                    }
                }
            }

            // List
            VStack(spacing: AppSpacing.xs) {
                if filteredNotifications.isEmpty {
                    EmptyState(
                        icon: "bell.slash",
                        title: "暂无消息",
                        subtitle: "当前没有待处理的消息"
                    )
                } else {
                    ForEach(Array(filteredNotifications.prefix(3))) { notification in
                        UnifiedNotificationRow(notification: notification) {
                            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                                notifications[index].isRead = true
                            }
                        }
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "持仓列表")
                Spacer()
                NavigationLink(destination: HoldingListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.accent)
                }
            }

            if let portfolio = tradingService.portfolio, !portfolio.holdings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(portfolio.holdings.prefix(3))) { holding in
                        HoldingRow(holding: holding)
                        if holding.id != portfolio.holdings.prefix(3).last?.id {
                            AppDivider()
                        }
                    }
                }
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
            } else {
                EmptyState(
                    icon: "chart.bar",
                    title: "暂无持仓",
                    subtitle: "导入持仓数据以开始使用"
                )
                .padding(AppSpacing.lg)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "设置")

            VStack(spacing: 0) {
                Button {
                    showingThemePicker = true
                } label: {
                    ListItem(icon: "paintbrush", title: "外观", subtitle: "深色模式", showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                ListItem(icon: "bell", title: "通知设置", subtitle: nil)
                AppDivider()
                NavigationLink(destination: AgentListView()) {
                    ListItem(icon: "person.2", title: "Agent 管理", subtitle: nil, showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                ListItem(icon: "cpu", title: "API Key 设置", subtitle: nil, showArrow: true)
                AppDivider()
                ListItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: nil)
                AppDivider()
                ListItem(icon: "info.circle", title: "关于", subtitle: "v1.0.0")

                AppDivider()

                // 退出登录和注销用户 - 放在最底下
                Button(action: {}) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.error)
                            .frame(width: 24)
                        Text("退出登录")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.error)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }
}

// ============================================
// MARK: - Supporting Views
// ============================================

struct UnifiedNotificationRow: View {
    @Environment(\.appColors) private var colors
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: notification.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: notification.iconColor))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(notification.title)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                        if !notification.isRead {
                            Circle().fill(colors.accent).frame(width: 6, height: 6)
                        }
                    }
                    Text(notification.body)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(AppSpacing.md)
        }
        .buttonStyle(.plain)
    }
}
