/**
 * Device 连接管理器
 *
 * 负责管理移动端 App 的 WebSocket 连接
 * - 维护 token -> WebSocket 的映射
 * - 维护 token -> gatewayId 的映射
 * - 提供连接的添加、移除、查询操作
 */

class DeviceManager {
  constructor() {
    // token -> WebSocket 连接
    this.devices = new Map()
    // token -> gatewayId 映射
    this.tokenToGateway = new Map()
    // gatewayId -> token[] 反向索引
    this.gatewayToTokens = new Map()
  }

  /**
   * 添加 Device 连接
   * @param {string} token - 设备标识 token
   * @param {WebSocket} ws - WebSocket 连接
   * @param {string} gatewayId - 关联的 Gateway ID
   */
  add(token, ws, gatewayId) {
    // 如果已存在，先移除旧连接
    if (this.devices.has(token)) {
      const oldWs = this.devices.get(token)
      if (oldWs !== ws) {
        oldWs.close()
      }
      // 清理旧的 gateway 关联
      const oldGatewayId = this.tokenToGateway.get(token)
      if (oldGatewayId && this.gatewayToTokens.has(oldGatewayId)) {
        const tokens = this.gatewayToTokens.get(oldGatewayId)
        const index = tokens.indexOf(token)
        if (index > -1) {
          tokens.splice(index, 1)
        }
      }
    }

    this.devices.set(token, ws)
    this.tokenToGateway.set(token, gatewayId)

    // 更新反向索引
    if (!this.gatewayToTokens.has(gatewayId)) {
      this.gatewayToTokens.set(gatewayId, [])
    }
    this.gatewayToTokens.get(gatewayId).push(token)

    // 添加清理回调
    ws.on('close', () => {
      this.remove(token)
    })

    console.log(`[DeviceManager] Added device: ${token} -> ${gatewayId}, total: ${this.size()}`)
  }

  /**
   * 移除 Device 连接
   * @param {string} token - 设备标识 token
   */
  remove(token) {
    const gatewayId = this.tokenToGateway.get(token)

    // 从反向索引中移除
    if (gatewayId && this.gatewayToTokens.has(gatewayId)) {
      const tokens = this.gatewayToTokens.get(gatewayId)
      const index = tokens.indexOf(token)
      if (index > -1) {
        tokens.splice(index, 1)
      }
      if (tokens.length === 0) {
        this.gatewayToTokens.delete(gatewayId)
      }
    }

    this.tokenToGateway.delete(token)

    const deleted = this.devices.delete(token)
    if (deleted) {
      console.log(`[DeviceManager] Removed device: ${token}, total: ${this.size()}`)
    }
    return deleted
  }

  /**
   * 获取 Device 连接
   * @param {string} token - 设备标识 token
   * @returns {WebSocket|null}
   */
  get(token) {
    return this.devices.get(token) || null
  }

  /**
   * 获取 Device 对应的 Gateway ID
   * @param {string} token - 设备标识 token
   * @returns {string|null}
   */
  getGatewayIdByToken(token) {
    return this.tokenToGateway.get(token) || null
  }

  /**
   * 检查 Device 是否在线
   * @param {string} token - 设备标识 token
   * @returns {boolean}
   */
  has(token) {
    return this.devices.has(token)
  }

  /**
   * 获取所有在线 Device token
   * @returns {string[]}
   */
  keys() {
    return Array.from(this.devices.keys())
  }

  /**
   * 获取 Device 数量
   * @returns {number}
   */
  size() {
    return this.devices.size
  }

  /**
   * 根据 Gateway ID 查找所有关联的 Device
   * @param {string} gatewayId - Gateway ID
   * @returns {string[]} token 数组
   */
  findDevicesByGateway(gatewayId) {
    return this.gatewayToTokens.get(gatewayId) || []
  }

  /**
   * 根据 Gateway ID 查找第一个 Device
   * @param {string} gatewayId - Gateway ID
   * @returns {string|null} token
   */
  findDeviceByGateway(gatewayId) {
    const tokens = this.gatewayToTokens.get(gatewayId)
    return tokens && tokens.length > 0 ? tokens[0] : null
  }

  /**
   * 获取所有连接信息（调试用）
   * @returns {Object[]}
   */
  getAll() {
    const result = []
    for (const [token, ws] of this.devices.entries()) {
      result.push({
        token,
        gatewayId: this.tokenToGateway.get(token),
        readyState: ws.readyState,
        isAlive: ws.isAlive
      })
    }
    return result
  }

  /**
   * 广播消息给所有 Device
   * @param {Object} message - 要发送的消息
   */
  broadcast(message) {
    const data = JSON.stringify(message)
    for (const ws of this.devices.values()) {
      if (ws.readyState === 1) { // OPEN
        ws.send(data)
      }
    }
  }

  /**
   * 移除所有连接
   */
  clear() {
    for (const ws of this.devices.values()) {
      ws.close()
    }
    this.devices.clear()
    this.tokenToGateway.clear()
    this.gatewayToTokens.clear()
    console.log('[DeviceManager] Cleared all devices')
  }
}

module.exports = { DeviceManager }
