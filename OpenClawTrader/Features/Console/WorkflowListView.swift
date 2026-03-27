import SwiftUI

//
//  WorkflowListView.swift
//  OpenClawTrader
//
//  功能：工作流列表，支持状态筛选
//

// ============================================
// MARK: - Workflow List View
// ============================================

struct WorkflowListView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @State private var selectedStatus: WorkflowStatus? = nil

    enum WorkflowStatus: String, CaseIterable {
        case all = "全部"
        case active = "活跃"
        case paused = "暂停"
        case error = "错误"
    }

    private var filteredWorkflows: [Workflow] {
        if let selected = selectedStatus {
            switch selected {
            case .active: return service.workflows.filter { $0.status == .active }
            case .paused: return service.workflows.filter { $0.status == .paused }
            case .error: return service.workflows.filter { $0.status == .error }
            default: break
            }
        }
        return service.workflows
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "工作流")

            VStack(spacing: AppSpacing.md) {
                // Status Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(WorkflowStatus.allCases, id: \.self) { status in
                            Button(action: { selectedStatus = (status == .all ? nil : status) }) {
                                Text(status.rawValue)
                                    .font(AppFonts.caption())
                                    .foregroundColor(selectedStatus == status || (status == .all && selectedStatus == nil) ? colors.background : colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedStatus == status || (status == .all && selectedStatus == nil) ? colors.accent : colors.backgroundSecondary)
                                    .cornerRadius(AppRadius.full)
                            }
                        }
                    }
                }

                // Workflows List
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        if filteredWorkflows.isEmpty {
                            EmptyState(
                                icon: "arrow.triangle.branch",
                                title: "没有工作流",
                                subtitle: "当前筛选条件下没有工作流"
                            )
                        } else {
                            ForEach(filteredWorkflows) { workflow in
                                NavigationLink(destination: WorkflowMonitorView(workflow: workflow)) {
                                    WorkflowCard(workflow: workflow)
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
}

// ============================================
// MARK: - Workflow Card
// ============================================

struct WorkflowCard: View {
    @Environment(\.appColors) private var colors
    let workflow: Workflow

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    Text(workflow.description)
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(
                    text: statusText,
                    color: statusColor
                )
            }

            HStack(spacing: AppSpacing.lg) {
                StatColumn(title: "触发方式", value: workflow.triggerType.rawValue)
                StatColumn(title: "总运行", value: "\(workflow.totalRuns)")
                StatColumn(title: "失败", value: "\(workflow.failedRuns)", valueColor: workflow.failedRuns > 0 ? AppColors.error : colors.textSecondary)
                StatColumn(title: "平均时长", value: String(format: "%.1fs", workflow.avgDuration))
            }

            if let lastRun = workflow.lastRunAt {
                Text("最后运行: \(formatDate(lastRun))")
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private var statusText: String {
        switch workflow.status {
        case .active: return "活跃"
        case .paused: return "暂停"
        case .error: return "错误"
        case .draft: return "草稿"
        }
    }

    private var statusColor: Color {
        switch workflow.status {
        case .active: return AppColors.success
        case .paused: return AppColors.warning
        case .error: return AppColors.error
        case .draft: return AppColors.textTertiary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatColumn: View {
    @Environment(\.appColors) private var colors
    let title: String
    let value: String
    var valueColor: Color = Color(hex: "FFFFFF")

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)

            Text(value)
                .font(AppFonts.monoCaption())
                .foregroundColor(valueColor)
        }
    }
}
