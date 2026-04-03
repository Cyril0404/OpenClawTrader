import SwiftUI

//
//  SettingsView.swift
//  OpenClawTrader
//
//  功能: 设置页面 - API Key 配置
//

struct SettingsView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var relayURL: String = ""
    @State private var showingSaveSuccess = false
    @State private var showingClearConfirm = false
    @State private var showingClearSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // API Key Section
                apiKeySection
                
                // Relay URL Section (read-only reference)
                relayURLSection
                
                // Clear Data Section
                clearDataSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            apiKey = StorageService.shared.apiKey
            relayURL = StorageService.shared.relayURL
        }
        .alert("保存成功", isPresented: $showingSaveSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("API Key 已保存")
        }
        .alert("清除所有数据", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认清除", role: .destructive) {
                StorageService.shared.deleteAccount()
                apiKey = ""
                relayURL = ""
                showingClearSuccess = true
            }
        } message: {
            Text("确定要清除所有本地数据吗？此操作不可恢复。")
        }
        .alert("清除成功", isPresented: $showingClearSuccess) {
            Button("确定", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("所有本地数据已清除")
        }
    }
    
    // MARK: - API Key Section
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "API Key 配置")
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("API Key")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                
                SecureField("请输入 API Key", text: $apiKey)
                    .font(AppFonts.monoBody())
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.md)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
                
                Text("输入您的 OpenClaw API Key，用于连接 AI 服务")
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }
            
            Button(action: saveAPIKey) {
                Text("保存")
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.accent)
                    .cornerRadius(AppRadius.small)
            }
            .disabled(apiKey.isEmpty)
        }
    }
    
    // MARK: - Relay URL Section
    
    private var relayURLSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "连接信息")
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Relay URL")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                
                Text(relayURL.isEmpty ? "未配置" : relayURL)
                    .font(AppFonts.monoBody())
                    .foregroundColor(relayURL.isEmpty ? colors.textTertiary : colors.textPrimary)
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
                
                Text("当前 Relay 服务器地址，通过 OpenClawConnectView 配置")
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }
        }
    }
    
    // MARK: - Clear Data Section
    
    private var clearDataSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "数据管理")
            
            VStack(spacing: 0) {
                Button(action: { showingClearConfirm = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.error)
                            .frame(width: 24)
                        Text("清除所有数据")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.error)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
            }
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
            
            Text("清除后需要重新配对 OpenClaw")
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)
        }
    }
    
    // MARK: - Actions
    
    private func saveAPIKey() {
        StorageService.shared.apiKey = apiKey
        showingSaveSuccess = true
    }
}
