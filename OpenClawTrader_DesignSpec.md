# OpenClaw Trader - 设计规范 v1.0

## 设计哲学

**"Less, but better"** — 少即是多
- 去除一切不必要的装饰
- 黑白为主，极简线条
- 大量留白，信息密度低
- 精致的微交互传递高级感

---

## 1. 色彩系统

### 主色板 (Monochrome)
```
Background Primary:    #000000  (纯黑背景)
Background Secondary:  #0A0A0A  (卡片背景)
Background Tertiary:   #141414  (输入框/次级区域)
Border:                #1A1A1A  (分隔线)
Border Light:          #2A2A2A  (hover状态)

Text Primary:          #FFFFFF  (标题/重要文字)
Text Secondary:        #8A8A8A  (正文/辅助)
Text Tertiary:         #4A4A4A  (占位符/禁用)
Text Inverse:          #000000  (白底黑字)

Accent:                #FFFFFF  (强调色 - 纯白)
Accent Muted:          #3A3A3A  (次级强调)
Accent Subtle:         #1F1F1F  (hover背景)
```

### 功能色 (Functional)
```
Success:    #2ECC71  (健康/盈利 - 墨绿)
Warning:    #F39C12  (警告/提醒 - 琥珀)
Error:      #E74C3C  (错误/亏损 - 暗红)
Info:       #3498DB  (信息 - 冷蓝)
```

### 渐变 (仅用于 Logo/特殊场景)
```
Gradient:   linear-gradient(135deg, #FFFFFF 0%, #888888 100%)
```

---

## 2. 字体系统

### 字体族
```
主字体:     SF Pro Display (iOS 系统)
等宽字体:   SF Mono (代码/数字)
中文字体:   PingFang SC (中文内容)
```

### 字号规范
```
大标题:     34pt / Bold      (页面标题)
标题1:      28pt / Bold      (模块标题)
标题2:      22pt / Semibold   (卡片标题)
标题3:      17pt / Semibold   (列表项标题)
正文:       15pt / Regular    (主要正文)
副文本:     13pt / Regular    (辅助说明)
小字:       11pt / Regular    (标签/时间戳)
等宽数字:   SF Mono / 17pt    (数据展示)
```

### 行高
```
标题行高:   1.2
正文行高:   1.5
数字行高:   1.0 (紧凑)
```

---

## 3. 间距系统 (8pt Grid)

```
xxs:    4pt
xs:     8pt
sm:     12pt
md:     16pt
lg:     24pt
xl:     32pt
xxl:    48pt
xxxl:   64pt
```

---

## 4. 圆角规范

```
小圆角:   6pt   (按钮、标签)
中圆角:   12pt  (卡片、输入框)
大圆角:   16pt  (底部弹窗)
全圆角:   9999pt (胶囊按钮/头像)
```

---

## 5. 阴影 (极轻)

```swift
// 仅在需要浮起感时使用
shadow: color=#FFFFFF opacity=0.03, x=0, y=1, blur=8
```

---

## 6. 图标系统

