import SwiftUI

//
//  WorkspaceListView.swift
//  OpenClawTrader
//
//  功能：工作空间选择器，支持切换和创建
//

// ============================================
// MARK: - Workspace Picker View
// ============================================

struct WorkspacePickerView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(service.workspaces) { workspace in
                        WorkspaceRowView(workspace: workspace, isSelected: workspace.id == service.currentWorkspace?.id)
                            .onTapGesture {
                                service.switchWorkspace(workspace)
                                dismiss()
                            }
                    }
                    .listRowBackground(colors.backgroundSecondary)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(colors.background)
            .navigationTitle("选择工作空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWorkspaceView()
            }
        }
    }
}

// ============================================
// MARK: - Workspace Row View
// ============================================

struct WorkspaceRowView: View {
    @Environment(\.appColors) private var colors
    let workspace: Workspace
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workspace.name)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    if workspace.isActive {
                        StatusBadge(text: "活跃", color: AppColors.success)
                    }
                }

                Text(workspace.description)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.accent)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

// ============================================
// MARK: - Create Workspace View
// ============================================

struct CreateWorkspaceView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("工作空间名称")
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

                Spacer()

                PrimaryButton(title: "创建工作空间") {
                    service.createWorkspace(name: name, description: description)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
            .padding(AppSpacing.md)
            .background(colors.background)
            .navigationTitle("新建工作空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.textSecondary)
                }
            }
        }
    }
}
