# 妙股多Agent架构设计 - 基于CC架构

> 设计时间：2026-04-04
> 依据：CC源码架构学习成果
> 状态：设计方案完成，待实现

---

## 一、整体架构

```
┌──────────────────────────────────────────────────────────────┐
│                         丞相（Coordinator）                   │
│  - 任务分解与调度                                           │
│  - 调度御史/博士/股神/管家                                   │
│  - 合成结果汇报用户                                          │
└─────────────────────────────┬────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  御史(yushi)  │      │  博士(boshi)  │      │  股神(gushen) │
│  资讯Agent   │      │  研究Agent   │      │  投资Agent   │
│  - 行情查询  │      │  - 深度分析  │      │  - 投资建议  │
│  - 消息整合  │      │  - 报告生成  │      │  - 风险评估  │
└──────────────┘      └──────────────┘      └──────────────┘
        │
        ▼
┌──────────────┐
│  管家(guardian)│
│  系统Agent   │
│  - 安全检测  │
│  - 权限管理  │
│  - 日志记录  │
└──────────────┘
```

---

## 二、CC的Coordinator模式应用

### 2.1 丞相的核心职责

```typescript
// 丞相的角色：任务分解 + 合成结果 + 汇报用户
const Coordinator = {
  // 1. 分解任务
  decompose(task: string): Task[] {
    // 分析用户请求 → 拆分成子任务
    // 分配给合适的Agent
  },

  // 2. 调度Agent（并行研究）
  async dispatch(tasks: Task[]): Promise<Result[]> {
    //御史、博士可并行启动
    //同一文件集的写操作需串行
  },

  // 3. 合成结果
  synthesize(results: Result[]): Summary {
    // 理解每个Agent的发现
    // 写出具体的下一步spec
  },

  // 4. 继续或停止Agent
  continue(agentId: string, spec: string): void
  stop(agentId: string): void
}
```

### 2.2 自包含Prompt原则

**CC原则：Worker看不到主对话，每个Prompt必须包含所有上下文**

```typescript
// 错误示范（CC明确禁止）
"基于之前的分析，继续完善报告"

// 正确示范
const prompt = `
你是妙股的博士Agent，负责生成交易行为分析报告。

## 用户信息
- 资金账号：20660xxxxxxxxx
- 风险偏好：激进
- 主要策略：打板

## 历史发现
- 用户习惯在10:00前买入
- 偏好小市值股票
- 止损执行率低

## 当前任务
根据以上信息，写出第一章"交易频率分析"，包含：
1. 近30天交易次数统计
2. 交易时间分布
3. 与大盘对比

## 完成标准
- 输出一份结构化分析报告
- 每个结论附上数据来源
- 写完后返回报告内容
`
```

### 2.3 Continue vs Spawn 判断

| 情境 | 选择 | 原因 |
|------|------|------|
| 御史查行情 → 博士分析同一只股票 | **Continue** | 上下文重叠，继续用 |
| 博士分析股票A → 博士分析股票B | **Spawn fresh** | 完全不同任务 |
| Agent报错 | **Continue** | 保留错误上下文 |

```typescript
// 判断逻辑
if (contextOverlap(high)) {
  continueAgent(agentId, newSpec)
} else {
  spawnAgent(newSpec)
}
```

---

## 三、妙股Tool系统设计

### 3.1 Tool类型定义（基于CC的Tool结构）

```typescript
// 基于CC的Tool.ts设计
interface MiaoguTool<Input, Output> {
  name: string
  description(input: Input): Promise<string>
  inputSchema: z.ZodType<Input>
  
  call(
    args: Input,
    context: ToolUseContext
  ): Promise<ToolResult<Output>>

  // 安全检查
  isReadOnly(args: Input): boolean
  isDestructive?(args: Input): boolean

  // 中断行为
  interruptBehavior?(): 'cancel' | 'block'
}
```

### 3.2 妙股的Tool列表

| Tool | 作用 | isReadOnly | isDestructive |
|------|------|-----------|--------------|
| `StockQueryTool` | 查询行情数据 | ✅ | ❌ |
| `NewsQueryTool` | 查询资讯 | ✅ | ❌ |
| `AnalysisTool` | AI分析交易 | ✅ | ❌ |
| `ReportTool` | 生成报告 | ❌ | ❌ |
| `TradeImportTool` | 导入交易记录 | ❌ | ✅ |
| `CacheTool` | 缓存管理 | ❌ | ✅ |
| `LogTool` | 日志记录 | ❌ | ✅ |

### 3.3 Tool注册机制（基于CC的findToolByName）

```typescript
// 工具注册表
const tools: MiaoguTool[] = [
  StockQueryTool,
  NewsQueryTool,
  AnalysisTool,
  ReportTool,
  TradeImportTool,
  CacheTool,
  LogTool,
]

// 工具查找
function findTool(name: string): MiaoguTool | undefined {
  return tools.find(t => t.name === name)
}

// 工具调用
async function callTool(name: string, args: any, context: ToolUseContext) {
  const tool = findTool(name)
  if (!tool) throw new Error(`Unknown tool: ${name}`)
  
  // 安全检查
  if (!context.canUse(tool.name)) {
    throw new Error(`Permission denied: ${tool.name}`)
  }
  
  // 破坏性操作二次确认
  if (tool.isDestructive?.(args)) {
    const confirmed = await context.confirm(`执行 ${tool.name}?`)
    if (!confirmed) return
  }
  
  return tool.call(args, context)
}
```

---

## 四、妙股Context管理设计

### 4.1 分层压缩策略（基于CC）

