#!/bin/bash
###############################################################################
#  本地 LaTeX Docker 容器一键启动脚本
#  功能：基于 texlive/texlive:latest 镜像，创建含 SSH 的 LaTeX 编写环境
#  用法：bash docker_claude_latex.sh
###############################################################################

CONTAINER_NAME="docker-claude-latex"
HOST_PORT=2224
CONTAINER_PORT=22
ROOT_PASSWORD="yourpassword"

echo "============================================================"
echo "  LaTeX Docker 容器启动"
echo "  镜像: texlive/texlive:latest"
echo "  SSH 端口映射: ${HOST_PORT} -> ${CONTAINER_PORT}"
echo "============================================================"
echo ""

# 检查镜像是否存在，不存在则拉取
if ! docker image inspect texlive/texlive:latest >/dev/null 2>&1; then
    echo "=== 拉取 texlive/texlive:latest 镜像（约 5GB，请耐心等待）==="
    docker pull texlive/texlive:latest
    echo "镜像拉取完成"
    echo ""
fi

# 检查容器是否已存在，存在则直接启动
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "容器 ${CONTAINER_NAME} 已存在，直接进入..."
    docker start ${CONTAINER_NAME} >/dev/null 2>&1
    docker exec -itu root ${CONTAINER_NAME} bash
    exit 0
fi

echo "=== 创建并启动容器 ==="
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
    --name ${CONTAINER_NAME} \
    -p ${HOST_PORT}:${CONTAINER_PORT} \
    texlive/texlive:latest \
    /bin/bash -c "
        apt-get update && \
        apt-get install -y openssh-server && \
        mkdir -p /var/run/sshd && \
        echo 'root:${ROOT_PASSWORD}' | chpasswd && \
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
        /usr/sbin/sshd -D
    "

echo ""
echo "============================================================"
echo "  容器已启动！"
echo "  SSH 连接: ssh -p ${HOST_PORT} root@localhost"
echo "  密码: ${ROOT_PASSWORD}"
echo "  进入容器: docker exec -itu root ${CONTAINER_NAME} bash"
echo ""
echo "  VSCode 插件: 请安装 LaTeX Workshop (James-Yu.latex-workshop)"
echo "============================================================"
