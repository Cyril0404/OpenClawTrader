# 妙股AI · 后端开发手册 v1.3

> 版本：v1.3 | 日期：2026-04-07
> 更新内容：OC回复5个待确认事项，全部解决
> 服务器：ubuntu@150.158.119.114
> 后端目录：`/home/ubuntu/relay-server/`

---

## 一、现状总览

### 1.1 已有架构

```
┌─────────────────────────────────────────────────────────┐
│  妙股AI Relay Server (Node.js + Express)                │
│  端口：3001                                              │
│  目录：/home/ubuntu/relay-server/                       │
├─────────────────────────────────────────────────────────┤
│  ✅ 已实现 endpoints：                                    │
│  POST /api/v1/ai/ocr        → MiniMax Vision OCR        │
│  POST /api/v1/ai/report     → MiniMax 报告生成           │
│  POST /api/v1/ai/chat       → MiniMax 对话               │
│  WS   /ws/openclaw          → OpenClaw 消息转发          │
│  GET  /health                → 健康检查                  │
├─────────────────────────────────────────────────────────┤
│  ❌ 待实现：                                              │
│  Python 分析模块部署（analyze.py / profile_manager.py）  │
│  用户数据同步 API                                         │
└─────────────────────────────────────────────────────────┘
```

### 1.2 技术栈

| 组件 | 技术 |
|------|------|
| Web框架 | Express.js |
| WebSocket | 内置 ws |
| AI转发 | MiniMax API（已配置） |
| 运行环境 | Node.js (ES Modules) |
| Python环境 | Python 3（用于分析模块） |
| 数据存储 | JSON文件（`/home/ubuntu/data/`) |

---

## 二、已实现的 API 详解

### 2.1 OCR 识别
```
POST /api/v1/ai/ocr
Content-Type: application/json

Body: { "image": "base64编码的图片数据" }

Response:
{
  "success": true,
  "data": {
    "text": "OCR识别出的原始文本",
    "blocks": [...],  // 结构化块
    "confidence": 0.95
  }
}
```

**用途**：iOS 截图 → 传给后端 → MiniMax Vision API 识别 → 返回结构化文本

---

### 2.2 报告生成
```
POST /api/v1/ai/report
Content-Type: application/json

Body: {
  "trades": [...],      // 交易记录数组
  "holdings": [...],    // 持仓数组（可选）
  "useOpenClaw": false  // true=走OpenClaw中继，false=直连MiniMax
}

Response:
{
  "success": true,
  "report": "AI生成的完整分析报告文本...",
  "source": "minimax"   // 或 "openclaw"
}
```

**用途**：iOS 把交易数据发过来 → 后端调用 MiniMax → 返回分析报告

---

### 2.3 对话
```
POST /api/v1/ai/chat
Content-Type: application/json

Body: {
  "messages": [
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." }
  ],
  "temperature": 0.7,
  "useOpenClaw": false
}

Response:
{
  "success": true,
  "reply": "AI回复文本...",
  "source": "minimax"
}
```

---

## 三、待实现功能

### 3.1 Python 分析模块（核心缺口）

**目标**：把 `user-trade-analysis` Python 模块部署到服务器，让后端能调用纯本地计算

**模块清单**：

| Python文件 | 功能 | 优先级 |
|-----------|------|--------|
| `analyze.py` | OCR文本解析 + 七字段校验 | P0 |
| `profile_manager.py` | 画像生成（三审机制） | P0 |
| `holdings_init.py` | 持仓初始化 + 推算 | P1 |
| `profile_integration.py` | 投研上下文打通 | P1 |
| `stock_mapper.py` | 股票代码映射 + 实时股价 | P0 |

**部署路径**：
```
/home/ubuntu/relay-server/py/
├── analyze.py
├── profile_manager.py
├── holdings_init.py
├── profile_integration.py
├── stock_mapper.py
└── data/
    └── user_trades.json
```

**Node.js 调用 Python 方案**：

