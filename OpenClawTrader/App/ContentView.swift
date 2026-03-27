import SwiftUI

//
//  ContentView.swift
//  OpenClawTrader
//
//  功能：主容器视图，包含底部TabBar导航
//  底部Tab：消息、交易、我的
//

// ============================================
// MARK: - Content View (Tab Container)
// ============================================

struct ContentView: View {
    @Environment(\.appColors) private var colors
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab Content
            TabContent(selectedTab: selectedTab)

            // Custom Tab Bar
            customTabBar
        }
        .background(colors.background)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabItem(icon: "bell", title: "消息", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabItem(icon: "chart.line.uptrend.xyaxis", title: "交易", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabItem(icon: "person", title: "我的", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, 20)
        .background(colors.backgroundSecondary)
    }
}

// ============================================
// MARK: - Tab Content
// ============================================

struct TabContent: View {
    let selectedTab: Int

    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                NavigationStack {
                    NotificationListView()
                }
            case 1:
                NavigationStack {
                    TradingDashboardView()
                }
            case 2:
                NavigationStack {
                    ProfileView()
                }
            default:
                NotificationListView()
            }
        }
    }
}

// ============================================
// MARK: - Tab Item
// ============================================

struct TabItem: View {
    @Environment(\.appColors) private var colors
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? colors.textPrimary : colors.textTertiary)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? colors.textPrimary : colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
    }
}
