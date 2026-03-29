# OpenClawTrader 配对问题排查指南

## 快速排查流程

```
配对失败？
├── 配对码问题？
│   ├── 配对码过期（5分钟）→ 重新生成
│   ├── 配对码已被使用 → 重新生成
│   └── 配对码输入错误 → 仔细核对6位码
├── 连接问题？
│   ├── Relay Server 无响应 → 检查服务状态
│   ├── WebSocket 连接失败 → 检查网络/端口
│   └── Gateway 未注册 → 重启 gateway-bridge
└── Token 问题？
    ├── token 无效 → 重新走完整配对流程
    └── 服务重启后 token 丢失 → 重新配对
```

---

## 常见问题

### Q1: 配对码验证返回"配对码无效"

**原因**：
- 配对码已过期（5分钟有效期）
- 配对码已被使用（一次性）
- 配对码输入错误

**解决**：
```bash
# 在桌面端重新生成配对码
cd ~/openclaw/relay-server
npm run pair
```

---

### Q2: 配对码验证返回"配对码已过期"

**原因**：配对码生成后超过 5 分钟未使用

**解决**：
```bash
# 重新生成（桌面端）
npm run pair
```

---

### Q3: 验证成功，但 WebSocket 连接时提示 token 无效

**原因**：token 对应的 Gateway 不存在（Gateway 未连接或已断开）

**排查步骤**：
1. 确认桌面端 gateway-bridge 正在运行
2. 确认桌面端已成功注册到 relay server
3. 检查 relay server 日志中是否有 `gateway` 注册记录

```bash
# 查看 relay server 日志
pm2 logs openclaw-relay
# 应该有类似输出：
# [Gateway] New gateway registered: desktop-gw-001
```

---

### Q4: WebSocket 连接成功，但没有收到 `device_connected` 通知

**原因**：
- Gateway 端连接已断开
- relay server 无法找到对应的 gatewayId

**解决**：
```bash
# 1. 重启 relay server 端 gateway-bridge
# （在桌面端执行）
node ~/openclaw/gateway-bridge.js

# 2. 确认 relay server 端 tokenRegistry 有对应映射
# 检查 relay server 日志
grep "TokenRegistry" /Users/zifanni/openclaw/relay-server/logs/*.log
```

---

### Q5: "gateway unknown" 错误

**原因**：
- `gatewayManager.keys()` 返回 Iterator，直接使用 `.length` 属性无效
- 可用 gateway 列表为空

**解决**：
修改 `relay-server/src/api/pair.js`，将：
```javascript
const availableGateways = gatewayManager ? gatewayManager.keys() : []
const selectedGatewayId = gatewayId || (availableGateways.length > 0 ? availableGateways[0] : null)
```

改为：
```javascript
const availableGateways = gatewayManager ? [...gatewayManager.keys()] : []
const selectedGatewayId = gatewayId || (availableGateways.length > 0 ? availableGateways[0] : null)
```

---

### Q6: 服务重启后，之前配对过的设备需要重新配对

**原因**：
- token 映射存储在内存中，重启后丢失

**解决**：
- 确保 `relay-server/src/shared/tokenRegistry.js` 已实现 `tokens.json` 持久化
- relay server 版本 >= 2026-03-29 的版本支持此功能

---

### Q7: iOS 扫码后无反应

**排查**：
1. 检查相机权限是否授权
2. 确认二维码内容是 `openclaw://pair?...` 格式
3. 确认 iOS App 已正确解析 URL

---

### Q8: relay server 部署在腾讯云，外部无法访问

**排查**：
1. 确认腾讯云安全组已开放 3001 端口
2. 确认 PM2 正在运行
3. 确认防火墙允许外部访问

```bash
# 在腾讯云服务器上执行
curl http://localhost:3001/health
# 应该返回 {"status":"ok",...}
```

---

## 诊断命令

### 检查 relay server 状态
```bash
pm2 status openclaw-relay
pm2 logs openclaw-relay --lines 50
```

### 检查 Gateway 连接数
```bash
curl http://150.158.119.114:3001/health
```

### 检查配对码文件
```bash
cat ~/openclaw/relay-server/data/pairing-codes.json
```

### 检查 token 映射
```bash
cat ~/openclaw/relay-server/data/tokens.json
```

### 测试配对 API
```bash
# 生成配对码
curl -X POST http://150.158.119.114:3001/api/pair/generate

# 验证配对码（替换 CODE 为实际码）
curl -X POST http://150.158.119.114:3001/api/pair/verify \
  -H "Content-Type: application/json" \
  -d '{"code": "CODE"}'
```

---

## relay server 日志关键词

| 关键词 | 含义 |
|--------|------|
| `[Pair] Generated code XXX` | 配对码已生成 |
| `[Pair] Verify success` | 配对码验证成功 |
| `[Pair] Verify failed: code not found` | 配对码无效 |
| `[Pair] Verify failed: code expired` | 配对码过期 |
| `[TokenRegistry] Registered token` | Token 已注册 |
| `[Gateway] New gateway registered` | Gateway 已连接 |
| `[Device] Device registered` | 设备已连接 |

---

*文档版本: v1.0*
*最后更新: 2026-03-29*