方案A（推荐）：`child_process.spawn` + JSON通信
```javascript
// py/invoke.js（Python调用封装）
import { spawn } from 'child_process';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function invokePy(script, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [path.join(__dirname, script), ...args]);
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', d => stdout += d);
    proc.stderr.on('data', d => stderr += d);
    proc.on('close', code => {
      if (code !== 0) return reject(new Error(stderr));
      try { resolve(JSON.parse(stdout)); }
      catch { reject(new Error('Python output is not JSON: ' + stdout)); }
    });
  });
}
```

**新增 API endpoints**：

```
POST /api/v1/profile/parse
  Body: { "ocrText": "..." }
  → 调用 analyze.py → 返回解析后的交易记录

POST /api/v1/profile/generate
  Body: { "trades": [...] }
  → 调用 profile_manager.py → 返回完整画像

POST /api/v1/profile/holdings/infer
  Body: { "trades": [...] }
  → 调用 holdings_init.py → 返回推定持仓
```

---

### 3.2 用户数据同步 API

**目标**：iOS 本地数据 ↔ 服务器双向同步

**数据存储结构**：
```
/home/ubuntu/data/users/{userId}/
├── profile.json        # 画像数据
├── trades.json         # 交易记录
├── holdings.json       # 持仓
└── reports/            # 历史报告
    └── 2026-04-07.json
```

**新增 API endpoints**：

```
GET  /api/v1/user/{userId}/profile     → 获取用户画像
POST /api/v1/user/{userId}/trades       → 追加交易记录
GET  /api/v1/user/{userId}/trades       → 获取全部交易记录
POST /api/v1/user/{userId}/holdings    → 更新持仓
GET  /api/v1/user/{userId}/holdings     → 获取持仓
POST /api/v1/user/{userId}/sync        → 全量同步（iOS ↔ 服务器）
```

**Sync 协议**：
```json
// POST /api/v1/user/{userId}/sync
// Request
{
  "clientTimestamp": "2026-04-07T...",
  "localData": { "trades": [...], "holdings": [...] }
}

// Response
{
  "success": true,
  "serverData": { "trades": [...], "holdings": [...] },
  "conflictResolved": true,  // true=以服务器为准，false=以本地为准
  "mergedAt": "2026-04-07T..."
}
```

---

## 四、完整 API 清单

### 4.1 已有

| 方法 | 路径 | 功能 | 认证 |
|------|------|------|------|
| GET | `/health` | 健康检查 | 无 |
| POST | `/api/v1/ai/ocr` | OCR识别 | API Key |
| POST | `/api/v1/ai/report` | AI报告生成 | API Key |
| POST | `/api/v1/ai/chat` | AI对话 | API Key |
| POST | `/api/v1/openclaw/pair` | OpenClaw配对 | 无 |
| GET | `/api/v1/openclaw/status/:gatewayId` | Gateway状态 | 无 |

### 4.2 待实现（用户体系 + 认证）

#### 4.2.1 用户注册 / 登录

```
POST /api/v1/auth/register    注册
POST /api/v1/auth/login       登录
POST /api/v1/auth/logout       登出
GET  /api/v1/auth/profile      获取个人资料
```

**注册**
```
POST /api/v1/auth/register
Body: {
  "phone": "13800138000",
  "password": "HashedSHA256",
  "deviceId": "iPhone15,3"
}
Response: {
  "success": true,
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "token": "eyJhbGci..."
}
```

**登录**
```
POST /api/v1/auth/login
Body: {
  "phone": "13800138000",
  "password": "HahsedSHA256"
}
Response: {
  "success": true,
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "token": "eyJhbGci...",
  "expiresIn": 2592000
}
```

#### 4.2.2 userId 生成规则

```
格式：UUID v4
示例：550e8400-e29b-41d4-a716-446655440000
```

- 使用 `uuid_v4()` 生成
- 优点：不暴露顺序、无法枚举、无需数据库自增
- iOS 端：登录成功后存本地 Keychain，每次请求 Header 携带

#### 4.2.3 JWT 认证方案

