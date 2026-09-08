#!/bin/bash
set -e

echo "=== [1/4] 检查 Node.js ==="

if ! command -v node >/dev/null 2>&1; then
    echo "Node.js 未安装"
    exit 1
fi

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

echo ""
echo "=== [2/4] 安装 Codex CLI ==="

npm install -g @openai/codex

echo ""
echo "=== [3/4] 安装支持 Codex 的 Copilot API ==="

npm uninstall -g copilot-api || true

npm install -g @jeffreycao/copilot-api@latest --force

echo ""
echo "=== [4/4] 创建 Codex 配置 ==="

mkdir -p ~/.codex

cat > ~/.codex/config.toml <<'EOF'
model = "gpt-6-astra"
model_provider = "copilot"
model_reasoning_effort = "max"
service_tier = "ultrafast"

[model_providers.copilot]
name = "Copilot API"
base_url = "http://127.0.0.1:4141"
env_key = "COPILOT_API_KEY"
wire_api = "responses"

[projects."/root"]
trust_level = "trusted"
EOF

echo ""
echo 'export COPILOT_API_KEY=dummy' >> ~/.bashrc

echo ""
echo "========================================"
echo "Codex + Copilot API 安装完成"
echo "========================================"
echo ""
echo "下一步执行："
echo ""
echo "1. 启动 Copilot API"
echo "   copilot-api start --codex"
echo ""
echo "2. 新开终端"
echo "   source ~/.bashrc"
echo ""
echo "3. 验证服务"
echo "   curl http://127.0.0.1:4141/models"
echo ""
echo "4. 启动 Codex"
echo "   codex"
echo ""
