/**
 * Gateway 连接管理器
 *
 * 负责管理桌面端 Gateway 的 WebSocket 连接
 * - 维护 gatewayId -> WebSocket 的映射
 * - 提供连接的添加、移除、查询操作
 */

class GatewayManager {
  constructor() {
    // gatewayId -> WebSocket 连接
    this.gateways = new Map()
  }

  /**
   * 添加 Gateway 连接
   * @param {string} gatewayId - Gateway 唯一标识
   * @param {WebSocket} ws - WebSocket 连接
   */
  add(gatewayId, ws) {
    // 如果已存在，先移除旧的连接
    if (this.gateways.has(gatewayId)) {
      const oldWs = this.gateways.get(gatewayId)
      if (oldWs !== ws) {
        oldWs.close()
      }
    }

    this.gateways.set(gatewayId, ws)

    // 添加清理回调
    ws.on('close', () => {
      this.remove(gatewayId)
    })

    console.log(`[GatewayManager] Added gateway: ${gatewayId}, total: ${this.size()}`)
  }

  /**
   * 移除 Gateway 连接
   * @param {string} gatewayId - Gateway 唯一标识
   */
  remove(gatewayId) {
    const deleted = this.gateways.delete(gatewayId)
    if (deleted) {
      console.log(`[GatewayManager] Removed gateway: ${gatewayId}, total: ${this.size()}`)
    }
    return deleted
  }

  /**
   * 获取 Gateway 连接
   * @param {string} gatewayId - Gateway 唯一标识
   * @returns {WebSocket|null}
   */
  get(gatewayId) {
    return this.gateways.get(gatewayId) || null
  }

  /**
   * 检查 Gateway 是否在线
   * @param {string} gatewayId - Gateway 唯一标识
   * @returns {boolean}
   */
  has(gatewayId) {
    return this.gateways.has(gatewayId)
  }

  /**
   * 获取所有在线 Gateway ID
   * @returns {string[]}
   */
  keys() {
    return Array.from(this.gateways.keys())
  }

  /**
   * 获取 Gateway 数量
   * @returns {number}
   */
  size() {
    return this.gateways.size
  }

  /**
   * 获取所有连接信息（调试用）
   * @returns {Object[]}
   */
  getAll() {
    const result = []
    for (const [gatewayId, ws] of this.gateways.entries()) {
      result.push({
        gatewayId,
        readyState: ws.readyState,
        isAlive: ws.isAlive
      })
    }
    return result
  }

  /**
   * 广播消息给所有 Gateway
   * @param {Object} message - 要发送的消息
   */
  broadcast(message) {
    const data = JSON.stringify(message)
    for (const ws of this.gateways.values()) {
      if (ws.readyState === 1) { // OPEN
        ws.send(data)
      }
    }
  }

  /**
   * 移除所有连接
   */
  clear() {
    for (const ws of this.gateways.values()) {
      ws.close()
    }
    this.gateways.clear()
    console.log('[GatewayManager] Cleared all gateways')
  }
}

module.exports = { GatewayManager }