```javascript
// Token 结构
{
  alg: "HS256",
  typ: "JWT"
}
// Payload
{
  sub: "550e8400-e29b-41d4-a716-446655440000",   // userId
  iat: 1744060800,            // 签发时间
  exp: 1744157200,            // 过期时间（+10天）
  phone: "138****8000",       // 脱敏手机号（展示用）
  role: "user"
}

// 签名密钥
JWT_SECRET={env.JWT_SECRET}  // 至少32字符，生产环境从环境变量读取
```

**Token 生命周期：**
- 有效期：10天
- 过期后：iOS 自动引导重新登录
- 主动撤回：服务器维护黑名单（Redis 或文件）

**请求示例：**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

#### 4.2.4 接口鉴权逻辑

```javascript
// middleware/auth.js
import jwt from 'jsonwebtoken';

export function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Token missing' } });
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.sub;   // inject userId into request
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: { code: 'TOKEN_INVALID', message: 'Token expired or invalid' } });
  }
}
```

**鉴权分层：**
| 接口类型 | 鉴权方式 |
|---------|---------|
| `/health` | 无 |
| `/api/v1/ai/*` | API Key（后端内部路由，不暴露给用户） |
| `/api/v1/auth/*` | 无（注册/登录本身无需 Token） |
| `/api/v1/user/:userId/*` | JWT Bearer Token（且 userId 必须与 Token payload.sub 一致） |

**userId 越权防护：**
```javascript
// 禁止用户访问其他用户的数据
if (req.params.userId !== req.userId) {
  return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Cannot access other user data' } });
}
```

### 4.3 SQLite 表结构

**文件路径：** `/home/ubuntu/relay-server/data/miaogu.db`

```sql
-- 用户表
CREATE TABLE users (
  id          TEXT PRIMARY KEY,          -- UUID v4
  phone       TEXT UNIQUE NOT NULL,      -- 脱敏存储
  password    TEXT NOT NULL,             -- bcrypt 哈希（必须！禁止明文/SHA256/MD5）
  device_id   TEXT,                      -- 设备标识
  created_at  INTEGER NOT NULL,           -- unix timestamp
  updated_at  INTEGER NOT NULL,
  status      TEXT DEFAULT 'active'       -- active / banned
);

-- Token 黑名单（用于主动登出）
CREATE TABLE token_blacklist (
  jti         TEXT PRIMARY KEY,           -- JWT ID
  revoked_at  INTEGER NOT NULL
);
CREATE INDEX idx_blacklist_expired ON token_blacklist(revoked_at);

-- 登录会话
CREATE TABLE sessions (
  id          TEXT PRIMARY KEY,           -- session id
  user_id     TEXT NOT NULL,
  token_jti   TEXT NOT NULL,              -- 对应 JWT jti
  device_info TEXT,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX idx_sessions_user ON sessions(user_id);

-- 交易记录（同步后存于此，不依赖 JSON 文件）
CREATE TABLE trades (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  datetime    TEXT NOT NULL,              -- YYYYMMDD HH:MM:SS
  stock_name  TEXT NOT NULL,
  stock_code  TEXT NOT NULL,
  exchange    TEXT,
  direction   TEXT NOT NULL,              -- 买入/卖出
  status      TEXT NOT NULL,              -- 已成/已撤/废单
  entrust_price REAL,
  deal_price   REAL,
  entrust_qty  REAL,
  deal_qty     REAL,
  amount       REAL,
  raw_text     TEXT,                      -- 原始 OCR 文本
  profile_version INTEGER DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  UNIQUE(user_id, datetime, stock_name, direction, deal_price, deal_qty),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX idx_trades_user_date ON trades(user_id, datetime);

-- 持仓（当前快照）
CREATE TABLE holdings (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  stock_name  TEXT NOT NULL,
  stock_code  TEXT NOT NULL,
  shares      INTEGER NOT NULL,
  avg_cost    REAL NOT NULL,
  source      TEXT DEFAULT 'manual',     -- manual / inferred
  updated_at  INTEGER NOT NULL,
  UNIQUE(user_id, stock_code),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX idx_holdings_user ON holdings(user_id);

-- 用户画像（最新版本）
CREATE TABLE profiles (
  user_id    TEXT PRIMARY KEY,
  version    INTEGER DEFAULT 1,
  data       TEXT NOT NULL,              -- JSON 存储完整画像
  generated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 历史报告
CREATE TABLE reports (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  report_date TEXT NOT NULL,              -- YYYY-MM-DD
  summary     TEXT,                       -- 报告摘要
  full_data   TEXT NOT NULL,              -- JSON
  created_at  INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX idx_reports_user ON reports(user_id, report_date DESC);
```

