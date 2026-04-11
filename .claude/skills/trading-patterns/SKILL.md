---
name: trading-patterns
description: 股票技术指标计算和交易模式识别。触发条件：计算MA/MACD/KDJ/RSI/Bollinger、分析持仓、风险评估
argument-hint: "[股票代码] [时间范围] [指标类型]"
user-invocable: true
allowed-tools: Read,Bash,Grep,Glob
model: sonnet
effort: high
context: fork
---

# Trading Patterns Skill

股票技术分析工具，提供指标计算和交易模式识别。

## 技术指标计算

### 移动平均线 (MA)

```typescript
function calculateMA(prices: number[], period: number): number {
  if (prices.length < period) return 0;
  const slice = prices.slice(-period);
  return slice.reduce((a, b) => a + b, 0) / period;
}
```

**使用场景：**
- MA5、MA10、MA20、MA60 短期/中期/长期趋势
- 金叉/死叉判断
- 支撑位/阻力位识别

### MACD (移动平均收敛发散)

```typescript
function calculateMACD(prices: number[]): { macd: number; signal: number; histogram: number } {
  const ema12 = calculateEMA(prices, 12);
  const ema26 = calculateEMA(prices, 26);
  const macd = ema12 - ema26;
  const signal = calculateEMA([...Array(9)].map((_, i) => macd), 9);
  const histogram = macd - signal;
  return { macd, signal, histogram };
}
```

### KDJ 随机指标

```typescript
function calculateKDJ(prices: number[], period: number = 9): { k: number; d: number; j: number } {
  const recentPrices = prices.slice(-period);
  const lowest = Math.min(...recentPrices);
  const highest = Math.max(...recentPrices);
  const rsv = highest === lowest ? 50 : ((prices[prices.length - 1] - lowest) / (highest - lowest)) * 100;

  const k = (2/3) * 50 + (1/3) * rsv;  // 简化的K值计算
  const d = (2/3) * 50 + (1/3) * k;
  const j = 3 * k - 2 * d;

  return { k, d, j };
}
```

### RSI (相对强弱指数)

```typescript
function calculateRSI(prices: number[], period: number = 14): number {
  if (prices.length < period + 1) return 50;

  let gains = 0;
  let losses = 0;

  for (let i = prices.length - period; i < prices.length; i++) {
    const diff = prices[i] - prices[i - 1];
    if (diff > 0) gains += diff;
    else losses -= diff;
  }

  const avgGain = gains / period;
  const avgLoss = losses / period;
  const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}
```

###布林带 (Bollinger Bands)

```typescript
function calculateBollingerBands(prices: number[], period: number = 20, stdDev: number = 2): {
  upper: number;
  middle: number;
  lower: number;
} {
  const middle = calculateMA(prices, period);
  const variance = prices.slice(-period).reduce((sum, p) => sum + Math.pow(p - middle, 2), 0) / period;
  const std = Math.sqrt(variance);

  return {
    upper: middle + stdDev * std,
    middle,
    lower: middle - stdDev * std
  };
}
```

## 持仓分析

### 平均持仓天数

```typescript
function calculateAverageHoldingPeriod(holdings: Holding[]): number {
  if (holdings.length === 0) return 0;

  const now = Date.now();
  const totalDays = holdings.reduce((sum, h) => {
    const days = (now - new Date(h.purchaseDate).getTime()) / (1000 * 60 * 60 * 24);
    return sum + days;
  }, 0);

  return totalDays / holdings.length;
}
```

### 持仓盈亏分析

```typescript
interface HoldingAnalysis {
  symbol: string;
  currentValue: number;
  costBasis: number;
  profitLoss: number;
  profitLossPercent: number;
  daysHeld: number;
}

function analyzeHoldings(holdings: Holding[], currentPrices: Record<string, number>): HoldingAnalysis[] {
  return holdings.map(h => {
    const currentPrice = currentPrices[h.symbol] || h.purchasePrice;
    const currentValue = currentPrice * h.quantity;
    const costBasis = h.purchasePrice * h.quantity;
    const profitLoss = currentValue - costBasis;
    const profitLossPercent = (profitLoss / costBasis) * 100;

    return {
      symbol: h.symbol,
      currentValue,
      costBasis,
      profitLoss,
      profitLossPercent,
      daysHeld: calculateDaysHeld(h.purchaseDate)
    };
  });
}
```

## 风险管理

### 仓位管理规则

```typescript
interface PositionSize {
  maxPosition: number;      // 单只股票最大仓位 (建议 20%)
  maxTotalPosition: number;  // 总仓位上限 (建议 80%)
  stopLossPercent: number;  // 止损比例 (建议 7%)
}

const DEFAULT_POSITION_SIZE: PositionSize = {
  maxPosition: 0.2,
  maxTotalPosition: 0.8,
  stopLossPercent: 0.07
};
```

### 风险评估

```typescript
function assessRisk(
  portfolio: Holding[],
  currentPrices: Record<string, number>,
  volatility: number
): { riskLevel: 'low' | 'medium' | 'high'; recommendation: string } {
  const totalExposure = calculateTotalExposure(portfolio, currentPrices);
  const concentration = calculateConcentration(portfolio, currentPrices);

  if (totalExposure > 0.9 || concentration > 0.4) {
    return { riskLevel: 'high', recommendation: '建议减仓，控制风险' };
  }
  if (totalExposure > 0.7 || concentration > 0.25 || volatility > 0.3) {
    return { riskLevel: 'medium', recommendation: '谨慎操作，关注仓位' };
  }
  return { riskLevel: 'low', recommendation: '仓位合理，可择机加仓' };
}
```

## 信号识别

### 买入信号

- MACD 金叉 (DIF从下往上穿越DEA)
- KDJ 低位金叉 (K从下往上穿越D，且<30)
- RSI < 30 超卖区域
- 股价触及布林带下轨
- MA5 上穿 MA10 (短期上涨趋势)

### 卖出信号

- MACD 死叉 (DIF从上往下穿越DEA)
- KDJ 高位死叉 (K从上往下穿越D，且>70)
- RSI > 70 超买区域
- 股价触及布林带上轨
- MA5 下穿 MA10 (短期下跌趋势)

## 使用示例

```bash
# 计算单只股票的MA
./scripts/calculate_ma.sh 600519 20

# 批量分析持仓
./scripts/analyze_portfolio.sh
```

## 注意事项

- 技术指标仅供参考，不构成投资建议
- 建议结合基本面分析综合判断
- 轻仓操作，合理止损
