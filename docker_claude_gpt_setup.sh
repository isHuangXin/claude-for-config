#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "请在 Debian/Ubuntu Docker 容器中以 root 身份运行此脚本。" >&2
    exit 1
fi

echo "=== [1/4] 安装 Node.js ==="
apt-get update
apt-get install -y curl ca-certificates
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

echo ""
echo "=== [2/4] 安装 Claude Code CLI 和 Copilot API Proxy ==="
npm uninstall -g copilot-api || true
npm install -g @jeffreycao/copilot-api@latest --force
npm install -g @anthropic-ai/claude-code

echo ""
echo "=== [3/4] 创建 Claude GPT 配置文件 ==="
mkdir -p "$HOME/.claude"
node <<'SETTINGS'
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const settingsPath = path.join(os.homedir(), ".claude", "settings.json");
const exists = fs.existsSync(settingsPath);
const settings = exists ? JSON.parse(fs.readFileSync(settingsPath, "utf8")) : {};

if (!settings || typeof settings !== "object" || Array.isArray(settings)) {
    throw new Error("现有 settings.json 必须是 JSON 对象，已停止写入。");
}
if (settings.env !== undefined &&
    (!settings.env || typeof settings.env !== "object" || Array.isArray(settings.env))) {
    throw new Error("现有 settings.json 的 env 必须是 JSON 对象，已停止写入。");
}

const model = "gpt-6-astra";
settings.model = model;
settings.env = {
    ...settings.env,
    ANTHROPIC_BASE_URL: "http://127.0.0.1:4141",
    ANTHROPIC_AUTH_TOKEN: "dummy",
    ANTHROPIC_MODEL: model,
    ANTHROPIC_SMALL_FAST_MODEL: model,
    ANTHROPIC_DEFAULT_OPUS_MODEL: model,
    ANTHROPIC_DEFAULT_SONNET_MODEL: model,
    ANTHROPIC_DEFAULT_HAIKU_MODEL: model,
    DISABLE_NON_ESSENTIAL_MODEL_CALLS: "1",
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1"
};

if (exists) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const backupPath = `${settingsPath}.bak.${timestamp}`;
    fs.copyFileSync(settingsPath, backupPath, fs.constants.COPYFILE_EXCL);
    console.log(`原配置已备份至：${backupPath}`);
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n", { mode: 0o600 });
console.log(`Claude GPT 配置已写入：${settingsPath}`);
console.log(`默认模型：${model}`);
SETTINGS

# echo ""
# echo 'export COPILOT_API_KEY=dummy' >> ~/.bashrc

echo ""
echo "=== [4/4] Claude GPT 环境搭建完成 ==="
echo ""
echo "接下来请手动执行："
echo ""
echo "1. 首次使用 Codex 后端时，完成登录"
echo "   copilot-api auth login --provider codex"
echo ""
echo "2. 启动 Copilot API，并保持该终端运行"
echo "   copilot-api start"
echo ""
echo "3. 新开终端，确认模型列表中包含 gpt-6-astra"
echo "   curl http://127.0.0.1:4141/models"
echo ""
echo "4. 启动 Claude Code"
echo "   claude"
echo ""
echo "如果账户未提供 gpt-6-astra，请将配置中的模型名称改为 /models 返回的可用模型。"
