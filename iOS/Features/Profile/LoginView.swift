import SwiftUI

//
//  LoginView.swift
//  OpenClawTrader
//
//  功能：登录页面（手机号验证码登录）
//

// ============================================
// MARK: - Login View
// ============================================

struct LoginView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var authService = AuthService.shared
    @State private var phone = ""
    @State private var code = ""
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var rememberMe = true
    let onLoginSuccess: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Logo & Title
                    logoSection

                    // Form
                    formSection

                    // Remember & Forgot
                    rememberSection

                    // Login Button
                    loginButton
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
            }
        }
        .background(colors.background)
        .alert("提示", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(colors.accent)

            Text("OpenClaw Trader")
                .font(AppFonts.largeTitle())
                .foregroundColor(colors.textPrimary)

            Text("智能投资助手")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Phone
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("手机号")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    Text("+86")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)

                    TextField("请输入手机号", text: $phone)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .keyboardType(.phonePad)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)
                }
            }

            // Verification Code
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("验证码")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    TextField("请输入验证码", text: $code)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)

                    Button(action: sendCode) {
                        Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                            .font(AppFonts.caption())
                            .foregroundColor(countdown > 0 ? colors.textTertiary : colors.accent)
                            .padding(.horizontal, AppSpacing.sm)
                    }
                    .disabled(countdown > 0)
                }
            }
        }
    }

    // MARK: - Remember Section

    private var rememberSection: some View {
        HStack {
            Spacer()

            Toggle(isOn: $rememberMe) {
                Text("记住我")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: colors.accent))
        }
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button(action: login) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colors.background))
                        .scaleEffect(0.8)
                } else {
                    Text("登录")
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

    // MARK: - Helpers

    private var isFormValid: Bool {
        phone.count >= 11 && code.count == 6
    }

    private func sendCode() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            let success = await authService.login(username: phone, password: code)
            await MainActor.run {
                isLoading = false
                if success {
                    onLoginSuccess()
                } else {
                    errorMessage = authService.error ?? "登录失败"
                }
            }
        }
    }
}

// ============================================
// MARK: - Forgot Password View
// ============================================

struct ForgotPasswordView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var step: Step = .phone

    enum Step {
        case phone
        case code
        case password
        case success
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                switch step {
                case .phone:
                    phoneStepView
                case .code:
                    codeStepView
                case .password:
                    passwordStepView
                case .success:
                    successView
                }
            }
            .padding(AppSpacing.lg)
            .background(colors.background)
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.accent)
                }
            }
        }
    }

    private var phoneStepView: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("请输入您的手机号")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("手机号")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    Text("+86")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)

                    TextField("请输入手机号", text: $phone)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .keyboardType(.phonePad)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)
                }
            }

            Spacer()

            Button(action: { step = .code }) {
                Text("下一步")
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(colors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(phone.count >= 11 ? colors.accent : colors.backgroundTertiary)
                    .cornerRadius(AppRadius.small)
            }
            .disabled(phone.count < 11)
        }
    }

    private var codeStepView: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("请输入发送至 \(phone) 的验证码")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("验证码")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    TextField("请输入验证码", text: $code)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.sm)
                        .background(colors.backgroundSecondary)
                        .cornerRadius(AppRadius.small)

                    Button(action: sendCode) {
                        Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                            .font(AppFonts.caption())
                            .foregroundColor(countdown > 0 ? colors.textTertiary : colors.accent)
                    }
                    .disabled(countdown > 0)
                }
            }

            Spacer()

            Button(action: { step = .password }) {
                Text("下一步")
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(colors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(code.count == 6 ? colors.accent : colors.backgroundTertiary)
                    .cornerRadius(AppRadius.small)
            }
            .disabled(code.count != 6)
        }
    }

    private var passwordStepView: some View {
        VStack(spacing: AppSpacing.lg) {
            inputField(title: "设置新密码", text: $newPassword, isSecure: true)
            inputField(title: "确认新密码", text: $confirmPassword, isSecure: true)

            Spacer()

            Button(action: resetPassword) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colors.background))
                            .scaleEffect(0.8)
                    } else {
                        Text("完成")
                            .font(AppFonts.body())
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(colors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isPasswordValid ? colors.accent : colors.backgroundTertiary)
                .cornerRadius(AppRadius.small)
            }
            .disabled(!isPasswordValid || isLoading)
        }
    }

    private var successView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(AppColors.success)

            Text("密码重置成功")
                .font(AppFonts.title1())
                .foregroundColor(colors.textPrimary)

            Text("请使用新密码登录")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)

            Spacer()

            Button(action: { dismiss() }) {
                Text("返回登录")
                    .font(AppFonts.body())
                    .fontWeight(.semibold)
                    .foregroundColor(colors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.accent)
                    .cornerRadius(AppRadius.small)
            }
        }
    }

    private func inputField(title: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            if isSecure {
                SecureField("请输入\(title)", text: text)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
            } else {
                TextField("请输入\(title)", text: text)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
            }
        }
    }

    private var isPasswordValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func sendCode() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }

    private func resetPassword() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            step = .success
        }
    }
}
