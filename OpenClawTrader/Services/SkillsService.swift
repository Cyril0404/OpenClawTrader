import Foundation

//
//  SkillsService.swift
//  OpenClawTrader
//
//  功能：技能服务，管理 OpenClaw 技能列表和开关状态
//

// ============================================
// MARK: - Skills Service
// ============================================

@MainActor
class SkillsService: ObservableObject {
    static let shared = SkillsService()

    @Published var skills: [Skill] = []
    @Published var isLoading = false
    @Published var error: String?

    private let gatewayBaseURL = "http://localhost:18789"

    private init() {}

    // MARK: - Load Skills

    func loadSkills() {
        // TODO: 后续对接真实 API
    }

    // MARK: - Fetch from API

    func fetchSkills() async {
        isLoading = true
        error = nil

        // TODO: 调用真实 API
        // let response: [SkillResponse] = try await APIClient.shared.request("/v1/skills")
        // skills = response.map { Skill(id: $0.id, name: $0.name, ... ) }

        isLoading = false
    }

    // MARK: - Toggle Skill

    func toggleSkill(_ skill: Skill) async {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else { return }

        // 先更新 UI
        skills[index].isEnabled.toggle()

        do {
            // TODO: 调用真实 API
            // let body = ["enabled": skills[index].isEnabled]
            // try await APIClient.shared.request("/v1/skills/\(skill.id)", method: .patch, body: body)
        } catch {
            // 失败时回滚
            skills[index].isEnabled.toggle()
            self.error = error.localizedDescription
        }
    }

    // MARK: - Get Skills By Category

    func skillsByCategory() -> [Skill.SkillCategory: [Skill]] {
        Dictionary(grouping: skills, by: { $0.category })
    }

    // MARK: - Get Enabled Skills

    var enabledSkills: [Skill] {
        skills.filter { $0.isEnabled }
    }

    // MARK: - Get Disabled Skills

    var disabledSkills: [Skill] {
        skills.filter { !$0.isEnabled }
    }
}
