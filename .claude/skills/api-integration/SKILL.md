---
name: api-integration
description: OpenClaw API调用、认证token管理、请求重试和错误处理。触发条件：API调用、token刷新、网络错误处理
argument-hint: "[API方法] [端点] [重试次数]"
user-invocable: true
allowed-tools: Read,Bash,Grep,Glob,Write
model: sonnet
effort: high
context: fork
---

# API Integration Skill

OpenClaw API 集成最佳实践，包含认证、请求管理和错误处理。

## 认证管理

### Token刷新机制

```typescript
interface AuthState {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

class TokenManager {
  private state: AuthState | null = null;

  async getValidToken(): Promise<string> {
    if (!this.state || Date.now() >= this.state.expiresAt) {
      await this.refresh();
    }
    return this.state!.accessToken;
  }

  async refresh(): Promise<void> {
    const response = await fetch('/api/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refreshToken: this.state?.refreshToken })
    });

    if (!response.ok) {
      throw new Error('Token refresh failed');
    }

    this.state = await response.json();
  }
}
```

### Gateway Token处理

```typescript
interface GatewayConfig {
  baseUrl: string;
  workspaceId: string;
  token: string;
}

// 从环境变量或配置获取Gateway token
function getGatewayConfig(): GatewayConfig {
  return {
    baseUrl: process.env.GATEWAY_BASE_URL || 'http://localhost:8080',
    workspaceId: process.env.GATEWAY_WORKSPACE_ID || '',
    token: process.env.GATEWAY_TOKEN || ''
  };
}
```

## HTTP客户端封装

### 带重试的请求

```typescript
interface RequestOptions extends RequestInit {
  timeout?: number;
  retries?: number;
  retryDelay?: number;
}

async function fetchWithRetry<T>(
  url: string,
  options: RequestOptions = {}
): Promise<T> {
  const {
    timeout = 30000,
    retries = 3,
    retryDelay = 1000,
    ...fetchOptions
  } = options;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(url, {
        ...fetchOptions,
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (!response.ok && attempt < retries) {
        await delay(retryDelay * Math.pow(2, attempt)); // 指数退避
        continue;
      }

      return response.json();
    } catch (error) {
      if (attempt === retries) throw error;
      await delay(retryDelay * Math.pow(2, attempt));
    }
  }

  throw new Error('Max retries exceeded');
}
```

### API响应处理

```typescript
interface ApiResponse<T> {
  data: T | null;
  error: {
    message: string;
    code: string;
  } | null;
}

function handleResponse<T>(response: Response): ApiResponse<T> {
  if (response.ok) {
    return { data: response.json(), error: null };
  }

  return {
    data: null,
    error: {
      message: response.statusText,
      code: `HTTP_${response.status}`
    }
  };
}
```

## 日志记录

### 请求日志格式 (JSON)

```typescript
interface RequestLog {
  timestamp: string;
  correlationId: string;
  method: string;
  url: string;
  statusCode: number;
  duration: number;
  error?: string;
}

function logRequest(log: RequestLog): void {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: log.error ? 'error' : 'info',
    ...log
  }));
}
```

### 敏感信息过滤

```typescript
const SENSITIVE_FIELDS = ['token', 'password', 'secret', 'authorization'];

function sanitizeLog(obj: Record<string, unknown>): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_FIELDS.some(f => key.toLowerCase().includes(f))) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeLog(value as Record<string, unknown>);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}
```

## 错误处理

### 错误分类

```typescript
enum ErrorCode {
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT = 'TIMEOUT',
  AUTH_FAILED = 'AUTH_FAILED',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  RATE_LIMITED = 'RATE_LIMITED',
  SERVER_ERROR = 'SERVER_ERROR',
  INVALID_RESPONSE = 'INVALID_RESPONSE'
}

interface ApiError extends Error {
  code: ErrorCode;
  retryable: boolean;
  details?: unknown;
}
```

### 错误恢复策略

```typescript
async function withRetry<T>(
  operation: () => Promise<T>,
  options: { retries: number; onRetry?: (e: Error, attempt: number) => void }
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt <= options.retries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;

      if (!isRetryable(error) || attempt === options.retries) {
        throw error;
      }

      options.onRetry?.(lastError, attempt + 1);
      await delay(getBackoffMs(attempt));
    }
  }

  throw lastError;
}
```

## 断路器模式

```typescript
class CircuitBreaker {
  private failures = 0;
  private lastFailure: number = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';

  constructor(
    private threshold: number = 5,
    private timeout: number = 60000
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailure >= this.timeout) {
        this.state = 'half-open';
      } else {
        throw new Error('Circuit breaker is open');
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failures = 0;
    this.state = 'closed';
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailure = Date.now();
    if (this.failures >= this.threshold) {
      this.state = 'open';
    }
  }
}
```

## 使用示例

```typescript
// 标准API调用
const client = new APIClient({
  baseURL: 'http://localhost:3001',
  tokenManager: new TokenManager()
});

const response = await client.request('/api/agent/messages', {
  method: 'POST',
  body: { message: 'Hello' }
});
```

## 注意事项

- 永远不要在日志中记录敏感信息
- 所有API调用必须有超时配置
- 实现断路器防止级联故障
- 认证失败时清除本地token并提示重新登录
