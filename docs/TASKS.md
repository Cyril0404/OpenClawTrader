# iOS 开发任务清单

> 最后更新：2026-04-03
> 状态：待开发

---

## 🔴 P0 — 核心流程断了（必须先修）

| # | 问题 | 文件 | 说明 | 优先级 |
|---|------|------|------|--------|
| 1 | **登录是假的** | `ContentView.swift:20` | `isLoggedIn = true` 硬编码，跳过登录直接进主页 | P0 |
| 2 | **「行情」Tab 没内容** | `ContentView.swift` case 1 | 指向 `TradingDashboardView`，但实际没有独立文件，编译能过是因为 `PortfolioView.swift` 里定义了同名视图 | P0 |
| 3 | **持仓数据是假的** | `PortfolioView.swift` | 没有真实股票数据，都是 mock | P0 |
| 4 | **没有真实数据 API** | `StockDataService.swift` | 所有方法都有 `TODO: 调用真实API` | P0 |
| 5 | **订单导入是假的** | `ImportOrderView.swift` | 表单填完不知道发到哪里 | P0 |

---

## 🟡 P1 — 功能有但残缺

| # | 问题 | 文件 | 说明 |
|---|------|------|------|
| 6 | **登录/注册 API 没接** | `AuthService.swift` | `TODO: 调用真实API进行登录验证` |
| 7 | **舆情分析是假的** | `SentimentService.swift` | `TODO: 调用真实API获取舆情数据` |
| 8 | **回测功能是假的** | `BacktestService.swift` | `TODO: 获取真实K线数据` |
| 9 | **Skills 功能没接 API** | `SkillsService.swift` | `TODO: 后续对接真实 API` |
| 10 | **通知系统没有推送** | `NotificationListView.swift` | 只有本地列表，没有 APNS 集成 |
| 11 | **没有 App Store 跳转** | `OpenClawTraderApp.swift` | 没有 URL Scheme / Universal Link |
| 12 | **没有持久化聊天记录** | `WebSocketChatService.swift` | 断开重连后历史消息丢失 |
| 13 | **持仓成本手动输入** | `ImportHoldingView.swift` | 用户要自己算成本，没有自动拉数据 |

---

## 🟢 P2 — 体验优化

| # | 问题 | 说明 |
|---|------|------|
| 14 | **没有网络状态提示** | 断网时用户不知道连接断了 |
| 15 | **没有配对状态反馈** | 配对中/失败/成功没有清晰 UI |
| 16 | **WebSocket 重连没有 UI 提示** | 断开时用户看不到"正在重连" |
| 17 | **没有版本检查** | 不提示更新 |

---

## 当前已完成 ✅

| 功能 | Commit | 说明 |
|------|--------|------|
| WebSocket 自动重连 | `316c43f` + `d6a49d9` | 指数退避 + 心跳 + 状态机 |
| 助理事件 UI 刷新 | `8786064` | `onChange` 替代 `onReceive` |
| SettingsView（API Key） | - | 已删除，App 用 Gateway 不需要 |
| 编译验证 | `28321b7` | BUILD SUCCEEDED |

---

## 开发顺序建议

1. **先修 P0**：#1 登录流程 + #4 真实数据 API，否则 App 是空壳
2. **再做 P1**：持仓、订单、舆情等核心数据接真实 API
3. **最后 P2**：网络状态、配对反馈、重连提示等体验优化

> **注意：** App 连接的是用户自己的 OpenClaw Gateway，不需要用户配 API Key。AI 能力由 Gateway 驱动。
