
#!/bin/bash
# 一键启动 databricks proxy + cloudflared 隧道
# 用法: ~/start_proxy.sh
set -e
DIR="$HOME"
JS="$DIR/code_list/databricks_5433.js"
KEY_FILE="$DIR/.proxy_key"
LOG="$DIR/proxy.log"
TUNNEL_LOG="$DIR/tunnel.log"
PROXY_PID="$DIR/.proxy.pid"
TUNNEL_PID="$DIR/.tunnel.pid"
CF="$HOME/.local/bin/cloudflared"

# --- 生成或读取密钥（持久，重启不变）---
if [ ! -f "$KEY_FILE" ]; then
    openssl rand -hex 16 | sed 's/^/sk-proxy-/' > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi
KEY=$(cat "$KEY_FILE")

# --- 停旧进程（用 PID 文件，不用 pgrep：pgrep -f 会匹配到调用它的 shell 自身）---
for PF in "$PROXY_PID" "$TUNNEL_PID"; do
    if [ -f "$PF" ]; then
        P=$(cat "$PF")
        if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
            kill "$P" 2>/dev/null || true
        fi
        rm -f "$PF"
    fi
done
# 兜底：按监听端口找残留的 node
if ss -tlnp 2>/dev/null | grep -q ':8082'; then
    STALE=$(ss -tlnp 2>/dev/null | grep ':8082' | grep -oP 'pid=\K[0-9]+' | head -1)
    [ -n "$STALE" ] && kill "$STALE" 2>/dev/null || true
fi
sleep 2

# --- 启动代理 ---
: > "$LOG"
PROXY_API_KEY="$KEY" setsid nohup node "$JS" > "$LOG" 2>&1 < /dev/null &
echo $! > "$PROXY_PID"
sleep 2
if ! ss -tln 2>/dev/null | grep -q ':8082'; then
    echo "❌ 代理启动失败"; cat "$LOG"; exit 1
fi

# --- 启动隧道（没装 cloudflared 就只跑本机代理）---
if [ ! -x "$CF" ]; then
    sed -n '1,5p' "$LOG"
    echo ""
    echo "⚠️  未找到 $CF，跳过隧道；本机可用 http://127.0.0.1:8082"
    exit 0
fi
: > "$TUNNEL_LOG"
setsid nohup "$CF" tunnel --url http://localhost:8082 --no-autoupdate \
    > "$TUNNEL_LOG" 2>&1 < /dev/null &
echo $! > "$TUNNEL_PID"

URL=""
for i in $(seq 1 45); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    [ -n "$URL" ] && break
    sleep 1
done

if [ -z "$URL" ]; then
    echo "❌ 隧道启动失败"; tail -10 "$TUNNEL_LOG"; exit 1
fi

# --- 存盘，方便随时查 ---
echo "$URL" > "$HOME/.proxy_url"

# --- 输出 ---
sed -n '1,5p' "$LOG"
echo ""
echo "隧道: $URL"
echo ""
echo "========== 客户端 ~/.claude/settings.json =========="
cat <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$URL",
    "ANTHROPIC_AUTH_TOKEN": "$KEY",
    "ANTHROPIC_MODEL": "claude-opus-5",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-haiku-4-5",
    "API_TIMEOUT_MS": "3000000",
    "MAX_THINKING_TOKENS": "31999",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
    "MAX_MCP_OUTPUT_TOKENS": "64000"
  },
  "effortLevel": "xhigh"
}
EOF
echo "===================================================="
echo "本机: 把 ANTHROPIC_BASE_URL 换成 http://127.0.0.1:8082"
