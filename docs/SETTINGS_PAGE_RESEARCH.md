# Settings页面数据获取方案研究

> 最后更新：2026-03-30
> 作者：丞相
> 状态：✅ 已验证

---

## 结论一句话

PocketClaw通过**两个渠道**获取Settings页面数据：
1. `sessions.list` RPC — 获取agents列表和状态
2. **本地文件读取** — 获取context用量和最近产出

---

## 一、Gateway RPC接口验证

### 测试方法

在Mac mini上运行：
```bash
openclaw logs --follow
```

同时观察PocketClaw的连接行为。

### 发现的RPC调用

**PocketClaw每6秒调用一次：**

```
⇄ res ✓ sessions.list 68ms conn=3cf0846d…12ca
```

**没有发现其他RPC调用。**

`gateway.status`、`gateway.info`、`agents.list` 等均未被调用。

### sessions.list返回的数据结构

每个session包含：
```json
{
  "sessionId": "xxx",
  "updatedAt": 1774859085786,
  "label": "Cron: 股票数据每5分钟更新",
  "systemSent": true,
  "origin": {
    "provider": "heartbeat",
    "label": "heartbeat"
  }
}
```

对于subagent类型的session：
```json
{
  "sessionId": "xxx",
  "subagentRole": "leaf",
  "model": "MiniMax-M2.7",
  "modelProvider": "minimax",
  "spawnedBy": "agent:main:feishu:direct:ou_c5fea36b314d4312e247ab1ee9165b21"
}
```

---

## 二、Settings页面数据对比

### PocketClaw实际显示的数据

| 数据项 | 来源 | 获取方式 |
|--------|------|---------|
| 设备名（Macmini） | ClawPilot配对信息 | 本地文件 |
| 在线状态 | WebSocket连接状态 | Gateway RPC |
| Agent列表（main/101/201） | sessions.list | Gateway RPC |
| 工作状态（工作中/空闲） | sessions.list.updatedAt | Gateway RPC |
| "52k/204k" context用量 | .jsonl文件行数统计 | **本地文件读取** |
| "最近产出"摘要 | .jsonl文件最新消息 | **本地文件读取** |
| Model（MiniMax-M2.7） | subagent session.model | sessions.list |

### 关键发现

**context用量（"52k/204k"）无法通过RPC获取。**

PocketClaw通过读取 `~/.openclaw/agents/{agent}/sessions/{sessionId}.jsonl` 文件，统计行数来估算context用量。

---

## 三、OpenClawTrader的方案选择

### 方案对比

| 方案 | 说明 | 可行性 |
|------|------|--------|
| **HTTP代理到Gateway** | 用/v1/models等HTTP端点 | ❌ Gateway不支持这些端点 |
| **改用sessions.list RPC** | iOS直连Gateway WebSocket | ✅ 可行 |
| **Companion文件读取** | 通过ClawPilot中转读本地文件 | ✅ 可行（已在Mac mini上运行） |
| **relay-server加文件读** | 中继服务器ssh到Mac读文件 | ⚠️ 延迟高，体验差 |

### 推荐方案

**方案A：sessions.list + ClawPilot中转（推荐）**

```
iOS App 
  ↓ WebSocket
ClawPilot（Mac mini后台运行）
  ↓ 读本地文件
~/.openclaw/agents/*/sessions/*.jsonl
```

优点：
- ClawPilot已经在Mac mini上运行，天然有文件访问权限
- 不需要额外服务器
- 数据完整（context用量+最近产出都能拿到）

缺点：
- iPhone必须和Mac mini在同一网络
- 或者通过relay-server中转ClawPilot连接

---

## 四、iOS App实现建议

### 数据获取优先级

| 优先级 | 数据 | 获取方式 | 状态 |
|--------|------|---------|------|
| P0 | agents列表 | sessions.list | ✅ 可行 |
| P0 | 工作状态 | sessions.list.updatedAt | ✅ 可行 |
| P1 | context用量 | 读.jsonl统计行数 | ⚠️ 需ClawPilot中转 |
| P1 | 最近产出 | 读.jsonl最后一条 | ⚠️ 需ClawPilot中转 |
| P2 | Model信息 | sessions.list.model | ✅ 可行（subagent） |

### 简化方案（先上线）

只显示P0数据：
- agents列表
- 工作状态
- 最后活跃时间

暂不显示context用量和最近产出。

---

## 五、待确认

以下RPC是否存在于OpenClaw Gateway：

| RPC方法 | 说明 | 状态 |
|---------|------|------|
| `models.list` | 获取已配置的模型列表 | ❓ 待验证 |
| `skills.status` | 获取skills启用状态 | ❓ 待验证 |

**验证方法：** 在Mac mini上运行 `openclaw logs --follow`，观察PocketClaw是否有调用这两个方法。

如果两者都存在，则Settings页面的所有数据都可以通过RPC获取，context用量（52k/204k）可通过sessions.list + 本地文件计算补充。

## 六、相关文档

- [ARCHITECTURE.md](./ARCHITECTURE.md) - 整体架构
- [STATUS_20260330.md](./STATUS_20260330.md) - 项目现状
- [RELAY_SERVER.md](./RELAY_SERVER.md) - 中继服务器配置
