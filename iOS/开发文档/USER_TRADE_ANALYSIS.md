# 投资助手（User Trade Analysis）技能 — iOS 落地开发文档

> 文档版本：v1.1 | 日期：2026-04-07
> 更新：v1.1 — 确认技术决策：OCR用苹果原生 / 画像放后端 / 以iOS现有模型为准 / SQLite存储  
> 目的：将 `user-trade-analysis` Python 模块完整移植到妙股 iOS 项目  
> 项目路径：`/Users/zifanni/openclaw/OpenClawTrader/iOS/`

---

## 一、技能概述

### 核心定位
研究**用户自身**的交易行为，建立越来越懂该用户的投资画像，回答：
- "我是什么风格的投资者？我的弱点在哪？"
- "我的买卖时机选择合理吗？"
- "我的持仓健康吗？"

### 与个股投研的区别

| 技能 | 研究对象 | 回答什么问题 |
|------|---------|-------------|
| **user-trade-analysis** | 用户自身的交易行为 | "我是什么风格？我的弱点在哪？" |
| **stock-investment-report** | 单只股票 | "这只股票值不值得买？" |

两者互补：研究报告告诉你买什么，画像分析告诉你你自己是怎么交易的。

---

## 二、iOS 项目现有结构参考

```
iOS/
├── Features/
│   ├── Analysis/          # 分析模块（已有 TechnicalAnalysisView）
│   ├── Profile/           # 用户模块（已有 ProfileView, SkillsView）
│   └── ...
├── Services/             # Service层（已有 StockDataService, TradingService 等）
├── Models/               # 数据模型
└── 开发文档/              # 本文档所在目录
```

### 相关现有文件
- `Features/Profile/ProfileView.swift` — 用户画像主界面（已有，459行）
- `Features/Analysis/TechnicalAnalysisView.swift` — 技术分析（已有，815行）
- `Services/TradingService.swift` — 交易服务（已有持仓管理）
- `Services/StockDataService.swift` — 行情数据服务

---

## 三、数据模型

### 3.1 交易记录（Trade）

```swift
struct Trade: Codable, Identifiable {
    var id: String = UUID().uuidString
    var stockName: String      // "永泰能源"
    var stockCode: String      // "600157"
    var exchange: String        // "沪A"
    var datetime: String        // "20260330 09:32:11"
    var direction: String        // "买入" / "卖出"
    var status: String          // "已成" / "已撤" / "废单"
    var entrustPrice: Double?   // 委托价
    var dealPrice: Double?       // 成交价
    var entrustQty: Double?      // 委托量
    var dealQty: Double?        // 成交量
    var amount: Double?          // 金额 = dealPrice * dealQty
    var addedAt: String         // ISO时间戳
}
```

### 3.2 用户画像（UserProfile）

```swift
struct UserProfile: Codable {
    // 基础指标
    var totalTrades: Int = 0
    var style: String = ""              // "短线" / "中线" / "长线"
    var winRate: Double = 0.0           // 盈亏率 0.0~1.0
    var cancelRate: Double = 0.0         // 撤单率 0.0~1.0
    var confidence: String = "低"         // "低" / "中" / "高"
    var avgHoldingDays: Double = 0.0     // 平均持股天数

    // 偏好
    var sectorPreference: [String] = []   // 偏好板块
    var topStocks: [String: Int] = [:]    // 交易最多的股票

    // v1.2 增强字段
    var oneLiner: String = ""            // 一句话概括用户风格
    var personalityTags: [String] = []    // 性格标签 ["频繁交易", "爱抄底"...]
    var capabilityRadar: [String: Double] = [:]  // 能力雷达 {选股: 0.8, 择时: 0.5...}
    var behaviorInsights: [String] = []  // 行为洞察
    var personalizedAdvice: [[String:String]] = []  // [[title:"", priority:"高", content:""]]
    var insights: [String] = []            // 关键洞察（文本列表）
}
```

### 3.3 持仓（Holding）

