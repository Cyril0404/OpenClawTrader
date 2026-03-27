import SwiftUI

// ============================================
// MARK: - Console Dashboard View
// ============================================

struct ConsoleDashboardView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @State private var showingWorkspacePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Workspace Selector
                    workspaceSelector

                    // Stats Grid
                    statsGrid

                    // Models Section
                    modelsSection

                    // Recent Agents
                    recentAgentsSection

                    // Active Workflows
                    activeWorkflowsSection
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showingWorkspacePicker) {
            WorkspacePickerView()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("控制台")
                    .font(AppFonts.largeTitle())
                    .foregroundColor(colors.textPrimary)

                if let workspace = service.currentWorkspace {
                    Text(workspace.name)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            Spacer()

            IconButton(icon: "bell") {
                // Notifications
            }
            IconButton(icon: "gearshape") {
                // Settings
            }
        }
    }

    // MARK: - Workspace Selector

    private var workspaceSelector: some View {
        Button(action: { showingWorkspacePicker = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前工作空间")
                        .font(AppFonts.small())
                        .foregroundColor(colors.textTertiary)

                    Text(service.currentWorkspace?.name ?? "未选择")
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            if let workspace = service.currentWorkspace {
                InfoCard(title: "活跃 Agent", value: "\(workspace.agentCount)")
                InfoCard(title: "今日 Tokens", value: formatTokens(workspace.tokenUsage.usedToday))
                InfoCard(title: "工作流", value: "\(workspace.workflowCount)", trend: workspace.workflowCount > 0 ? .up : .neutral)
                InfoCard(title: "错误率", value: "0.2", unit: "%", trend: .down)
            }
        }
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "模型")

            VStack(spacing: 0) {
                ForEach(service.models.prefix(3)) { model in
                    ModelRowView(model: model) {
                        // Model tap
                    }

                    if model.id != service.models.prefix(3).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Recent Agents

    private var recentAgentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "最近 Agent")
                Spacer()
                NavigationLink(destination: AgentListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(service.agents.prefix(3)) { agent in
                    ListItem(
                        icon: "cpu",
                        title: agent.name,
                        subtitle: "最后活跃 \(timeAgo(agent.lastActiveAt))"
                    )

                    if agent.id != service.agents.prefix(3).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Active Workflows

    private var activeWorkflowsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionHeader(title: "活跃工作流")
                Spacer()
                NavigationLink(destination: WorkflowListView()) {
                    Text("查看全部")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(service.workflows.filter { $0.status == .active }.prefix(2)) { workflow in
                    WorkflowRowView(workflow: workflow)

                    if workflow.id != service.workflows.filter({ $0.status == .active }).prefix(2).last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval)) 秒前"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        }
        return "\(Int(interval / 86400)) 天前"
    }
}

// ============================================
// MARK: - Model Row View
// ============================================

struct ModelRowView: View {
    @Environment(\.appColors) private var colors
    let model: AIModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(model.status == .active ? AppColors.success : colors.textTertiary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    Text(model.provider)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                if model.isDefault {
                    StatusBadge(text: "默认", color: AppColors.info)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.textTertiary)
            }
            .padding(AppSpacing.md)
        }
    }
}

// ============================================
// MARK: - Workflow Row View
// ============================================

struct WorkflowRowView: View {
    @Environment(\.appColors) private var colors
    let workflow: Workflow

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                HStack(spacing: AppSpacing.xs) {
                    Text("\(workflow.totalRuns) 次运行")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    if workflow.failedRuns > 0 {
                        Text("· \(workflow.failedRuns) 失败")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.error)
                    }
                }
            }

            Spacer()

            StatusBadge(
                text: workflow.status.rawValue,
                color: workflow.status == .active ? AppColors.success : (workflow.status == .error ? AppColors.error : colors.textTertiary)
            )
        }
        .padding(AppSpacing.md)
    }
}
