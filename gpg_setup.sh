#!/bin/bash
###############################################################################
#  GPG 密钥生成 & Git 签名配置一键脚本
#  功能：生成 GPG 密钥 + 配置 Git 签名 + 输出公钥（用于上传 GitHub）
#  用法：bash gpg_setup.sh [name] [email]
#  示例：bash gpg_setup.sh isHuangXin huangxin.hust@gmail.com
###############################################################################
set -e

# ======================== 参数解析 ========================
GPG_NAME="${1:-isHuangXin}"
GPG_EMAIL="${2:-huangxin.hust@gmail.com}"

echo "============================================================"
echo "  GPG 密钥生成 & Git 签名配置"
echo "  姓名:  ${GPG_NAME}"
echo "  邮箱:  ${GPG_EMAIL}"
echo "============================================================"
echo ""

# ======================== Step 1: 清理旧环境 ========================
echo "=== [1/4] 清理旧 GPG 环境 ==="

# 停止旧的 gpg-agent（避免版本不匹配问题）
gpgconf --kill all 2>/dev/null || true

# 备份旧目录（如果存在且非空）
if [ -d "$HOME/.gnupg" ] && [ "$(ls -A $HOME/.gnupg 2>/dev/null)" ]; then
    BACKUP_DIR="$HOME/.gnupg.bak.$(date +%Y%m%d%H%M%S)"
    echo "备份旧 .gnupg 目录到 ${BACKUP_DIR}"
    mv "$HOME/.gnupg" "${BACKUP_DIR}"
fi

# 创建新目录
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

echo "[1/4] 完成"
echo ""

# ======================== Step 2: 生成 GPG 密钥 ========================
echo "=== [2/4] 生成 GPG 密钥 (RSA 4096) ==="

gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${GPG_NAME}
Name-Email: ${GPG_EMAIL}
Expire-Date: 0
%no-protection
%commit
EOF

echo "[2/4] 完成"
echo ""

# ======================== Step 3: 配置 Git ========================
echo "=== [3/4] 配置 Git GPG 签名 ==="

# 获取 KEY_ID
KEY_ID=$(gpg --list-secret-keys --keyid-format long 2>/dev/null \
    | grep "^sec" \
    | head -1 \
    | sed 's/.*\/\([A-F0-9]*\) .*/\1/')

if [ -z "${KEY_ID}" ]; then
    echo "错误: 未找到 GPG 密钥"
    exit 1
fi

echo "KEY_ID: ${KEY_ID}"

# 配置 Git
git config --global user.signingkey "${KEY_ID}"
git config --global commit.gpgsign true
git config --global gpg.program gpg

echo "[3/4] 完成"
echo ""

# ======================== Step 4: 输出公钥 ========================
echo "=== [4/4] 导出 GPG 公钥 ==="
echo ""
echo ">>> 请复制以下公钥并添加到 GitHub <<<"
echo ">>> https://github.com/settings/gpg/new <<<"
echo ""
gpg --armor --export "${KEY_ID}"
echo ""

# ======================== 验证 ========================
echo "============================================================"
echo "  配置完成！验证结果："
echo "============================================================"
echo ""
echo "GPG 密钥:"
gpg --list-secret-keys --keyid-format long
echo ""
echo "Git 签名配置:"
echo "  user.signingkey = $(git config --global user.signingkey)"
echo "  commit.gpgsign  = $(git config --global commit.gpgsign)"
echo ""
echo "============================================================"
echo "  下一步操作："
echo "  1. 复制上面的公钥"
echo "  2. 打开 https://github.com/settings/gpg/new"
echo "  3. 粘贴公钥并点击 Add GPG key"
echo "  4. (可选) 开启 Vigilant mode: Settings → SSH and GPG keys"
echo "  5. 重新签名最近的 commit: git commit --amend --no-edit -S"
echo "============================================================"
