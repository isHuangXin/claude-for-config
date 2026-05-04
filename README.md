# claude-for-config

Quick Config & Install Scripts for Docker GPU Development Environment, powered by Claude Code.

## Overview

This repository provides one-click setup scripts and guides for creating GPU-enabled Docker containers with:

- **CUDA Toolkit 12.8**
- **Python 3.11**
- **PyTorch 2.9.1 (CUDA 12.8)**
- **RDMA / InfiniBand support**
- **Claude Code CLI**

## Files

| File | Description |
|------|-------------|
| `new_docker_setup_guide.md` | Step-by-step guide for creating a Docker container with GPU & RDMA support |
| `new_docker_env_setup.sh` | One-click script: installs CUDA 12.8 + Python 3.11 + PyTorch 2.9.1 inside container |
| `claude_code_docker_setup_guide.md` | Guide for installing Claude Code CLI in Docker |
| `claude_code_docker_setup.sh` | One-click script: installs Node.js + Claude Code CLI |

## Quick Start

### 1. Create Docker Container

```bash
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
```

### 2. Install Environment (inside container)

```bash
# Install CUDA + Python + PyTorch
bash /home/huangxin/code_list/claude-for-config/new_docker_env_setup.sh

# Install Claude Code CLI
bash /home/huangxin/code_list/claude-for-config/claude_code_docker_setup.sh
```

### 3. Verify

```bash
nvcc --version
python --version
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
claude --version
```

## License

See [LICENSE](LICENSE) for details.

## Author

Xin Huang — [@isHuangXin](https://github.com/isHuangXin)
