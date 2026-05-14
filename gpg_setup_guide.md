# GPG 密钥生成 & Git Commit 签名验证指南

> 为 Git commit 添加 GPG 签名，使 GitHub 上的提交显示绿色 **Verified** 标签。

---

## 背景知识

### 什么是 GPG 签名？

Git 的 `user.name` 和 `user.email` 任何人都可以随意填写，GPG 签名用于**证明 commit 确实是你本人提交的**。签名后 GitHub 会显示绿色的 Verified 标签。

### 相关目录

| 目录 | 用途 |
|------|------|
| `~/.ssh/` | SSH 密钥，用于连接服务器、GitHub 认证 |
| `~/.gnupg/` | GPG 密钥，用于签名 commit、加密文件 |

### 适用场景

- **需要签名**：企业合规、开源项目安全审计、多人协作确认提交者身份
- **不需要签名**：个人项目、临时容器环境（密钥不便持久化）

---

## 快速使用

使用同目录下的一键脚本（在容器或本机内执行）：

```bash
# 使用默认配置（isHuangXin / huangxin.hust@gmail.com）
bash /home/huangxin/code_list/claude-for-config/gpg_setup.sh

# 自定义姓名和邮箱
bash /home/huangxin/code_list/claude-for-config/gpg_setup.sh "YourName" "your@email.com"
```

脚本执行后会输出 GPG 公钥，复制并上传到 GitHub 即可。

---

## 手动操作步骤

### 第一步：生成 GPG 密钥

```bash
# 清理旧环境
gpgconf --kill all
rm -rf ~/.gnupg
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg

# 生成密钥（非交互式）
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: isHuangXin
Name-Email: huangxin.hust@gmail.com
Expire-Date: 0
%no-protection
%commit
EOF
```

### 第二步：查看密钥 ID

```bash
gpg --list-secret-keys --keyid-format long
```

输出示例：

```
sec   rsa4096/37CD59A0341624A0 2026-05-14 [SCEAR]
      5722E8E48040F2AD52C2894B37CD59A0341624A0
uid                 [ultimate] isHuangXin <huangxin.hust@gmail.com>
```

其中 `37CD59A0341624A0` 就是 **KEY_ID**。

### 第三步：配置 Git 使用 GPG 签名

```bash
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
```

### 第四步：导出公钥并上传 GitHub

```bash
gpg --armor --export <KEY_ID>
```

1. 复制输出的完整内容（从 `-----BEGIN PGP PUBLIC KEY BLOCK-----` 到 `-----END PGP PUBLIC KEY BLOCK-----`）
2. 打开 [GitHub GPG Keys 设置](https://github.com/settings/gpg/new)
3. 粘贴公钥，点击 **Add GPG key**

### 第五步：验证签名

```bash
# 重新签名最近一次 commit
git commit --amend --no-edit -S
git push --force

# 验证本地签名
git log --show-signature -1
```

---

## GitHub Vigilant Mode

| 设置 | 未签名 commit 显示 | 已签名 commit 显示 |
|------|---------------------|---------------------|
| 关闭 (默认) | 无标记 | Verified |
| 开启 | **Unverified** | Verified |

设置路径：GitHub → Settings → SSH and GPG keys → 底部 Vigilant mode

---

## 关闭 GPG 签名

如果不需要签名，可以关闭：

```bash
git config --global commit.gpgsign false
```

---

## 容器环境注意事项

- GPG 密钥存储在 `~/.gnupg/` 目录
- 容器重建后，如果 `~/.gnupg/` 未挂载到宿主机，密钥会丢失
- 跨服务器使用需要导出并导入密钥：

```bash
# 导出（在旧机器上）
gpg --export-secret-keys <KEY_ID> > gpg-private.key

# 导入（在新机器上）
gpg --import gpg-private.key
```

---

## 常见问题

### Q: commit 显示 "Unable to verify this signature"

原因：commit 带了签名，但 GitHub 上没有对应的 GPG 公钥。

解决：上传公钥到 GitHub，或关闭 GPG 签名后重新提交。

### Q: gpg: agent_genkey failed: Forbidden

原因：gpg-agent 版本不匹配。

解决：

```bash
gpgconf --kill all
rm -rf ~/.gnupg
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
# 重新生成密钥
```

### Q: 换了服务器/容器怎么办？

方案 A：导出导入密钥（见上方"容器环境注意事项"）

方案 B：重新生成密钥并上传 GitHub（旧密钥可保留，GitHub 支持多个 GPG key）
