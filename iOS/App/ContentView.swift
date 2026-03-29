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
    @State private var isLoggedIn = true

    var body: some View {
        Group {
            if isLoggedIn {
                mainContent
            } else {
                LoginView(onLoginSuccess: {
                    isLoggedIn = true
                })
            }
        }
        .background(colors.background)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            TabContent(selectedTab: selectedTab, onLogout: {
                isLoggedIn = false
            })
            customTabBar
        }
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
        .padding(.bottom, 16)
        .background(colors.backgroundSecondary)
    }
}

// ============================================
// MARK: - Tab Content
// ============================================

struct TabContent: View {
    let selectedTab: Int
    let onLogout: () -> Void

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
                    UnifiedMeView(onLogout: onLogout)
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
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? colors.textPrimary : colors.textTertiary)
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? colors.textPrimary : colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .offset(y: 24)
        }
    }
}
