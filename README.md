# claude-for-config

Quick Config & Install Scripts for Docker GPU Development Environment, powered by Claude Code.

## Overview

This repository provides one-click setup scripts and guides for:

- **GPU Docker Container** — CUDA 12.8 + Python 3.11 + PyTorch 2.9.1 + RDMA support
- **LaTeX Docker Container** — Full TeX Live environment with SSH access
- **Claude Code CLI** — Claude Code installation via Copilot API Proxy

## Files

### GPU Development Environment (Remote Server)

| File | Description |
|------|-------------|
| `new_docker_setup_guide.md` | Guide for creating a Docker container with GPU & RDMA support |
| `new_docker_env_setup.sh` | One-click script: CUDA 12.8 + Python 3.11 + PyTorch 2.9.1 |

### LaTeX Environment (Local macOS)

| File | Description |
|------|-------------|
| `docker_claude_latex_guide.md` | Guide for creating a LaTeX Docker container with SSH |
| `docker_claude_latex.sh` | One-click script: TeX Live container with SSH public key auth |

### Claude Code CLI (Local & Remote)

| File | Description |
|------|-------------|
| `docker_claude_setup_guide.md` | Guide for installing Claude Code CLI via Copilot API Proxy |
| `docker_claude_setup.sh` | One-click script: Node.js + Claude Code CLI + Copilot API |

## Quick Start

### GPU Development Container (Remote Server)

```bash
# 1. Create container with GPU & RDMA support
docker run -it --user root \
  --ulimit memlock=-1:-1 \
  --ulimit nofile=65536:65536 \
  --network=host \
  --gpus all \
  -v /:/hostroot \
  -v /home:/home \
  -v /data:/data \
  -v /data0:/data0 \
  -v /data1:/data1 \
  -v /data2:/data2 \
  -v /data3:/data3 \
  -v /home/huangxin/.ssh:/root/.ssh \
  --privileged --ipc=host \
  -p 2232:22 \
  --name <CONTAINER_NAME> \
  ubuntu

# 2. Install CUDA + Python + PyTorch (inside container)
bash /home/huangxin/code_list/claude-for-config/new_docker_env_setup.sh

# 3. Install Claude Code CLI (inside container)
bash /home/huangxin/code_list/claude-for-config/docker_claude_setup.sh
```

### LaTeX Container (Local macOS)

```bash
# One-click: create or enter LaTeX container
bash docker_claude_latex.sh
```

The script will:
- Pull `texlive/texlive:latest` image if not present (~5GB)
- Create container with SSH and mount local directories
- If container already exists, start and enter it directly

## License

See [LICENSE](LICENSE) for details.

## Author

Xin Huang — [@isHuangXin](https://github.com/isHuangXin)
