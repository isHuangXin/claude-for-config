#!/bin/bash
set -e

echo "=== [1/4] 安装 Node.js ==="
apt-get update
apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

echo "=== [2/4] 安装 Claude Code CLI 和 Copilot API Proxy ==="
npm install -g copilot-api
npm install -g @anthropic-ai/claude-code

echo "=== [3/4] 创建 Claude Code 配置文件 ==="
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'SETTINGS'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4141",
    "ANTHROPIC_AUTH_TOKEN": "dummy",
    "ANTHROPIC_MODEL": "claude-opus-4.6-1m",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-opus-4.6-1m",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
SETTINGS

echo "=== [4/4] 环境搭建完成 ==="
echo ""
echo "接下来请手动执行："
echo "  1. copilot-api start    # 启动 Copilot Proxy（需要浏览器登录）"
echo "  2. claude               # 启动 Claude Code"
