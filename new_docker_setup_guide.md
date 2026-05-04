# 新建 Docker 容器完整环境搭建指南

> 基于 Ubuntu 镜像，搭建含 GPU 支持、CUDA Toolkit、Python 3.11、PyTorch 的开发环境。

---

## 第一步：创建 Docker 容器

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
  -p <HOST_PORT>:<CONTAINER_PORT> \
  --name <CONTAINER_NAME> \
  ubuntu
```

**参数说明：**

| 参数 | 说明 | 示例 |
|------|------|------|
| `--ulimit memlock=-1:-1` | 解锁内存锁定限制，RDMA `ibv_reg_mr` 需要锁定物理内存页 | — |
| `--ulimit nofile=65536:65536` | 提高文件描述符上限，RDMA 连接需要大量 fd | — |
| `--network=host` | 使用宿主机网络栈，RDMA InfiniBand 设备直通 | — |
| `-v /home/huangxin/.ssh:/root/.ssh` | 挂载 SSH 密钥到容器 root 用户 | — |
| `<HOST_PORT>:<CONTAINER_PORT>` | 端口映射 | `2232:22` |
| `<CONTAINER_NAME>` | 容器名称 | `flat_memory_system` |

---

## 第二步：安装基础工具 & CUDA Toolkit

进入容器后执行：

### 2.1 安装基础工具

```bash
apt-get update
apt-get install -y wget git curl
apt-get install -y cmake
```

### 2.2 安装 CUDA Toolkit 12.8

```bash
# 清理可能存在的旧密钥包
rm -f /home/huangxin/code_list/cuda-keyring_1.1-1_all.deb

# 下载并安装 CUDA 密钥
cd /home/huangxin/code_list
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb

# 安装 CUDA Toolkit
apt-get update
apt-get install -y cuda-toolkit-12-8
```

### 2.3 配置环境变量

```bash
echo 'export PATH=/usr/local/cuda-12.8/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### 2.4 验证安装

```bash
nvcc --version
```

---

## 第三步：安装 Python 3.11

```bash
apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip

# 创建软链接
ln -sf /usr/bin/python3   /usr/local/bin/python
ln -sf /usr/bin/pip3      /usr/local/bin/pip
```

### 验证安装

```bash
python --version
pip --version
```

---

## 第四步：安装 PyTorch（CUDA 12.8）

```bash
pip install --break-system-packages \
  torch==2.9.1 \
  torchvision==0.24.1 \
  torchaudio==2.9.1 \
  --index-url https://download.pytorch.org/whl/cu128
```

### 验证安装

```bash
python -c "import torch; print(f'PyTorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')"
```

---

## 快速使用

可使用同目录下的一键脚本快速完成 Step 2 ~ Step 4（需在容器内执行）：

```bash
# 创建容器（手动执行，替换参数）
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
  --name flat_memory_system \
  ubuntu

# 进入容器后，执行一键安装脚本
bash /home/huangxin/code_list/a_docker_and_claude_code_cli_setting/new_docker_env_setup.sh
```
