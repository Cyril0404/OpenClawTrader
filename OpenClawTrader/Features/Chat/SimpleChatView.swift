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
    @State private var isLoading = false
    @State private var isVoiceMode = false
    @State private var isRecording = false
    @State private var recordedText = ""
    @State private var showAttachmentMenu = false
    @State private var showModelPicker = false
    @State private var showCommandList = false
    @State private var showUsageDetail = false
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
                                ChatMessageBubble(
                                    message: message,
                                    onCopy: { copyMessage(message.content) },
                                    onFavorite: { favoriteMessage(message) },
                                    onDelete: { deleteMessage(message) },
                                    onQuote: { quoteMessage(message) },
                                    onRemind: { remindMessage(message) }
                                )
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
        VStack(spacing: 2) {
            HStack(spacing: AppSpacing.xs) {
                Spacer()

                // Agent 名称 + 状态点
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(service.mainAgent?.status == .running ? AppColors.success : colors.textTertiary)
                        .frame(width: 8, height: 8)

                    Text(service.mainAgent?.name ?? "助手")
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)
                }

                // Agent 选择器
                Menu {
                    ForEach(service.agents) { agent in
                        Button(action: { selectAgent(agent) }) {
                            HStack {
                                Text(agent.name)
                                if agent.id == service.mainAgent?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    NavigationLink(destination: AgentListView()) {
                        Label("管理 Agent", systemImage: "person.2")
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()
            }

            // Context 用量（不带前缀）
            Text(contextUsageText)
                .font(AppFonts.small())
                .foregroundColor(colors.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(colors.backgroundSecondary)
    }

    private var contextUsageText: String {
        guard let workspace = service.currentWorkspace else {
            return "暂无用量信息"
        }
        let used = workspace.tokenUsage.usedToday
        let limit = workspace.tokenUsage.limit
        let percentage = limit > 0 ? Double(used) / Double(limit) * 100 : 0
        return "\(formatTokenCount(used)) / \(formatTokenCount(limit)) (\(String(format: "%.1f", percentage))%)"
    }

    private var currentModelName: String {
        service.models.first { $0.isDefault }?.name ?? "未选择"
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
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
        VStack(spacing: AppSpacing.xs) {
            // 顶部功能栏
            HStack(spacing: AppSpacing.md) {
                // 正在用的 Model
                Button(action: { showModelPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                        Text(currentModelName)
                            .font(AppFonts.small())
                    }
                    .foregroundColor(colors.textSecondary)
                }

                Text("·")
                    .foregroundColor(colors.textTertiary)

                // 命令
                Button(action: { showCommandList = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 11))
                        Text("命令")
                            .font(AppFonts.small())
                    }
                    .foregroundColor(colors.textSecondary)
                }

                Text("·")
                    .foregroundColor(colors.textTertiary)

                // 用量
                Button(action: { showUsageDetail = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 11))
                        Text("用量")
                            .font(AppFonts.small())
                    }
                    .foregroundColor(colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xs)
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheet(selectedModel: Binding(
                    get: { service.models.first { $0.isDefault } },
                    set: { if let model = $0 { service.setDefaultModel(model) } }
                ), models: service.models)
            }
            .sheet(isPresented: $showCommandList) {
                CommandListSheet(onSelect: { command in
                    inputText = command.prefix
                    isInputFocused = true
                })
            }
            .sheet(isPresented: $showUsageDetail) {
                UsageDetailSheet(models: service.models)
            }

            // 输入区域
            HStack(spacing: AppSpacing.sm) {
                // 语音模式切换 / 语音输入按钮
                Button(action: { isVoiceMode.toggle() }) {
                    Image(systemName: isVoiceMode ? "keyboard" : "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isVoiceMode ? colors.accent : colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(colors.backgroundTertiary)
                        .cornerRadius(18)
                }

                if isVoiceMode {
                    // 语音输入模式
                    Button(action: {}) {
                        Text(isRecording ? "松开结束" : "按住说话")
                            .font(AppFonts.body())
                            .foregroundColor(isRecording ? .white : colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isRecording ? AppColors.error : colors.backgroundTertiary)
                            .cornerRadius(20)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isRecording = true }
                            .onEnded { _ in isRecording = false }
                    )
                } else {
                    // 文字输入模式
                    TextField("输入消息...", text: $inputText, axis: .vertical)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(colors.backgroundTertiary)
                        .cornerRadius(20)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                }

                // 添加附件按钮
                Button(action: { showAttachmentMenu = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(colors.textSecondary)
                }
                .confirmationDialog("添加附件", isPresented: $showAttachmentMenu) {
                    Button("图片") { addImage() }
                    Button("文件") { addFile() }
                    Button("取消", role: .cancel) { }
                }

                // 发送按钮
                Button(action: sendMessage) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colors.textSecondary))
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(shouldShowSend ? colors.accent : colors.textTertiary)
                    }
                }
                .disabled(!shouldShowSend || isLoading)
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.sm)
        .background(colors.backgroundSecondary)
    }

    private var shouldShowSend: Bool {
        if isVoiceMode {
            return !recordedText.isEmpty
        }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func selectAgent(_ agent: Agent) {
        service.mainAgent = agent
        // 切换 Agent 时加载该 Agent 的会话历史
        loadConversation()
    }

    private func loadConversation() {
        guard let agentId = service.mainAgent?.id else { return }
        let history = service.getConversation(for: agentId)
        messages = history.map { msg in
            SimpleChatMessage(
                role: msg.role.rawValue,
                content: msg.content,
                timestamp: msg.timestamp
            )
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let agentId = service.mainAgent?.id else { return }

        // 添加用户消息
        let userMsg = SimpleChatMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMsg)
        inputText = ""
        isLoading = true

        // 调用服务发送消息
        service.sendMessage(content: text, to: agentId) { [self] result in
            isLoading = false
            switch result {
            case .success(let reply):
                let assistantMsg = SimpleChatMessage(
                    role: "assistant",
                    content: reply,
                    timestamp: Date()
                )
                messages.append(assistantMsg)
            case .failure(let error):
                let errorMsg = SimpleChatMessage(
                    role: "assistant",
                    content: "发送失败: \(error.localizedDescription)",
                    timestamp: Date()
                )
                messages.append(errorMsg)
            }
        }
    }

    // MARK: - Message Actions

    private func copyMessage(_ content: String) {
        UIPasteboard.general.string = content
    }

    private func favoriteMessage(_ message: SimpleChatMessage) {
        // TODO: 收藏功能实现
    }

    private func deleteMessage(_ message: SimpleChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }
    }

    private func quoteMessage(_ message: SimpleChatMessage) {
        inputText = "\"\(message.content)\"\n"
        isInputFocused = true
    }

    private func remindMessage(_ message: SimpleChatMessage) {
        // TODO: 提醒功能实现
    }

    // MARK: - Input Actions

    private func addImage() {
        // TODO: 图片选择功能
    }

    private func addFile() {
        // TODO: 文件选择功能
    }
}

