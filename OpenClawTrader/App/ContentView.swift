import SwiftUI

//
//  ContentView.swift
//  OpenClawTrader
//
//  Tab结构（2026-03-27 重构）：
//  聊天 — 极简AI对话
//  行情 — 股票行情
//  我的 — 持仓+消息+AI建议+设置（全部合并）
//

// ============================================
// MARK: - Content View (Tab Container)
// ============================================

struct ContentView: View {
    @Environment(\.appColors) private var colors
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            TabContent(selectedTab: selectedTab)
            customTabBar
        }
        .background(colors.background)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabItem(icon: "bubble.left.and.bubble.right", title: "聊天", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabItem(icon: "chart.line.uptrend.xyaxis", title: "行情", isSelected: selectedTab == 1) {
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
                    SimpleChatView()
                }
            case 1:
                NavigationStack {
                    TradingDashboardView()
                }
            case 2:
                NavigationStack {
                    UnifiedMeView()
                }
            default:
                SimpleChatView()
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
