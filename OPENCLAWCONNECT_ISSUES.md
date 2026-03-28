# OpenClawConnectView.swift 代码问题修复清单

**文件路径：** `~/openclaw/OpenClawTrader/OpenClawTrader/Features/Profile/OpenClawConnectView.swift`

---

## 问题1：复制命令是假的 URL（致命）

**位置：** `copyInstallCommand()` 函数

**现状（有问题）：**
```swift
private func copyInstallCommand() {
    let command = "curl -sSL https://openclaw.example.com/install.sh | sh"
    UIPasteboard.general.string = command
}
```

**修复为：**
```swift
private func copyInstallCommand() {
    let command = "curl -fsSL https://raw.githubusercontent.com/Cyril0404/ClawRed/main/install.sh | bash"
    UIPasteboard.general.string = command
}
```

---

## 问题2：配对成功后 UI 不刷新（致命）

**位置：** `verifyCode()` 函数末尾

**现状：** 验证成功后保存了 token，但 UI 不变化，用户不知道成功了

**修复：** 在 `if response.success {` 内部加一行 `isPaired = true`

---

## 问题3：isPaired 不响应变化（致命）

**位置：** `isPaired` 的 computed property 定义

**现状：**
```swift
private var isPaired: Bool {
    refreshTrigger
    return pairingService.isPaired
}
```
refreshTrigger 永远不变，所以 isPaired 永远是 false。

**修复：** 改成 @State 变量：
```swift
@State private var isPaired = false

// .onAppear 里
.onAppear {
    isPaired = pairingService.isPaired
}

// verifyCode 成功后
isPaired = true

// 解绑操作里
isPaired = false
```

---

## 问题4：命令文本只显示一行（严重）

**位置：** methodOneSection 里的 Text(clawredInstallCommand)

**现状：** 有 .lineLimit(1) 导致400字只显示一行省略号

**修复：** 去掉 lineLimit(1)，用 ScrollView 包裹：
```swift
ScrollView {
    Text(clawredInstallCommand)
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(Color(hex: "00FF00"))
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)
}
.frame(maxHeight: 200)
.background(Color.black)
.cornerRadius(AppRadius.small)
```

---

## 问题5：检测服务器状态的方法不存在（严重）

**位置：** checkServerStatus() 函数

**现状：**
```swift
let isOnline = await pairingService.checkServerStatus() // 方法不存在
```

**修复：** 自己实现：
```swift
private func checkServerStatus() async {
    serverStatus = .checking
    do {
        let url = URL(string: "http://150.158.119.114:3001/health")!
        let (_, response) = try await URLSession.shared.data(from: url)
        serverStatus = (response as? HTTPURLResponse)?.statusCode == 200 ? .online : .offline
    } catch {
        serverStatus = .offline
    }
}
```

---

## 问题6：serverStatusSection 里的 task 重复触发

**位置：** serverStatusSection computed property 内部有 .task {}

**修复：** 把 .task {} 从 serverStatusSection 里移除，只保留在主视图 body 的 .task modifier 里。

---

## 问题7：方式二 UI 内容全空

**位置：** methodTwoSection

**现状：** InstallStepRow 的 description 全是空字符串，用户看不到说明

**修复（推荐方案）：** 删掉 InstallStepRow，改成和方式一一样的简洁命令块风格，加上说明文字"打开终端 App，粘贴并运行命令"。

---

**要求：**
1. 按顺序修复以上所有问题
2. 修复完后 Build 并验证
3. 截图展示最终效果
4. 注意：clawredInstallCommand 内容不变，保持完整的那段文字
