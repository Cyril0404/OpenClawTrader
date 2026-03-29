import SwiftUI
import UserNotifications

//
//  SimpleChatView.swift
//  OpenClawTrader
//
//  功能:极简AI聊天界面,仅保留对话核心功能
//

// ============================================
// MARK: - Chat Input State (Shared)
// ============================================

@MainActor
final class ChatInputState: ObservableObject {
    static let shared = ChatInputState()
    @Published var pendingText: String = ""
}

// ============================================
// MARK: - Simple Chat View
// ============================================

struct SimpleChatView: View {
    @Environment(\.appColors) private var colors
    @StateObject private var service = OpenClawService.shared
    @StateObject private var wsService = WebSocketChatService.shared
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
    @State private var showAgentList = false
    @FocusState private var isInputFocused: Bool

    // 图片/文件选择
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showImageSourceMenu = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage?
    @State private var pendingAttachments: [Attachment] = []

    // 收藏和提醒
    @State private var showRemindSheet = false
    @State private var remindMessageForSheet: SimpleChatMessage?
    @State private var favoriteMessages: [SimpleChatMessage] = []
    @State private var remindTime = Date().addingTimeInterval(3600) // 默认1小时后

    // 输入框状态持久化 - 使用静态变量保证跨视图实例持久化
    @State private var pendingInput = ChatInputState.shared.pendingText


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

