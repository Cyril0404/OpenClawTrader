# OpenClaw Trader - 代码开发规范 v1.0

## 1. 基础语法规范
### 1.1 Swift 语法要求
```swift
// ✅ 正确
enum Category: String, Codable {
    case 仓位 = "仓位管理"  // case后面必须加空格
    case 止损 = "止损策略"
}

// ❌ 错误
enum Category: String, Codable {
    case仓位 = "仓位管理"   // 缺少空格，语法错误
}
```

### 1.2 通用规则
- 所有关键字和值之间必须有空格
- 代码缩进使用4个空格（不要用tab）
- 单行代码长度不超过120个字符
- 大括号`{`必须和前面的语句在同一行
- 二元运算符（+、-、*、/、=、==等）前后必须有空格

## 2. 命名规范
### 2.1 文件命名
- 采用大驼峰命名法：`TradingAnalysis.swift`、`PortfolioView.swift`
- 后缀明确：View结尾是视图、Model结尾是模型、Service结尾是服务类
- 禁止使用拼音缩写，除非是通用缩写（API、URL、UUID等）

### 2.2 变量/函数命名
- 变量/函数：小驼峰命名法：`tradingAnalysis`、`fetchPortfolioData()`
- 常量：全部大写+下划线分隔：`MAX_HOLDING_COUNT`、`API_BASE_URL`
- 枚举：小写开头，描述清晰：`.success`、`.warning`

### 2.3 资源命名
- 图片资源：小写下划线命名：`icon_portfolio.png`、`bg_card.png`
- 本地化字符串：`trading_portfolio_title`

## 3. 代码结构规范
### 3.1 目录结构
```
OpenClawTrader/
├── App/                # App入口、根视图
├── Design/            # 颜色、字体、通用组件
├── Features/          # 业务功能模块
│   ├── Console/       # OpenClaw控制台
│   ├── Trading/       # 交易相关
│   ├── Data/          # 数据报表
│   ├── Notifications/ # 通知中心
│   └── Profile/       # 个人设置
├── Services/          # 网络、存储、OCR等服务
├── Models/            # 数据模型
├── Utils/             # 扩展、工具类
└── Resources/         # 资源文件
```

### 3.2 模块拆分
- 每个功能模块独立目录
- 模块间通过protocol解耦，禁止跨模块直接依赖
- 通用组件放在`Design/Components/`目录，禁止重复造轮子

## 4. 代码注释规范
### 4.1 文件头注释
每个文件开头必须有简短说明：
```swift
//
//  PortfolioView.swift
//  OpenClawTrader
//
//  Created by Claude Code on 2026/03/27.
//  功能：持仓列表视图，展示用户持仓明细和收益统计
//
```

### 4.2 函数注释
公共函数必须有注释说明功能、参数、返回值：
```swift
/// 计算持仓总收益
/// - Parameter holdings: 持仓数组
/// - Returns: 总收益金额（Double）
func calculateTotalProfit(holdings: [Holding]) -> Double {
    // 实现
}
```

### 4.3 TODO/FIXME
- 临时待办用`// TODO:`标记
- 已知问题用`// FIXME:`标记
- 必须说明问题描述和负责人

## 5. 代码提交规范
### 5.1 Commit Message 格式
```
<类型>: <描述>

[可选：详细描述]
```

### 5.2 提交类型
- `feat`: 新增功能
- `fix`: 修复bug
- `docs`: 文档修改
- `style`: 格式调整（不影响代码运行）
- `refactor`: 重构（不新增功能、不修复bug）
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具配置修改

### 5.3 示例
```
feat: 新增持仓截图导入功能
fix: 修复TradingAnalysis.swift枚举语法错误
docs: 添加代码开发规范文档
```

## 6. 性能规范
- 列表必须使用`List`或`LazyVStack`，禁止用普通`VStack`
- 图片资源必须用`AsyncImage`异步加载
- 网络请求必须有缓存机制
- 主线程只做UI更新，耗时操作必须放到后台线程

## 7. 安全规范
- API Key、敏感信息不能硬编码到代码中，必须通过配置文件读取
- 用户隐私数据必须存在Keychain中，不能存在UserDefaults
- 网络请求必须用HTTPS，禁止明文传输
- 输入框必须做长度和格式校验

## 8. 异常处理规范
- 所有可能抛出错误的地方必须处理
- 网络请求必须有失败回调和重试机制
- 错误信息必须友好，禁止崩溃
- 关键异常必须上报日志

---
*规范版本: v1.0*
*最后更新: 2026-03-27*