// ============================================
// MARK: - Model Picker Sheet
// ============================================

struct ModelPickerSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: AIModel?
    let models: [AIModel]

    var body: some View {
        NavigationStack {
            List(models) { model in
                Button(action: {
                    selectedModel = model
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.name)
                                .font(AppFonts.body())
                                .foregroundColor(colors.textPrimary)
                            Text(model.provider)
                                .font(AppFonts.caption())
                                .foregroundColor(colors.textSecondary)
                        }
                        Spacer()
                        if model.id == selectedModel?.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// ============================================
// MARK: - Command List Sheet
// ============================================

struct CommandListSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    let onSelect: (UserCommand) -> Void

    @State private var commands: [UserCommand] = UserCommand.defaultCommands
    @State private var showingAddCommand = false
    @State private var newCommandPrefix = ""
    @State private var newCommandName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(commands) { command in
                    Button(action: {
                        onSelect(command)
                        dismiss()
                    }) {
                        HStack {
                            Text(command.prefix)
                                .font(AppFonts.monoBody())
                                .foregroundColor(colors.accent)
                            Text(command.name)
                                .font(AppFonts.body())
                                .foregroundColor(colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(colors.textTertiary)
                        }
                    }
                }
                .onDelete(perform: deleteCommand)
            }
            .navigationTitle("命令")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCommand = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("添加命令", isPresented: $showingAddCommand) {
                TextField("命令前缀，如 /gpt", text: $newCommandPrefix)
                TextField("命令名称", text: $newCommandName)
                Button("取消", role: .cancel) {
                    newCommandPrefix = ""
                    newCommandName = ""
                }
                Button("添加") {
                    if !newCommandPrefix.isEmpty && !newCommandName.isEmpty {
                        commands.append(UserCommand(id: UUID().uuidString, prefix: newCommandPrefix, name: newCommandName))
                        newCommandPrefix = ""
                        newCommandName = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func deleteCommand(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
    }
}

// ============================================
// MARK: - User Command Model
// ============================================

struct UserCommand: Identifiable, Codable {
    let id: String
    var prefix: String
    var name: String

    static let defaultCommands: [UserCommand] = [
        UserCommand(id: "1", prefix: "/gpt", name: "使用 GPT"),
        UserCommand(id: "2", prefix: "/claude", name: "使用 Claude"),
        UserCommand(id: "3", prefix: "/image", name: "生成图片"),
        UserCommand(id: "4", prefix: "/analyze", name: "分析股票"),
        UserCommand(id: "5", prefix: "/trade", name: "交易建议")
    ]
}

// ============================================
// MARK: - Usage Detail Sheet
// ============================================

struct UsageDetailSheet: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    let models: [AIModel]

    var body: some View {
        NavigationStack {
            List(models) { model in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(model.name)
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                        Spacer()
                        Text(model.isDefault ? "默认" : "")
                            .font(AppFonts.small())
                            .foregroundColor(colors.textSecondary)
                    }

                    Text("Provider: \(model.provider)")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading) {
                            Text("总调用")
                                .font(AppFonts.small())
                                .foregroundColor(colors.textTertiary)
                            Text("\(model.usageStats.totalCalls)")
                                .font(AppFonts.monoBody())
                                .foregroundColor(colors.textPrimary)
                        }

                        VStack(alignment: .leading) {
                            Text("总Token")
                                .font(AppFonts.small())
                                .foregroundColor(colors.textTertiary)
                            Text(formatLargeNumber(model.usageStats.totalTokens))
                                .font(AppFonts.monoBody())
                                .foregroundColor(colors.textPrimary)
                        }

                        VStack(alignment: .leading) {
                            Text("成功率")
                                .font(AppFonts.small())
                                .foregroundColor(colors.textTertiary)
                            Text(successRate(model))
                                .font(AppFonts.monoBody())
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .navigationTitle("用量统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatLargeNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }

    private func successRate(_ model: AIModel) -> String {
        let total = model.usageStats.totalCalls
        guard total > 0 else { return "0%" }
        let rate = Double(model.usageStats.successfulCalls) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }
}

// ============================================
// MARK: - Chat Message Model
// ============================================

struct SimpleChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
}

// ============================================
// MARK: - Message Bubble
// ============================================

struct ChatMessageBubble: View {
    @Environment(\.appColors) private var colors
    let message: SimpleChatMessage
    let onCopy: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    let onQuote: () -> Void
    let onRemind: () -> Void

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(AppFonts.body())
                    .foregroundColor(isUser ? .white : .black)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(isUser ? colors.accent : Color.white)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                Text(formatTime(message.timestamp))
                    .font(AppFonts.small())
                    .foregroundColor(colors.textTertiary)
            }
            .contextMenu {
                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                }
                Button(action: onFavorite) {
                    Label("收藏", systemImage: "star")
                }
                if isUser {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                }
                Button(action: onQuote) {
                    Label("引用", systemImage: "quote.bubble")
                }
                Button(action: onRemind) {
                    Label("提醒", systemImage: "bell")
                }
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
