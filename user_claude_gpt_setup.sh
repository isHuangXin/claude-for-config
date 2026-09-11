#!/bin/bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "请以普通用户运行此脚本，不要使用 sudo bash 或 root 账户。" >&2
    exit 1
fi

node_is_supported() {
    command -v node >/dev/null 2>&1 && node -e '
        const [major, minor, patch] = process.versions.node.split(".").map(Number);
        process.exit(major > 20 || (major === 20 &&
            (minor > 18 || (minor === 18 && patch >= 1))) ? 0 : 1);
    '
}

echo "=== [1/5] 检查 Node.js 和 npm ==="
if ! node_is_supported || ! command -v npm >/dev/null 2>&1; then
    if ! command -v sudo >/dev/null 2>&1 || ! command -v apt-get >/dev/null 2>&1; then
        echo "需要 Node.js >= 20.18.1 和 npm；自动安装仅支持具有 sudo 权限的 Debian/Ubuntu 用户。" >&2
        exit 1
    fi

    echo "将使用 sudo 在系统中安装 Node.js 22，可能需要输入当前用户的密码。"
    sudo -v
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
    sudo apt-get install -y nodejs
    hash -r

    if ! node_is_supported || ! command -v npm >/dev/null 2>&1; then
        echo "当前 PATH 中的 Node.js/npm 仍不满足要求，请检查是否被旧版本或版本管理器覆盖。" >&2
        exit 1
    fi
fi

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

echo ""
echo "=== [2/5] 将 Claude Code 和 Copilot API 安装到当前用户目录 ==="
install_prefix="$HOME/.local"
mkdir -p "$install_prefix/bin"
export PATH="$install_prefix/bin:$PATH"
npm install -g --prefix "$install_prefix" @jeffreycao/copilot-api@latest --force
npm install -g --prefix "$install_prefix" @anthropic-ai/claude-code

echo ""
echo "=== [3/5] 配置当前用户的 Bash PATH ==="
path_line='export PATH="$HOME/.local/bin:$PATH"'
login_rc="$HOME/.profile"
if [ -f "$HOME/.bash_profile" ]; then
    login_rc="$HOME/.bash_profile"
elif [ -f "$HOME/.bash_login" ]; then
    login_rc="$HOME/.bash_login"
fi
for rc_file in "$HOME/.bashrc" "$login_rc"; do
    if ! grep -Fqx "$path_line" "$rc_file" 2>/dev/null; then
        printf '\n%s\n' "$path_line" >> "$rc_file"
    fi
done

echo ""
echo "=== [4/5] 创建当前用户的 Claude GPT 配置 ==="
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

echo ""
echo "=== [5/5] 普通用户 Claude GPT 环境搭建完成 ==="
echo "CLI 安装目录：$install_prefix/bin"
echo "配置文件：$HOME/.claude/settings.json"
echo ""
echo "接下来均以当前普通用户执行，不要加 sudo："
echo ""
echo "1. 让当前终端加载新的 PATH"
echo '   export PATH="$HOME/.local/bin:$PATH"'
echo ""
echo "2. 首次使用 Codex 后端时，完成登录"
echo "   copilot-api auth login --provider codex"
echo ""
echo "3. 启动 Copilot API，并保持该终端运行"
echo "   copilot-api start"
echo ""
echo "4. 新开 Bash 终端，确认模型列表中包含 gpt-6-astra"
echo "   curl http://127.0.0.1:4141/models"
echo ""
echo "5. 启动 Claude Code"
echo "   claude"
echo ""
echo "如果账户未提供 gpt-6-astra，请将配置中的模型名称改为 /models 返回的可用模型。"