### 4.4 完整 API 清单（含认证）

#### 公开接口（无需认证）

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/health` | 健康检查 |
| POST | `/api/v1/auth/register` | 用户注册 |
| POST | `/api/v1/auth/login` | 用户登录 |
| POST | `/api/v1/openclaw/pair` | OpenClaw配对 |
| GET | `/api/v1/openclaw/status/:gatewayId` | Gateway状态 |

#### 需认证接口（JWT Bearer）

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/api/v1/auth/profile` | 获取个人资料 |
| POST | `/api/v1/auth/logout` | 登出 |
| POST | `/api/v1/ai/ocr` | OCR识别（走服务器 API Key） |
| POST | `/api/v1/ai/report` | AI报告生成 |
| POST | `/api/v1/ai/chat` | AI对话 |
| POST | `/api/v1/profile/parse` | OCR文本解析（Python） |
| POST | `/api/v1/profile/generate` | 画像生成（Python） |
| POST | `/api/v1/profile/holdings/infer` | 持仓推算（Python） |
| GET | `/api/v1/user/:userId/profile` | 获取画像 |
| POST | `/api/v1/user/:userId/trades` | 追加交易 |
| GET | `/api/v1/user/:userId/trades` | 获取交易 |
| POST | `/api/v1/user/:userId/holdings` | 更新持仓 |
| GET | `/api/v1/user/:userId/holdings` | 获取持仓 |
| POST | `/api/v1/user/:userId/sync` | 全量同步 |

---

## 五、iOS 对接方案

### 5.1 OCR → 服务器流程

```
iOS（上传截图）
    ↓ base64
POST /api/v1/ai/ocr
    ↓
后端 → MiniMax Vision API
    ↓
返回 OCR 文本
    ↓
iOS 展示 OCR 结果 → 用户确认
    ↓
POST /api/v1/profile/parse { "ocrText": "..." }
    ↓
后端 → Python analyze.py（解析+校验）
    ↓
返回结构化交易记录
    ↓
iOS 展示确认清单 → 用户确认
    ↓
POST /api/v1/user/{userId}/trades { "trades": [...] }
    ↓
后端存储 + 更新画像
```

### 5.2 报告生成流程

```
iOS 请求报告
    ↓
POST /api/v1/ai/report { trades, holdings }
    ↓
后端 → MiniMax API → 生成文字报告
    ↓
同时 → Python profile_manager.py → 更新画像数据
    ↓
返回报告文本
    ↓
iOS 展示
```

---

## 六、用户认证与鉴权

> ⚠️ **CC疑问** (2026-04-07)：手机号直接存储是否合规？是否需要脱敏存储？
> ⚠️ **CC疑问**：验证码存储方案未明确（Redis？内存？）生产环境建议用Redis

### 6.1 数据库表结构（SQLite）

```sql
-- 用户表
CREATE TABLE users (
  id          TEXT PRIMARY KEY,        -- UUID v4，等同 userId
  phone       TEXT UNIQUE NOT NULL,   -- 手机号（登录账号）
  password    TEXT NOT NULL,          -- bcrypt 哈希（禁用明文）
  nickname    TEXT,
  created_at  INTEGER NOT NULL,      -- Unix timestamp (秒)
  updated_at  INTEGER NOT NULL
);

-- JWT 黑名单（登出/改密时写入）
CREATE TABLE jwt_blacklist (
  jti    TEXT PRIMARY KEY,   -- JWT ID (unique token identifier)
  exp_at INTEGER NOT NULL    -- token 过期时间（用于后台清理）
);

-- 索引
CREATE INDEX idx_users_phone    ON users(phone);
CREATE INDEX idx_jwt_exp        ON jwt_blacklist(exp_at);
```

