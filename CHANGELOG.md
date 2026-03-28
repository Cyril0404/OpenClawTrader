# Changelog

所有版本变更记录都会在此文档中维护。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [Unreleased]

### 新增
- [ ] 待添加新功能记录

### 修复
- [ ] 待添加Bug修复记录

### 改进
- [ ] 待添加性能/体验改进记录

---

## [1.3.0] - 2026-03-28

### 新增

#### 登录模块 (LoginView)
- **登录页面重构**
  - 手机号 + 验证码登录方式
  - "记住我"开关按钮（在右边）
  - 获取验证码按钮（60秒倒计时）
  - 登录成功后进入主页面

- **忘记密码功能**
  - 三步流程：手机号 → 验证码 → 设置新密码 → 完成
  - `ForgotPasswordView` 独立页面

- **注册功能**
  - 手机号 + 验证码 + 密码注册
  - 注册成功后自动切换到登录

#### OpenClaw 连接 (OpenClawConnectView)
- **连接页面优化**
  - API 地址和 API Key 输入
  - 测试连接功能（显示成功/失败结果）
  - 记住设置开关
  - 从本地存储加载已保存的设置

- **OpenClaw API 对接**
  - 对接真实 API: http://localhost:18789
  - `APIClient` 网络请求客户端
  - 支持 `GET /v1/status` 测试连接
  - 支持 `POST /v1/chat` 发送消息
  - 支持 `GET /v1/workspaces` 获取工作空间列表
  - Bearer Token 认证

#### 用户模块
- **退出登录**
  - 确认弹窗
  - 退出后返回登录页面
  - 断开 OpenClaw 连接、重置服务状态

- **注销账号**
  - 确认弹窗（提示数据不可恢复）
  - 清除所有本地数据
  - 注销后返回登录页面

- **添加 OpenClaw**
  - 点击"添加 OpenClaw"打开连接页面
  - 配置 API 地址和 Key

### 修复
- TabItem 中 `appColors` 类型错误
- ContentView 切换到登录页功能

### 改进
- 登录页面简化：移除单独的注册页面
- 持仓列表样式优化
- 移除"API Key 设置"入口（与添加 OpenClaw 功能合并）
- 移除股票搜索功能（通过"+"菜单导入持仓）

---

## [1.2.0] - 2026-03-28

### 新增

#### 交易页面 (TradingDashboardView)
- **导入功能重构**
  - 右上角加号按钮改为菜单形式
  - 支持「导入持仓」和「导入委托」两个选项
  - 持仓导入：手动输入 / 截图识别
  - 委托导入：手动输入 / 截图识别

- **持仓概览优化**
  - 删除「实盘」标签
  - 新增持仓股数显示（`X 只`）

- **页面布局调整**
  - 持仓明细移到交易风格画像上方
  - 新增「活跃委托」展示区
  - 删除总持仓和AI投资建议板块

- **委托单功能**
  - 新增 `Order` 模型（委托类型、买卖方向、状态）
  - 支持限价单、市价单、止损单、止损限价单
  - 委托状态：待成交、部分成交、已成交、已取消、已拒绝
  - 新增 `ImportOrderView` 委托导入页面
  - 新增 `OrderRow` 和 `OrderListView` 委托列表页面
  - 取消委托功能

#### 我的页面 (UnifiedMeView)
- **页面重构**
  - 删除「持仓概览」板块
  - 删除「AI投资建议」板块
  - 新增独立「OpenClaw 连接」版块
    - 显示当前连接的 Workspace
    - 可切换/连接其他 Workspace
    - 可添加多个 OpenClaw

- **设置优化**
  - 「外观」选项栏调整到中间位置（更易点击）
  - 删除 ThemePickerSheet 的「完成」按钮（点击选项自动关闭）
  - 「退出登录」移到设置最底部

- **退出登录**
  - 新增退出登录按钮（红色）
  - 放在设置列表最底部

### 修复
- iOS 17.0 适配：@Observable 需要 iOS 17.0+
- ThemePickerSheet 显示不完整问题

