import SwiftUI

//
//  ProfileView.swift
//  OpenClawTrader
//
//  功能：个人中心页面，包含账户管理、OpenClaw管理入口
//

// ============================================
// MARK: - Profile View
// ============================================

struct ProfileView: View {
    @Environment(\.appColors) private var colors
    @Environment(ThemeManager.self) private var themeManager
    @State private var isConnected = StorageService.shared.isConnected
    @State private var showingThemePicker = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "我的")

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Profile Header
                    profileHeader

                    // Connection Status
                    connectionCard

                    // OpenClaw Management Section (when connected)
                    if isConnected {
                        openClawSection
                    }

                    // Settings Section
                    settingsSection
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(colors.backgroundTertiary)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(colors.textTertiary)
                )

            Text("未登录")
                .font(AppFonts.title2())
                .foregroundColor(colors.textPrimary)

            Text("连接 OpenClaw 以开始使用")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
        .padding(.vertical, AppSpacing.lg)
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Circle()
                    .fill(isConnected ? AppColors.success : colors.textTertiary)
                    .frame(width: 8, height: 8)

                Text(isConnected ? "已连接 OpenClaw" : "未连接")
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Text(isConnected ? "在线" : "离线")
                    .font(AppFonts.caption())
                    .foregroundColor(isConnected ? AppColors.success : colors.textTertiary)
            }

            if isConnected {
                SecondaryButton(title: "断开连接") {
                    StorageService.shared.disconnect()
                    isConnected = false
                }
            } else {
                NavigationLink(destination: OpenClawConnectView()) {
                    Text("连接 OpenClaw")
                        .font(AppFonts.body())
                        .fontWeight(.medium)
                        .foregroundColor(colors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(colors.accent)
                        .cornerRadius(AppRadius.small)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    // MARK: - OpenClaw Section

    private var openClawSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "OpenClaw 管理")

            VStack(spacing: 0) {
                NavigationLink(destination: ConsoleDashboardView()) {
                    ListItem(
                        icon: "square.grid.2x2",
                        title: "控制台概览",
                        subtitle: "Workspace 状态总览",
                        showArrow: true
                    )
                }

                AppDivider()

                NavigationLink(destination: ModelListView()) {
                    ListItem(
                        icon: "cpu",
                        title: "模型管理",
                        subtitle: nil,
                        showArrow: true
                    )
                }

                AppDivider()

                NavigationLink(destination: AgentListView()) {
                    ListItem(
                        icon: "person.2",
                        title: "Agent 管理",
                        subtitle: nil,
                        showArrow: true
                    )
                }

                AppDivider()

                NavigationLink(destination: WorkflowListView()) {
                    ListItem(
                        icon: "arrow.triangle.branch",
                        title: "工作流",
                        subtitle: nil,
                        showArrow: true
                    )
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "设置")

            VStack(spacing: 0) {
                // Theme Setting
                Button {
                    showingThemePicker = true
                } label: {
                    ListItem(
                        icon: "paintbrush",
                        title: "外观",
                        subtitle: themeManager.mode.rawValue,
                        showArrow: true
                    )
                }
                .buttonStyle(.plain)

                AppDivider()

                ListItem(icon: "bell", title: "通知设置", subtitle: nil)
                AppDivider()
                ListItem(icon: "lock", title: "隐私设置", subtitle: nil)
                AppDivider()
                ListItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: nil)
                AppDivider()
                ListItem(icon: "info.circle", title: "关于", subtitle: "v1.0.0")
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }
}

// ============================================
// MARK: - Theme Picker Sheet
// ============================================

struct ThemePickerSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Button {
                            themeManager.mode = mode
                            dismiss()
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                    .foregroundColor(colors.textPrimary)

                                Spacer()

                                if themeManager.mode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(colors.textSecondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("外观")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
