# OpenClaw Relay Server

WebSocket 中继服务器，用于 OpenClaw 移动端配对功能。

## 功能特性

- 配对码生成和验证 API
- WebSocket 连接管理（Gateway 和 Device）
- 消息路由转发
- 心跳检测和自动断开
- 支持 1000+ 并发连接

## 架构

```
[iOS App] ←WebSocket→ [中继服务器] ←WebSocket→ [用户本地Gateway]
```

## 快速开始

### 1. 安装依赖

```bash
cd ~/openclaw/relay-server
npm install
```

### 2. 开发模式运行

```bash
npm run dev
# 或直接
node src/index.js
```

### 3. 生产环境运行（PM2）

```bash
# 安装 PM2（如果还没安装）
npm install -g pm2

# 启动服务
pm2 start pm2.config.js

# 查看日志
pm2 logs openclaw-relay

# 重启服务
pm2 restart openclaw-relay

# 停止服务
pm2 stop openclaw-relay
```

## API 接口

### 生成配对码

```bash
POST /api/pair/generate

# 请求体（可选）
{
  "gatewayId": "可选，绑定到特定Gateway"
}

# 响应
{
  "code": "NVJ53Z",           # 6位配对码
  "expiresAt": "ISO时间",     # 5分钟后过期
  "serverUrl": "ws://...",    # WebSocket服务器地址
  "token": "uuid"            # 临时token
}
```

### 验证配对码

```bash
POST /api/pair/verify

# 请求体
{
  "code": "NVJ53Z",
  "token": "之前生成的token"
}

# 响应
{
  "success": true,
  "gatewayToken": "用于WebSocket连接的token",
  "gatewayId": "绑定的Gateway ID"
}
```

### 健康检查

```bash
GET /health

# 响应
{
  "status": "ok",
  "uptime": 12345,
  "connections": {
    "gateway": 2,
    "device": 3
  }
}
```

## WebSocket 协议

### 桌面端（Gateway）连接

```javascript
// 连接时发送
{
  "type": "gateway",
  "gatewayId": "桌面端的唯一ID"
}

// 服务器响应
{
  "type": "registered",
  "role": "gateway",
  "gatewayId": "xxx"
}

// 收到设备消息
{
  "type": "message",
  "from": "device",
  "content": "消息内容"
}

// 设备断开
{
  "type": "device_disconnected",
  "token": "设备token"
}
```

### 移动端（Device）连接

```javascript
// 连接时发送
{
  "type": "device",
  "token": "验证成功获得的gatewayToken"
}

// 服务器响应
{
  "type": "registered",
  "role": "device",
  "gatewayId": "xxx"
}

// 发送消息
{
  "type": "message",
  "content": "消息内容"
}

// 收到Gateway消息
{
  "type": "message",
  "from": "gateway",
  "content": "消息内容"
}

// Gateway断开
{
  "type": "gateway_disconnected"
}
```

### 通用消息

```javascript
// 心跳
{ "type": "ping" }
// 服务器响应
{ "type": "pong" }

// 错误
{
  "type": "error",
  "message": "错误信息"
}
```

## 配对流程

1. 桌面端调用 `POST /api/pair/generate` 获取配对码
2. 桌面端显示配对二维码（二维码内容：`openclaw://relay?server=<地址>&code=<6位码>`）
3. iOS 端扫码，调用 `POST /api/pair/verify` 验证 code
4. 验证成功，iOS 获得 gatewayToken，连接到 WebSocket
5. 服务器通知对应 Gateway「有新设备连接」
6. 路由建立完成，iOS 可以发送消息

## 配置

通过环境变量配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| PORT | 3001 | HTTP/WebSocket 端口 |
| HOST | 0.0.0.0 | 监听地址 |
| NODE_ENV | development | 运行环境 |
| SERVER_URL | ws://localhost:PORT | 对外暴露的 WebSocket 地址 |

## 部署

### Nginx 反向代理配置示例

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # WebSocket 升级
    location /ws {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }

    # HTTP API
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### PM2 开机自启

```bash
pm2 startup
pm2 save
```

## 测试

```bash
# 测试生成配对码
curl -X POST http://localhost:3001/api/pair/generate

# 测试验证配对码
curl -X POST http://localhost:3001/api/pair/verify \
  -H "Content-Type: application/json" \
  -d '{"code": "NVJ53Z"}'

# 健康检查
curl http://localhost:3001/health
```

## License

MIT
