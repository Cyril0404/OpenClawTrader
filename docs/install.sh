#!/bin/bash
# Claude Code + 飞书 + 丞相 协作系统一键安装脚本
# 用法: bash install.sh <飞书AppID> <飞书AppSecret>

set -e

echo "=========================================="
echo "  CC-OC-Feishu 一键安装脚本 v2 (带记忆)"
echo "=========================================="

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置
RELAY_DIR="$HOME/relay-server"
LOCAL_SCRIPT="$HOME/.openclaw/workspace/scripts/cc_oc_watch.py"
LOG_DIR="/tmp/claude_collab"
HISTORY_FILE="$LOG_DIR/feishu_history.json"
MAX_HISTORY=10  # 保留最近10条对话

# 检查参数
FEISHU_APP_ID="${1:-}"
FEISHU_APP_SECRET="${2:-}"

if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ]; then
    echo -e "${YELLOW}用法: bash install.sh <飞书AppID> <飞书AppSecret>${NC}"
    echo ""
    echo "示例:"
    echo "  bash install.sh cli_a93473d066f8dbc3 jDfJySahqm9U8q0zYJR0egFFmDrK5EPt"
    exit 1
fi

echo -e "${GREEN}[1/6] 检查环境...${NC}"
command -v node >/dev/null 2>&1 || { echo "需要 Node.js"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "需要 Python3"; exit 1; }
command -v pm2 >/dev/null 2>&1 || { echo "需要 pm2 (npm install -g pm2)"; exit 1; }

echo -e "${GREEN}[2/6] 创建目录...${NC}"
mkdir -p "$RELAY_DIR/src"
mkdir -p "$(dirname $LOCAL_SCRIPT)"
mkdir -p "$LOG_DIR"

echo -e "${GREEN}[3/6] 创建 relay-server (带历史记录)...${NC}"
cat > "$RELAY_DIR/package.json" << 'EOF'
{
  "name": "relay-server",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

cat > "$RELAY_DIR/pm2.config.js" << 'EOF'
export default {
  apps: [{
    name: 'relay-server',
    script: './src/index.js',
    interpreter: 'node',
    port: 3005,
    watch: false,
    autorestart: true,
    env: {
      FEISHU_BOT_APP_ID: '',
      FEISHU_BOT_APP_SECRET: ''
    }
  }]
}
EOF

cat > "$RELAY_DIR/src/index.js" << 'INDEXEOF'
import express from 'express'
import { readFileSync, writeFileSync, existsSync } from 'fs'

const app = express()
app.use(express.json())

const FEISHU_BOT_APP_ID = process.env.FEISHU_BOT_APP_ID || ''
const FEISHU_BOT_APP_SECRET = process.env.FEISHU_BOT_APP_SECRET || ''
const HISTORY_FILE = process.env.HISTORY_FILE || '/tmp/claude_collab/feishu_history.json'
const MAX_HISTORY = 10

// ========== 飞书历史管理 ==========
function loadHistory() {
  try {
    if (existsSync(HISTORY_FILE)) {
      return JSON.parse(readFileSync(HISTORY_FILE, 'utf8'))
    }
  } catch (e) {
    console.error('[History] Load error:', e)
  }
  return { conversations: {} }
}

function saveHistory(history) {
  try {
    writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2))
  } catch (e) {
    console.error('[History] Save error:', e)
  }
}

function addToHistory(chatId, role, content) {
  const history = loadHistory()
  if (!history.conversations[chatId]) {
    history.conversations[chatId] = []
  }
  history.conversations[chatId].push({ role, content, time: Date.now() })
  // 只保留最近 MAX_HISTORY 条
  if (history.conversations[chatId].length > MAX_HISTORY) {
    history.conversations[chatId] = history.conversations[chatId].slice(-MAX_HISTORY)
  }
  saveHistory(history)
}

function getHistory(chatId) {
  const history = loadHistory()
  return history.conversations[chatId] || []
}

// ========== AgentMQ ==========
class AgentMessageQueue {
  constructor() {
    this.queues = new Map()
  }

  enqueue(agentId, message) {
    if (!this.queues.has(agentId)) {
      this.queues.set(agentId, [])
    }
    const msgId = require('crypto').randomUUID()
    const queuedMsg = { id: msgId, ...message }
    this.queues.get(agentId).push(queuedMsg)
    return msgId
  }

  dequeue(agentId) {
    const messages = this.queues.get(agentId) || []
    this.queues.delete(agentId)
    return messages
  }

  peek(agentId) {
    return this.queues.get(agentId) || []
  }

