/**
 * OpenClaw Relay Server
 * WebSocket 中继服务器，用于 OpenClaw 移动端配对功能
 *
 * 职责：
 * 1. HTTP API - 配对码生成和验证
 * 2. WebSocket - Gateway 和 Device 的连接管理
 * 3. 消息路由 - Gateway 和 Device 之间的消息转发
 *
 * 不参与任何 AI 计算，只做消息转发
 */

const express = require('express')
const { WebSocketServer } = require('ws')
const http = require('http')
const path = require('path')
const fs = require('fs')

// 引入模块
const pairAPI = require('./api/pair')
const { GatewayManager } = require('./relay/gateway')
const { DeviceManager } = require('./relay/device')
const { getGatewayIdByToken } = require('./shared/tokenRegistry')

// 创建 Express 应用和 HTTP 服务器
const app = express()
const server = http.createServer(app)

// 从环境变量获取配置
const PORT = process.env.PORT || 3001
const HOST = process.env.HOST || '0.0.0.0'
const NODE_ENV = process.env.NODE_ENV || 'development'

// 确保日志目录存在
const logsDir = path.join(__dirname, '..', 'logs')
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true })
}

// 中间件 - JSON 解析
app.use(express.json())

// 请求日志中间件
app.use((req, res, next) => {
  const timestamp = new Date().toISOString()
  console.log(`[${timestamp}] ${req.method} ${req.path}`)
  next()
})

// CORS 头（开发环境）
if (NODE_ENV === 'development') {
  app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*')
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    if (req.method === 'OPTIONS') {
      return res.sendStatus(200)
    }
    next()
  })
}

// 挂载配对 API
app.use('/api/pair', pairAPI)

// 健康检查端点
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    connections: {
      gateway: gatewayManager.size(),
      device: deviceManager.size()
    }
  })
})

// 获取服务器信息
app.get('/api/server-info', (req, res) => {
  res.json({
    wsUrl: `ws://${req.headers.host || `${HOST}:${PORT}`}`,
    wssUrl: `wss://${req.headers.host || `${HOST}:${PORT}`}`,
    port: PORT
  })
})

// 创建 WebSocket 服务器
const wss = new WebSocketServer({ server })

// 初始化连接管理器
const gatewayManager = new GatewayManager()
const deviceManager = new DeviceManager()

// 注入 gatewayManager 到 pairAPI（必须在 managers 创建后）
pairAPI.setGatewayManager(gatewayManager)

// ============================================================
// HTTP → WebSocket 代理（供 App HTTP API 调用）
// ============================================================
// HTTP path -> RPC method 映射
// Gateway 的 WebSocket 协议使用 .list / .status 后缀
const PATH_TO_METHOD = {
  'status': 'status',
  'agents': 'agents.list',
  'models': 'models.list',
  'sessions': 'sessions.list',
  'skills': 'skills.status',
  // workflows 和 workspaces Gateway 不支持
  'workflows': null,
  'workspaces': null,
}

const pendingHttpProxies = new Map()

// HTTP 代理端点：App 用 HTTP 调用 Gateway API
// App 传 token 在 Authorization: Bearer <token> 头里
app.all('/api/v1/:path(*)', (req, res) => {
  const authHeader = req.headers.authorization || ''
  const token = authHeader.replace(/^Bearer\s+/i, '').trim()

  if (!token) {
    return res.status(401).json({ error: 'Missing Authorization token' })
  }

  const gatewayId = getGatewayIdByToken(token)
  if (!gatewayId) {
    return res.status(401).json({ error: 'Invalid or expired token' })
  }

  const gatewayWs = gatewayManager.get(gatewayId)
  if (!gatewayWs) {
    return res.status(503).json({ error: 'Gateway not connected' })
  }

  // 查询 method 映射
  const rpcMethod = PATH_TO_METHOD[req.params.path]
  if (rpcMethod === null) {
    // 不支持的端点，返回空数组
    res.json([])
    return
  }
  if (!rpcMethod) {
    // 未知的 path，使用原名称
    res.status(400).json({ error: `Unknown API: ${req.params.path}` })
    return
  }

  // 把 HTTP 请求转换成 JSON-RPC 2.0 消息
  const requestId = require('crypto').randomUUID()
  const rpcRequest = {
    type: 'req',
    id: requestId,
    method: rpcMethod,
    params: req.method === 'GET' ? {} : req.body || {}
  }

  const wrapper = {
    type: 'message',
    from: 'device',
    to: gatewayId,
    content: JSON.stringify(rpcRequest)
  }

  // 设置超时
  const timeout = setTimeout(() => {
    if (pendingHttpProxies.has(requestId)) {
      pendingHttpProxies.delete(requestId)
      res.status(504).json({ error: 'Gateway request timeout' })
    }
  }, 30000)

  pendingHttpProxies.set(requestId, {
    resolve: (result) => {
      console.log(`[HTTPProxy] Resolving request ${requestId}:`, JSON.stringify(result).substring(0, 100))
      clearTimeout(timeout)
      res.json(result)
    },
    reject: (err) => {
      console.log(`[HTTPProxy] Rejecting request ${requestId}:`, err.message)
      clearTimeout(timeout)
      res.status(500).json({ error: err.message })
    },
    timeout
  })

  console.log(`[HTTPProxy] Forwarding to gateway ${gatewayId}, ws.readyState=${gatewayWs.readyState}:`, JSON.stringify(wrapper).substring(0, 200))
  try {
    gatewayWs.send(JSON.stringify(wrapper))
    console.log(`[HTTPProxy] Message sent successfully`)
  } catch (err) {
    console.log(`[HTTPProxy] Send failed:`, err.message)
    return res.status(500).json({ error: 'Failed to send to gateway' })
  }
})

