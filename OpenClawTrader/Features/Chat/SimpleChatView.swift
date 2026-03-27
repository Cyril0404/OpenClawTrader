import SwiftUI

//
//  SimpleChatView.swift
//  OpenClawTrader
//
//  功能：极简AI聊天界面，仅保留对话核心功能
//

// ============================================
// MARK: - Simple Chat View
// ============================================

struct SimpleChatView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @State private var inputText = ""
    @State private var messages: [SimpleChatMessage] = []
    @FocusState private var isInputFocused: Bool


    // SimpleChatMessage moved to top-level
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.lg)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input Bar
            inputBar
        }
        .background(colors.background)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColors.success)
                .frame(width: 8, height: 8)

            Text("丞相")
                .font(AppFonts.title3())
                .foregroundColor(colors.textPrimary)

            Spacer()

            Text("在线")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(colors.backgroundSecondary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(colors.textTertiary)
            Text("随时开始对话")
                .font(AppFonts.title3())
                .foregroundColor(colors.textSecondary)
            Text("可以问我任何问题，股票分析、资讯查找、交易建议都可以")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .font(AppFonts.body())
                .foregroundColor(colors.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(colors.backgroundSecondary)
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isInputFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? colors.textTertiary : colors.accent)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(colors.backgroundSecondary)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMsg = SimpleChatMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMsg)
        inputText = ""

        // Simulate AI response (placeholder)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let reply = SimpleChatMessage(
                role: "assistant",
                content: "收到你的消息：\(text)\n\n正在处理中，请稍候...",
                timestamp: Date()
            )
            messages.append(reply)
        }
    }
}


// ============================================
// MARK: - Chat Message Model
// ============================================

struct SimpleChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
}

// ============================================
// MARK: - Message Bubble
// ============================================

struct ChatMessageBubble: View {
    @Environment(\.appColors) private var colors
    let message: SimpleChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(AppFonts.body())
                    .foregroundColor(isUser ? .white : colors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(isUser ? colors.accent : colors.backgroundSecondary)
                    .cornerRadius(16)

                Text(formatTime(message.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