            // 附件工具栏
            if showAttachmentMenu {
                attachmentToolbar
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imageSourceType) { image in
                if let image = image {
                    let attachment = Attachment(type: .image, imageData: image.jpegData(compressionQuality: 0.8))
                    pendingAttachments.append(attachment)
                    showAttachmentMenu = true
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { urls in
                for url in urls {
                    let attachment = Attachment(type: .file, url: url, fileName: url.lastPathComponent, fileSize: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0)
                    pendingAttachments.append(attachment)
                }
                showAttachmentMenu = true
            }
        }
        .confirmationDialog("选择图片来源", isPresented: $showImageSourceMenu) {
            Button("拍照") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("从相册选择") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showRemindSheet) {
            if let message = remindMessageForSheet {
                ReminderSheet(
                    message: message,
                    remindTime: $remindTime,
                    onConfirm: { msg, time in
                        scheduleReminder(for: msg, at: time)
                        showRemindSheet = false
                    },
                    onCancel: {
                        showRemindSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAgentList) {
            AgentListView(onAgentSelected: { agent in
                service.mainAgent = agent
                showAgentList = false
            })
        }
        .onReceive(wsService.$incomingMessages) { newMessages in
            for text in newMessages {
                messages.append(SimpleChatMessage(role: "assistant", content: text, timestamp: Date()))
            }
            if !newMessages.isEmpty {
                wsService.incomingMessages.removeAll()
            }
        }
        .onAppear {
            // 恢复之前保存的输入
            inputText = ChatInputState.shared.pendingText
            // 只要有凭证就尝试连接 WebSocket（不依赖 isConnected，因为 /v1/status 可能404）
            let baseURL = StorageService.shared.relayURL
            let token = StorageService.shared.apiKey
            print("[Chat] baseURL=\(baseURL), token=\(token.prefix(8))..., emptyURL=\(baseURL.isEmpty), emptyToken=\(token.isEmpty)")
            if !baseURL.isEmpty && !token.isEmpty {
                print("[Chat] Connecting WebSocket to \(baseURL)...")
                wsService.connect(baseURL: baseURL, token: token)
                wsService.setStreamCallback { [self] text in
                    // 流式消息追加到最后一个 AI 消息
                    if let lastIdx = messages.lastIndex(where: { $0.role == "assistant" }) {
                        messages[lastIdx] = SimpleChatMessage(
                            role: "assistant",
                            content: messages[lastIdx].content + text,
                            timestamp: messages[lastIdx].timestamp
                        )
                    }
                }
            }
        }
        .onDisappear {
            // 保存当前输入
            ChatInputState.shared.pendingText = inputText
            wsService.disconnect()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        VStack(spacing: 2) {
            HStack(spacing: AppSpacing.xs) {
                Spacer()

                // Agent 名称 + 状态点
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill((service.isConnected || wsService.isConnected) ? AppColors.success : AppColors.error)
                        .frame(width: 8, height: 8)

                    Text((service.isConnected || wsService.isConnected) ? (service.mainAgent?.name ?? "OpenClaw") : "未连接")
                        .font(AppFonts.title3())
                        .foregroundColor(colors.textPrimary)

                    Button {
                        showAgentList = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(colors.textSecondary)
                    }
                }

                Spacer()
            }

            // Context 用量(不带前缀)
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
            Text("可以问我任何问题,股票分析、资讯查找、交易建议都可以")
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
                    // 语音输入模式 - TODO: 实现语音录制功能
                    Button(action: {}) {
                        Text("语音功能开发中")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(colors.backgroundTertiary)
                            .cornerRadius(20)
                    }
                    .disabled(true)
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
                Button(action: { showAttachmentMenu.toggle() }) {
                    Image(systemName: showAttachmentMenu ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(colors.textSecondary)
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

    // MARK: - Attachment Toolbar

    private var attachmentToolbar: some View {
        HStack(spacing: AppSpacing.xl) {
            // 图片
            Button(action: { addImage() }) {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                    Text("图片")
                        .font(AppFonts.caption())
                }
                .foregroundColor(colors.textPrimary)
            }

            // 文件
            Button(action: { addFile() }) {
                VStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 24))
                    Text("文件")
                        .font(AppFonts.caption())
                }
                .foregroundColor(colors.textPrimary)
            }

            // 语音
            Button(action: { isVoiceMode = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "mic")
                        .font(.system(size: 24))
                    Text("语音")
                        .font(AppFonts.caption())
                }
                .foregroundColor(colors.textPrimary)
            }

            Spacer()

            // 关闭按钮
            Button(action: { showAttachmentMenu = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(colors.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(colors.backgroundSecondary)
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

        // 检查是否已连接
        guard service.isConnected else {
            // 未连接时显示提示消息
            let errorMsg = SimpleChatMessage(
                role: "assistant",
                content: "请先连接 OpenClaw 才能发送消息",
                timestamp: Date()
            )
            messages.append(errorMsg)
            return
        }

        // 检查是否有有效内容
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        // 检查是否有选中的 Agent
        guard let agentId = service.mainAgent?.id else {
            let errorMsg = SimpleChatMessage(
                role: "assistant",
                content: "请先选择一个助手 Agent",
                timestamp: Date()
            )
            messages.append(errorMsg)
            return
        }

        // 构建消息内容(包含附件描述)
        var fullContent = text
        if !pendingAttachments.isEmpty {
            let attachmentDescs = pendingAttachments.map { attachment in
                switch attachment.type {
                case .image:
                    return "[图片: \(attachment.imageData?.count ?? 0) bytes]"
                case .file:
                    return "[文件: \(attachment.fileName ?? "unknown")]"
                }
            }.joined(separator: ", ")
            if !text.isEmpty {
                fullContent = "\(text)\n\n\(attachmentDescs)"
            } else {
                fullContent = attachmentDescs
            }
        }

        // 添加用户消息
        let userMsg = SimpleChatMessage(
            role: "user",
            content: text,
            timestamp: Date(),
            attachments: pendingAttachments
        )
        messages.append(userMsg)
        inputText = ""
        ChatInputState.shared.pendingText = ""
        pendingAttachments = []
        showAttachmentMenu = false
        isLoading = true

        // 调用服务发送消息(优先 WebSocket,fallback HTTP)
        if wsService.isConnected {
            // WebSocket 模式
            // 添加 AI 占位消息
            let aiMsgId = UUID().uuidString
            var aiMsg = SimpleChatMessage(
                role: "assistant",
                content: "思考中...",
                timestamp: Date()
            )
            messages.append(aiMsg)
            let aiMsgIdx = messages.count - 1

            isLoading = false
            wsService.sendChatMessage(fullContent) { response in
                Task { @MainActor in
                    if let lastIdx = messages.lastIndex(where: { $0.role == "assistant" }) {
                        if let resp = response, !resp.isEmpty {
                            messages[lastIdx] = SimpleChatMessage(
                                role: "assistant",
                                content: resp,
                                timestamp: messages[lastIdx].timestamp
                            )
                        } else {
                            messages[lastIdx] = SimpleChatMessage(
                                role: "assistant",
                                content: "(空响应)",
                                timestamp: messages[lastIdx].timestamp
                            )
                        }
                    }
                }
            }
        } else {
            // HTTP fallback
            service.sendMessage(content: fullContent, to: agentId) { [self] result in
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
    }

    // MARK: - Message Actions

    private func copyMessage(_ content: String) {
        UIPasteboard.general.string = content
    }

    private func favoriteMessage(_ message: SimpleChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isFavorite.toggle()
            if messages[index].isFavorite {
                favoriteMessages.append(messages[index])
            } else {
                favoriteMessages.removeAll { $0.id == message.id }
            }
        }
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
        remindMessageForSheet = message
        showRemindSheet = true
    }

    private func scheduleReminder(for message: SimpleChatMessage, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "消息提醒"
        content.body = message.content
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: message.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Input Actions

    private func addImage() {
        showImageSourceMenu = true
    }

    private func addFile() {
        showDocumentPicker = true
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
                TextField("命令前缀,如 /gpt", text: $newCommandPrefix)
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
    var attachments: [Attachment] = []
    var isFavorite: Bool = false
}

// ============================================
// MARK: - Attachment Model
// ============================================

struct Attachment: Identifiable {
    let id = UUID()
    let type: AttachmentType
    var url: URL?
    var imageData: Data?
    var fileName: String?
    var fileSize: Int64?

    enum AttachmentType {
        case image
        case file
    }
}

// ============================================
// MARK: - Image Picker
// ============================================

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.selectedImage = image
            parent.onImagePicked(image)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            parent.dismiss()
        }
    }
}

// ============================================
// MARK: - Document Picker
// ============================================

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
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
                // 附件显示
                if !message.attachments.isEmpty {
                    attachmentView
                }

                // 文本内容
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(AppFonts.body())
                        .foregroundColor(isUser ? .white : .black)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(message.content.isEmpty ? Color.clear : (isUser ? colors.accent : Color.white))
                        .cornerRadius(16)
                        .textSelection(.enabled)
                }

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

    // 附件视图
    @ViewBuilder
    private var attachmentView: some View {
        ForEach(message.attachments) { attachment in
            switch attachment.type {
            case .image:
                if let imageData = attachment.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(12)
                }
            case .file:
                if let fileName = attachment.fileName {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20))
                            .foregroundColor(colors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileName)
                                .font(AppFonts.caption())
                                .foregroundColor(isUser ? .white : colors.textPrimary)
                                .lineLimit(1)
                            if let size = attachment.fileSize {
                                Text(formatFileSize(size))
                                    .font(AppFonts.small())
                                    .foregroundColor(isUser ? .white.opacity(0.7) : colors.textTertiary)
                            }
                        }
                    }
                    .padding(AppSpacing.sm)
                    .background(isUser ? colors.accent.opacity(0.3) : colors.backgroundSecondary)
                    .cornerRadius(8)
                }
            }
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// ============================================
// MARK: - Reminder Sheet
// ============================================

struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appColors) private var colors

