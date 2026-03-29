/**
 * 共享的 token 注册表
 * 
 * 解决 pair.js (HTTP API) 和 relay-server (WebSocket) 之间的
 * token → gatewayId 共享问题
 * 
 * pair.js 在 verify 时写入
 * index.js 在 handleDeviceConnect 时读取
 */

const tokenToGatewayId = new Map()

/**
 * 注册 token → gatewayId 映射
 * @param {string} token - 设备 token（pairing verify 返回的 gatewayToken）
 * @param {string} gatewayId - Gateway ID
 */
function registerToken(token, gatewayId) {
  tokenToGatewayId.set(token, gatewayId)
  console.log(`[TokenRegistry] Registered token ${token.substring(0, 8)}... → ${gatewayId}`)
}

/**
 * 根据 token 查找 gatewayId
 * @param {string} token
 * @returns {string|null}
 */
function getGatewayIdByToken(token) {
  return tokenToGatewayId.get(token) || null
}

/**
 * 清除指定 token
 */
function removeToken(token) {
  tokenToGatewayId.delete(token)
}

module.exports = {
  registerToken,
  getGatewayIdByToken,
  removeToken,
  tokenToGatewayId
}