- **风格:** 线性图标 (Line Icons)
- **粗细:** 1.5pt stroke
- **尺寸:** 20pt (小) / 24pt (中) / 28pt (大)
- **颜色:** Text Secondary (#8A8A8A)，激活时 Text Primary (#FFFFFF)
- **推荐图标库:** SF Symbols (系统自带)

---

## 7. 动效哲学

### 原则
- **慢而优雅:** 300-400ms
- **缓动函数:** ease-out / spring
- **克制使用:** 只在关键交互时使用

### 标准动效
```
页面转场:     350ms ease-out
按钮反馈:     150ms ease-out
卡片展开:     300ms spring(0.8)
加载动画:     1.2s linear (呼吸灯效果)
滑块拖动:     0ms (即时响应)
```

---

## 8. 组件设计

### 8.1 导航栏
- 背景: Background Primary (#000000)
- 标题: Text Primary / 17pt Semibold
- 无底边分隔线（极简）
- 可选: 右侧操作按钮为 Text Secondary

### 8.2 底部 Tab Bar
- 背景: Background Secondary (#0A0A0A) + 顶部 0.5pt Border
- 图标: 24pt SF Symbols，Inactive: #4A4A4A，Active: #FFFFFF
- 文字: 10pt，Active: #FFFFFF，Inactive: #4A4A4A
- 无选中背景色，纯文字+图标

### 8.3 卡片
```
背景:        Background Secondary (#0A0A0A)
边框:        Border (#1A1A1A) / 0.5pt
圆角:        12pt
内边距:      16pt
间距:        卡片之间 12pt
```

### 8.4 按钮

**主按钮 (Primary)**
```
背景:        #FFFFFF
文字:        #000000 / 15pt Semibold
圆角:        6pt
高度:        48pt
```

**次按钮 (Secondary)**
```
背景:        Transparent
边框:        #2A2A2A / 1pt
文字:        #FFFFFF / 15pt Medium
圆角:        6pt
高度:        48pt
```

**文字按钮 (Text)**
```
背景:        Transparent
文字:        #8A8A8A / 15pt Regular
圆角:        6pt
高度:        44pt
```

### 8.5 输入框
```
背景:        Background Tertiary (#141414)
边框:        Border (#1A1A1A) / 1pt
圆角:        8pt
高度:        48pt
文字:        Text Primary / 15pt
占位符:      Text Tertiary / 15pt
Focus边框:   #3A3A3A
```

### 8.6 列表项
```
背景:        Transparent
高度:        56pt (单行) / 72pt (双行)
分隔线:      Border (#1A1A1A) / 0.5pt (左侧 16pt 缩进)
左侧图标:    24pt / Text Secondary
标题:        17pt Semibold / Text Primary
副标题:      13pt Regular / Text Secondary
右侧箭头:    Text Tertiary / 16pt
```

### 8.7 数据展示

**数字卡片 (Large Number Display)**
```
数值:        SF Mono / 34pt Bold / Text Primary
单位:        SF Mono / 15pt Regular / Text Secondary
标签:        11pt Regular / Text Tertiary
```

**状态标签 (Status Badge)**
```
背景:        Accent Subtle (#1F1F1F)
文字:        Text Secondary / 11pt Medium
圆角:        全圆角 (胶囊)
内边距:      4pt 8pt
```

**进度/滑块**
```
轨道:        #1A1A1A
填充:        #FFFFFF
高度:        4pt
圆角:        2pt
Thumb:       20pt 白色圆，Border #1A1A1A
```

### 8.8 图表
```
背景:        Transparent
网格线:      #1A1A1A
数据线:      纯白 #FFFFFF 或 功能色
数据填充:    白色 10% opacity
文字:        Text Secondary
```

### 8.9 空状态
```
图标:        48pt / Text Tertiary
标题:        17pt Semibold / Text Secondary
副文本:      15pt Regular / Text Tertiary
间距:        16pt
```

### 8.10 加载状态
```
骨架屏:      #141414 背景 + #1A1A1A 闪烁动画
Loading:     白色圆点呼吸灯 / 8pt 直径
进度环:      2pt stroke / 白色
```

---

## 9. 页面布局规范

### 9.1 底部导航结构
```
┌─────────────────────┬─────────────────────┬─────────────────────┐
│        行情          │        AI助手        │         我的         │
│  chart.line.uptrend  │bubble.left.and.bubble.right│     person        │
│   (市场/自选行情)     │   (默认打开主Agent对话)│    (设置/账户)       │
└─────────────────────┴─────────────────────┴─────────────────────┘
```
- 默认选中第2个Tab（AI助手），打开App直接进入聊天界面
- TabBar 高度: 50pt + 底部安全区
- TabBar 背景: Background Secondary
- 图标: 22pt SF Symbols
- 文字: 10pt
- 选中态: Text Primary (#FFFFFF)
- 未选中: Text Tertiary (#4A4A4A)

### 9.2 安全区域
- 顶部: 系统刘海 + 8pt
- 底部: Home Indicator + 34pt
- 侧边: 16pt 边距

### 9.3 页面结构
```
顶部导航:     44pt (不含状态栏)
页面标题:     34pt 大标题 或 28pt Section标题
内容区:      滚动区域，底部留 100pt (TabBar高度)
卡片间距:    12pt
列表项间距:  无间距，连续排列
```

### 9.4 典型页面节奏
```
- 顶部大标题 (34pt) + 8pt
- 副标题/说明 (13pt) + 24pt
- 数据卡片区 + 24pt
- 功能列表 + 16pt
- 底部操作区 + 32pt
```

---

## 10. 交互反馈

### 10.1 按钮状态
```
Default:     正常显示
Pressed:     opacity 0.7 / 150ms
Disabled:    opacity 0.3
Loading:     显示 spinner，禁用交互
```

### 10.2 手势
```
点击:        高亮反馈 + 触觉轻震
长按:        0.5s 后触发 context menu
滑动删除:    左侧滑动显示红色删除区
下拉刷新:    自定义白色刷新指示器
```

---

## 11. 日/夜模式适配

### 深色模式 (Dark Mode) - 默认
```
Background Primary:    #000000  (纯黑背景)
Background Secondary:  #0A0A0A  (卡片背景)
Background Tertiary:   #141414  (输入框/次级区域)
Border:               #1A1A1A  (分隔线)
Border Light:         #2A2A2A  (hover状态)

Text Primary:         #FFFFFF  (标题/重要文字)
Text Secondary:       #8A8A8A  (正文/辅助)
Text Tertiary:        #4A4A4A  (占位符/禁用)
Text Inverse:         #000000  (白底黑字)

Accent:               #FFFFFF  (强调色 - 纯白)
Accent Muted:         #3A3A3A  (次级强调)
Accent Subtle:        #1F1F1F  (hover背景)
```

### 日间模式 (Light Mode)
```
Background Primary:    #FFFFFF  (纯白背景)
Background Secondary:  #F5F5F5  (卡片背景)
Background Tertiary:   #EBEBEB  (输入框/次级区域)
Border:               #E0E0E0  (分隔线)
Border Light:         #D0D0D0  (hover状态)

Text Primary:         #000000  (标题/重要文字)
Text Secondary:       #666666  (正文/辅助)
Text Tertiary:        #999999  (占位符/禁用)
Text Inverse:         #FFFFFF  (黑底白字)

Accent:               #000000  (强调色 - 纯黑)
Accent Muted:         #C0C0C0  (次级强调)
Accent Subtle:        #E8E8E8  (hover背景)
```

### 切换机制
- 默认跟随系统设置 (userInterfaceStyle: .unspecified)
- 用户可在设置中手动切换：跟随系统 / 日间模式 / 深色模式
- 切换时平滑过渡动画 (300ms)

---

## 12. 辅助功能

- 所有文本 contrast ratio > 4.5:1
- 可访问性标签完整
- 支持 Dynamic Type (最大到 xxxLarge)
- 减少动画模式支持

---

*设计版本: v1.1*
*最后更新: 2026-03-27*
