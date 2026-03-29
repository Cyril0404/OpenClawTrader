# relay-server 腾讯云部署指南

## 目标
在腾讯云服务器 (150.158.119.114) 上运行 relay-server，让 iPhone 可以通过服务器中转连接 Mac 上的 OpenClaw Gateway。

## 当前状态
- ✅ Mac 本地 relay-server 已运行（端口 3001）
- ✅ gateway-bridge 已运行，连接到本地 Gateway
- ✅ E2E 消息转发测试成功
- ⚠️ 服务器上的 relay-server 有 bug（tokenRegistry 问题），需要更新

## 服务器信息
- IP: 150.158.119.114
- SSH 端口: 22
- relay-server 端口: 3001

## 部署步骤

### 步骤 1: 上传 relay-server 文件到服务器

在 Mac 上运行：
```bash
# 打包 relay-server
cd ~/openclaw/relay-server
tar -czvf /tmp/relay-server.tar.gz src/ package.json

# 上传到腾讯云（需要密码）
sshpass -p 'YOUR_PASSWORD' scp /tmp/relay-server.tar.gz root@150.158.119.114:/root/relay-server.tar.gz
```

### 步骤 2: 在服务器上解压并安装依赖

```bash
ssh root@150.158.119.114
# 输入密码

mkdir -p /root/relay-server
cd /root/relay-server
tar -xzvf /root/relay-server.tar.gz

# 安装依赖
npm install

# 停止旧服务
pm2 stop relay-server 2>/dev/null || true
forever stopall 2>/dev/null || true

# 启动新服务
node src/index.js &
```

### 步骤 3: 验证服务器 relay-server

```bash
curl http://150.158.119.114:3001/health
# 应返回 {"status":"ok","uptime":...,"connections":{"gateway":0,"device":0}}
```

### 步骤 4: 更新 Mac 上的 gateway-bridge

修改 /Users/zifanni/bin/gateway-bridge-runner.sh：
```bash
RELAY_URL="ws://150.158.119.114:3001"  # 改用腾讯云地址
```

然后重启 gateway-bridge：
```bash
pkill -f gateway-bridge-runner
nohup env PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin bash /Users/zifanni/bin/gateway-bridge-runner.sh > /dev/null 2>&1 &
```

### 步骤 5: 测试端到端

iPhone 连接 ws://150.158.119.114:3001，生成配对码配对，测试消息发送。

## 文件说明

relay-server/src/index.js - 主入口
relay-server/src/shared/tokenRegistry.js - 配对码注册表（必须 in-memory Map，不能用 global）
relay-server/src/relay/gateway.js - Gateway 连接管理
relay-server/src/relay/device.js - Device 连接管理
relay-server/src/api/pair.js - 配对码 API

## 架构

```
iPhone App
    ↓ WebSocket
relay-server (腾讯云 150.158.119.114:3001)
    ↓ WebSocket
gateway-bridge (Mac 本地)
    ↓ WebSocket
OpenClaw Gateway (Mac localhost:18789)
    ↓
Cloudflare Tunnel → 公网
```

## 调试命令

服务器上：
```bash
# 查看 relay-server 日志
tail -f /tmp/relay-server.log

# 重启服务
pkill -f "node src/index.js"; cd /root/relay-server && node src/index.js &
```

Mac 上：
```bash
# 查看 gateway-bridge 日志
tail -f /tmp/gateway-bridge.log

# 重启 gateway-bridge
pkill -f gateway-bridge-runner
nohup env PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin bash /Users/zifanni/bin/gateway-bridge-runner.sh > /dev/null 2>&1 &
```
