import SwiftUI
import AVFoundation

//
//  OpenClawConnectView.swift
//  OpenClawTrader
//
//  功能：添加 OpenClaw 页面 - 移动端配对
//

// ============================================
// MARK: - OpenClaw Connect View
// ============================================

struct OpenClawConnectView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pairingService = PairingService.shared

    @State private var showScanner = false
    @State private var showManualInput = false
    @State private var manualCode = ""
    @State private var copied = false
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var showUnbindConfirm = false
    @State private var isPaired = false

    // 直接使用 pairingService.isPaired 作为状态源
    private var isPairedState: Bool {
        isPaired || pairingService.isPaired
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header
                headerSection

                if isPairedState {
                    pairedSection
                } else {
                    // Method 1: Let OpenClaw help install
                    methodOneSection

                    // Method 2: Self install
                    methodTwoSection

                    // Divider
                    dividerSection

                    // Scan and Manual Input
                    pairingMethodsSection

                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.xl)
        }
        .background(colors.background)
        .navigationTitle("添加 OpenClaw")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isPaired = pairingService.isPaired
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                showScanner = false
                handleScannedCode(code)
            }
        }
        .alert("输入配对码", isPresented: $showManualInput) {
            TextField("请输入6位配对码", text: $manualCode)
                .textInputAutocapitalization(.characters)
            Button("取消", role: .cancel) {
                manualCode = ""
            }
            Button("确认") {
                handleManualCode(manualCode)
                manualCode = ""
            }
        } message: {
            Text("请输入桌面端显示的6位配对码")
        }
        .alert("配对失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("解除配对", isPresented: $showUnbindConfirm) {
            Button("取消", role: .cancel) {}
            Button("解除配对", role: .destructive) {
                pairingService.unbind()
                isPaired = false
            }
        } message: {
            Text("确定要解除与 OpenClaw 桌面端的配对连接吗？")
        }
        .overlay {
            if isVerifying {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("验证中...")
                            .font(AppFonts.body())
                            .foregroundColor(.white)
                    }
                    .padding(AppSpacing.xl)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(AppRadius.medium)
                }
            }
        }
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

    // MARK: - Method One Section

    private let clawredInstallCommand = """
请先从这个仓库安装 clawred skills，并严格按下面要求执行：
https://github.com/Cyril0404/ClawRed
先直接运行 npm install -g clawred@latest，确保本机的 clawred 命令已经是最新版。涉及后台常驻时不要使用 npx。
如果本机没有 Node.js，请先安装 Node.js（https://nodejs.org/），否则 clawred 无法运行。
完成后，请使用 clawred-pair skill 帮我完成 OpenClawTrader 配对。
严格按 skill 的步骤执行，不要跳过检查。
如果成功，请把最终 6 位配对码单独放一行，方便我复制。
如果失败，请直接告诉我卡在哪一步，以及下一条应该执行的命令。
"""

    private var methodOneSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("方式一")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)

            Text("复制命令，发给 OpenClaw 桌面端执行")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 代码块 - 只显示第一行，隐藏多余行
            ZStack(alignment: .topLeading) {
                // 背景
                Color.black
                    .cornerRadius(AppRadius.small)

                // 第一行命令
                Text("curl -fsSL https://raw.githubusercontent.com/Cyril0404/ClawRed/main/install.sh | bash")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "00FF00"))
                    .lineLimit(1)
                    .padding(AppSpacing.sm)
            }
            .frame(height: 44)

            // 复制按钮
            Button(action: {
                UIPasteboard.general.string = clawredInstallCommand
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            }) {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "已复制" : "复制命令")
                }
                .font(AppFonts.caption())
                .foregroundColor(colors.accent)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.sm)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.small)
            }
        }
    }

    // MARK: - Method Two Section

    private var methodTwoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("方式二")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("自主安装")
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)

                // Step 1: 安装 clawred
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Text("1")
                        .font(AppFonts.caption())
                        .fontWeight(.bold)
                        .foregroundColor(colors.background)
                        .frame(width: 24, height: 24)
                        .background(colors.accent)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("安装 clawred")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)

                        Text("复制下方命令，粘贴到终端运行")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)

                        ScrollView {
                            Text("curl -fsSL https://raw.githubusercontent.com/Cyril0404/ClawRed/main/install.sh | bash")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "00FF00"))
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 60)
                        .background(Color.black)
                        .cornerRadius(AppRadius.small)

                        Button(action: {
                            copyInstallCommand()
                        }) {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "已复制" : "复制命令")
                            }
                            .font(AppFonts.caption())
                            .foregroundColor(colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.sm)
                            .background(colors.backgroundTertiary)
                            .cornerRadius(AppRadius.small)
                        }
                    }
                }

                // Step 2: 配对
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Text("2")
                        .font(AppFonts.caption())
                        .fontWeight(.bold)
                        .foregroundColor(colors.background)
                        .frame(width: 24, height: 24)
                        .background(colors.accent)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("配对")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)

                        Text("运行命令后，桌面端会显示6位配对码")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)
        }
    }

    // MARK: - Divider Section

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(colors.textTertiary.opacity(0.3))
                .frame(height: 1)
            Text("或")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)
            Rectangle()
                .fill(colors.textTertiary.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Pairing Methods Section

    private var pairingMethodsSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("扫码或手动输入配对码")
                .font(AppFonts.caption())
                .foregroundColor(colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppSpacing.md) {
                // Scan QR
                Button(action: {
                    showScanner = true
                }) {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 32))
                        Text("扫码")
                            .font(AppFonts.caption())
                    }
                    .foregroundColor(colors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
                }

                // Manual input
                Button(action: {
                    showManualInput = true
                }) {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 32))
                        Text("手动输入")
                            .font(AppFonts.caption())
                    }
                    .foregroundColor(colors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(colors.backgroundSecondary)
                    .cornerRadius(AppRadius.small)
                }
            }
        }
    }

    // MARK: - Paired Section

    private var pairedSection: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(colors.accent)

                Text("配对成功")
                    .font(AppFonts.title1())
                    .foregroundColor(colors.textPrimary)

                if let token = pairingService.gatewayToken {
                    Text("Gateway Token: \(String(token.prefix(8)))...")
                        .font(AppFonts.caption())
                        .foregroundColor(colors.textSecondary)
                }

                Text("iOS App 已与桌面端 Gateway 配对成功")
                    .font(AppFonts.body())
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: AppSpacing.md) {
                Button(action: {
                    dismiss()
                }) {
                    Text("完成")
                        .font(AppFonts.body())
                        .fontWeight(.semibold)
                        .foregroundColor(colors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(colors.accent)
                        .cornerRadius(AppRadius.small)
                }

                Button(action: {
                    showUnbindConfirm = true
                }) {
                    Text("解除配对")
                        .font(AppFonts.body())
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Helper Methods

    private func copyInstallCommand() {
        let command = "curl -fsSL https://raw.githubusercontent.com/Cyril0404/ClawRed/main/install.sh | bash"
        UIPasteboard.general.string = command
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func generateCode() {
        Task {
            await pairingService.generatePairingCode()
        }
    }

    private func handleScannedCode(_ code: String) {
        // 尝试解析为 URL 格式
        if let parsed = pairingService.parsePairingURL(code) {
            manualCode = parsed.code
            verifyCode(parsed.code)
            return
        }

        // 如果不是 URL 格式，检查是否是纯配对码（6位）
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.count == 6 && trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            manualCode = trimmed
            verifyCode(trimmed)
            return
        }

        // 格式错误 - 显示原始内容帮助调试
        errorMessage = "二维码格式不正确\n原始内容: \(String(code.prefix(50)))\n请确保扫描的是 OpenClaw 生成的配对二维码"
    }

    private func handleManualCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        verifyCode(trimmed)
    }

    private func verifyCode(_ code: String) {
        guard !code.isEmpty else {
            errorMessage = "配对码不能为空"
            return
        }

        isVerifying = true
        errorMessage = nil

        Task {
            if let response = await pairingService.verifyPairingCode(code) {
                isVerifying = false
                if response.success {
                    // 保存 token 到 Keychain
                    if let token = response.gatewayToken {
                        pairingService.savePairingKey(token)
                        // 优先使用 gatewayApiUrl，否则使用 relayAPI
                        let baseURL = response.gatewayApiUrl ?? pairingService.relayAPI
                        // 同时保存到 StorageService 让 OpenClawService 能检测到连接状态
                        StorageService.shared.saveConnection(
                            baseURL: baseURL,
                            apiKey: token
                        )
                        // 立即触发 OpenClawService 连接
                        await OpenClawService.shared.connect()
                        isPaired = true
                    } else if let apiUrl = response.gatewayApiUrl {
                        // gatewayToken 为空但有 apiUrl，尝试使用
                        StorageService.shared.saveConnection(
                            baseURL: apiUrl,
                            apiKey: pairingService.getPairingKey() ?? ""
                        )
                        await OpenClawService.shared.connect()
                        isPaired = true
                    } else {
                        // 服务器返回成功但没有有效凭证
                        errorMessage = "配对成功但未返回有效凭证，请重试"
                        isPaired = false
                    }
                } else {
                    errorMessage = response.error ?? "配对码无效"
                    isPaired = false
                }
            } else {
                isVerifying = false
                errorMessage = pairingService.errorMessage ?? "验证失败，请检查网络连接"
                isPaired = false
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// ============================================
// MARK: - Install Step Row
// ============================================

struct InstallStepRow: View {
    let number: Int
    let title: String
    let description: String

    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text("\(number)")
                .font(AppFonts.caption())
                .fontWeight(.bold)
                .foregroundColor(colors.background)
                .frame(width: 24, height: 24)
                .background(colors.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body())
                    .foregroundColor(colors.textPrimary)

                Text(description)
                    .font(AppFonts.caption())
                    .foregroundColor(colors.textSecondary)
            }
        }
    }
}

// ============================================
// MARK: - QR Scanner View
// ============================================

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCodeScanned: (String) -> Void

    var body: some View {
        NavigationStack {
            QRScannerRepresentable(onCodeScanned: { code in
                onCodeScanned(code)
            })
            .navigationTitle("扫描二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeScanned: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession,
              captureSession.canAddInput(videoInput) else {
            return
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        // Add overlay
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        let scanArea: CGFloat = 250
        let scanRect = CGRect(
            x: (view.bounds.width - scanArea) / 2,
            y: (view.bounds.height - scanArea) / 2,
            width: scanArea,
            height: scanArea
        )

        let path = UIBezierPath(rect: overlayView.bounds)
        let scanPath = UIBezierPath(roundedRect: scanRect, cornerRadius: 12)
        path.append(scanPath)
        path.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer

        view.addSubview(overlayView)

        // Add corner borders
        let cornerView = UIView()
        cornerView.frame = scanRect
        cornerView.backgroundColor = .clear

        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        let cornerColor = UIColor.white.cgColor

        addCorner(cornerView, x: 0, y: 0, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .topLeft)
        addCorner(cornerView, x: scanArea - cornerLength, y: 0, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .topRight)
        addCorner(cornerView, x: 0, y: scanArea - cornerLength, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .bottomLeft)
        addCorner(cornerView, x: scanArea - cornerLength, y: scanArea - cornerLength, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .bottomRight)

        view.addSubview(cornerView)

        // Add label
        let label = UILabel()
        label.text = "将二维码放入框内"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: scanRect.maxY + 30, width: view.bounds.width, height: 30)
        view.addSubview(label)
    }

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func addCorner(_ view: UIView, x: CGFloat, y: CGFloat, length: CGFloat, width: CGFloat, color: CGColor, corner: Corner) {
        let hLayer = CALayer()
        hLayer.frame = CGRect(x: x, y: y, width: length, height: width)
        hLayer.backgroundColor = color

        let vLayer = CALayer()
        vLayer.frame = CGRect(x: x, y: y, width: width, height: length)
        vLayer.backgroundColor = color

        switch corner {
        case .topLeft:
            hLayer.frame = CGRect(x: x, y: y, width: length, height: width)
            vLayer.frame = CGRect(x: x, y: y, width: width, height: length)
        case .topRight:
            hLayer.frame = CGRect(x: x, y: y, width: length, height: width)
            vLayer.frame = CGRect(x: x + length - width, y: y, width: width, height: length)
        case .bottomLeft:
            hLayer.frame = CGRect(x: x, y: y + length - width, width: length, height: width)
            vLayer.frame = CGRect(x: x, y: y, width: width, height: length)
        case .bottomRight:
            hLayer.frame = CGRect(x: x, y: y + length - width, width: length, height: width)
            vLayer.frame = CGRect(x: x + length - width, y: y, width: width, height: length)
        }

        view.layer.addSublayer(hLayer)
        view.layer.addSublayer(vLayer)
    }

    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            stopScanning()
            onCodeScanned?(stringValue)
        }
    }
}
