import SwiftUI

//
//  ImportHoldingView.swift
//  OpenClawTrader
//
//  功能：持仓导入页面，支持手动输入和截图识别
//

// ============================================
// MARK: - Import Holding View
// ============================================

struct ImportHoldingView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var inputMethod: InputMethod = .manual
    @State private var symbol = ""
    @State private var name = ""
    @State private var shares = ""
    @State private var averageCost = ""
    @State private var currentPrice = ""

    enum InputMethod: String, CaseIterable {
        case manual = "手动输入"
        case screenshot = "截图识别"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                // Method Selector
                Picker("输入方式", selection: $inputMethod) {
                    ForEach(InputMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if inputMethod == .manual {
                    manualInputForm
                } else {
                    screenshotInputView
                }

                Spacer()

                PrimaryButton(title: "确认导入") {
                    importHolding()
                }
                .disabled(!isFormValid)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
            .background(colors.background)
            .navigationTitle("导入持仓")
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

    private var manualInputForm: some View {
        VStack(spacing: AppSpacing.md) {
            FormField(title: "股票代码", placeholder: "如 AAPL", text: $symbol)
            FormField(title: "股票名称", placeholder: "如 Apple Inc.", text: $name)
            FormField(title: "持股数量", placeholder: "如 100", text: $shares, keyboardType: .numberPad)
            FormField(title: "平均成本", placeholder: "如 165.50", text: $averageCost, keyboardType: .decimalPad)
            FormField(title: "当前价格", placeholder: "如 178.50", text: $currentPrice, keyboardType: .decimalPad)
        }
    }

    private var screenshotInputView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(colors.textTertiary)

                Text("截图识别")
                    .font(AppFonts.title3())
                    .foregroundColor(colors.textPrimary)

                Text("上传持仓截图，自动识别股票信息")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SecondaryButton(title: "选择截图") {
                // Image picker
            }

            Spacer()
        }
    }

    private var isFormValid: Bool {
        !symbol.isEmpty && !name.isEmpty && !shares.isEmpty && !averageCost.isEmpty && !currentPrice.isEmpty
    }

    private func importHolding() {
        guard let sharesInt = Int(shares),
              let costDouble = Double(averageCost),
              let priceDouble = Double(currentPrice) else { return }

        service.importHolding(
            symbol: symbol,
            shares: sharesInt,
            averageCost: costDouble,
            currentPrice: priceDouble,
            name: name
        )

        dismiss()
    }
}

// ============================================
// MARK: - Form Field
// ============================================

struct FormField: View {
    @Environment(\.appColors) private var colors
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)

            TextField(placeholder, text: $text)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)
                .keyboardType(keyboardType)
                .padding(AppSpacing.sm)
                .background(colors.backgroundTertiary)
                .cornerRadius(AppRadius.small)
        }
    }
}
