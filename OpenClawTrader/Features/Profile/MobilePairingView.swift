import SwiftUI
import AVFoundation

//
//  MobilePairingView.swift
//  OpenClawTrader
//
//  功能：移动端配对页面
//

// ============================================
// MARK: - Mobile Pairing View
// ============================================

struct MobilePairingView: View {
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pairingService = PairingService.shared

    @State private var currentStep: PairingStep = .selectMethod
    @State private var showScanner = false
    @State private var showManualInput = false
    @State private var manualCode = ""
    @State private var copied = false

    enum PairingStep {
        case selectMethod      // 选择安装方式
        case showSteps        // 显示安装步骤
        case generateCode     // 生成配对码
        case scanOrInput      // 扫码或输入
        case paired           // 配对成功
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    switch currentStep {
                    case .selectMethod:
                        selectMethodSection
                    case .showSteps:
                        showStepsSection
                    case .generateCode, .scanOrInput:
                        pairingCodeSection
                    case .paired:
                        pairedSection
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
            }
        }
        .background(colors.background)
        .navigationTitle("移动端配对")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                showScanner = false
                handleScannedCode(code)
            }
        }
        .alert("输入配对码", isPresented: $showManualInput) {
            TextField("请输入6位配对码", text: $manualCode)
                .textInputAutocapitalization(.characters)
            Button("取消", role: .cancel) {}
            Button("确认") {
                handleManualCode(manualCode)
            }
        } message: {
            Text("请输入桌面端显示的6位配对码")
        }
    }

    // MARK: - Select Method Section

    private var selectMethodSection: some View {
        VStack(spacing: AppSpacing.xl) {
            // Header
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(colors.accent)

                Text("移动端配对")
                    .font(AppFonts.title1())
                    .foregroundColor(colors.textPrimary)

                Text("将 iOS App 与桌面端 Gateway 配对")
                    .font(AppFonts.body())
                    .foregroundColor(colors.textSecondary)
            }

            // Method 1: Let OpenClaw help install
            Button(action: {
                copyInstallCommand()
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("方式一")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textTertiary)
                        Text("让 OpenClaw 帮忙安装")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }
                    Spacer()
                    if copied {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppColors.success)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(colors.textSecondary)
                    }
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
            }

            // Method 2: Self install
            Button(action: {
                currentStep = .showSteps
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("方式二")
                            .font(AppFonts.caption())
                            .foregroundColor(colors.textSecondary)
                        Text("自主安装")
                            .font(AppFonts.body())
                            .foregroundColor(colors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(colors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.medium)
            }

            // Proceed to pairing
            Button(action: {
                currentStep = .generateCode
                generateCode()
            }) {
                HStack {
                    Text("已有配对码？直接生成配对")
                        .font(AppFonts.body())
                        .foregroundColor(colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
            }
        }
    }

    // MARK: - Show Steps Section

    private var showStepsSection: some View {
        VStack(spacing: AppSpacing.xl) {
            // Back button
            Button(action: {
                currentStep = .selectMethod
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Steps
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("自主安装步骤")
                    .font(AppFonts.title2())
                    .foregroundColor(colors.textPrimary)

                InstallStepRow(number: 1, title: "安装 clawpilot", description: "运行安装命令")
                InstallStepRow(number: 2, title: "检查 Gateway 配置", description: "确认本地服务已启用")
                InstallStepRow(number: 3, title: "启动 Gateway", description: "确保服务运行在端口 18789")
                InstallStepRow(number: 4, title: "生成配对码", description: "在桌面端获取配对码")
            }
            .padding(AppSpacing.md)
            .background(colors.backgroundSecondary)
            .cornerRadius(AppRadius.medium)

            // Copy install command
            Button(action: {
                copyInstallCommand()
            }) {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "已复制" : "复制安装命令")
                }
                .foregroundColor(colors.accent)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(colors.backgroundSecondary)
                .cornerRadius(AppRadius.small)
            }

            // Continue to generate code
            Button(action: {
                currentStep = .generateCode
                generateCode()
            }) {
                Text("完成安装步骤后，点击此处生成配对码")
                    .font(AppFonts.body())
                    .foregroundColor(colors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.accent)
                    .cornerRadius(AppRadius.small)
            }
        }
    }

    // MARK: - Pairing Code Section

    private var pairingCodeSection: some View {
        VStack(spacing: AppSpacing.xl) {
            // Back button
            Button(action: {
                currentStep = .selectMethod
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
                .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let code = pairingService.currentCode {
                // Show QR Code
                qrCodeView(code: code)

                // Pairing methods
                pairingMethodsView
            } else if pairingService.pairingStatus == PairingService.PairingStatus.generating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: colors.accent))
                    .scaleEffect(1.5)
                    .frame(height: 200)
            } else if let error = pairingService.errorMessage {
                // Error state
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.error)

                    Text(error)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.error)
                        .multilineTextAlignment(.center)

                    Button("重试") {
                        generateCode()
                    }
                    .foregroundColor(colors.accent)
                }
            }
        }
    }

    private func qrCodeView(code: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            // QR Code
            if let qrData = pairingService.qrCodeData,
               let qrImage = generateQRCode(from: qrData) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(AppSpacing.md)
                    .background(Color.white)
                    .cornerRadius(AppRadius.medium)
            } else {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(colors.backgroundSecondary)
                    .frame(width: 200, height: 200)
                    .overlay(
                        ProgressView()
                    )
            }

            // Code display
            Text(code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(colors.textPrimary)
                .tracking(8)

            Text("配对码有效期: 5分钟")
                .font(AppFonts.caption())
                .foregroundColor(colors.textTertiary)
        }
        .padding(AppSpacing.lg)
        .background(colors.backgroundSecondary)
        .cornerRadius(AppRadius.medium)
    }

    private var pairingMethodsView: some View {
        VStack(spacing: AppSpacing.md) {
            Text("其他配对方式")
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
                    .foregroundColor(AppColors.success)

                Text("配对成功")
                    .font(AppFonts.title1())
                    .foregroundColor(colors.textPrimary)

                Text("iOS App 已与桌面端 Gateway 配对成功")
                    .font(AppFonts.body())
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

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
        }
    }

    // MARK: - Helper Methods

    private func copyInstallCommand() {
        let command = "curl -sSL https://openclaw.example.com/install.sh | sh"
        UIPasteboard.general.string = command
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func generateCode() {
        Task {
            await pairingService.generatePairingCode()
            if pairingService.pairingStatus == PairingService.PairingStatus.ready {
                currentStep = .scanOrInput
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        if let validCode = pairingService.parseQRCode(code) {
            manualCode = validCode
            verifyCode(validCode)
        }
    }

    private func handleManualCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        verifyCode(trimmed)
    }

    private func verifyCode(_ code: String) {
        Task {
            let success = await pairingService.verifyPairingCode(code)
            if success {
                currentStep = .paired
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

        // Top-left
        addCorner(cornerView, x: 0, y: 0, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .topLeft)
        // Top-right
        addCorner(cornerView, x: scanArea - cornerLength, y: 0, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .topRight)
        // Bottom-left
        addCorner(cornerView, x: 0, y: scanArea - cornerLength, length: cornerLength, width: cornerWidth, color: cornerColor, corner: .bottomLeft)
        // Bottom-right
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