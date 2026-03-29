module.exports = {
  apps: [
    {
      name: 'openclaw-relay',
      script: 'src/index.js',
      instances: 1,
      exec_mode: 'cluster',
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      env_development: {
        NODE_ENV: 'development',
        PORT: 3001
      },
      // 日志配置
      log_file: './logs/combined.log',
      out_file: './logs/out.log',
      error_file: './logs/error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      // 重启策略
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      // 监控
      monitor: true,
      // 优雅关闭
      kill_timeout: 5000,
      listen_timeout: 3000
    }
  ]
}
