# LaTeX Docker 容器搭建指南

> 基于 `texlive/texlive:latest` 镜像，在本地 macOS 上搭建完整 LaTeX 编写环境，通过 SSH 连接使用 Claude Code 编辑。

---

## 前置条件

- 已安装 Docker Desktop (macOS)
- 网络畅通（镜像约 5GB）

---

## 第一步：拉取 TeX Live 镜像

```bash
docker pull texlive/texlive:latest
```

> 镜像约 5GB，包含完整的 TeX Live 发行版（所有宏包）。如果下载慢，可配置 Docker 镜像加速器。

验证镜像：

```bash
docker images | grep texlive
```

---

## 第二步：创建并启动容器

```bash
docker run -itd --user root \
    -v /Users/huangxin/code_list:/home/huangxin/code_list \
    -v /Users/huangxin/paper_list:/home/huangxin/paper_list \
    -v /Users/huangxin/dataset_list:/home/huangxin/dataset_list \
    -v /Users/huangxin/model_list:/home/huangxin/model_list \
    -v /Users/huangxin/phd_list:/home/huangxin/phd_list \
    -v /Users/huangxin/work_list:/home/huangxin/work_list \
    -v /Users/huangxin/document_list:/home/huangxin/document_list \
    -v /Users/huangxin/.ssh:/root/.ssh \
    -w /home/huangxin/ \
    --name docker-claude-latex \
    -p 2224:22 \
    texlive/texlive:latest \
    /bin/bash -c "
        apt-get update && \
        apt-get install -y openssh-server && \
        mkdir -p /var/run/sshd && \
        echo 'root:yourpassword' | chpasswd && \
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
        /usr/sbin/sshd -D
    "
```

**参数说明：**

| 参数 | 说明 |
|------|------|
| `-itd` | 交互模式 + 后台运行 |
| `-v /Users/huangxin/...:/home/huangxin/...` | 挂载本地目录到容器 |
| `-w /home/huangxin/` | 设置工作目录 |
| `-p 2224:22` | SSH 端口映射，宿主机 2224 → 容器 22 |
| `--name docker-claude-latex` | 容器名称 |
| `/bin/bash -c "..."` | 启动时安装 SSH 并配置 root 登录 |

---

## 第三步：进入容器

```bash
docker exec -itu root docker-claude-latex bash
```

---

## 第四步：通过 SSH 连接容器

```bash
ssh -p 2224 root@localhost
# 密码: yourpassword
```

---

## 第四步：使用 Claude Code 连接

在本地终端通过 SSH 连接后，即可使用 Claude Code 编辑 LaTeX 文件：

```bash
ssh -p 2224 root@localhost
claude   # 启动 Claude Code CLI
```

---

## 常用操作

### 编译 LaTeX 文件

```bash
# 进入容器
ssh -p 2224 root@localhost

# 编译
cd /home/huangxin/paper_list/<your_paper>
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex

# 或使用 latexmk 一键编译
latexmk -pdf main.tex
```

### 容器管理

```bash
# 查看容器状态
docker ps -a | grep docker-claude-latex

# 停止容器
docker stop docker-claude-latex

# 启动已停止的容器
docker start docker-claude-latex

# 删除容器
docker rm -f docker-claude-latex
```

---

## 快速使用

使用同目录下的一键脚本：

```bash
bash /home/huangxin/code_list/claude-for-config/docker_claude_latex.sh
```

脚本会自动检查镜像、创建容器并启动 SSH 服务。
