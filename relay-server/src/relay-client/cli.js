#!/usr/bin/env node

/**
 * OpenClaw Relay Client CLI
 *
 * 桌面端 Gateway 中继客户端命令行工具
 *
 * 使用方式：
 *   node cli.js pair              # 生成配对码并显示二维码
 *   node cli.js connect            # 连接云端中继服务
 *   node cli.js status             # 查看连接状态
 */

const { RelayClient, PairingCLI } = require('./index')

const args = process.argv.slice(2)
const command = args[0]

async function main() {
  switch (command) {
    case 'pair':
      await runPair()
      break

    case 'connect':
      await runConnect()
      break

    case 'status':
      runStatus()
      break

    default:
      showHelp()
  }
}

async function runPair() {
  console.log('\n🔗 OpenClaw 配对工具\n')

  const cli = new PairingCLI()

  try {
    const info = await cli.generatePairingCode({
      gatewayId: args[1] || undefined
    })

    // 保持运行，直到用户按 Ctrl+C
    process.on('SIGINT', () => {
      console.log('\n\n👋 取消配对')
      cli.cleanup()
      process.exit(0)
    })

  } catch (err) {
    console.error('\n❌ 配对失败:', err.message)
    cli.cleanup()
    process.exit(1)
  }
}

async function runConnect() {
  console.log('\n🔗 OpenClaw 中继连接工具\n')

  const client = new RelayClient({
    gatewayId: args[1] || undefined,
    onAiResponse: (response) => {
      console.log('\n🤖 AI 回复:', response)
    }
  })

  client.on('registered', () => {
    console.log('✅ 已注册到云端中继服务')
  })

  client.on('device_connected', (info) => {
    console.log('\n📱 设备连接:', info.token)
  })

  client.on('device_disconnected', (info) => {
    console.log('\n📱 设备断开:', info.token)
  })

  client.on('disconnected', () => {
    console.log('\n⚠️ 与云端断开连接')
  })

  client.on('reconnect_failed', () => {
    console.error('\n❌ 重连失败，请检查网络连接')
    process.exit(1)
  })

  try {
    await client.connect()
    console.log('✅ 成功连接到云端中继服务')
    console.log(`   Gateway ID: ${client.gatewayId}`)
    console.log('\n按 Ctrl+C 断开连接\n')

    // 保持运行
    process.on('SIGINT', () => {
      console.log('\n\n👋 断开连接')
      client.disconnect()
      process.exit(0)
    })

  } catch (err) {
    console.error('\n❌ 连接失败:', err.message)
    process.exit(1)
  }
}

function runStatus() {
  console.log('\n📊 连接状态\n')
  console.log('   功能开发中...')
  console.log('   (需要先运行 connect 命令建立连接)\n')
}

function showHelp() {
  console.log(`
🔗 OpenClaw Relay Client CLI

用法:
  openclaw-relay <command> [options]

命令:
  pair [gatewayId]     生成配对码并显示二维码
  connect [gatewayId] 连接到云端中继服务
  status               查看连接状态

示例:
  openclaw-relay pair
  openclaw-relay connect my-gateway-001

环境变量:
  RELAY_API    云端 API 地址（默认 http://150.158.119.114:3001/api）
  RELAY_WS     云端 WebSocket 地址（默认 ws://150.158.119.114:3001）
`)
  process.exit(0)
}

main().catch((err) => {
  console.error('Error:', err.message)
  process.exit(1)
})
