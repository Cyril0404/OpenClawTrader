/**
 * OpenClaw Relay Client
 *
 * 桌面端 Gateway 的中继客户端模块
 * - 连接云端 WebSocket 中继服务
 * - 提供 CLI 命令行配对功能
 * - 消息转发到本地 AI
 *
 * 使用方式：
 * const { RelayClient } = require('./relay-client')
 * const client = new RelayClient({ gatewayId: 'xxx' })
 * client.connect()
 */

const WebSocket = require('ws')
const http = require('http')
const EventEmitter = require('events')

// 云端中继服务地址
const RELAY_API = 'http://150.158.119.114:3001/api'
const RELAY_WS = 'ws://150.158.119.114:3001'

/**
 * 中继客户端类
 */
class RelayClient extends EventEmitter {
  /**
   * @param {Object} options
   * @param {string} options.gatewayId - 本地 Gateway 唯一 ID
   * @param {string} options.gatewayApiUrl - 本地 Gateway API 地址（默认 http://localhost:18789）
   * @param {Function} options.onAiResponse - AI 响应回调
   */
  constructor(options = {}) {
    super()

    this.gatewayId = options.gatewayId || this.generateGatewayId()
    this.gatewayApiUrl = options.gatewayApiUrl || 'http://localhost:18789'
    this.onAiResponse = options.onAiResponse || (() => {})

    this.ws = null
    this.isConnected = false
    this.reconnectAttempts = 0
    this.maxReconnectAttempts = 10
    this.reconnectDelay = 1000 // 初始重连延迟（毫秒）
    this.pingInterval = null
    this.pairingInfo = null
  }

  /**
   * 生成 Gateway ID（基于 MAC 地址或随机 UUID）
   */
  generateGatewayId() {
    const { networkInterfaces } = require('os')
    const nets = networkInterfaces()

    // 尝试获取 MAC 地址
    for (const name of Object.keys(nets)) {
      for (const net of nets[name]) {
        if (net.mac && net.mac !== '00:00:00:00:00:00') {
          return `gateway-${net.mac.replace(/:/g, '')}`
        }
      }
    }

    // 降级为随机 UUID
    const { v4: uuidv4 } = require('uuid')
    return `gateway-${uuidv4()}`
  }

