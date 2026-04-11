import Foundation

//
//  User.swift
//  OpenClawTrader
//
//  功能：用户模型
//

// ============================================
// MARK: - User Model
// ============================================

struct User: Codable, Identifiable {
    let id: String
    var phone: String       // 手机号（脱敏格式，如 138****8000）
    var nickname: String?
    var email: String?
    var avatarURL: String?
    var createdAt: Date

    /// 显示用用户名（等同于phone）
    var username: String { phone }

    init(id: String = UUID().uuidString, phone: String, nickname: String? = nil, email: String? = nil, avatarURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.phone = phone
        self.nickname = nickname
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}