// ============================================================

/**
 * WebSocket 连接处理
 */
wss.on('connection', (ws, req) => {
  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress
  console.log(`[WS] New connection from ${clientIp}`)

  // 为连接分配唯一 ID
  ws.clientId = require('uuid').v4()
  ws.isAlive = true

  // 心跳检测
  ws.on('pong', () => {
    ws.isAlive = true
  })

  // 消息处理
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString())
      console.log(`[WS] Message from ${ws.role || 'unknown'}:`, JSON.stringify(message).substring(0, 300))
      handleMessage(ws, message)
    } catch (err) {
      console.error(`[WS] Invalid message from ${ws.clientId}:`, err.message)
      sendError(ws, 'Invalid message format')
    }
  })

  // 断开连接处理
  ws.on('close', () => {
    console.log(`[WS] Connection closed: ${ws.clientId}`)
    cleanupConnection(ws)
  })

  // 错误处理
  ws.on('error', (err) => {
    console.error(`[WS] Error on ${ws.clientId}:`, err.message)
  })
})

/**
 * 处理 WebSocket 消息
 */
function handleMessage(ws, message) {
  const { type } = message

  switch (type) {
    case 'gateway':
      // Gateway 连接注册（桌面端）
      handleGatewayConnect(ws, message)
      break

    case 'device':
    case 'register':
      // Device 连接注册（移动端）
      handleDeviceConnect(ws, message)
      break

    case 'message':
      // 业务消息转发
      handleRelayMessage(ws, message)
      break

    case 'ping':
      // 客户端心跳
      ws.send(JSON.stringify({ type: 'pong' }))
      break

    default:
      console.warn(`[WS] Unknown message type: ${type}`)
      sendError(ws, `Unknown message type: ${type}`)
  }
}

/**
 * 处理 Gateway 连接（桌面端）
 */
function handleGatewayConnect(ws, message) {
  const { gatewayId, gatewayUrl } = message

  if (!gatewayId) {
    sendError(ws, 'gatewayId is required')
    return
  }

  ws.role = 'gateway'
  ws.gatewayId = gatewayId
  ws.gatewayUrl = gatewayUrl || null

  // 设置 HTTP 代理回调：当 gateway-bridge 收到 Gateway 响应时，通知 relay 唤醒 HTTP 请求
  ws.onHttpProxyResponse = (originalId, res) => {
    console.log(`[HTTPProxy] onHttpProxyResponse called for id ${originalId}, result:`, JSON.stringify(res).substring(0, 200))
    if (pendingHttpProxies.has(originalId)) {
      const { resolve, reject, timeout } = pendingHttpProxies.get(originalId)
      clearTimeout(timeout)
      pendingHttpProxies.delete(originalId)
      if (res.error) {
        reject(new Error(res.error.message || JSON.stringify(res.error)))
      } else {
        resolve(res.result)
      }
    } else {
      console.log(`[HTTPProxy] No pending request for id ${originalId}`)
    }
  }

  gatewayManager.add(gatewayId, ws)
  global._gatewayBridge = ws  // 供 HTTP 代理代查 agents
  console.log(`[Gateway] Registered: ${gatewayId}`)

  ws.send(JSON.stringify({
    type: 'registered',
    role: 'gateway',
    gatewayId
  }))
}

/**
 * 处理 Device 连接（移动端）
 */
function handleDeviceConnect(ws, message) {
  const { token } = message

  if (!token) {
    sendError(ws, 'token is required')
    return
  }

  ws.role = 'device'
  ws.token = token

  // 查找对应的 Gateway（从共享 tokenRegistry 查找）
  const gatewayId = getGatewayIdByToken(token)

  if (!gatewayId) {
    sendError(ws, 'Invalid or expired token')
    return
  }

  deviceManager.add(token, ws, gatewayId)

  // 通知 Gateway 有新设备连接
  const gatewayWs = gatewayManager.get(gatewayId)
  if (gatewayWs) {
    gatewayWs.send(JSON.stringify({
      type: 'device_connected',
      token
    }))
  }

  console.log(`[Device] Registered: ${token} -> ${gatewayId}`)

  ws.send(JSON.stringify({
    type: 'registered',
    role: 'device',
    gatewayId
  }))
}