### 改进
- 项目最低部署版本从 iOS 16.0 升级到 iOS 17.0
- ThemePickerSheet 弹窗高度调整为 .medium

---

## [1.1.0] - 2026-03-28

### 新增

#### 聊天页面 (SimpleChatView)
- **Header 重构**
  - Agent 名字 + 状态点居中显示
  - Agent 名称下方显示 context 用量（格式：`45.0K / 5.0M (0.9%)`）
  - Agent 选择器下拉菜单（可切换 Agent，进入管理页面）

- **功能栏**（输入框上方）
  - `模型` 按钮：对接 OpenClaw 模型列表，可切换默认模型（ModelPickerSheet）
  - `命令` 按钮：用户自定义命令，支持增删（CommandListSheet）
    - 默认命令：`/gpt`, `/claude`, `/image`, `/analyze`, `/trade`
    - 点击命令自动填入输入框
  - `用量` 按钮：显示各模型用量统计（UsageDetailSheet）

- **输入框功能**
  - 文字输入模式：标准 TextField
  - 语音输入模式：点击切换，输入框变为"按住说话"按钮
  - 附件功能：+ 按钮支持添加图片/文件（TODO）
  - 发送按钮：带 loading 状态

- **消息气泡**
  - AI 消息气泡改为白色背景黑色文字（与用户黑色背景白色文字区分）
  - 文本可选中（`.textSelection(.enabled)`）
  - 长按弹出功能菜单：复制、收藏、删除、引用、提醒
  - 引用功能：自动将消息内容插入输入框

- **会话功能**
  - 消息发送/接收对接 OpenClaw API（service.sendMessage）
  - 自动保存/加载 Agent 会话历史
  - 切换 Agent 时自动加载对应会话
  - 错误处理：API 失败时显示模拟回复

#### Tab Bar 优化
- TabItem 高度从 50pt 缩小到 44pt
- 图标大小从 22pt 缩小到 20pt
- 文字大小从 10pt 缩小到 9pt
- 底部 padding 优化
- 图标添加 offset(y: 4) 往下移动

#### Agent 管理入口
- 在 UnifiedMeView 设置区域添加「Agent 管理」入口

#### 数据模型更新
- OpenClawService 新增 `mainAgent` 属性
- OpenClawService 新增 `conversations` 字典存储会话历史
- 新增 `ChatRequest` / `ChatResponse` 结构
- 新增 `UserCommand` 模型支持自定义命令

### 修复
- AgentChatView Header 布局问题（已废弃，由 SimpleChatView 替代）
- 消息气泡 contextMenu 重复定义问题

### 改进
- 输入框 horizontal padding 从 16pt 减少到 8pt（更宽）
- Tab Bar 整体高度更紧凑

---

## [1.0.0] - 2026-03-27

### 新增
- ✅ 完整iOS App源代码（SwiftUI）
- ✅ PRDT产品需求文档
- ✅ 设计规格文档
- ✅ 代码开发规范
- ✅ Git提交规范
- ✅ PR模板和CODEOWNERS配置
- ✅ CHANGELOG版本记录模板

### 功能模块
- 📱 App架构：纯SwiftUI，模块化架构
- 🔌 OpenClaw控制台：Workspace管理、模型配置、Agent聊天、工作流监控
- 📊 交易模块：持仓管理、交易分析、AI建议、模拟交易
- 📈 数据模块：收益报表、历史交易、数据导出
- 🔔 通知中心：多类型通知、分类筛选、通知设置
- ⚙️ 个人设置：账户管理、OpenClaw连接、外观设置

---

## 版本说明
- **主版本号**：不兼容的API变更
- **次版本号**：向下兼容的功能新增
- **修订号**：向下兼容的问题修正

### 类型说明
- `新增`：新功能
- `修复`：Bug修复
- `改进`：性能优化、体验提升、代码重构等不影响功能的变更
- `废弃`：即将移除的功能
- `移除`：已移除的功能
- `安全`：安全相关的修复
