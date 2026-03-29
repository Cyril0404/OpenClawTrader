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
    @State private var showUnbindConfirm = false
    @State private var showPrivacyPolicy = false
    @State private var showFreeMembership = false
    @State private var showShareSheet = false

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
        .alert("确认解绑", isPresented: $showUnbindConfirm) {
            Button("取消", role: .cancel) {}
            Button("解绑", role: .destructive) {
                PairingService.shared.unbind()
                isConnected = false
            }
        } message: {
            Text("确定要解除与 OpenClaw 的连接吗？")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showFreeMembership) {
            FreeMembershipView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["推荐你使用 OpenClawTrader，轻松交易，随时随地行情分析！https://openclaw.example.com"])
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
                SecondaryButton(title: "解绑") {
                    showUnbindConfirm = true
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

                Button {
                    showPrivacyPolicy = true
                } label: {
                    ListItem(icon: "lock.shield", title: "隐私政策", subtitle: nil, showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                Button {
                    showFreeMembership = true
                } label: {
                    ListItem(icon: "gift", title: "领取免费会员", subtitle: nil, showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                Button {
                    rateApp()
                } label: {
                    ListItem(icon: "star", title: "给个五星好评", subtitle: nil, showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                Button {
                    showShareSheet = true
                } label: {
                    ListItem(icon: "square.and.arrow.up", title: "分享给朋友", subtitle: nil, showArrow: true)
                }
                .buttonStyle(.plain)

                AppDivider()

                ListItem(icon: "bell", title: "通知设置", subtitle: nil)
                AppDivider()
                ListItem(icon: "questionmark.circle", title: "帮助与反馈", subtitle: nil)
                AppDivider()
                ListItem(icon: "info.circle", title: "关于", subtitle: "v1.0.0")
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Actions

    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXX?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// ============================================
// MARK: - Privacy Policy View
// ============================================

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColors) private var colors

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("隐私政策")
                        .font(AppFonts.title1())
                        .foregroundColor(colors.textPrimary)

                    Text("""
                    最后更新日期：2026年3月28日

                    本隐私政策阐述了 OpenClawTrader 如何收集、使用和保护您的个人信息。

                    **1. 信息收集**
                    我们收集您提供的账户信息、设备信息和使用数据，以提供和改进我们的服务。

                    **2. 信息使用**
                    您的信息用于：
                    - 提供和维持服务
                    - 改进和优化服务
                    - 保护您的账户安全

                    **3. 信息保护**
                    我们采用行业标准的安全措施来保护您的个人信息。

                    **4. 联系我们**
                    如有任何隐私相关问题，请联系我们。
                    """)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                }
                .padding(AppSpacing.lg)
            }
            .background(colors.background)
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// ============================================
// MARK: - Free Membership View
// ============================================

struct FreeMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColors) private var colors

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Spacer()

                Image(systemName: "gift.fill")
                    .font(.system(size: 72))
                    .foregroundColor(colors.accent)

                VStack(spacing: AppSpacing.sm) {
                    Text("免费会员")
                        .font(AppFonts.title1())
                        .foregroundColor(colors.textPrimary)

                    Text("邀请好友即可获得免费会员资格")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppSpacing.md) {
                    FeatureRow(icon: "star.fill", text: "享受高级分析功能")
                    FeatureRow(icon: "chart.bar.fill", text: "无限查看历史数据")
                    FeatureRow(icon: "bell.fill", text: "优先接收行情提醒")
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("立即邀请")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(colors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(colors.accent)
                        .cornerRadius(AppRadius.small)
                }
                .padding(.horizontal, AppSpacing.xl)
            }
            .padding(.vertical, AppSpacing.xl)
            .background(colors.background)
            .navigationTitle("免费会员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(colors.accent)
                .frame(width: 32)
            Text(text)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }
}

// ============================================
// MARK: - Share Sheet
// ============================================

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
