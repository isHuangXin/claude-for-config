#!/bin/bash
###############################################################################
#  Ubuntu APT 换源脚本（阿里云镜像）
#  功能：将 Ubuntu 官方源替换为阿里云镜像，加速 apt-get 下载
#  用法：bash change_apt_source.sh [--restore]
#        --restore  恢复为 Ubuntu 官方源
###############################################################################

SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
OFFICIAL="http://archive.ubuntu.com"
MIRROR="https://mirrors.aliyun.com"

# 检查文件是否存在
if [ ! -f "$SOURCES_FILE" ]; then
    echo "错误: 未找到 $SOURCES_FILE"
    echo "可能不是 Ubuntu 24.04+ 系统，请手动修改 /etc/apt/sources.list"
    exit 1
fi

if [ "$1" = "--restore" ]; then
    echo "=== 恢复为 Ubuntu 官方源 ==="
    sed -i "s|${MIRROR}|${OFFICIAL}|g" "$SOURCES_FILE"
    echo "已恢复: ${OFFICIAL}"
else
    echo "=== 切换为阿里云镜像源 ==="
    # 备份原文件（仅首次）
    if [ ! -f "${SOURCES_FILE}.bak" ]; then
        cp "$SOURCES_FILE" "${SOURCES_FILE}.bak"
        echo "已备份原文件: ${SOURCES_FILE}.bak"
    fi
    sed -i "s|${OFFICIAL}|${MIRROR}|g" "$SOURCES_FILE"
    echo "已切换: ${MIRROR}"
fi

echo ""
echo "正在更新包索引..."
apt-get update

echo ""
echo "当前源:"
grep "^URIs:" "$SOURCES_FILE"
echo ""
echo "恢复命令: bash $0 --restore"
