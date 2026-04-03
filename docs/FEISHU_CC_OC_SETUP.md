# 飞书 + Claude Code (CC) + 丞相 (OC) 协作系统安装指南

> 文档版本：v1.0
> 创建时间：2026-04-01
> 维护者：Claude Code (CC)

---

## 一、系统架构

```
用户 ←→ 飞书群/机器人 ←→ relay-server (腾讯云)
                                    ↓ (HTTP轮询)
                              cc_oc_watch.py (本地)
                                    ↓ (claude -p)
                              Claude Code 处理
                                    ↓ (回复)
                              飞书群 (消息线程)
```

### 组件说明

| 组件 | 位置 | 作用 |
|------|------|------|
| relay-server | 腾讯云 (150.158.119.114:3005) | 消息队列，接收飞书webhook |
| cc_oc_watch.py | Mac Mini 本地 | 轮询relay-server，转发CC处理 |
| Feishu Bot | 飞书开放平台 | 接收/发送群消息 |

---

## 二、腾讯云 relay-server 部署

### 2.1 代码结构

```
relay-server/
├── src/
│   └── index.js          # 主服务器（含飞书webhook）
├── package.json
└── pm2.config.js
```

### 2.2 核心依赖

- Node.js 18+
- pm2 (进程管理)
- express (HTTP服务)

### 2.3 部署步骤

```bash
# 1. 安装依赖
cd /home/ubuntu/relay-server
npm install

# 2. 使用pm2启动
pm2 start pm2.config.js

# 3. 设置开机自启
pm2 startup
pm2 save
```

### 2.4 关键API端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/webhook/feishu` | GET/POST | 飞书webhook（验证+接收消息） |
| `/api/agent/messages/:agentId` | GET | 获取消息（不删除） |
| `/api/agent/messages/:agentId/peek` | GET | 查看消息不删除 |
| `/api/agent/messages` | POST | 发送消息到队列 |
| `/api/feishu/reply` | POST | 通过飞书回复消息 |

### 2.5 飞书webhook配置

在飞书开放平台配置webhook URL:
```
https://你的域名/webhook/feishu
```

需要启用事件订阅:
- `im.message.receive_v1` (接收消息)

---

## 三、本地 cc_oc_watch.py 配置

### 3.1 文件位置

```
/Users/zifanni/.openclaw/workspace/scripts/cc_oc_watch.py
```

### 3.2 核心配置

```python
RELAY_URL = "http://150.158.119.114:3005"  # 腾讯云relay-server地址
QUEUE_ENDPOINT = f"{RELAY_URL}/api/agent/messages/cc-terminal"
```

### 3.3 启动命令

```bash
cd /Users/zifanni/.openclaw/workspace/scripts
python3 cc_oc_watch.py
```

### 3.4 守护进程（可选）

```bash
nohup python3 cc_oc_watch.py > /tmp/claude_collab/cc_watch.log 2>&1 &
```

### 3.5 日志文件

- `/tmp/claude_collab/cc_auto_reply.log` - 主日志
- `/tmp/claude_collab/processed_ids.json` - 已处理消息ID

---

## 四、飞书机器人配置

### 4.1 获取凭证

在飞书开放平台创建应用后获取:
- `app_id`: 如 `cli_a93473d066f8dbc3`
- `app_secret`: 如 `jDfJySahqm9U8q0zYJR0egFFmDrK5EPt`

### 4.2 权限配置

需要开通以下权限:
- `im:message` - 发送消息
- `im:message:receive_v1` - 接收消息

### 4.3 事件订阅

启用 `im.message.receive_v1` 事件

### 4.4 凭证保存

```bash
# 保存到文件（relay-server使用）
~/Desktop/docs/cc_feishu_bot.json
```

---

## 五、消息流程

### 5.1 用户发送消息流程

1. 用户在飞书群 @机器人 或 私聊机器人
2. 飞书服务器 POST 到 `https://域名/webhook/feishu`
3. relay-server 验证并解析消息
4. 消息入队到 `cc-terminal` 队列
5. cc_oc_watch.py 轮询获取消息
6. 调用 `claude -p` 转发给 Claude Code
7. Claude Code 处理并返回回复
8. cc_oc_watch.py 调用 `/api/feishu/reply` 回复到飞书

### 5.2 消息格式

```json
{
  "id": "消息UUID",
  "from": "feishu",
  "to": "cc-terminal",
  "content": "用户消息内容",
  "type": "text",
  "source": "feishu",
  "feishu_message_id": "飞书消息ID",
  "sender_id": "发送者open_id"
}
```

---

## 六、故障排查

### 6.1 消息没收到

1. 检查飞书事件订阅是否启用
2. 检查webhook URL是否可访问
3. 查看腾讯云relay-server日志:
   ```bash
   ssh ubuntu@150.158.119.114 "pm2 logs relay-server --lines 50"
   ```

### 6.2 CC没回复

1. 检查cc_oc_watch.py是否运行:
   ```bash
   ps aux | grep cc_oc_watch
   ```
2. 检查日志:
   ```bash
   tail -f /tmp/claude_collab/cc_auto_reply.log
   ```

### 6.3 飞书回复失败

1. 检查飞书bot权限
2. 检查message_id是否有效
3. 查看腾讯云日志中的Feishu API返回码

---

## 七、相关文件路径

| 文件 | 路径 |
|------|------|
| relay-server | `/home/ubuntu/relay-server/` |
| cc_oc_watch.py | `/Users/zifanni/.openclaw/workspace/scripts/` |
| cc_feishu_bot.json | `~/Desktop/docs/` |
| CC协作文档 | `/Users/zifanni/openclaw/workspace/CLAUDE_COLLABORATION.md` |

---

## 八、修改记录

| 时间 | 修改人 | 修改内容 |
|------|--------|----------|
| 2026-04-01 | CC | 初始版本创建 |
