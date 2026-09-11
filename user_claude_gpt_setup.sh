#!/bin/bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "请直接以普通用户运行此脚本，不要使用 root 账户。" >&2
    exit 1
fi

install_prefix="$HOME/.local"
mkdir -p "$install_prefix/bin"
export PATH="$install_prefix/bin:$PATH"

node_is_supported() {
    command -v node >/dev/null 2>&1 && node -e '
        const [major, minor, patch] = process.versions.node.split(".").map(Number);
        process.exit(major > 20 || (major === 20 &&
            (minor > 18 || (minor === 18 && patch >= 1))) ? 0 : 1);
    '
}

echo "=== [1/5] 检查 Node.js 和 npm（无需 sudo 或密码） ==="
if ! node_is_supported || ! command -v npm >/dev/null 2>&1; then
    if [ "$(uname -s)" != "Linux" ]; then
        echo "自动安装仅支持 Linux；请先在用户目录安装 Node.js >= 20.18.1 和 npm。" >&2
        exit 1
    fi
    case "$(uname -m)" in
        x86_64) node_arch="x64" ;;
        aarch64|arm64) node_arch="arm64" ;;
        *) echo "当前 CPU 架构不支持自动安装 Node.js，请手动安装兼容版本。" >&2; exit 1 ;;
    esac

    if command -v curl >/dev/null 2>&1; then
        download=(curl -fsSL --proto '=https' --proto-redir '=https' -o)
    elif command -v wget >/dev/null 2>&1; then
        download=(wget --https-only -q -O)
    else
        echo "缺少下载工具：需要 curl 或 wget，请联系管理员提供。" >&2
        exit 1
    fi
    for cmd in tar gzip sha256sum; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "缺少解压或校验工具：$cmd，请联系管理员提供。" >&2
            exit 1
        fi
    done
    for executable in node npm npx; do
        target="$install_prefix/bin/$executable"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "$target 已存在且不是符号链接，为避免覆盖已停止；请先手动处理该文件。" >&2
            exit 1
        fi
    done

    echo "将从 Node.js 官网下载 Node.js 22，安装到 $install_prefix，不修改系统软件。"
    node_root="$install_prefix/lib/nodejs"
    mkdir -p "$node_root"
    download_dir="$(mktemp -d "$node_root/.download.XXXXXX")"
    trap 'rm -rf -- "$download_dir"' EXIT

    if ! "${download[@]}" "$download_dir/SHASUMS256.txt" "https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt"; then
        echo "无法下载 Node.js 校验清单，请检查网络连接。" >&2
        exit 1
    fi
    archive=""
    archive_pattern="^node-v22\.[0-9]+\.[0-9]+-linux-${node_arch}\.tar\.gz$"
    while read -r checksum filename; do
        if [[ "$filename" =~ $archive_pattern && "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
            archive="$filename"
            expected_checksum="$checksum"
            break
        fi
    done < "$download_dir/SHASUMS256.txt"
    if [ -z "$archive" ]; then
        echo "官方校验清单中未找到当前架构的 Node.js 22 安装包。" >&2
        exit 1
    fi

    node_dir="$node_root/${archive%.tar.gz}"
    if [ ! -e "$node_dir" ]; then
        node_version="${archive%-linux-*}"
        node_version="${node_version#node-}"
        if ! "${download[@]}" "$download_dir/$archive" "https://nodejs.org/dist/$node_version/$archive"; then
            echo "无法下载 Node.js 安装包，请检查网络连接。" >&2
            exit 1
        fi
        if ! printf '%s  %s\n' "$expected_checksum" "$download_dir/$archive" | sha256sum --check --status; then
            echo "Node.js 安装包 SHA-256 校验失败，已停止安装。" >&2
            exit 1
        fi
        tar -xzf "$download_dir/$archive" -C "$download_dir"
        candidate_dir="$download_dir/${archive%.tar.gz}"
    else
        candidate_dir="$node_dir"
    fi
    if ! "$candidate_dir/bin/node" --version || ! PATH="$candidate_dir/bin:$PATH" "$candidate_dir/bin/npm" --version; then
        echo "Node.js/npm 无法在当前系统运行，请检查系统库兼容性或已有安装目录。" >&2
        exit 1
    fi
    if [ "$candidate_dir" != "$node_dir" ]; then
        mv "$candidate_dir" "$node_dir"
    fi
    for executable in node npm npx; do
        ln -sfn "$node_dir/bin/$executable" "$install_prefix/bin/$executable"
    done
    hash -r

    if ! node_is_supported || ! npm --version >/dev/null 2>&1; then
        echo "用户目录中的 Node.js/npm 仍不满足要求，请检查安装文件和系统兼容性。" >&2
        exit 1
    fi
fi

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

echo ""
echo "=== [2/5] 将 Claude Code 和 Copilot API 安装到当前用户目录 ==="
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
