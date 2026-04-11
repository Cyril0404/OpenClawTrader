import SwiftUI

//
//  ImportOrderView.swift
//  OpenClawTrader
//
//  功能：委托单导入页面，支持手动输入和截图识别
//

// ============================================
// MARK: - Import Order View
// ============================================

struct ImportOrderView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var inputMethod: InputMethod = .manual
    @State private var symbol = ""
    @State private var name = ""
    @State private var orderType: Order.OrderType = .limit
    @State private var orderSide: Order.OrderSide = .buy
    @State private var shares = ""
    @State private var price = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

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
                    importOrder()
                }
                .disabled(!isFormValid)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
            .background(colors.background)
            .navigationTitle("导入委托")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(colors.textSecondary)
                }
            }
            .alert("导入结果", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
    }

    private var manualInputForm: some View {
        VStack(spacing: AppSpacing.md) {
            // 委托类型选择
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("委托类型")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    ForEach([Order.OrderType.limit, .market, .stop, .stopLimit], id: \.self) { type in
                        Button(action: { orderType = type }) {
                            Text(type.rawValue)
                                .font(AppFonts.caption())
                                .foregroundColor(orderType == type ? .white : colors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(orderType == type ? colors.accent : colors.backgroundTertiary)
                                .cornerRadius(AppRadius.small)
                        }
                    }
                }
            }

            // 买卖方向选择
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("买卖方向")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    ForEach([Order.OrderSide.buy, .sell], id: \.self) { side in
                        Button(action: { orderSide = side }) {
                            Text(side.rawValue)
                                .font(AppFonts.caption())
                                .foregroundColor(orderSide == side ? .white : colors.textSecondary)
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.xs)
                                .background(orderSide == side ? (side == .buy ? AppColors.success : AppColors.error) : colors.backgroundTertiary)
                                .cornerRadius(AppRadius.small)
                        }
                    }
                }
            }

            FormField(title: "股票代码", placeholder: "如 AAPL", text: $symbol)
            FormField(title: "股票名称", placeholder: "如 Apple Inc.", text: $name)
            FormField(title: "委托数量", placeholder: "如 100", text: $shares, keyboardType: .numberPad)

            if orderType == .limit || orderType == .stopLimit {
                FormField(title: "委托价格", placeholder: "如 180.00", text: $price, keyboardType: .decimalPad)
            } else if orderType == .stop {
                FormField(title: "触发价格", placeholder: "如 175.00", text: $price, keyboardType: .decimalPad)
            }
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

                Text("目前只支持东莞证券截图识别，其他券商很可能出错")
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
        !symbol.isEmpty && !name.isEmpty && !shares.isEmpty
    }

    private func importOrder() {
        guard let sharesInt = Int(shares) else { return }
        let priceDouble = Double(price) ?? 0

        let result = service.importOrder(
            symbol: symbol,
            name: name,
            type: orderType,
            side: orderSide,
            shares: sharesInt,
            price: priceDouble
        )

        // 显示导入结果提示
        if result.imported > 0 {
            successMessage = "成功导入 \(result.imported) 个委托单"
        } else {
            successMessage = "该委托单已存在，无需重复录入"
        }
        showSuccessAlert = true
    }
}

// ============================================
// MARK: - Order Row
// ============================================

struct OrderRow: View {
    @Environment(\.appColors) private var colors
    let order: Order
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 方向指示
            Circle()
                .fill(order.side == .buy ? AppColors.success : AppColors.error)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(order.symbol)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)

                    Text(order.side.rawValue)
                        .font(AppFonts.caption())
                        .foregroundColor(order.side == .buy ? AppColors.success : AppColors.error)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background((order.side == .buy ? AppColors.success : AppColors.error).opacity(0.2))
                        .cornerRadius(4)
                }

                Text("\(order.shares) 股 @ \(String(format: "%.2f", order.price))")
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(order.status.displayName)
                    .font(AppFonts.small())
                    .foregroundColor(statusColor)

                if order.isActive {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.error)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
    }

    private var statusColor: Color {
        switch order.status {
        case .pending:
            return AppColors.warning
        case .partiallyFilled:
            return AppColors.info
        case .filled:
            return AppColors.success
        case .cancelled, .rejected:
            return colors.textTertiary
        }
    }
}

// ============================================
// MARK: - Order List View
// ============================================

struct OrderListView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = TradingService.shared

    private var activeOrders: [Order] {
        service.orders.filter { $0.isActive }
    }

    private var historicalOrders: [Order] {
        service.orders.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if !activeOrders.isEmpty {
                Section("活跃委托") {
                    ForEach(activeOrders) { order in
                        OrderRow(order: order) {
                            service.cancelOrder(order)
                        }
                    }
                }
            }

            if !historicalOrders.isEmpty {
                Section("历史委托") {
                    ForEach(historicalOrders) { order in
                        OrderRow(order: order) {
                            // No cancel action for historical
                        }
                    }
                }
            }
        }
        .navigationTitle("委托单")
        .navigationBarTitleDisplayMode(.inline)
    }
}
