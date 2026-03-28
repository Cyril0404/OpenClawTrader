import SwiftUI

//
//  OpenClawConnectView.swift
//  OpenClawTrader
//
//  功能：OpenClaw连接配置页面
//

// ============================================
// MARK: - OpenClaw Connect View
// ============================================

struct OpenClawConnectView: View {
    @Environment(\.appColors) private var colors
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var rememberSettings = true
    @State private var isLoading = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    headerSection

                    // Form
                    formSection

                    // Remember Toggle
                    rememberToggle

                    // Test Connection Button
                    testButton

                    Spacer(minLength: AppSpacing.lg)

                    // Connect Button
                    connectButton
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
            }
        }
        .background(colors.background)
        .navigationTitle("连接 OpenClaw")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load saved settings
            baseURL = StorageService.shared.apiBaseURL
            apiKey = StorageService.shared.apiKey
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(colors.accent)

            Text("连接 OpenClaw")
                .font(AppFonts.title1())
                .foregroundColor(colors.textPrimary)

            Text("输入您的 OpenClaw API 信息")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: AppSpacing.md) {
            // API Address
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("API 地址")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                TextField("https://api.openclaw.example.com", text: $baseURL)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.sm)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
                    .overlay(
                        Group {
                            if !baseURL.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: { baseURL = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(colors.textTertiary)
                                    }
                                    .padding(.trailing, AppSpacing.sm)
                                }
                            }
                        }
                    )
            }

            // API Key
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("API Key")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                SecureField("sk-...", text: $apiKey)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
            }

            // Error Message
            if let error = errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 14))
                    Text(error)
                        .font(AppFonts.caption())
                }
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Test Result
            if let result = testResult {
                testResultView(result)
            }
        }
    }

    // MARK: - Remember Toggle

    private var rememberToggle: some View {
        Toggle(isOn: $rememberSettings) {
            Text("记住设置")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
        .toggleStyle(SwitchToggleStyle(tint: colors.accent))
    }

    // MARK: - Test Button

    private var testButton: some View {
        Button(action: testConnection) {
            HStack {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.accent))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                    Text("测试连接")
                        .font(AppFonts.body())
                }
            }
            .foregroundColor(colors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.small)
        }
        .disabled(apiKey.isEmpty || isTesting)
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: connect) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.background))
                        .scaleEffect(0.8)
                } else {
                    Text("连接")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(colors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isFormValid ? colors.accent : colors.backgroundTertiary)
            .cornerRadius(AppRadius.small)
        }
        .disabled(!isFormValid || isLoading)
    }

    // MARK: - Test Result View

    @ViewBuilder
    private func testResultView(_ result: TestResult) -> some View {
        switch result {
        case .success:
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("连接成功")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.success)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failure(let message):
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.error)
                Text(message)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.error)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        errorMessage = nil

        Task {
            do {
                let status = try await OpenClawService.testConnection(baseURL: baseURL, apiKey: apiKey)
                await MainActor.run {
                    isTesting = false
                    testResult = .success
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func connect() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 先测试连接
                _ = try await OpenClawService.testConnection(baseURL: baseURL, apiKey: apiKey)

                await MainActor.run {
                    isLoading = false

                    // 保存配置
                    if rememberSettings {
                        StorageService.shared.saveConnection(baseURL: baseURL, apiKey: apiKey)
                    }

                    // 连接成功后调用 OpenClawService 的 connect
                    Task {
                        await OpenClawService.shared.connect()
                    }

                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
