import SwiftUI

//
//  OpenClawConnectView.swift
//  OpenClawTrader
//
//  功能：OpenClaw连接配置页面，输入API地址和密钥
//

// ============================================
// MARK: - OpenClaw Connect View
// ============================================

struct OpenClawConnectView: View {
    @Environment(\.appColors) private var colors
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Header
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "link.circle")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(colors.textSecondary)

                Text("连接 OpenClaw")
                    .font(AppFonts.title1())
                    .foregroundColor(colors.textPrimary)

                Text("输入您的 OpenClaw API 信息以连接")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }
            .padding(.top, AppSpacing.xl)

            // Form
            VStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("API 地址")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    TextField("https://api.openclaw.example.com", text: $baseURL)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundTertiary)
                        .cornerRadius(AppRadius.small)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("API Key")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    SecureField("sk-...", text: $apiKey)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundTertiary)
                        .cornerRadius(AppRadius.small)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            // Connect Button
            PrimaryButton(title: "连接", isLoading: isLoading) {
                connect()
            }
            .disabled(baseURL.isEmpty || apiKey.isEmpty)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.lg)
        .background(colors.background)
        .navigationTitle("连接")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func connect() {
        isLoading = true
        errorMessage = nil

        // Simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            StorageService.shared.saveConnection(baseURL: baseURL, apiKey: apiKey)
            isLoading = false
            dismiss()
        }
    }
}
