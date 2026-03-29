import SwiftUI

//
//  AgentListView.swift
//  OpenClawTrader
//
//  功能：Agent管理列表，支持创建和状态监控
//

// ============================================
// MARK: - Agent List View
// ============================================

struct AgentListView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = OpenClawService.shared
    @State private var searchText = ""
    @State private var showingCreateSheet = false

    /// 外部传入的 Agent 选择回调（用于 sheet 模式）
    var onAgentSelected: ((Agent) -> Void)?

    private var filteredAgents: [Agent] {
        if searchText.isEmpty {
            return service.agents
        }
        return service.agents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "Agent 管理")

            VStack(spacing: AppSpacing.md) {
                SearchBar(text: $searchText)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Status Summary
                        statusSummary

                        // Agents List
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: "全部 Agent (\(filteredAgents.count))")

                            if filteredAgents.isEmpty {
                                EmptyState(
                                    icon: "cpu",
                                    title: "没有 Agent",
                                    subtitle: "创建一个 Agent 开始使用",
                                    actionTitle: "创建 Agent",
                                    action: { showingCreateSheet = true }
                                )
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(filteredAgents) { agent in
                                        Button {
                                            if let callback = onAgentSelected {
                                                callback(agent)
                                            } else {
                                                // 默认行为：导航到聊天页面
                                                // NavigationLink would go here in non-sheet mode
                                            }
                                        } label: {
                                            AgentRow(agent: agent)
                                        }

                                        if agent.id != filteredAgents.last?.id {
                                            AppDivider()
                                        }
                                    }
                                }
                                .background(colors.backgroundSecondary)
                                .cornerRadius(AppRadius.medium)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.lg)
                }
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showingCreateSheet) {
            CreateAgentView()
        }
    }

    private var statusSummary: some View {
        HStack(spacing: AppSpacing.sm) {
            StatusCard(title: "运行中", count: service.agents.filter { $0.status == .running }.count, color: AppColors.success)
            StatusCard(title: "空闲", count: service.agents.filter { $0.status == .idle }.count, color: colors.textTertiary)
            StatusCard(title: "错误", count: service.agents.filter { $0.status == .error }.count, color: AppColors.error)
        }
    }
}

struct StatusCard: View {
    @Environment(\.appColors) private var colors
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            Text("\(count)")
                .font(AppFonts.title2())
                .foregroundColor(color)

            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }
}

// ============================================
// MARK: - Agent Row
// ============================================

struct AgentRow: View {
    @Environment(\.appColors) private var colors
    let agent: Agent

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "cpu")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                Text("\(agent.conversationCount) 次对话")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            Circle()
                .fill(agent.status == .running ? AppColors.success : (agent.status == .error ? AppColors.error : colors.textTertiary))
                .frame(width: 8, height: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
        }
        .padding(AppSpacing.md)
    }
}

// ============================================
// MARK: - Create Agent View
// ============================================

struct CreateAgentView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var selectedModelId = ""
    @State private var systemPrompt = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Agent 名称")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        TextField("输入名称", text: $name)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                            .padding(AppSpacing.sm)
                            .background(colors.backgroundTertiary)
                            .cornerRadius(AppRadius.small)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("描述")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        TextField("输入描述", text: $description)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                            .padding(AppSpacing.sm)
                            .background(colors.backgroundTertiary)
                            .cornerRadius(AppRadius.small)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("选择模型")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(service.models) { model in
                                    Button(action: { selectedModelId = model.id }) {
                                        Text(model.name)
                                            .font(AppFonts.caption())
                                            .foregroundColor(selectedModelId == model.id ? colors.background : colors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedModelId == model.id ? colors.accent : colors.backgroundTertiary)
                                            .cornerRadius(AppRadius.full)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("系统提示词")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        TextEditor(text: $systemPrompt)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(AppSpacing.xs)
                            .background(colors.backgroundTertiary)
                            .cornerRadius(AppRadius.small)
                    }

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(colors.background)
            .navigationTitle("创建 Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        createAgent()
                        dismiss()
                    }
                    .foregroundColor(colors.accent)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func createAgent() {
        let modelId = selectedModelId.isEmpty ? (service.models.first?.id ?? "") : selectedModelId
        service.createAgent(name: name, description: description, modelId: modelId, systemPrompt: systemPrompt)
    }
}