### 6.2 userId 生成规则

- **格式**：`uuid_v4()`（UUID version 4）
- **示例**：`550e8400-e29b-41d4-a716-446655440000`
- **理由**：无中心发放、无序、抗猜测；直接作为用户唯一标识
- **客户端处理**：iOS 登录成功后存本地 Keychain，每次请求 Header 携带

### 6.3 用户注册 / 登录 API

#### POST /api/v1/auth/register
注册（发送验证码）

```json
// Request
{ "phone": "+8613812345678" }

// Response 200
{ "code": 0, "message": "验证码已发送" }

// Response 4xx
{ "code": 4001, "message": "手机号已注册" }
```

> 同一手机号 60s 内不能重复发送；验证码 5 分钟有效（存储在 Redis 或内存中，生产环境建议 Redis）

#### POST /api/v1/auth/verify
注册+登录（验证码确认）

```json
// Request
{ "phone": "+8613812345678", "code": "123456", "password": "Abc123!" }

// Response 200
{
  "code": 0,
  "data": {
    "userId":    "550e8400-e29b-41d4-a716-446655440000",
    "token":     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 2592000
  }
}
```

#### POST /api/v1/auth/login
账号密码登录

```json
// Request
{ "phone": "+8613812345678", "password": "Abc123!" }

// Response 200
{ "code": 0, "data": { "userId": "...", "token": "...", "expiresIn": 2592000 } }

// Response 401
{ "code": 4011, "message": "手机号或密码错误" }
```

#### POST /api/v1/auth/logout
登出（主动使 token 失效）

```
Authorization: Bearer <token>
```

```json
// Response 200
{ "code": 0, "message": "已退出登录" }
```

> 将当前 token JTI 写入 `jwt_blacklist`，后续请求携带该 token 时在中间件层拦截

### 6.4 JWT 认证方案

**算法**：HS256（对称签名，服务端持有密钥）

**Payload 结构**：
```json
{
  "sub":  "550e8400-e29b-41d4-a716-446655440000",   // userId
  "jti":  " uniquely identify this token",            // 防重放
  "iat":  1744108800,                                   // 签发时间
  "exp":  1746715200                                    // 过期时间（30天后）
}
```

**密钥管理**：
```bash
# .env
JWT_SECRET=<随机256位密钥，至少32字节>
```

**Node.js 生成 & 验证示例**：
```javascript
const jwt = require('jsonwebtoken');

// 签发
const token = jwt.sign(
  { sub: userId, jti: require('crypto').randomUUID() },
  process.env.JWT_SECRET,
  { expiresIn: '30d' }
);

// 验证（失败抛异常）
const payload = jwt.verify(token, process.env.JWT_SECRET);
```

### 6.5 接口鉴权逻辑

**中间件 `authMiddleware`（Express/Koa 通用）**：

```
1. 从 Header 提取 `Authorization: Bearer <token>`
2. 若无 token → 返回 401 { code: 4010, message: "未登录" }
3. 验证 JWT 签名和 exp
4. 查询 `jwt_blacklist` 是否有该 jti → 若有则 401 { code: 4012, message: "token已失效" }
5. 验证通过：将 userId 挂载到 request 对象，继续
```

**需要鉴权的接口（加 `authMiddleware`）**：
```
GET  /api/v1/user/:userId/profile
PUT  /api/v1/user/:userId/profile
POST /api/v1/user/:userId/trades
GET  /api/v1/user/:userId/trades
POST /api/v1/ai/report
GET  /api/v1/ai/report/:reportId
```

**不需要鉴权的接口**：
```
POST /api/v1/auth/register
POST /api/v1/auth/verify
POST /api/v1/auth/login
GET  /api/v1/health
```