```typescript
// CC的分层压缩 → 妙股的分层压缩
const ContextManager = {
  // L1: 微压缩（0成本）
  async microCompact(messages: Message[]): Promise<Message[]> {
    // 合并连续同类消息
    // 移除空白格式
    // 保留关键转折点
  },

  // L2: 会话记忆（低成本）
  async sessionMemoryCompact(messages: Message[]): Promise<Memory> {
    // 提取关键决策
    // 写入记忆文件
    // 轻量总结，不需要LLM
  },

  // L3: 传统压缩（API成本）
  async compact(messages: Message[], context: ToolUseContext): Promise<Message[]> {
    // 调用LLM总结
    // 保留关键信息
    // 替换原始消息
  }
}
```

### 4.2 触发条件

| 层级 | 触发条件 | 成本 |
|------|---------|------|
| L1微压缩 | 每轮自动 | 0 |
| L2会话记忆 | Context使用>50% | 低 |
| L3压缩 | Context使用>80% | API |

### 4.3 妙股特有的Context内容

```typescript
// 用户Context（类似CC的getUserContext）
const getMiaoguUserContext = memoize(async () => {
  return {
    // 交易偏好（从历史学习）
    tradingPreferences: await getTradingPreferences(),
    
    // 当前账户状态
    accountStatus: await getAccountStatus(),
    
    // 项目记忆（.miaogu.md）
    projectMemory: await getProjectMemory(),
    
    // 当前日期
    currentDate: new Date().toISOString(),
  }
})
```

---

## 五、妙股MCP接入设计

### 5.1 外部服务MCP化

```typescript
// akshare MCP Server（Stdio方式）
const akshareMCP = {
  type: 'stdio',
  command: 'python',
  args: ['/path/to/akshare_mcp_server.py'],
  env: {}
}

// 腾讯云OCR MCP Server（SSE方式）
const ocrMCP = {
  type: 'sse',
  url: 'https://ocr.tencentcloudapi.com/mcp',
  headers: {
    'Authorization': 'Bearer xxx'
  }
}

// MiniMax MCP Server（HTTP方式）
const minimaxMCP = {
  type: 'http',
  url: 'https://api.minimax.chat/mcp',
  headers: {
    'Authorization': 'Bearer xxx'
  }
}
```

### 5.2 MCP连接管理

```typescript
// 基于CC的MCPConnectionManager
class MiaoguMCPConnectionManager {
  private connections: Map<string, MCPConnection> = new Map()

  async connect(config: MCPConfig): Promise<void> {
    const conn = await MCPConnection.create(config)
    this.connections.set(config.name, conn)
  }

  async callTool(serverName: string, toolName: string, args: any): Promise<any> {
    const conn = this.connections.get(serverName)
    return conn.callTool(toolName, args)
  }

  async disconnect(serverName: string): Promise<void> {
    const conn = this.connections.get(serverName)
    await conn.close()
    this.connections.delete(serverName)
  }
}
```

---

## 六、妙股Hook设计

### 6.1 Hook事件类型

```typescript
// 基于CC的27种Hook事件
type MiaoguHookEvent = 
  // 生命周期
  | 'SessionStart'
  | 'SessionEnd'
  
  // 工具执行（核心）
  | 'PreStockQuery'
  | 'PostStockQuery'
  | 'PreAnalysis'
  | 'PostAnalysis'
  | 'PreReport'
  | 'PostReport'
  
  // 用户交互
  | 'UserSubmit'
  | 'UserConfirm'
  
  // 压缩
  | 'PreCompact'
  | 'PostCompact'
  
  // 系统
  | 'Error'
  | 'Timeout'
```

### 6.2 Hook应用场景

```typescript
// 1. API调用日志Hook
const logApiHook = {
  event: 'PostStockQuery',
  path: '/hooks/log-api-call.sh',
  async: true
}

// 2. Token消耗统计Hook
const tokenTrackHook = {
  event: 'PostAnalysis',
  path: '/hooks/track-tokens.sh',
  async: true
}

// 3. 自动缓存Hook
const cacheHook = {
  event: 'PostStockQuery',
  path: '/hooks/cache-result.sh',
  async: true
}

// 4. 错误告警Hook
const errorAlertHook = {
  event: 'Error',
  path: '/hooks/error-alert.sh',
  async: false  // 同步，阻塞式
}
```

### 6.3 Hook执行器

```typescript
// 基于CC的executeHooks
async function* executeMiaoguHooks(
  event: MiaoguHookEvent,
  input: HookInput
): AsyncGenerator<HookOutput> {
  const hooks = getRegisteredHooks(event)
  
  for (const hook of hooks) {
    yield* executeHook(hook, input)
  }
}

// 使用示例
async function queryStock(code: string) {
  // PreHook
  yield* executeMiaoguHooks('PreStockQuery', { code })
  
  // 执行查询
  const result = await akshare.query(code)
  
  // PostHook
  yield* executeMiaoguHooks('PostStockQuery', { code, result })
  
  return result
}
```

---

## 七、实现优先级

### P0 - 核心框架
- [ ] 丞相角色实现（任务分解、调度、合成）
- [ ] 基本Tool注册机制
- [ ] 御史/博士/股神的基础Prompt

### P1 - 完善功能
- [ ] Context分层压缩
- [ ] MCP接入akshare
- [ ] Hook系统

### P2 - 高级功能
- [ ] 多用户隔离
- [ ] 限流机制
- [ ] 缓存优化

---

## 八、文档位置

```
~/openclaw/OpenClawTrader/docs/
└── 妙股多Agent架构设计.md
```
