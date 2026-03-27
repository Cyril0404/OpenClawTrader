import SwiftUI

//
//  WorkflowMonitorView.swift
//  OpenClawTrader
//
//  功能：工作流监控页面，展示实时日志流和步骤详情
//

// ============================================
// MARK: - Workflow Monitor View
// ============================================

struct WorkflowMonitorView: View {
    @Environment(\.appColors) private var colors
    let workflow: Workflow
    @StateObject private var service = OpenClawService.shared
    @State private var logs: [WorkflowLog] = []
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(workflow.name)
                    .font(AppFonts.title2())
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Button(action: toggleWorkflow) {
                    Text(workflow.status == .active ? "暂停" : "启动")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colors.backgroundTertiary)
                        .cornerRadius(AppRadius.full)
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Info Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                        InfoCard(title: "总运行", value: "\(workflow.totalRuns)")
                        InfoCard(title: "失败", value: "\(workflow.failedRuns)")
                        InfoCard(title: "成功率", value: successRate)
                        InfoCard(title: "平均时长", value: String(format: "%.1fs", workflow.avgDuration))
                    }

                    // Steps
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "工作流步骤")

                        VStack(spacing: 0) {
                            ForEach(workflow.steps) { step in
                                StepRow(step: step)

                                if step.id != workflow.steps.last?.id {
                                    AppDivider()
                                }
                            }
                        }
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.medium)
                    }

                    // Recent Logs
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "实时日志")

                        VStack(spacing: 0) {
                            if logs.isEmpty {
                                Text("暂无日志")
                                    .font(AppFonts.caption())
                                    .foregroundColor(colors.textTertiary)
                                    .padding(AppSpacing.md)
                            } else {
                                ForEach(logs) { log in
                                    LogRow(log: log)

                                    if log.id != logs.last?.id {
                                        AppDivider()
                                    }
                                }
                            }
                        }
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .navigationBarHidden(true)
        .onAppear {
            loadMockLogs()
        }
    }

    private var statusColor: Color {
        switch workflow.status {
        case .active: return AppColors.success
        case .paused: return AppColors.warning
        case .error: return AppColors.error
        case .draft: return colors.textTertiary
        }
    }

    private var successRate: String {
        guard workflow.totalRuns > 0 else { return "0%" }
        let rate = Double(workflow.totalRuns - workflow.failedRuns) / Double(workflow.totalRuns) * 100
        return String(format: "%.1f%%", rate)
    }

    private func toggleWorkflow() {
        service.toggleWorkflowStatus(workflow)
    }

    private func loadMockLogs() {
        logs = [
            WorkflowLog(id: "log_001", workflowId: workflow.id, stepId: "step_001", level: .info,
                      message: "开始收集数据源...", timestamp: Date().addingTimeInterval(-30)),
            WorkflowLog(id: "log_002", workflowId: workflow.id, stepId: "step_001", level: .info,
                      message: "成功连接数据源 A", timestamp: Date().addingTimeInterval(-25)),
            WorkflowLog(id: "log_003", workflowId: workflow.id, stepId: "step_001", level: .info,
                      message: "成功连接数据源 B", timestamp: Date().addingTimeInterval(-20)),
            WorkflowLog(id: "log_004", workflowId: workflow.id, stepId: "step_001", level: .warning,
                      message: "数据源 C 连接超时，使用缓存数据", timestamp: Date().addingTimeInterval(-15)),
            WorkflowLog(id: "log_005", workflowId: workflow.id, stepId: "step_002", level: .info,
                      message: "开始处理数据...", timestamp: Date().addingTimeInterval(-10))
        ]
    }
}

// ============================================
// MARK: - Step Row
// ============================================

struct StepRow: View {
    @Environment(\.appColors) private var colors
    let step: WorkflowStep

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: stepIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(stepColor)
                .frame(width: 24)

            Text(step.name)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)

            Spacer()

            Text(stepText)
                .font(AppFonts.caption())
                .foregroundColor(stepColor)
        }
        .padding(AppSpacing.md)
    }

    private var stepIcon: String {
        switch step.status {
        case .pending: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private var stepColor: Color {
        switch step.status {
        case .pending: return colors.textTertiary
        case .running: return AppColors.info
        case .completed: return AppColors.success
        case .failed: return AppColors.error
        case .skipped: return colors.textTertiary
        }
    }

    private var stepText: String {
        switch step.status {
        case .pending: return "等待"
        case .running: return "运行中"
        case .completed: return "完成"
        case .failed: return "失败"
        case .skipped: return "跳过"
        }
    }
}

// ============================================
// MARK: - Log Row
// ============================================

struct LogRow: View {
    @Environment(\.appColors) private var colors
    let log: WorkflowLog

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(logIcon)
                .font(.system(size: 12))
                .foregroundColor(logColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(AppFonts.monoCaption())
                    .foregroundColor(colors.textPrimary)

                Text(formatTime(log.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
    }

    private var logIcon: String {
        switch log.level {
        case .debug: return "D"
        case .info: return "I"
        case .warning: return "W"
        case .error: return "E"
        }
    }

    private var logColor: Color {
        switch log.level {
        case .debug: return colors.textTertiary
        case .info: return AppColors.info
        case .warning: return AppColors.warning
        case .error: return AppColors.error
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