  /**
   * 连接到云端 WebSocket 中继
   */
  connect() {
    return new Promise((resolve, reject) => {
      console.log(`[RelayClient] Connecting to ${RELAY_WS}...`)

      this.ws = new WebSocket(RELAY_WS)

      // 连接超时
      const timeout = setTimeout(() => {
        reject(new Error('Connection timeout'))
      }, 10000)

      this.ws.on('open', () => {
        clearTimeout(timeout)
        console.log(`[RelayClient] Connected`)
        this.isConnected = true
        this.reconnectAttempts = 0
        this.reconnectDelay = 1000

        // 注册 Gateway
        this.register()

        // 启动心跳
        this.startHeartbeat()

        resolve()
      })

      this.ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString())
          this.handleMessage(message)
        } catch (err) {
          console.error('[RelayClient] Failed to parse message:', err)
        }
      })

      this.ws.on('close', () => {
        console.log('[RelayClient] Connection closed')
        this.isConnected = false
        this.stopHeartbeat()
        this.scheduleReconnect()
        this.emit('disconnected')
      })

      this.ws.on('error', (err) => {
        console.error('[RelayClient] WebSocket error:', err.message)
        clearTimeout(timeout)
        reject(err)
      })
    })
  }

  /**
   * 注册 Gateway 到中继服务
   */
  register() {
    this.send({
      type: 'gateway',
      gatewayId: this.gatewayId
    })
    console.log(`[RelayClient] Registered as ${this.gatewayId}`)
  }

  /**
   * 处理收到的消息
   */
  handleMessage(message) {
    const { type, content, from } = message

    switch (type) {
      case 'registered':
        console.log('[RelayClient] Registration confirmed')
        this.emit('registered', message)
        break

      case 'device_connected':
        console.log('[RelayClient] Device connected:', message.token)
        this.emit('device_connected', message)
        break

      case 'device_disconnected':
        console.log('[RelayClient] Device disconnected:', message.token)
        this.emit('device_disconnected', message)
        break

      case 'message':
        // 收到移动端消息，转发给本地 AI
        console.log('[RelayClient] Received message from device')
        this.forwardToAI(content, from)
        break

      case 'pong':
        // 心跳响应
        break

      case 'error':
        console.error('[RelayClient] Server error:', message.message)
        this.emit('error', message)
        break

      default:
        console.warn('[RelayClient] Unknown message type:', type)
    }
  }

  /**
   * 转发消息给本地 AI
   * @param {string} content - 消息内容
   * @param {string} from - 消息来源（device token）
   */
  async forwardToAI(content, from) {
    try {
      console.log('[RelayClient] Forwarding to local AI...')

      // 调用本地 Gateway API
      const response = await this.callLocalAI(content)

      // 通过 WebSocket 发送回复
      this.send({
        type: 'message',
        content: response,
        from: 'gateway'
      })

      // 回调
      this.onAiResponse(response)

    } catch (err) {
      console.error('[RelayClient] AI forward error:', err)

      // 发送错误回复
      this.send({
        type: 'message',
        content: `错误：${err.message}`,
        from: 'gateway'
      })
    }
  }

  /**
   * 调用本地 AI API
   * @param {string} userMessage - 用户消息
   * @returns {Promise<string>} AI 回复
   */
  callLocalAI(userMessage) {
    return new Promise((resolve, reject) => {
      const data = JSON.stringify({
        message: userMessage,
        stream: false
      })

      const url = new URL('/api/chat', this.gatewayApiUrl)

      const options = {
        hostname: url.hostname,
        port: url.port || 80,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data)
        },
        timeout: 30000
      }

      const req = http.request(options, (res) => {
        let body = ''

        res.on('data', (chunk) => {
          body += chunk
        })

        res.on('end', () => {
          if (res.statusCode === 200) {
            try {
              const json = JSON.parse(body)
              resolve(json.content || json.response || JSON.stringify(json))
            } catch {
              resolve(body)
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`))
          }
        })
      })

      req.on('error', (err) => {
        reject(new Error(`Failed to connect to local AI: ${err.message}`))
      })

      req.on('timeout', () => {
        req.destroy()
        reject(new Error('AI request timeout'))
      })

      req.write(data)
      req.end()
    })
  }

  /**
   * 发送消息到云端
   */
  send(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message))
    }
  }

  /**
   * 启动心跳
   */
  startHeartbeat() {
    this.stopHeartbeat()
    this.pingInterval = setInterval(() => {
      if (this.isConnected) {
        this.send({ type: 'ping' })
      }
    }, 30000) // 每 30 秒
  }

  /**
   * 停止心跳
   */
  stopHeartbeat() {
    if (this.pingInterval) {
      clearInterval(this.pingInterval)
      this.pingInterval = null
    }
  }

  /**
   * 调度重连（指数退避）
   */
  scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[RelayClient] Max reconnection attempts reached')
      this.emit('reconnect_failed')
      return
    }

    this.reconnectAttempts++
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), 60000)

    console.log(`[RelayClient] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})...`)

    setTimeout(() => {
      this.connect().catch((err) => {
        console.error('[RelayClient] Reconnection failed:', err.message)
      })
    }, delay)
  }

  /**
   * 断开连接
   */
  disconnect() {
    this.stopHeartbeat()
    this.maxReconnectAttempts = 0 // 防止自动重连

    if (this.ws) {
      this.ws.close()
      this.ws = null
    }

    this.isConnected = false
    console.log('[RelayClient] Disconnected')
  }

  /**
   * 获取连接状态
   */
  getStatus() {
    return {
      connected: this.isConnected,
      gatewayId: this.gatewayId,
      reconnectAttempts: this.reconnectAttempts
    }
  }
}

/**
 * 生成配对码 CLI 模块
 */
class PairingCLI {
  constructor() {
    this.client = null
    this.countdownInterval = null
    this.pairingInfo = null
  }

  /**
   * 生成配对码
   * @param {Object} options
   * @param {string} options.gatewayId - Gateway ID
   * @returns {Promise<Object>} 配对信息
   */
  async generatePairingCode(options = {}) {
    const gatewayId = options.gatewayId || new RelayClient().generateGatewayId()

    console.log(`[PairingCLI] Generating pairing code for gateway: ${gatewayId}...`)

    try {
      // 调用云端 API 生成配对码
      const response = await this.httpRequest(`${RELAY_API}/pair/generate`, {
        method: 'POST',
        body: { gatewayId }
      })

      this.pairingInfo = {
        code: response.code,
        token: response.token,
        expiresAt: new Date(response.expiresAt),
        serverUrl: response.serverUrl,
        gatewayId
      }

      console.log('\n========================================')
      console.log('         配对码已生成')
      console.log('========================================')
      console.log(`  配对码: ${this.pairingInfo.code}`)
      console.log(`  服务器: ${this.pairingInfo.serverUrl}`)
      console.log(`  二维码: openclaw://pair?code=${this.pairingInfo.code}&server=${encodeURIComponent(this.pairingInfo.serverUrl)}`)
      console.log('========================================\n')

      // 显示二维码
      this.displayQRCode(this.pairingInfo.code, this.pairingInfo.serverUrl)

      // 启动倒计时
      this.startCountdown()

      return this.pairingInfo

    } catch (err) {
      console.error('[PairingCLI] Failed to generate pairing code:', err.message)
      throw err
    }
  }

  /**
   * 显示二维码（ASCII 格式）
   */
  displayQRCode(code, server) {
    const qrData = `openclaw://pair?code=${code}&server=${encodeURIComponent(server)}`

    // 使用 qrcode-terminal 生成 ASCII 二维码
    try {
      const qrcode = require('qrcode-terminal')
      qrcode.generate(qrData, { small: true })
    } catch {
      // 如果没有 qrcode-terminal，显示文字链接
      console.log('  (安装 qrcode-terminal 可显示二维码: npm install -g qrcode-terminal)')
      console.log(`  链接: ${qrData}\n`)
    }

    console.log('  请使用 OpenClawTrader App 扫码绑定')
    console.log(`  配对码有效期: 5 分钟\n`)
  }

  /**
   * 启动倒计时
   */
  startCountdown() {
    this.stopCountdown()

    const updateCountdown = () => {
      const now = new Date()
      const remaining = Math.max(0, this.pairingInfo.expiresAt - now)
      const minutes = Math.floor(remaining / 60000)
      const seconds = Math.floor((remaining % 60000) / 1000)

      process.stdout.write(`\r  剩余时间: ${minutes}:${seconds.toString().padStart(2, '0')}  `)

      if (remaining <= 0) {
        console.log('\n[PairingCLI] Pairing code expired')
        this.stopCountdown()
      }
    }

    updateCountdown()
    this.countdownInterval = setInterval(updateCountdown, 1000)
  }

  /**
   * 停止倒计时
   */
  stopCountdown() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
      this.countdownInterval = null
    }
  }

  /**
   * HTTP 请求
   */
  httpRequest(url, options = {}) {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url)

      const reqOptions = {
        hostname: urlObj.hostname,
        port: urlObj.port || 80,
        path: urlObj.pathname,
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      }

      const req = http.request(reqOptions, (res) => {
        let body = ''

        res.on('data', (chunk) => {
          body += chunk
        })

        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(body))
            } catch {
              resolve(body)
            }
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`))
          }
        })
      })

      req.on('error', reject)

      if (options.body) {
        const bodyStr = JSON.stringify(options.body)
        req.write(bodyStr)
      }

      req.end()
    })
  }

  /**
   * 清理
   */
  cleanup() {
    this.stopCountdown()
  }
}

// 导出模块
module.exports = { RelayClient, PairingCLI }
