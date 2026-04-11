#!/bin/bash
# OpenClawTrader Session End Script
# 保存会话状态到磁盘

set -euo pipefail

MEMORY_DIR="$HOME/openclaw/OpenClawTrader/.claude/memory"
CACHE_DIR="$MEMORY_DIR/cache"
SESSIONS_DIR="$MEMORY_DIR/sessions"

echo "OpenClawTrader: Saving session state..."

# 确保目录存在
mkdir -p "$CACHE_DIR" "$SESSIONS_DIR"

# 创建每日会话文件
today=$(date '+%Y-%m-%d')
session_file="$SESSIONS_DIR/${today}-session.md"

# 检查是否已存在今日会话
if [ -f "$session_file" ]; then
  # 追加更新而不是覆盖
  last_update=$(date '+%Y-%m-%d %H:%M:%S')
  echo "" >> "$session_file"
  echo "## Update at $last_update" >> "$session_file"
else
  # 创建新会话文件
  cat > "$session_file" << EOF
# Session: $today

**Started:** $(date '+%Y-%m-%d %H:%M')
**Last Update:** $(date '+%Y-%m-%d %H:%M')

---

## Current State

### In Progress
-

### Completed
-

### Pending
-

### Notes
-

EOF
fi

echo "OpenClawTrader: Session saved to $session_file"

# 清理旧会话（保留30天）
find "$SESSIONS_DIR" -name "*-session.md" -type f -mtime +30 -delete 2>/dev/null || true

# 保存当前工作状态快照
if [ -d "$HOME/openclaw/OpenClawTrader/iOS" ]; then
  echo "OpenClawTrader: Checking for uncommitted changes..."

  cd "$HOME/openclaw/OpenClawTrader"
  if git status --porcelain 2>/dev/null | grep -q .; then
    echo "  ⚠️  There are uncommitted changes - consider committing"
    git status --short >> "$session_file" 2>/dev/null || true
  fi
fi

echo "OpenClawTrader: Session end complete"
