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
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingOpenClawConnect = false
    @State private var showingMobilePairing = false
    @State private var showingSkillsView = false
    let onLogout: () -> Void

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

                // 4. 设置
                settingsSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet()
        }
        .sheet(isPresented: $showingOpenClawConnect) {
            OpenClawConnectView()
        }
        .sheet(isPresented: $showingMobilePairing) {
            MobilePairingView()
        }
        .sheet(isPresented: $showingSkillsView) {
            NavigationStack {
                SkillsView()
            }
        }
        .alert("退出登录", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("确认退出", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
        .alert("注销账号", isPresented: $showingDeleteAccountAlert) {
            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) {
                performDeleteAccount()
            }
        } message: {
            Text("注销后将删除所有账号数据，此操作不可恢复。确定要注销账号吗？")
        }
    }

    // MARK: - Actions

    /// 退出登录
    private func performLogout() {
        StorageService.shared.disconnect()
        OpenClawService.shared.reset()
        onLogout()
    }

    /// 注销账号
    private func performDeleteAccount() {
        StorageService.shared.deleteAccount()
        OpenClawService.shared.reset()
        TradingService.shared.reset()
        onLogout()
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
            Button(action: { showingOpenClawConnect = true }) {
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

            // 移动端配对
            Button(action: { showingMobilePairing = true }) {
                HStack {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 16))
                    Text("移动端配对")
                        .font(AppFonts.caption())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(colors.textTertiary)
                }
                .foregroundColor(colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
            }

            // 技能控制
            Button(action: { showingSkillsView = true }) {
                HStack {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 16))
                    Text("技能控制")
                        .font(AppFonts.caption())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(colors.textTertiary)
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

                ListItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: nil)
                AppDivider()
                ListItem(icon: "info.circle", title: "关于", subtitle: "v1.0.0")

                AppDivider()

                // 退出登录
                Button(action: { showingLogoutAlert = true }) {
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

                AppDivider()

                // 注销账号
                Button(action: { showingDeleteAccountAlert = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.error)
                            .frame(width: 24)
                        Text("注销账号")
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
