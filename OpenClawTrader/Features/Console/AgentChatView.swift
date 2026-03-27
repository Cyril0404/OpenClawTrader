import SwiftUI

// ============================================
// MARK: - Agent Chat View
// ============================================

struct AgentChatView: View {
    @Environment(\.appColors) private var colors
    let agent: Agent
    @StateObject private var service = OpenClawService.shared
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(agent.status == .running ? AppColors.success : colors.textTertiary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    Text(agent.status == .running ? "运行中" : "空闲")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                Menu {
                    Button(action: { service.startAgent(agent) }) {
                        Label("启动", systemImage: "play")
                    }
                    Button(action: { service.stopAgent(agent) }) {
                        Label("停止", systemImage: "stop")
                    }
                    Divider()
                    Button(role: .destructive, action: { service.deleteAgent(agent) }) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(colors.textSecondary)
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)

            // Messages
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    if messages.isEmpty {
                        EmptyState(
                            icon: "bubble.left.and.bubble.right",
                            title: "开始对话",
                            subtitle: "发送消息与 \(agent.name) 交流"
                        )
                        .padding(.top, AppSpacing.xxl)
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(colors.background)

            // Input
            HStack(spacing: AppSpacing.sm) {
                TextField("输入消息...", text: $inputText)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(height: 40)
                    .background(colors.backgroundTertiary)
                    .cornerRadius(AppRadius.small)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(inputText.isEmpty ? colors.textTertiary : colors.accent)
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(colors.backgroundSecondary)
        }
        .navigationBarHidden(true)
    }

    private func sendMessage() {
        let message = inputText
        inputText = ""

        messages.append(ChatMessage(role: "user", content: message, timestamp: Date()))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            messages.append(ChatMessage(
                role: "assistant",
                content: "这是一条模拟回复，实际使用时将连接 OpenClaw API。",
                timestamp: Date()
            ))
        }
    }
}

// ============================================
// MARK: - Message Bubble
// ============================================

struct MessageBubble: View {
    @Environment(\.appColors) private var colors
    let message: AgentChatView.ChatMessage

    var body: some View {
        HStack {
            if message.role == "assistant" {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundColor(colors.textTertiary)
                    .frame(width: 24)
            } else {
                Spacer()
                    .frame(width: 24)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(AppFonts.body())
                    .foregroundColor(message.role == "user" ? colors.background : colors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(message.role == "user" ? colors.accent : colors.backgroundSecondary)
                    .foregroundColor(message.role == "user" ? colors.background : colors.textPrimary)
                    .cornerRadius(AppRadius.small)

                Text(formatTime(message.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }

            if message.role == "user" {
                Image(systemName: "person")
                    .font(.system(size: 16))
                    .foregroundColor(colors.textTertiary)
                    .frame(width: 24)
            } else {
                Spacer()
                    .frame(width: 24)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