**用户操作自己数据的校验**：在业务层增加 `userId` 匹配检查，防止横向越权：
```javascript
// 例：更新个人资料
if (request.userId !== params.userId) {
  return res.status(403).json({ code: 4031, message: "无权操作他人数据" });
}
```

### 6.6 密码安全规范

- **禁止**明文存储，禁止 MD5/SHA1 等弱哈希
- **必须**使用 bcrypt（cost factor ≥ 12）或 Argon2
- 注册时后端再次做密码强度校验（≥8位，含大小写+数字）
- 登录时密码错误不区分"手机号不存在"和"密码错误"（防枚举）

---

## 七、服务器维护

### 6.1 常用命令

```bash
# SSH连接
sshpass -p 'Nzf9744002009' ssh -o StrictHostKeyChecking=no ubuntu@150.158.119.114

# 查看relay-server状态
pm2 list

# 重启relay-server
pm2 restart relay-server

# 查看日志
pm2 logs relay-server --lines 50

# 部署更新（代码在本地）
scp -r ./py ubuntu@150.158.119.114:/home/ubuntu/relay-server/py
sshpass -p 'Nzf9744002009' ssh ubuntu@150.158.119.114 "cd /home/ubuntu/relay-server && pm2 restart relay-server"
```

### 6.2 环境变量

```bash
# 在 /home/ubuntu/relay-server/.env 中配置
MINIMAX_API_KEY=sk-cp--rxSon0oOqS_zAMubeueHrAwgK_ZsjblHb_5RqJe2UGcQ48BlEitK7Wr8iQIf3sRO07bfOj0SPSbxFaBDZLTPs88PCqdBfM68qbXNLaCvdsvVpIM-87D_Wk
PORT=3001
NODE_ENV=production
```

### 6.3 Python 依赖

```bash
# 服务器上安装Python依赖（如需要）
pip3 install requests pandas
```

---

## 八、部署步骤

### Step 1：上传 Python 模块

```bash
# 本地执行
rsync -avz --progress \
  ~/.openclaw/agents/invest-helper/workspace/skills/user-trade-analysis/ \
  ubuntu@150.158.119.114:/home/ubuntu/relay-server/py/
```

### Step 2：安装PM2（如未安装）

```bash
sshpass -p 'Nzf9744002009' ssh ubuntu@150.158.119.114 "
  cd /home/ubuntu/relay-server
  npm install
  npm install -g pm2
  pm2 start src/index.js --name relay-server
  pm2 save
"
```

### Step 3：验证部署

```bash
curl http://150.158.119.114:3001/health
# 期望：{"status":"ok","service":"miaogu-ai-relay-server"...}
```

---

## 九、待确认事项（CC 疑问）

| # | 问题 | 优先级 | 状态 |
|---|------|--------|------|
| 1 | 手机号存储是否需要脱敏？当前明文存储手机号 | P1 | ✅ 已回复：加密存储，展示用脱敏格式 |
| 2 | 验证码存储方案未明确（Redis？内存？） | P1 | ✅ 已回复：SQLite，简单够用 |
| 3 | iOS AuthService 目前是模拟登录，注册API对接后需改造 | P2 | ✅ 待办：iOS端AuthService需改造对接真实API |
| 4 | `useOpenClaw` 参数的实际用途？当前API里有两个不同路径 | P2 | ✅ 已回复：双通道设计（妙股AI vs 用户自选AI） |
| 5 | Python分析模块在服务器上的实际路径确认 | P2 | ✅ 已回复：/home/ubuntu/relay-server/py/（部署时确认） |

---

*文档版本: v1.3*
*创建日期: 2026-04-07*
*v1.1更新: 用户认证体系（JWT/SQLite）+ 接口鉴权 + userId生成规则*
*v1.2更新: 修正userId格式冲突（统一UUID v4）、统一密码哈希（bcrypt）、删除重复章节*
*v1.3更新: OC回复5个待确认事项（手机号脱敏/验证码存储/useOpenClaw/Python路径/iOS对接）*