```swift
struct Holding: Codable, Identifiable {
    var id: String
    var symbol: String       // "600157"
    var name: String          // "永泰能源"
    var shares: Int
    var averageCost: Double   // 成本价
    var currentPrice: Double  // 当前价
    var currency: String = "CNY"
    var dayChange: Double
    var dayChangePercent: Double
}
```

---

## 四、已实现功能（Python → Swift 移植清单）

### ✅ F1: 委托单 OCR 录入
- **Python**: `analyze.py` → `parse_ocr_text()` + `strict_validate_trade()`
- **iOS 需要**: Vision/VisionKit OCR → 结构化解析 → 七字段校验
- **七字段**: datetime, stockName, stockCode, direction, status, price, qty

### ✅ F2: 用户画像生成
- **Python**: `profile_manager.py` → `ProfileManager.generate_profile()`
- **iOS 需要**: Swift 重写画像分析算法
- **输出**: style, winRate, cancelRate, avgHoldingDays, sectorPreference, insights

### ✅ F3: 持仓初始化
- **Python**: `holdings_init.py` → 三种初始化方式（截图/手动/推算）
- **iOS 需要**: 截图识别 + 手动录入界面

### ✅ F4: 投研打通
- **Python**: `profile_integration.py` → `ProfileIntegration.get_investment_context()`
- **iOS 需要**: 画像上下文注入到个股查询流程

### 🟡 F5: 月度复盘报告（月度统计）
- **Python**: 待实现
- **iOS 需要**: 月度交易频率/手续费/亏损来源统计

### 🟡 F6: 持仓健康度监控（仓位仪表盘）
- **Python**: 待实现
- **iOS 需要**: 仓位占比图 + 风险评级 + 预警通知

### 🟡 F7: 个股风险评估
- **Python**: 待实现
- **iOS 需要**: 波动率 + 机构持仓 + 技术面风险

---

## 五、核心算法说明（iOS 重写参考）

### 5.1 画像生成算法（profile_manager.py 三审机制）

```swift
// Swift 实现参考
func generateProfile(trades: [Trade]) -> UserProfile {
    // 初审：数据清洗，去重
    // 二审：模式识别
    // 三审：结论生成
    // 返回 UserProfile
}
```

**风格判断逻辑**：
- 平均持股 ≤ 1 天 → 超短线（日内）
- 平均持股 2~5 天 → 短线
- 平均持股 6~30 天 → 中线
- 平均持股 > 30 天 → 长线

**盈亏率计算**：
- 盈利笔数 / 总笔数（已成交）
- 同股票配对买卖估算（买入均价 vs 卖出均价）

**撤单率计算**：
- 已撤笔数 / 总（含已撤）笔数

**能力雷达**（5维度，0.0~1.0）：
| 维度 | 计算方式 |
|------|---------|
| 选股能力 | 盈利笔数 / 总笔数 |
| 择时能力 | 买入后3日内盈利概率 |
| 风控能力 | 亏损幅度控制（亏损单平均幅度） |
| 执行力 | 1 - 撤单率 |
| 盈亏比 | 平均盈利幅度 / 平均亏损幅度 |

### 5.2 OCR 解析核心逻辑（analyze.py）

**支持格式**：
```
格式1（单行无编号）：永泰能源 20260330 09:32:11 买入 已成 1.9800 1.9800 27100.00 27100.00
格式2（多行展开）：永泰能源 / 20260330 09:32:11 / 买入 / 已成 / 1.9800 / 27100.00
格式3（编号格式）：1. 永泰能源 20260330 09:32:11 买入 已成 1.9800 1.9800 27100.00 27100.00
```

**价格 vs 数量区分算法**：
```
1. 获取股票实时股价（如：兆易创新 ≈ 253元）
2. < 100 的数字：贴近实时股价(±50%) → 价格；否则 → 数量
3. ≥ 100 的数字：直接 → 数量（股数远大于任何股价）
```

