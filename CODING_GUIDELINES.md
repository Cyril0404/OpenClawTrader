# OpenClaw Trader - 代码开发规范 v1.1

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
├── Design/            # 颜色、字体、通用组件（单文件 Components.swift）
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
- 通用组件放在`Design/`目录的 Components.swift 中，禁止重复造轮子

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

## 5. 代码格式化
### 5.1 SwiftLint 集成
项目集成 SwiftLint 进行代码格式化检查：
```bash
# 安装
brew install swiftlint

# 检查
swiftlint

# 自动修复
swiftlint --fix
```

### 5.2 CI/CD 集成
- 每次 PR 必须通过 SwiftLint 检查
- 严重级别（error）的格式化问题会阻止合并
- 警告级别（warning）建议修复，但不阻塞合并

## 6. 代码提交规范
详细规范请参考 [COMMIT_GUIDELINES.md](./COMMIT_GUIDELINES.md)

### 6.1 Commit Message 格式
```
<类型>(<可选范围>): <主题>

[可选：正文]

[可选：页脚]
```

### 6.2 提交类型
- `feat`: 新增功能
- `fix`: 修复bug
- `docs`: 文档修改
- `style`: 格式调整（不影响代码运行）
- `refactor`: 重构（不新增功能、不修复bug）
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具配置修改

### 6.3 示例
```
feat: 新增持仓截图导入功能
fix(TradingAnalysis): 修复枚举语法错误
docs: 添加代码开发规范文档
```

## 7. 性能规范
- **长列表**：使用 `LazyVStack` 或 `List`，禁止用普通 `VStack`
- **固定小范围内容**：可以使用 `VStack`（如表单内 3-5 个固定字段）
- 图片资源必须用 `AsyncImage` 异步加载
- 网络请求必须有缓存机制
- 主线程只做UI更新，耗时操作必须放到后台线程

## 8. 安全规范
- API Key、敏感信息不能硬编码到代码中，必须通过配置文件读取
- 用户隐私数据（密码、Token、密钥）必须存在 Keychain 中
- 非敏感偏好设置（主题、语言、通知开关）可以使用 UserDefaults
- 网络请求必须用 HTTPS，禁止明文传输
- 输入框必须做长度和格式校验

## 9. 代码审查规范
### 9.1 PR 要求
- 所有代码必须通过 Pull Request 合并，禁止直接提交到 main/master 分支
- PR 必须包含：修改描述、测试计划、截图/录屏（UI 改动时）
- 至少 1 人 approve 才能合并

### 9.2 Review 注意事项
- 审查代码逻辑是否正确
- 审查是否有安全隐患
- 审查是否遵循本规范
- 建议而非强制时使用评论，而非直接修改

## 10. 异常处理规范
- 所有可能抛出错误的地方必须处理
- 网络请求必须有失败回调和重试机制
- 错误信息必须友好，禁止崩溃
- 关键异常必须上报日志

## 11. 测试规范
### 11.1 测试覆盖率目标
- 核心业务逻辑（Services、Models）：覆盖率 > 60%
- UI 组件：基础渲染测试

### 11.2 测试目录结构
```
OpenClawTraderTests/           # 单元测试
├── Services/
├── Models/
└── Views/

OpenClawTraderUITests/         # UI 测试
```

### 11.3 测试命名
- 测试函数命名：`func test<被测方法>_<场景>_<预期结果>()`
- 示例：`func testImportHolding_WithValidInput_ShouldUpdatePortfolio()`

## 12. 无障碍规范
- 支持 Dynamic Type（使用系统字体而非固定字号）
- 所有图片添加 `accessibilityLabel`
- 交互元素设置合理的 `accessibilityHint`
- 确保颜色对比度符合 WCAG 2.1 AA 标准

---
*规范版本: v1.2*
*最后更新: 2026-03-28*
