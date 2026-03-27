import SwiftUI

//
//  NotificationListView.swift
//  OpenClawTrader
//
//  功能：消息通知列表，支持多类型筛选
//

// ============================================
// MARK: - Notification List View
// ============================================

struct NotificationListView: View {
    @Environment(\.appColors) private var colors
    @State private var notifications: [AppNotification] = AppNotification.previewList
    @State private var selectedFilter: NotificationFilter = .all

    enum NotificationFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case agent = "Agent"
        case workflow = "工作流"
        case trade = "交易"
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.isRead }
        case .agent:
            return notifications.filter { $0.type == .agent }
        case .workflow:
            return notifications.filter { $0.type == .workflow }
        case .trade:
            return notifications.filter { $0.type == .trade || $0.type == .price }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "消息")

            VStack(spacing: AppSpacing.md) {
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

                // Notifications List
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        if filteredNotifications.isEmpty {
                            EmptyState(
                                icon: "bell.slash",
                                title: "暂无消息",
                                subtitle: "您当前没有待处理的消息"
                            )
                        } else {
                            ForEach(filteredNotifications) { notification in
                                NotificationRow(notification: notification)
                                    .onTapGesture {
                                        markAsRead(notification)
                                    }
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

    private func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
    }
}

// ============================================
// MARK: - Notification Row
// ============================================

struct NotificationRow: View {
    @Environment(\.appColors) private var colors
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: notification.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: notification.iconColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    if !notification.isRead {
                        Circle()
                            .fill(colors.accent)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(notification.body)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(2)

                Text(formatTime(notification.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(notification.isRead ? colors.backgroundSecondary : colors.backgroundTertiary)
        .cornerRadius(AppRadius.medium)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