  size(agentId) {
    return (this.queues.get(agentId) || []).length
  }
}

const agentMessageQueue = new AgentMessageQueue()

// ========== 飞书 Webhook ==========
app.get('/webhook/feishu', (req, res) => {
  const { challenge } = req.query
  if (challenge) {
    console.log('[Feishu Webhook] Verification challenge received')
    return res.json({ challenge })
  }
  res.status(400).json({ error: 'No challenge parameter' })
})

app.post('/webhook/feishu', async (req, res) => {
  try {
    const body = req.body
    const event = body.event || {}
    const message = event.message || {}
    const chatId = event.chat_id || 'unknown'

    console.log('[Feishu Webhook] Received:', JSON.stringify(body).substring(0, 200))

    // 提取消息内容
    let content = message.content || ''
    try {
      content = JSON.parse(content).text || content
    } catch {}

    // 保存用户消息到历史
    addToHistory(chatId, 'user', content)

    const ccMessage = {
      from: 'feishu',
      to: 'cc-terminal',
      content: content,
      type: 'text',
      source: 'feishu',
      feishu_message_id: message.message_id || '',
      sender_id: event.sender?.sender_id?.open_id || '',
      chat_id: chatId
    }

    const msgId = agentMessageQueue.enqueue('cc-terminal', ccMessage)
    console.log(`[AgentMQ] Enqueued for cc-terminal, size: ${agentMessageQueue.size('cc-terminal')}`)

    res.json({ success: true, msgId })
  } catch (err) {
    console.error('[Feishu Webhook] Error:', err)
    res.status(500).json({ error: err.message })
  }
})

// ========== Agent 消息 API ==========
app.get('/api/agent/messages/:agentId', (req, res) => {
  const { agentId } = req.params
  const messages = agentMessageQueue.dequeue(agentId)
  res.json({ success: true, agentId, messages })
})

app.get('/api/agent/messages/:agentId/peek', (req, res) => {
  const { agentId } = req.params
  const messages = agentMessageQueue.peek(agentId)
  res.json({ success: true, agentId, messages, count: messages.length })
})

// 获取聊天历史
app.get('/api/feishu/history/:chatId', (req, res) => {
  const { chatId } = req.params
  const history = getHistory(chatId)
  res.json({ success: true, chatId, history })
})

// ========== 飞书回复 API ==========
app.post('/api/feishu/reply', async (req, res) => {
  const { feishu_message_id, content, chat_id } = req.body

  if (!feishu_message_id || !content) {
    return res.status(400).json({ error: 'Missing feishu_message_id or content' })
  }

  try {
    // 保存机器人的回复到历史
    if (chat_id) {
      addToHistory(chat_id, 'assistant', content)
    }

    // 获取 tenant_access_token
    const tokenResp = await fetch('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ app_id: FEISHU_BOT_APP_ID, app_secret: FEISHU_BOT_APP_SECRET })
    })
    const tokenData = await tokenResp.json()
    const token = tokenData.tenant_access_token

    if (!token) {
      return res.status(500).json({ error: 'Failed to get token', details: tokenData })
    }

    // 发送回复
    const replyResp = await fetch('https://open.feishu.cn/open-apis/im/v1/messages', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        receive_id: feishu_message_id,
        msg_type: 'text',
        content: JSON.stringify({ text: content })
      })
    })

    const result = await replyResp.json()
    console.log('[Feishu Reply] Result:', JSON.stringify(result).substring(0, 100))

    if (result.code === 0) {
      res.json({ success: true, data: result.data })
    } else {
      res.status(500).json({ code: result.code, msg: result.msg })
    }
  } catch (err) {
    console.error('[Feishu Reply] Error:', err)
    res.status(500).json({ error: err.message })
  }
})

app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() })
})

