import SwiftUI

//
//  OpenClawConnectView.swift
//  OpenClawTrader
//
//  功能：移动端配对页面
//

// ============================================
// MARK: - OpenClaw Connect View (Mobile Pairing)
// ============================================

struct OpenClawConnectView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    headerSection

                    // Mobile Pairing View
                    MobilePairingView()

                    Spacer(minLength: AppSpacing.lg)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
            }
        }
        .background(colors.background)
        .navigationTitle("添加 OpenClaw")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(colors.accent)

            Text("添加 OpenClaw")
                .font(AppFonts.title1())
                .foregroundColor(colors.textPrimary)

            Text("通过移动端配对连接桌面端 Gateway")
                .font(AppFonts.body())
                .foregroundColor(colors.textSecondary)
        }
    }
}
