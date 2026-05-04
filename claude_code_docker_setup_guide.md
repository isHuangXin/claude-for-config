# Docker 容器中搭建 Claude Code CLI 环境指南

> **方案**: Claude Code CLI + Copilot API Proxy (`copilot-api`)
>
> 通过公司 GitHub Copilot 账号中的 Claude 模型访问，而非直连 Anthropic 账号。

---

## 前置条件

| 条件 | 说明 |
|------|------|
| GitHub Copilot | 已通过公司流程申请 GitHub Copilot / copilot-cli |
| Node.js | 容器内需安装 Node.js |
| VS Code | 使用内置 Terminal 操作即可 |

---

## 第一步：安装 Node.js（容器内）

在新建的 Docker 容器中执行以下命令：

```bash
# 更新包索引
apt-get update

# 安装 curl（如果容器内没有）
apt-get install -y curl

# 下载并执行 NodeSource 安装脚本（安装 Node.js 20.x）
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# 安装 Node.js
apt-get install -y nodejs

# 验证安装
node -v
npm -v
```

---

## 第二步：安装 Claude Code CLI 和 Copilot API Proxy

```bash
# 安装 Copilot API Proxy（将 Copilot 模型暴露为本地 API）
npm install -g copilot-api

# 安装 Claude Code CLI 本体
npm install -g @anthropic-ai/claude-code
```

---

## 第三步：启动 Copilot API Proxy

```bash
copilot-api start
```

启动后会依次发生：

1. 终端输出一个 **GitHub 登录链接**
2. 在浏览器中用 **公司 GitHub / Copilot 账号** 登录
3. 登录成功后，终端显示：
   - 可用模型列表
   - 本地代理地址（默认 `http://localhost:4141`）

> **注意**: 此终端窗口需要 **保持运行**，Claude Code 通过它访问模型。

---

## 第四步：配置 Claude Code 使用 Copilot Proxy

### 4.1 创建配置目录

```bash
mkdir -p ~/.claude
```

### 4.2 创建配置文件

```bash
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4141",
    "ANTHROPIC_AUTH_TOKEN": "dummy",
    "ANTHROPIC_MODEL": "claude-sonnet-4.5",
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-haiku-4.5",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
EOF
```

### 配置说明

| 配置项 | 说明 |
|--------|------|
| `ANTHROPIC_BASE_URL` | 指向本地 Copilot Proxy 地址 |
| `ANTHROPIC_AUTH_TOKEN` | 设置为 `dummy` 即可，认证在 Copilot Proxy 层完成 |
| `ANTHROPIC_MODEL` | 主模型，使用 `claude-sonnet-4.5` |
| `ANTHROPIC_SMALL_FAST_MODEL` | 轻量模型，使用 `claude-haiku-4.5` |
| `DISABLE_NON_ESSENTIAL_MODEL_CALLS` | 禁用非必要的模型调用 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 禁用非必要的网络流量 |

> **说明**: Token 设置为 `dummy` 是正常的，实际认证由 Copilot Proxy 处理，不会走个人 Anthropic 账号。

---

## 第五步：启动 Claude Code

在 VS Code Terminal 中，切换到项目目录后执行：

```bash
claude
```

看到 Claude Code 的交互界面即表示环境搭建成功。

---

## 快速复制脚本（一键执行）

将以下脚本保存后可在新容器中快速执行完成环境搭建：

```bash
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
    "ANTHROPIC_SMALL_FAST_MODEL": "claude-sonnet-4.6",
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
```
