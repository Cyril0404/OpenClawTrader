import SwiftUI

//
//  SkillsView.swift
//  OpenClawTrader
//
//  功能：技能控制页面，管理 OpenClaw 技能的开启和关闭
//

// ============================================
// MARK: - Skills View
// ============================================

struct SkillsView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var skillsService = SkillsService.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    headerSection

                    // Skills List
                    skillsListSection

                    // Summary
                    summarySection
                }
                .padding(.vertical, AppSpacing.lg)
            }
        }
        .background(colors.background)
        .navigationTitle("技能控制")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await skillsService.fetchSkills()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("OpenClaw 技能")
                .font(AppFonts.title2())
                .foregroundColor(colors.textPrimary)

            Text("开启或关闭不同的技能来定制您的 AI 助手")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Skills List Section

    private var skillsListSection: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(Skill.SkillCategory.allCases, id: \.self) { category in
                let categorySkills = skillsService.skills.filter { $0.category == category }
                if !categorySkills.isEmpty {
                    skillCategorySection(category: category, skills: categorySkills)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func skillCategorySection(category: Skill.SkillCategory, skills: [Skill]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Category Header
            HStack {
                Text(category.rawValue)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(skills.filter { $0.isEnabled }.count)/\(skills.count)")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }

            // Skills Cards
            VStack(spacing: 0) {
                ForEach(skills) { skill in
                    SkillRow(skill: skill) {
                        Task {
                            await skillsService.toggleSkill(skill)
                        }
                    }

                    if skill.id != skills.last?.id {
                        AppDivider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("已启用技能")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text("\(skillsService.enabledSkills.count) 个")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.accent)
            }

            HStack {
                Text("已禁用技能")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text("\(skillsService.disabledSkills.count) 个")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, AppSpacing.lg)
    }
}

// ============================================
// MARK: - Skill Row
// ============================================

struct SkillRow: View {
    let skill: Skill
    let onToggle: () -> Void

    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            Image(systemName: skill.icon)
                .font(.system(size: 20))
                .foregroundColor(skill.isEnabled ? colors.accent : colors.textTertiary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(skill.isEnabled ? colors.accent.opacity(0.1) : colors.backgroundTertiary)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(AppFonts.body())
                    .foregroundColor(skill.isEnabled ? colors.textPrimary : colors.textTertiary)

                Text(skill.description)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { skill.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: colors.accent))
        }
        .padding(AppSpacing.md)
    }
}

// ============================================
// MARK: - Skill Category Extension
// ============================================

extension Skill.SkillCategory: CaseIterable {
    static var allCases: [Skill.SkillCategory] {
        [.analysis, .trading, .risk, .information, .recommendation, .quant]
    }
}