    let message: SimpleChatMessage
    @Binding var remindTime: Date
    let onConfirm: (SimpleChatMessage, Date) -> Void
    let onCancel: () -> Void

    @State private var selectedInterval: ReminderInterval = .oneHour

    enum ReminderInterval: String, CaseIterable {
        case fiveMinutes = "5分钟后"
        case fifteenMinutes = "15分钟后"
        case thirtyMinutes = "30分钟后"
        case oneHour = "1小时后"
        case twoHours = "2小时后"
        case tomorrow = "明天"
        case custom = "自定义"

        var timeInterval: TimeInterval {
            switch self {
            case .fiveMinutes: return 5 * 60
            case .fifteenMinutes: return 15 * 60
            case .thirtyMinutes: return 30 * 60
            case .oneHour: return 3600
            case .twoHours: return 7200
            case .tomorrow: return 86400
            case .custom: return 0
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                // 消息预览
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("提醒内容")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)

                    Text(message.content)
                        .font(AppFonts.body())
                        .foregroundColor(colors.textPrimary)
                        .lineLimit(3)
                        .padding(AppSpacing.md)
                            .background(colors.backgroundSecondary)
                            .cornerRadius(AppRadius.small)
                    }
                    .padding(.horizontal)

                    Divider()

                    // 快速选择
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("提醒时间")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                            ForEach(ReminderInterval.allCases, id: \.self) { interval in
                                Button(action: {
                                    selectedInterval = interval
                                    if interval != .custom {
                                        remindTime = Date().addingTimeInterval(interval.timeInterval)
                                    }
                                }) {
                                    Text(interval.rawValue)
                                        .font(AppFonts.body())
                                        .foregroundColor(selectedInterval == interval ? .white : colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(AppSpacing.sm)
                                        .background(selectedInterval == interval ? colors.accent : colors.backgroundSecondary)
                                        .cornerRadius(AppRadius.small)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 自定义时间选择
                    if selectedInterval == .custom {
                        DatePicker("选择时间", selection: $remindTime, in: Date()...)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // 按钮
                    HStack(spacing: AppSpacing.md) {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(AppFonts.body())
                                .foregroundColor(colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(colors.backgroundSecondary)
                                .cornerRadius(AppRadius.small)
                        }

                        Button(action: {
                            onConfirm(message, remindTime)
                        }) {
                            Text("确定")
                                .font(AppFonts.body())
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(colors.accent)
                                .cornerRadius(AppRadius.small)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)
                .navigationTitle("设置提醒")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            onCancel()
                        }
                    }
                }
        }
    }
}
