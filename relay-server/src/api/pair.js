/**
 * 配对 API 模块
 *
 * 提供配对码的生成和验证功能
 * - POST /api/pair/generate - 生成配对码
 * - POST /api/pair/verify - 验证配对码
 */

const express = require('express')
const router = express.Router()
const fs = require('fs')
const path = require('path')

// gatewayManager 由 index.js 注入（用于自动选择可用 gateway）
let gatewayManager = null
router.setGatewayManager = (gm) => { gatewayManager = gm }
const { generatePairingCode, verifyPairingCode: doVerifyPairingCode } = require('../utils/codeGen')
const { registerToken, getGatewayIdByToken } = require('../shared/tokenRegistry')

// 文件持久化路径（绝对路径，兼容 PM2）
const DATA_DIR = '/Users/zifanni/openclaw/relay-server/data'
const PAIRING_CODES_FILE = path.join(DATA_DIR, 'pairing-codes.json')

// 确保 data 目录存在
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true })
}

// 从磁盘加载配对码
function loadPairingCodes() {
  try {
    if (fs.existsSync(PAIRING_CODES_FILE)) {
      const data = fs.readFileSync(PAIRING_CODES_FILE, 'utf8')
      const arr = JSON.parse(data)
      // 过滤掉已过期的码
      const now = Date.now()
      const validEntries = Object.entries(arr).filter(([code, info]) => new Date(info.expiresAt).getTime() > now)
      for (const [k, v] of validEntries) {
        pairingCodesMap.set(k, v)
      }
      console.log(`[Pair] Loaded ${pairingCodesMap.size} valid pairing codes from disk`)
    }
  } catch (e) {
    console.log('[Pair] Failed to load pairing codes:', e.message)
  }
}

// 保存配对码到磁盘
function savePairingCodes() {
  try {
    const obj = Object.fromEntries(pairingCodesMap)
    fs.writeFileSync(PAIRING_CODES_FILE, JSON.stringify(obj), 'utf8')
    console.log(`[Pair] Saved ${pairingCodesMap.size} pairing codes to disk`)
  } catch (e) {
    console.log('[Pair] Failed to save pairing codes:', e.message)
  }
}

// 配对码存储（内存 + 磁盘持久化）
// 初始为空，每次 loadPairingCodes 只追加不清空
let pairingCodesMap = new Map()

// 启动时加载（追加模式，不清空已有内存数据）
loadPairingCodes()

// 定期清理过期码（每分钟一次）
setInterval(() => {
  const now = Date.now()
  let changed = false
  for (const [code, info] of pairingCodesMap.entries()) {
    if (new Date(info.expiresAt).getTime() < now) {
      pairingCodesMap.delete(code)
      changed = true
    }
  }
  if (changed) {
    savePairingCodes()
    console.log(`[Pair] Cleaned expired codes, ${pairingCodesMap.size} remaining`)
  }
}, 60000)

/**
 * 生成配对码
 * POST /api/pair/generate
 *
 * 请求体：
 * {
 *   gatewayId?: string  // 可选，绑定到特定 Gateway
 * }
 *
 * 响应：
 * {
 *   code: string,        // 6位配对码
 *   expiresAt: string,   // 过期时间 ISO 格式
 *   serverUrl: string,   // WebSocket 服务器地址
 *   token: string        // 用于后续验证的临时 token
 * }
 */
router.post('/generate', (req, res) => {
  const { gatewayId, gatewayUrl } = req.body

  // 生成 6 位配对码
  const code = generatePairingCode()

  // 生成临时 token（用于验证阶段）
  const token = require('uuid').v4()

  // 5 分钟过期
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

  // 自动选择已连接的 gateway（如果没有指定）
  const availableGateways = gatewayManager ? gatewayManager.keys() : []
  const selectedGatewayId = gatewayId || (availableGateways.length > 0 ? availableGateways[0] : null)

  // 存储配对信息
  pairingCodesMap.set(code, {
    gatewayId: selectedGatewayId,
    gatewayUrl: gatewayUrl || null,
    token,
    createdAt: new Date(),
    expiresAt
  })
  savePairingCodes()

  // 注册 token → gatewayId 到共享注册表（用于 WebSocket 连接时查找）
  registerToken(token, selectedGatewayId)

  // 记录日志
  console.log(`[Pair] Generated code ${code} for gateway ${gatewayId || 'unknown'}`)

  // 获取服务器地址
  const serverUrl = process.env.SERVER_URL ||
    `ws://${req.headers.host || 'localhost:3001'}`

  res.json({
    code,
    expiresAt: expiresAt.toISOString(),
    serverUrl,
    token // 返回 token，客户端需要保存
  })
})

/**
 * 验证配对码
 * POST /api/pair/verify
 *
 * 请求体：
 * {
 *   code: string,   // 6位配对码
 *   token?: string  // 可选，验证时提供
 * }
 *
 * 响应：
 * {
 *   success: boolean,
 *   gatewayToken?: string,  // 成功后返回，用于 WebSocket 连接
 *   error?: string
 * }
 */
router.post('/verify', (req, res) => {
  const { code, token } = req.body

  if (!code) {
    return res.status(400).json({
      success: false,
      error: '配对码不能为空'
    })
  }

  // 每次验证前从磁盘刷新（clawred 可能是另一个进程写入的）
  loadPairingCodes()

  // 查找配对码
  const pairingInfo = pairingCodesMap.get(code)

  if (!pairingInfo) {
    console.log(`[Pair] Verify failed: code ${code} not found`)
    return res.json({
      success: false,
      error: '配对码无效'
    })
  }

  // 检查是否过期
  if (new Date() > pairingInfo.expiresAt) {
    pairingCodesMap.delete(code)
    console.log(`[Pair] Verify failed: code ${code} expired`)
    return res.json({
      success: false,
      error: '配对码已过期，请重新生成'
    })
  }

  // 验证 token（如果提供）
  if (token && pairingInfo.token !== token) {
    console.log(`[Pair] Verify failed: token mismatch for code ${code}`)
    return res.json({
      success: false,
      error: 'token 无效'
    })
  }

  // 生成 Gateway Token（用于 WebSocket 连接标识）
  const gatewayToken = require('uuid').v4()

  // 注册 gatewayToken → gatewayId 到共享注册表（用于 WebSocket 连接时查找）
  registerToken(gatewayToken, pairingInfo.gatewayId)

  // 删除已使用的配对码（一次性）
  pairingCodesMap.delete(code)

  console.log(`[Pair] Verify success: code ${code}, gatewayToken ${gatewayToken}`)

  res.json({
    success: true,
    gatewayToken,
    gatewayId: pairingInfo.gatewayId,
    gatewayApiUrl: pairingInfo.gatewayUrl
  })
})

/**
 * 清除过期的配对码（定时清理）
 */
setInterval(() => {
  const now = new Date()
  let cleaned = 0

  for (const [code, info] of pairingCodesMap.entries()) {
    if (now > info.expiresAt) {
      pairingCodesMap.delete(code)
      cleaned++
    }
  }

  if (cleaned > 0) {
    console.log(`[Pair] Cleaned ${cleaned} expired codes`)
  }
}, 60000) // 每分钟清理一次

module.exports = router
module.exports.getGatewayIdByToken = getGatewayIdByToken