**时间字符串预处理**：
```
输入：兆易创新 20260324 09:35:47 卖出 已撤 270.77 0.00 267.65 0.00
步骤1：清除 HH:MM:SS → "兆易创新 20260324   卖出 已撤 270.77 0.00 267.65 0.00"
步骤2：提取数字 → [20260324, 270.77, 0.00, 267.65, 0.00]
步骤3：20260324 是日期（8位+20开头）→ 过滤掉
步骤4：剩余 [270.77, 0.00, 267.65, 0.00]
步骤5：真实股价253元，270.77贴近 → 委托价；267.65 >> 253 → 数量
```

### 5.3 持仓推算算法（holdings_init.py）

```
逻辑：
1. 遍历所有已成交易记录（按股票分组）
2. 买入 → 累加股数；卖出 → 累减股数
3. 最终股数 > 0 → 推定持仓
4. 持仓成本 = Σ(买入均价 × 股数) / 总股数
```

---

## 六、iOS 界面规划

### 6.1 入口
- `ProfileView.swift` 增加"交易画像"Tab 或进入按钮
- 或 `SkillsView.swift` 展示"交易画像"技能卡

### 6.2 页面列表

| 页面 | 功能 | 优先级 |
|------|------|--------|
| `TradeProfileView.swift` | 画像主界面（雷达图+风格+关键洞察） | P0 |
| `HoldingsHealthView.swift` | 持仓健康度仪表盘 | P1 |
| `MonthlyReportView.swift` | 月度复盘报告 | P1 |
| `TradeImportView.swift` | 委托单截图录入 | P0 |
| `HoldingInitView.swift` | 持仓初始化 | P1 |
| `StockRiskView.swift` | 个股风险评估 | P2 |

### 6.3 TradeProfileView 布局参考

```
┌─────────────────────────┐
│  🎯 你的投资画像          │
├─────────────────────────┤
│  [雷达图: 5维度能力]      │
├─────────────────────────┤
│  风格：短线（单股重复操作） │
│  盈亏率：50%  撤单率：33% │
│  置信度：高              │
├─────────────────────────┤
│  💡 关键洞察              │
│  • 协鑫能科反复买卖3次    │
│  • 兆易创新撤单4次        │
│  • 撤单率偏高，需优化     │
├─────────────────────────┤
│  📊 偏好板块              │
│  半导体/芯片 / 电力设备   │
├─────────────────────────┤
│  [上传委托单]  [查看持仓] │
└─────────────────────────┘
```

### 6.4 HoldingsHealthView 布局参考

```
┌─────────────────────────┐
│  📦 持仓健康度            │
├─────────────────────────┤
│  整体风险：[████░░] 中高  │
│  仓位利用率：78%          │
├─────────────────────────┤
│  永泰能源  27,100股  45%  │ ← 超30%预警
│  皖能电力   6,000股  10%  │
│  兆易创新      200股   0%  │
├─────────────────────────┤
│  ⚠️ 单股仓位>40%告警     │
│  ⚠️ 撤单率33%注意优化     │
└─────────────────────────┘
```

---

## 七、服务层设计（Swift）

### 7.1 TradeProfileService

```swift
// Services/TradeProfileService.swift
// 核心原则：iOS只做展示和输入，数据计算全放后端
class TradeProfileService {
    static let shared = TradeProfileService()
    private init() {}

    // 1. 录入交易记录（OCR苹果原生识别后，调用后端解析+校验）
    func parseOCRText(_ text: String) async throws -> [Trade]

    // 2. 提交确认后的交易到后端（后端存SQLite + 更新画像）
    func submitTrades(_ trades: [Trade]) async throws -> Int

    // 3. 获取画像（从后端SQLite拉取）
    func fetchProfile() async throws -> UserProfile

    // 4. 获取持仓
    func fetchHoldings() async throws -> [Holding]

    // 5. 同步（iOS ↔ 服务器双向同步）
    func sync() async throws -> SyncResult
}
```

### 7.2 数据持久化
- 使用 **SQLite** 存储（后端 relay-server 共用同一数据库）
- 表结构见 `BACKEND_DEVELOPMENT.md` SQLite 表结构章节