/**
 * 处理业务消息转发
 */
function handleRelayMessage(ws, message) {
  const { content, to } = message

  if (ws.role === 'gateway') {
    // Gateway 发送给 Device
    const gatewayId = ws.gatewayId
    const targetToken = deviceManager.findDeviceByGateway(gatewayId)

    if (targetToken) {
      const deviceWs = deviceManager.get(targetToken)
      if (deviceWs) {
        deviceWs.send(JSON.stringify({
          type: 'message',
          from: 'gateway',
          content
        }))
        console.log(`[Relay] Gateway(${gatewayId}) -> Device(${targetToken})`)
      }
    }

    // 处理来自 gateway-bridge 的 HTTP 代理响应
    if (ws.onHttpProxyResponse) {
      try {
        const parsedContent = JSON.parse(content)
        const rid = parsedContent.id
        if (rid && pendingHttpProxies.has(rid)) {
          const { resolve, reject, timeout } = pendingHttpProxies.get(rid)
          clearTimeout(timeout)
          pendingHttpProxies.delete(rid)
          console.log(`[HTTPProxy] Resolving pending request ${rid}:`, JSON.stringify(parsedContent).substring(0, 100))
          if (parsedContent.error) {
            reject(new Error(parsedContent.error.message || JSON.stringify(parsedContent.error)))
          } else {
            resolve(parsedContent.result || parsedContent.payload || {})
          }
        }
      } catch (e) {
        console.log(`[HTTPProxy] Failed to parse response:`, e.message)
      }
    }
  } else if (ws.role === 'device') {
    // Device 发送给 Gateway
    const token = ws.token
    const gatewayId = getGatewayIdByToken(token)

    if (gatewayId) {
      const gatewayWs = gatewayManager.get(gatewayId)
      if (gatewayWs) {
        gatewayWs.send(JSON.stringify({
          type: 'message',
          from: 'device',
          content
        }))
        console.log(`[Relay] Device(${token.substring(0, 8)}...) -> Gateway(${gatewayId})`)
      } else {
        console.log(`[Relay] Device(${token.substring(0, 8)}...) -> Gateway(${gatewayId}) [gateway offline, dropping]`)
      }
    } else {
      console.log(`[Relay] Device token not registered, dropping message`)
    }
  }
}

/**
 * 清理断开的连接
 */
function cleanupConnection(ws) {
  if (ws.role === 'gateway' && ws.gatewayId) {
    gatewayManager.remove(ws.gatewayId)
    console.log(`[Gateway] Removed: ${ws.gatewayId}`)

    // 通知所有相关设备
    const devices = deviceManager.findDevicesByGateway(ws.gatewayId)
    devices.forEach(token => {
      const deviceWs = deviceManager.get(token)
      if (deviceWs) {
        deviceWs.send(JSON.stringify({
          type: 'gateway_disconnected'
        }))
      }
    })
  } else if (ws.role === 'device' && ws.token) {
    const gatewayId = getGatewayIdByToken(ws.token)
    deviceManager.remove(ws.token)
    console.log(`[Device] Removed: ${ws.token}`)

    // 通知 Gateway
    if (gatewayId) {
      const gatewayWs = gatewayManager.get(gatewayId)
      if (gatewayWs) {
        gatewayWs.send(JSON.stringify({
          type: 'device_disconnected',
          token: ws.token
        }))
      }
    }
  }
}

/**
 * 发送错误消息
 */
function sendError(ws, message) {
  ws.send(JSON.stringify({
    type: 'error',
    message
  }))
}

// 心跳 interval - 每 30 秒检测
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      console.log(`[Heartbeat] Terminating inactive connection: ${ws.clientId}`)
      cleanupConnection(ws)
      return ws.terminate()
    }

    ws.isAlive = false
    ws.ping()
  })
}, 30000)

// 60 秒无响应则断开
const connectionTimeout = 60000

// WebSocket 服务器错误处理
wss.on('error', (err) => {
  console.error('[WS] Server error:', err)
})

// 启动服务器
server.listen(PORT, HOST, () => {
  console.log(`
╔════════════════════════════════════════════════════╗
║     OpenClaw Relay Server Started                  ║
╠════════════════════════════════════════════════════╣
║  HTTP:      http://${HOST}:${PORT}                  ║
║  WebSocket: ws://${HOST}:${PORT}                    ║
║  Health:    http://${HOST}:${PORT}/health           ║
║  ENV:       ${NODE_ENV.padEnd(20)}                ║
╚════════════════════════════════════════════════════╝
  `)
})

// 优雅关闭
process.on('SIGTERM', () => {
  console.log('[Server] SIGTERM received, shutting down...')
  clearInterval(heartbeatInterval)

  wss.clients.forEach((ws) => {
    ws.close()
  })

  server.close(() => {
    console.log('[Server] HTTP server closed')
    process.exit(0)
  })
})

process.on('SIGINT', () => {
  console.log('[Server] SIGINT received, shutting down...')
  process.exit(0)
})

module.exports = { app, server, wss }
