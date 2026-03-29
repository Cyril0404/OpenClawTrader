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
    var username: String
    var email: String?
    var avatarURL: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, username: String, email: String? = nil, avatarURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}