### 7.3 画像数据结构

以 iOS 现有 `Models/UserProfile.swift`（263行）为准，直接映射到后端 SQLite profiles 表。

```swift
// profile_summary 字段映射到 profiles 表的 JSON 列
struct ProfileSummary: Codable {
    var style: String = ""
    var winRate: Double = 0.0
    var cancelRate: Double = 0.0
    var confidence: String = "低"
    var avgHoldingDays: Double = 0.0
    var oneLiner: String = ""
    var personalityTags: [String] = []
    var capabilityRadar: [String: Double] = [:]
    var behaviorInsights: [String] = []
    var personalizedAdvice: [PersonalizedAdvice] = []
    var insights: [String] = []
}
```

---

## 九、代码文件清单

### Python 原始代码位置
```
~/.openclaw/agents/invest-helper/workspace/skills/user-trade-analysis/
├── analyze.py              # OCR解析 + 主流程
├── profile_manager.py      # 画像生成（三审机制）
├── holdings_init.py       # 持仓初始化
├── profile_integration.py  # 投研打通
├── market_env.py           # 市场环境
├── stock_mapper.py         # 股票代码映射 + 实时股价
├── SKILL.md               # 技能说明
└── data/
    └── user_trades.json   # 持久化数据
```

### iOS 目标文件

| iOS 文件 | 对应后端/模块 | 说明 |
|---------|------------|------|
| `Services/TradeProfileService.swift` | 后端API调用 | iOS薄客户端，只负责展示+网络 |
| `Models/Trade.swift` | 后端 trades表 | 交易记录模型（以现有为准） |
| `Models/UserProfile.swift` | 后端 profiles表 | 画像模型（**以iOS现有263行版本为准**） |
| `Features/Profile/TradeProfileView.swift` | — | 画像展示页 |
| `Features/Profile/HoldingsHealthView.swift` | 后端 holdings表 | 持仓健康度 |
| `Features/Profile/MonthlyReportView.swift` | 后端 reports表 | 月度复盘报告 |

---

## 十、技术决策（已确认）

| 决策项 | 已确认方案 | 理由 |
|--------|-----------|------|
| OCR方案 | **苹果原生 VNRecognizeTextRequest** | 免费、离线可用、够用（委托单格式固定） |
| 画像计算 | **后端API** | 算法更新只改服务器，iOS无需发版 |
| 数据模型 | **以iOS现有 UserProfile.swift 为准** | 现有263行更丰富 |
| 数据存储 | **SQLite** | 并发安全，比JSON文件更正规 |

## 十、集成注意事项

1. **OCR 方案**：
   - 使用 iOS 系统自带 `VNRecognizeTextRequest`
   - 截图 → 系统OCR识别 → 返回文本
   - 无需调用后端或MiniMax API

2. **画像计算**：
   - iOS 截图/录入数据 → POST到后端API
   - 后端 Python 模块计算 → 返回画像JSON
   - iOS 只做展示，不做本地计算

3. **数据兼容性**：
   - iOS 本地 SQLite 存储
   - relay-server SQLite 存储（同一数据库文件）
   - 两边通过 `/api/v1/user/:userId/sync` 同步

4. **与妙股现有功能的衔接**：
   - 画像风格 → 个股查询时注入上下文（参考 `profile_integration.py`）
   - 持仓数据 → 与 `TradingService` 共用 `Holding` 模型
   - UserProfile 模型以 iOS 现有 `Models/UserProfile.swift`（263行）为准

---

## 十一、触发词（对话式入口）

```
分析我的交易
看看我的操作习惯
建我的投资画像
我最近买了什么
上传委托单
我的持仓健康吗
本月复盘
我的撤单率高吗
更新我的档案
```

---

*文档版本: v1.1 | 更新日期: 2026-04-07*
*技术决策确认：OCR苹果原生 / 画像后端API / iOS现有模型为准 / SQLite*
