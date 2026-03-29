/**
 * 配对码生成器
 *
 * 生成 6 位字母数字组合的配对码
 * 格式：大写字母 + 数字，去除易混淆字符（0, O, I, L, 1）
 */

const CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
const CODE_LENGTH = 6

/**
 * 生成随机配对码
 * @returns {string} 6位配对码
 */
function generatePairingCode() {
  let code = ''

  for (let i = 0; i < CODE_LENGTH; i++) {
    const randomIndex = Math.floor(Math.random() * CODE_CHARS.length)
    code += CODE_CHARS[randomIndex]
  }

  return code
}

/**
 * 验证配对码格式
 * @param {string} code - 待验证的配对码
 * @returns {boolean} 是否有效
 */
function isValidCode(code) {
  if (!code || typeof code !== 'string') {
    return false
  }

  if (code.length !== CODE_LENGTH) {
    return false
  }

  // 检查是否只包含允许的字符
  const validPattern = new RegExp(`^[${CODE_CHARS}]+$`)
  return validPattern.test(code)
}

/**
 * 从字符串中提取配对码
 * 比如从 "openclaw://relay?code=NVJ53Z" 中提取 "NVJ53Z"
 * @param {string} input - 输入字符串
 * @returns {string|null} 配对码或 null
 */
function extractCode(input) {
  if (!input || typeof input !== 'string') {
    return null
  }

  // URL 格式: openclaw://relay?code=NVJ53Z&server=...
  if (input.includes('://')) {
    try {
      const url = new URL(input)
      const code = url.searchParams.get('code')
      if (code && isValidCode(code)) {
        return code
      }
    } catch (e) {
      // URL 解析失败，尝试直接匹配
    }
  }

  // 直接是配对码
  if (isValidCode(input)) {
    return input
  }

  return null
}

/**
 * 生成随机 Gateway ID
 * @returns {string} UUID 格式的 Gateway ID
 */
function generateGatewayId() {
  const { v4: uuidv4 } = require('uuid')
  return uuidv4()
}

/**
 * 生成随机 Token
 * @returns {string} UUID 格式的 Token
 */
function generateToken() {
  const { v4: uuidv4 } = require('uuid')
  return uuidv4()
}

module.exports = {
  generatePairingCode,
  isValidCode,
  extractCode,
  generateGatewayId,
  generateToken,
  CODE_LENGTH,
  CODE_CHARS
}
