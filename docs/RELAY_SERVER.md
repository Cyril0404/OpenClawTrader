# Relay Server 部署指南

## 概述

Relay Server 是 OpenClawTrader 系统的云端中继服务，负责：
- 配对码的生成和验证（REST API）
- iOS App 与 Desktop Gateway 之间的 WebSocket 消息路由
- Gateway 和 Device 连接管理

**生产地址**: `ws://150.158.119.114:3001`

---

## 部署环境

| 项目 | 说明 |
|------|------|
| 服务器 | 腾讯云 CVM |
| 公网 IP | 150.158.119.114 |
| SSH 用户 | root / ubuntu |
| SSH 密码 | Nzf9744002009 |
| Node.js 版本 | >= 18.0.0 |
| 进程管理 | PM2 |

---

## 快速部署（腾讯云）

### 1. 连接服务器

```bash
ssh root@150.158.119.114
# 或
ssh ubuntu@150.158.119.114
```

### 2. 安装 Node.js（如果未安装）

```bash
# 使用 nvm 安装
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18
nvm alias default 18

# 验证
node --version  # 应显示 v18.x.x
```

### 3. 安装依赖

```bash
cd /root/relay-server  # 或你存放代码的路径

npm install
```

### 4. 安装 PM2

```bash
npm install -g pm2
```

### 5. 配置环境变量

```bash
export PORT=3001
export HOST=0.0.0.0
export NODE_ENV=production
export SERVER_URL=ws://150.158.119.114:3001
```

### 6. 启动服务

```bash
# 使用 PM2 启动
pm2 start pm2.config.js

# 或直接启动
pm2 start src/index.js --name openclaw-relay
```

### 7. 验证服务

```bash
# 健康检查
curl http://localhost:3001/health

# 应返回
{
  "status": "ok",
  "uptime": 12345,
  "connections": {
    "gateway": 0,
    "device": 0
  }
}
```

### 8. 配置开机自启

```bash
pm2 startup
pm2 save
```

---

## 腾讯云安全组配置

**必须开放 3001 端口**（TCP 协议）：

1. 登录腾讯云控制台
2. 进入「云服务器 CVM」→「安全组」
3. 添加规则：
   - 类型：自定义
   - 协议：TCP
   - 端口：3001
   - 来源：0.0.0.0/0
   - 策略：允许

**注意**：服务器内部防火墙也需要检查：
```bash
# 检查防火墙状态
sudo ufw status

# 如果防火墙开启，放行端口
sudo ufw allow 3001/tcp
```

---

## PM2 常用命令

```bash
# 启动服务
pm2 start pm2.config.js

# 查看状态
pm2 status

# 查看日志
pm2 logs openclaw-relay

# 实时日志
pm2 logs openclaw-relay --follow

# 重启服务
pm2 restart openclaw-relay

# 停止服务
pm2 stop openclaw-relay

# 删除进程
pm2 delete openclaw-relay

# 开机自启配置
pm2 startup
pm2 save

# 监控
pm2 monit
```

---

## PM2 配置文件

`pm2.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'openclaw-relay',
    script: './src/index.js',
    cwd: '/root/relay-server',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3001,
      HOST: '0.0.0.0',
      SERVER_URL: 'ws://150.158.119.114:3001'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true,
    max_memory_restart: '500M'
  }]
}
```

---

## Nginx 反向代理（可选）

如果需要域名访问或 HTTPS：

```nginx
server {
    listen 443 ssl;
    server_name relay.yourdomain.com;

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

---

## 数据目录

```
relay-server/data/
├── pairing-codes.json   # 配对码（自动创建）
└── tokens.json          # token 映射（自动创建）
```

**注意**：
- 这些文件由 PM2 进程（用户 root/ubuntu）创建
- 确保进程有写入权限
- 可使用 `chown` 更改所有者：
  ```bash
  chown -R ubuntu:ubuntu /path/to/relay-server/data
  ```

---

## 日志管理

```bash
# 日志文件位置
~/relay-server/logs/
├── out.log   # 标准输出
└── err.log   # 错误输出

# 清理日志
pm2 flush

# 导出日志
pm2 logs openclaw-relay --out > relay-out.log
pm2 logs openclaw-relay --err > relay-err.log
```

---

## 更新部署

```bash
# 1. 拉取最新代码
cd ~/relay-server
git pull

# 2. 安装新依赖（如果有）
npm install

# 3. 重启服务
pm2 restart openclaw-relay

# 4. 验证
curl http://localhost:3001/health
```

---

## API 端点参考

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/api/pair/generate` | POST | 生成配对码 |
| `/api/pair/verify` | POST | 验证配对码 |

完整 API 文档见 [DEVELOPMENT.md](../DEVELOPMENT.md)。

---

*文档版本: v1.0*
*最后更新: 2026-03-29*
