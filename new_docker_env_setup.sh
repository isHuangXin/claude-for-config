#!/bin/bash
###############################################################################
#  新 Docker 容器环境一键搭建脚本
#  功能：安装基础工具 + CUDA Toolkit 12.8 + Python 3.11 + PyTorch 2.9.1
#  用法：在容器内执行  bash new_docker_env_setup.sh
###############################################################################
set -e

echo "============================================================"
echo "  Docker 容器环境一键搭建"
echo "  CUDA Toolkit 12.8 + Python 3.11 + PyTorch 2.9.1 (cu128)"
echo "============================================================"
echo ""

# ======================== Step 1: 基础工具 ========================
echo "=== [1/4] 安装基础工具 (wget, git, curl) ==="
apt-get update
apt-get install -y wget git curl
echo "[1/4] 完成"
echo ""

# ======================== Step 2: CUDA Toolkit ========================
echo "=== [2/4] 安装 CUDA Toolkit 12.8 ==="

# 清理可能存在的旧密钥包
rm -f /home/huangxin/code_list/cuda-keyring_1.1-1_all.deb

# 下载并安装 CUDA 密钥
cd /home/huangxin/code_list
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb

# 安装 CUDA Toolkit
apt-get update
apt-get install -y cuda-toolkit-12-8

# 配置环境变量（避免重复追加）
# 立即生效（当前脚本进程）
export PATH=/usr/local/cuda-12.8/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH

# 持久化到 ~/.bashrc（避免重复追加）
if ! grep -q 'cuda-12.8' ~/.bashrc 2>/dev/null; then
    echo 'export PATH=/usr/local/cuda-12.8/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
fi

# 验证
echo "CUDA 版本:"
nvcc --version
echo "[2/4] 完成"
echo ""

# ======================== Step 3: Python 3.11 ========================
echo "=== [3/4] 安装 Python 3.11 ==="
apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get install -y python3.11 python3.11-venv python3.11-dev 
apt install -y python3-pip

# 创建软链接
ln -sf /usr/bin/python3   /usr/local/bin/python
ln -sf /usr/bin/pip3      /usr/local/bin/pip

echo "Python 版本: $(python --version)"
echo "pip 版本: $(pip --version)"
echo "[3/4] 完成"
echo ""

# ======================== Step 4: PyTorch ========================
echo "=== [4/4] 安装 PyTorch 2.9.1 (CUDA 12.8) ==="
pip install --break-system-packages \
    torch==2.9.1 \
    torchvision==0.24.1 \
    torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu128

echo "[4/4] 完成"
echo ""

# ======================== 验证 ========================
echo "============================================================"
echo "  环境搭建完成！验证结果："
echo "============================================================"
echo ""
echo "CUDA:"
nvcc --version | grep "release"
echo ""
echo "Python:"
python --version
echo ""
echo "PyTorch:"
python -c "
import torch
print(f'  PyTorch 版本: {torch.__version__}')
print(f'  CUDA 可用:    {torch.cuda.is_available()}')
print(f'  GPU 数量:     {torch.cuda.device_count()}')
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        print(f'  GPU {i}: {torch.cuda.get_device_name(i)}')
"
echo ""
echo "============================================================"
echo "  全部完成！新终端自动生效，当前终端请执行 source ~/.bashrc"
echo "============================================================"
