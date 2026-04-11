# CC-OC 协作开发记录

## 2026-04-02 更新

### 用户档案系统 v1

创建了 `/Users/zifanni/.openclaw/workspace/scripts/user_profile.py`

功能：
1. **持久化会话记忆** - 所有对话存到 JSON，重启后还能用
2. **主动学习用户偏好** - 从交互中学习用户的习惯
3. **跨会话上下文** - 记住上次聊到哪，进行中任务等

档案结构：
```json
{
  "preferences": {...},           // 已知偏好
  "learned_preferences": {...},   // 从交互中学习
  "session_context": {
    "ongoing_tasks": [],          // 进行中的任务
    "last_session_summary": ""    // 上次会话摘要
  },
  "decisions": [],                // 重要技术决策
  "conversation_summaries": []    // 历史会话摘要
}
```

### CC-OC-Watch v3 改进

借鉴 Claude Code 架构：
- 指数退避重试机制 (500ms * 2^n + 25% jitter)
- 会话状态跟踪 (消息数、回复数、错误数、运行时长)
- 健康检查 (relay-server、Claude binary、磁盘空间)
- 用户档案上下文注入

### 三个进化方向确认

用户确认这三个都很重要：
1. 持久化会话记忆 ✓ 已实现
2. 主动学习用户偏好 ✓ 已实现
3. 跨会话上下文 ✓ 已实现

---

## 2026-04-08 更新

### 吸收 everything-claude-code 知识库

研究了 145k stars 的 ECC 项目，吸收以下核心模式：

#### Skills 系统 (三级加载架构)

```
.claude/skills/
├── trading-patterns/     # 股票技术指标计算
│   └── SKILL.md          # YAML frontmatter + 指令
├── api-integration/       # API调用和认证管理
│   └── SKILL.md
```

**三级加载：**
1. Level 1 (metadata) - ~100 tokens，始终加载
2. Level 2 (body) - <5k tokens，技能触发时
3. Level 3 (bundled) - 按需加载

#### Hooks 系统 (事件驱动)

| Hook | 触发时机 | 用途 |
|------|----------|------|
| SessionStart | 会话启动 | 加载历史缓存 |
| Stop | 会话结束 | 保存状态 |
| PreToolUse | 工具执行前 | API日志 |
| PostToolUse | 工具执行后 | 构建检查 |

#### Memory 持久化

```
.claude/
├── hooks/
│   ├── hooks.json                    # 钩子配置
│   └── memory-persistence/
│       ├── session-start.sh         # 启动时加载
│       └── session-end.sh           # 结束时保存
└── memory/
    ├── cache/                        # 数据缓存
    ├── sessions/                    # 会话文件
    └── learned/                      # 学习的模式
```

#### 可复用的设计模式

1. **渐进式披露** - 避免上下文膨胀
2. **子代理隔离** - context: fork 隔离子任务
3. **事件驱动** - Hook解耦横切关注点
4. **模式提取** - Instincts从经验中学习

#### OpenClawTrader 应用场景

| ECC模式 | 应用 |
|---------|------|
| Skills系统 | 重构Service层为标准化skill |
| Memory持久化 | 股票数据跨会话缓存 |
| Hooks | API日志、错误追踪 |
| Instincts | 炒股决策模式提取 |

---

## 2026-04-08 下午

### 委托单录入修复

**问题：**
1. 录入委托单时没有提示"录入成功"和"录入多少个"
2. 重复的委托单可以重复录入

**修复：**

| 文件 | 修改 |
|------|------|
| `TradingService.swift:119-153` | `importOrder` 返回 `(imported, duplicates)`，增加重复检查 |
| `ImportOrderView.swift:25` | 添加 `successMessage` 状态变量 |
| `ImportOrderView.swift:69-75` | Alert显示动态消息 |
| `ImportOrderView.swift:166-189` | 根据导入结果显示不同提示 |

**重复检查逻辑：**
- 同一标的(symbol) + 同方向(buy/sell) + 同数量(shares) + 同价格(price)
- 仅检查活跃订单(status为pending/partiallyFilled)

**提示消息：**
- 成功：`"成功导入 X 个委托单"`
- 重复：`"该委托单已存在，无需重复录入"`

---

## 2026-04-08 下午（妙股AI项目）

### 委托清单重复问题修复

**问题：** OCR识别后保存草稿时，相同内容的委托单会被重复保存

**修复：**
- 文件：`MiaoguAI/Services/DatabaseService.swift:129-163`
- 添加 `isDuplicateDraft()` 方法检查内容重复
- 重复条件：stockName + direction + entrustPrice + entrustQty 都相同
- 只检查待确认(status=draft)的草稿，避免阻止修改已确认记录

```swift
private func isDuplicateDraft(_ draft: EntrustDraft, in existingDrafts: [EntrustDraft]) -> Bool {
    return existingDrafts.contains { existing in
        existing.status == .draft &&
        existing.stockName == draft.stockName &&
        existing.direction == draft.direction &&
        existing.entrustPrice == draft.entrustPrice &&
        existing.entrustQty == draft.entrustQty
    }
}
```

### OCR识别"13条但有1条不完整"问题

**分析：** 代码逻辑正确，验证失败的记录会进入 `incompleteTrades` 而不是 `trades` 数组
- VisionOCRService.swift 第221-258行有完整的验证逻辑
- UI正确显示了 `incompleteTrades` 警告（第312-346行）
- 日志显示 `parsed 13 trades, 0 incomplete` 说明13条都验证通过

**可能原因：** 验证逻辑可能需要更严格（如检查日期格式、价格范围等），建议用户手动核对识别结果

### 券商支持提示修改

**修复：** `OpenClawTrader/iOS/Features/Trading/ImportOrderView.swift:149`
- 修改前：`"上传委托截图，自动识别股票信息"`
- 修改后：`"目前只支持东莞证券截图识别，其他券商很可能出错"`

---

## 2026-04-08 下午（妙股AI项目第二次修复）

### OCR识别区分已成/废单 P1.5

**问题：**
1. 废单和已撤被当作正常记录录入了
2. 没有区分"已成"和"废单"
3. 数据不清晰的记录也被录入

**修复：**

#### 1. Trade模型添加status字段
- 文件：`MiaoguAI/Models/Trade.swift`
- 新增 `TradeStatus` 枚举：`done`（已成）、`cancelled`（已撤）、`rejected`（废单）、`unknown`
- Trade模型添加 `tradeStatus` 字段

#### 2. OCR状态解析重构
- 文件：`MiaoguAI/Services/VisionOCRService.swift`
- 重构 `extractTradeTypeNew` → `extractTradeTypeAndStatus`
- 同时返回 `TradeType` 和 `TradeStatus`
- 识别"已成"、"己成"、"成功" → done
- 识别"已撤"、"撤单" → cancelled
- 识别"废单"、"废" → rejected

#### 3. 验证逻辑修改
- 废单和已撤直接跳过，添加到 `incompleteTrades`
- 只有"已成"状态才会被录入委托清单
- 日志会显示 `✗ 股票名: 废单，跳过`

```swift
if tradeStatus == .rejected {
    print("  [\(i)] ✗ \(stockName): 废单，跳过")
    incompleteTrades.append(IncompleteTrade(...))
    continue
} else if tradeStatus == .cancelled {
    print("  [\(i)] ✗ \(stockName): 已撤，跳过")
    incompleteTrades.append(IncompleteTrade(...))
    continue
}
```

---

## 历史

### 2026-03-31
- 完成 iOS 项目代码审查 (10个问题)
- 分析 Flutter 迁移可行性
- 建立 CC-OC 协作文档
