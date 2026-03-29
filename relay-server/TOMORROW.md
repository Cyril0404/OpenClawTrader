# 明日待办：relay-server 腾讯云部署

## ✅ 今晚已完成

### 1. relay-server 本地测试成功
- E2E 消息转发：Device → relay → gateway-bridge → Gateway → 响应回传
- Gateway 签名验证通过
- gateway-bridge 自动冲连 + 运行稳定

### 2. gateway-bridge 修复
修复了 3 个关键 bug：
- `buildSignedDevice` 的 v2 payload 格式（`v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce`）
- Ed25519 签名用 `crypto.sign()` + base64urlencode
- Gateway ID 必须用 `openclaw-macos` + `ui` 模式
- 复用 ClawPilot 设备身份（`~/.clawai/device-identity.json`）

### 3. 持久化运行
- gateway-bridge runner：auto-restart，失败 5 秒后重连
- Launchd 服务已配置：ai.openclaw.gateway-bridge.plist
- 日志：/tmp/gateway-bridge.log

## ⏳ 等待腾讯云部署（需要 SSH 密码）

### 已准备好的内容
- **部署指南**：`~/openclaw/relay-server/DEPLOY.md`
- **SSH 公钥**（需添加到腾讯云）：
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDY4/bjr2u8jGux9eNly7xJ3EJlg9rceildOi6Mb80xsMSNUawaIutCln6DyvEPUekkTa3YS0bg+wA5l8wsQPcrUJ12lQoEx3V12vCHSeFM77NzmagzfRcRWfZV8HEfJdXfDfSspL1xWXWxkYmwlTXV2gpFPdb6Pz09FIZNnBtO0uDQEpQgqImpbHFIFgJYrx9vLmb8iynw3Iz4VPEfiL31kxfnP4B5ia0wcgckQG82trENQkA+aAzVQ+ZZ92KRGvcmsRGqbCVW3ehvpUTN1EW0gQZZ2abrxq99AXUMX5e5Lmb4Pd2nw6ZfBOCSC6HTNIsy2kGnT+jHepOzK81rajqM8piG3OGkx3QHdowCyZHyxHfnX2+7q6Y/PbyU7logN8HFVVweJHapyxyuORYXo51RQSgD5n9GTrxckapd7cyap/9uAX4q7aSyyl95yzdi3QcJQOU1ke0K8yK+VCWM0vxki0rkUlNCch+7ke4i87T//l+Ac+8sXw5Nnnfk4xpndbk= 348068992@qq.com
```

### 部署步骤（30 分钟）
1. 腾讯云控制台 → 添加上面的公钥到服务器
2. 把 SSH 密码给 丞相
3. 丞相自动完成：上传文件 → 重启服务 → 验证

### 架构（部署后）
```
iPhone App
    ↓ ws://150.158.119.114:3001
relay-server (腾讯云，公网 IP)
    ↓ ws://localhost:3001
gateway-bridge (Mac，持续连接)
    ↓ wss://xxx.trycloudflare.com
OpenClaw Gateway (Mac localhost:18789)
    ↓
互联网
```

## 当前测试状态
- ✅ 本地 E2E 测试通过
- ⏳ 外部（iPhone → 腾讯云 relay → Mac Gateway）待部署后测试

## 提醒神冢
1. 腾讯云控制台添加 SSH 公钥（或直接给密码）
2. 腾讯云买 ¥80/月服务器（还没买？）
3. 测试 iPhone 连接
