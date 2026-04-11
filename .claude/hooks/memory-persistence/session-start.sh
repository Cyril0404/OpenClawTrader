#!/bin/bash
# OpenClawTrader Session Start Script
# 参照 everything-claude-code 的 memory-persistence 设计

set -euo pipefail

MEMORY_DIR="$HOME/openclaw/OpenClawTrader/.claude/memory"
CACHE_DIR="$MEMORY_DIR/cache"
SESSIONS_DIR="$MEMORY_DIR/sessions"

echo "OpenClawTrader: Initializing session..."

# 确保目录存在
mkdir -p "$CACHE_DIR" "$SESSIONS_DIR"

# 检查最近7天的会话文件
recent_sessions=()
for i in {0..6}; do
  date_str=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
  if [ -n "$date_str" ]; then
    session_file="$SESSIONS_DIR/${date_str}-session.md"
    if [ -f "$session_file" ]; then
      recent_sessions+=("$session_file")
    fi
  fi
done

if [ ${#recent_sessions[@]} -gt 0 ]; then
  echo "OpenClawTrader: Found ${#recent_sessions[@]} recent session(s)"
  latest_session="${recent_sessions[0]}"
  echo "  Latest: $latest_session (modified $(date -r "$latest_session" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -f "%Sm" "$latest_session" 2>/dev/null || echo "unknown"))"
else
  echo "OpenClawTrader: No previous session found"
fi

# 检查股票数据缓存
if [ -f "$CACHE_DIR/stock-data.json" ]; then
  cache_age=$(($(date +%s) - $(stat -f "%m" "$CACHE_DIR/stock-data.json" 2>/dev/null || stat -c "%Y" "$CACHE_DIR/stock-data.json" 2>/dev/null || echo "0")))
  cache_age_minutes=$((cache_age / 60))

  if [ $cache_age_minutes -lt 5 ]; then
    echo "OpenClawTrader: Stock data cache is fresh (${cache_age_minutes}m old)"
  else
    echo "OpenClawTrader: Stock data cache is stale (${cache_age_minutes}m old) - consider refreshing"
  fi
else
  echo "OpenClawTrader: No stock data cache found"
fi

# 检查learned patterns
learned_dir="$MEMORY_DIR/learned"
if [ -d "$learned_dir" ] && [ -n "$(ls -A "$learned_dir" 2>/dev/null)" ]; then
  pattern_count=$(find "$learned_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "OpenClawTrader: Found $pattern_count learned pattern(s)"
fi

echo "OpenClawTrader: Session initialized"