const PORT = process.env.PORT || 3005
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Relay Server started on port ${PORT}`)
  console.log(`History file: ${HISTORY_FILE}`)
})
INDEXEOF

echo -e "${GREEN}[4/6] 安装依赖...${NC}"
cd "$RELAY_DIR"
npm install 2>&1 | tail -3

echo -e "${GREEN}[5/6] 创建本地 cc_oc_watch.py (带记忆)...${NC}"
cat > "$LOCAL_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
"""CC-OC消息监控脚本 - 带飞书历史记忆"""
import requests
import time
import subprocess
import json
import os

RELAY_URL = os.environ.get("RELAY_URL", "http://localhost:3005")
QUEUE_ENDPOINT = f"{RELAY_URL}/api/agent/messages/cc-terminal"
LOG_FILE = "/tmp/claude_collab/cc_auto_reply.log"
STATE_FILE = "/tmp/claude_collab/processed_ids.json"

def log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}] {msg}\n")
    print(f"[{timestamp}] {msg}")

def get_processed_ids():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            return set(json.load(f).get("ids", []))
    return set()

def save_processed_ids(ids):
    with open(STATE_FILE, "w") as f:
        json.dump({"ids": list(ids)}, f)

def get_history(chat_id):
    """获取飞书聊天历史"""
    try:
        resp = requests.get(f"{RELAY_URL}/api/feishu/history/{chat_id}", timeout=5)
        data = resp.json()
        if data.get("success"):
            return data.get("history", [])
    except Exception as e:
        log(f"获取历史失败: {e}")
    return []

def build_context(history):
    """构建带历史的上下文"""
    if not history:
        return ""
    context = "\n\n【最近对话历史】:\n"
    for i, msg in enumerate(history):
        role = "用户" if msg.get("role") == "user" else "CC"
        context += f"{role}: {msg.get('content', '')}\n"
    return context

def extract_text(raw):
    """从stream-json提取文本"""
    try:
        lines = raw.strip().split('\n')
        for line in lines:
            obj = json.loads(line)
            if obj.get("type") == "assistant":
                contents = obj.get("message", {}).get("content", [])
                for c in contents:
                    if c.get("type") == "text":
                        return c.get("text", "")
    except:
        pass
    return raw.strip() if raw else ""

def send_to_cc(content, context=""):
    """发送给CC处理"""
    try:
        full_prompt = f"用户发来消息: {content}。"
        if context:
            full_prompt += f"\n{context}"
        full_prompt += "\n请回复。"

        result = subprocess.run(
            ["claude", "-p", full_prompt],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode == 0:
            return extract_text(result.stdout)
    except Exception as e:
        log(f"CC调用失败: {e}")
    return None

def send_reply(feishu_msg_id, text, chat_id):
    """发送回复到飞书"""
    try:
        resp = requests.post(f"{RELAY_URL}/api/feishu/reply",
            json={"feishu_message_id": feishu_msg_id, "content": text, "chat_id": chat_id},
            timeout=10)
        return resp.json().get("code") == 0
    except Exception as e:
        log(f"发送失败: {e}")
        return False

def main():
    os.makedirs("/tmp/claude_collab", exist_ok=True)
    log("CC-OC Watcher 启动 (带记忆版)")
    processed_ids = get_processed_ids()
    log(f"已处理ID数: {len(processed_ids)}")

    while True:
        try:
            resp = requests.get(QUEUE_ENDPOINT, timeout=5)
            messages = resp.json().get("messages", [])
        except Exception as e:
            log(f"获取消息失败: {e}")
            messages = []

        for msg in messages:
            msg_id = msg.get("id")
            if msg_id in processed_ids:
                continue

            content = msg.get("content", "")
            feishu_msg_id = msg.get("feishu_message_id", "")
            chat_id = msg.get("chat_id", "")

            log(f"收到消息 [{msg_id}]: {content[:30]}...")

            # 获取历史并构建上下文
            history = get_history(chat_id) if chat_id else []
            context = build_context(history)
            if context:
                log(f"携带历史 {len(history)} 条")

            # 发送给CC（带上下文）
            reply = send_to_cc(content, context)

            if reply:
                log(f"CC回复: {reply[:50]}...")
                send_reply(feishu_msg_id, reply, chat_id)
                processed_ids.add(msg_id)
                save_processed_ids(processed_ids)
                log(f"消息 [{msg_id}] 已处理")
            else:
                log(f"消息 [{msg_id}] 处理失败")

        time.sleep(3)

if __name__ == "__main__":
    main()
PYEOF

chmod +x "$LOCAL_SCRIPT"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  安装完成！${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "下一步:"
echo ""
echo "1. 启动 relay-server (腾讯云):"
echo "   cd $RELAY_DIR"
echo "   FEISHU_BOT_APP_ID=$FEISHU_APP_ID \\"
echo "   FEISHU_BOT_APP_SECRET=$FEISHU_APP_SECRET \\"
echo "   pm2 start pm2.config.js"
echo ""
echo "2. 启动本地监控脚本 (Mac Mini):"
echo "   RELAY_URL=http://你的服务器IP:3005 \\"
echo "   python3 $LOCAL_SCRIPT"
echo ""
echo "3. 配置飞书 webhook URL 指向你的服务器 /webhook/feishu"
echo ""
echo "4. 历史记录文件: $HISTORY_FILE"
echo ""
