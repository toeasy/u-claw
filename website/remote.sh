#!/bin/bash
# ============================================================
# U-Claw 远程协助 v3（Mac/Linux）
# 用法: curl -fsSL https://u-claw.org/remote.sh | bash
# 改进: SSH 验证、同局域网直连、安全增强、自动超时
# ============================================================

set -e
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

clear
echo ""
echo -e "${CYAN}  ===========================================${NC}"
echo -e "${CYAN}  U-Claw 远程协助 v3${NC}"
echo -e "${CYAN}  ===========================================${NC}"
echo ""

# ---- 安全提示 ----
echo -e "${YELLOW}  ⚠ 本脚本将执行以下操作：${NC}"
echo -e "${DIM}    1. 开启 SSH 远程登录${NC}"
echo -e "${DIM}    2. 建立加密隧道到 U-Claw 中转服务器${NC}"
echo -e "${DIM}    3. 技术支持可通过 SSH 连接你的电脑${NC}"
echo -e "${DIM}    4. 关闭终端或 Ctrl+C 即可断开${NC}"
echo ""
echo -e -n "${YELLOW}  是否继续？(y/N): ${NC}"
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${RED}  已取消${NC}"
    exit 0
fi
echo ""

# ---- Step 1: SSH ----
echo -e "  [1/4] 检查 SSH ..."
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: 开启远程登录
    sudo systemsetup -setremotelogin on 2>/dev/null || true
    # 确保密码认证开启（macOS Ventura+ 可能默认关闭）
    SSHD_CONFIG="/etc/ssh/sshd_config"
    if grep -q "^PasswordAuthentication no" "$SSHD_CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}  检测到 SSH 密码登录被禁用，正在开启...${NC}"
        sudo sed -i '' 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$SSHD_CONFIG"
        sudo launchctl stop com.openssh.sshd 2>/dev/null || true
        sudo launchctl start com.openssh.sshd 2>/dev/null || true
    fi
else
    sudo systemctl start sshd 2>/dev/null || sudo systemctl start ssh 2>/dev/null || {
        sudo apt-get install -y openssh-server 2>/dev/null || sudo yum install -y openssh-server 2>/dev/null
        sudo systemctl start sshd 2>/dev/null || sudo systemctl start ssh
    }
fi

# 验证 SSH 真正在监听
if ss -tlnp 2>/dev/null | grep -q ':22 ' || netstat -an 2>/dev/null | grep -q '\.22 .*LISTEN'; then
    echo -e "${GREEN}  [OK] SSH 已启动并在监听端口 22${NC}"
else
    echo -e "${RED}  [!] SSH 未能成功启动${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        echo -e "${YELLOW}  请手动开启: 系统设置 → 通用 → 共享 → 远程登录${NC}"
    fi
    echo -e "${YELLOW}  开启后重新运行本脚本${NC}"
    exit 1
fi

# ---- Step 2: 检测本地 IP（局域网直连用）----
echo ""
echo -e "  [2/4] 检测网络环境 ..."

LOCAL_IP=""
if [[ "$(uname)" == "Darwin" ]]; then
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
else
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
fi

if [ -n "$LOCAL_IP" ]; then
    echo -e "${GREEN}  [OK] 本机局域网 IP: ${CYAN}${LOCAL_IP}${NC}"
else
    echo -e "${DIM}  未检测到局域网 IP${NC}"
fi

# ---- Step 3: frpc ----
echo ""
echo -e "  [3/4] 准备远程通道 ..."

FRP_DIR="/tmp/uclaw-frp"
mkdir -p "$FRP_DIR"
FRPC="$FRP_DIR/frpc"

if [ ! -f "$FRPC" ]; then
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [[ "$OS" == "darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            FRP_URL="https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_darwin_arm64.tar.gz"
        else
            FRP_URL="https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_darwin_amd64.tar.gz"
        fi
    else
        if [[ "$ARCH" == "aarch64" ]]; then
            FRP_URL="https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_linux_arm64.tar.gz"
        else
            FRP_URL="https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_linux_amd64.tar.gz"
        fi
    fi

    echo -e "${DIM}    下载: $FRP_URL${NC}"
    curl -sL "https://ghfast.top/$FRP_URL" -o "$FRP_DIR/frp.tar.gz" 2>/dev/null || \
    curl -sL "$FRP_URL" -o "$FRP_DIR/frp.tar.gz"
    tar xzf "$FRP_DIR/frp.tar.gz" -C "$FRP_DIR" --strip-components=1
    rm -f "$FRP_DIR/frp.tar.gz"
fi

chmod +x "$FRPC"
echo -e "${GREEN}  [OK] 远程通道工具就绪${NC}"

# ---- Step 4: 连接 ----
echo ""
echo -e "  [4/4] 建立连接 ..."

# 更大的端口范围，减少冲突
PORT=$((20000 + RANDOM % 1000))
USERNAME=$(whoami)
HOSTNAME_VAL=$(hostname)

# 会话 ID（用于标识本次连接）
SESSION_ID=$(date +%s | tail -c 5)

cat > "$FRP_DIR/frpc.toml" << EOF
serverAddr = "101.32.254.221"
serverPort = 7000
auth.method = "token"
auth.token = "uclaw-remote-2026"

[[proxies]]
name = "ssh-${USERNAME}-${SESSION_ID}-${PORT}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${PORT}
EOF

echo ""
echo -e "${GREEN}  ===========================================${NC}"
echo -e "${GREEN}  ✅ 远程协助已就绪！${NC}"
echo -e "${GREEN}  ===========================================${NC}"
echo ""
echo -e "${YELLOW}  +------------------------------------------+"
echo -e "  |  把下面这段发给技术支持（微信）：         |"
echo -e "  |                                          |"
printf "  |  ${CYAN}端口: %-36s${YELLOW}|\n" "$PORT"
printf "  |  ${CYAN}用户: %-36s${YELLOW}|\n" "$USERNAME"
printf "  |  ${CYAN}电脑: %-36s${YELLOW}|\n" "$HOSTNAME_VAL"
if [ -n "$LOCAL_IP" ]; then
printf "  |  ${CYAN}局域网: %-34s${YELLOW}|\n" "$LOCAL_IP"
fi
echo -e "  |                                          |"
echo -e "  +------------------------------------------+${NC}"
echo ""

# 局域网直连提示
if [ -n "$LOCAL_IP" ]; then
    echo -e "${CYAN}  💡 同一 WiFi 下可直连（更快）:${NC}"
    echo -e "${BOLD}     ssh ${USERNAME}@${LOCAL_IP}${NC}"
    echo ""
fi

echo -e "${DIM}  * 远程通道连接中，断线自动重连${NC}"
echo -e "${DIM}  * 按 Ctrl+C 或关闭终端即断开${NC}"
echo -e "${DIM}  * 连接将在 2 小时后自动断开${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}  正在断开远程连接...${NC}"
    kill $FRPC_PID 2>/dev/null || true
    rm -f "$FRP_DIR/frpc.toml"
    echo -e "${GREEN}  已安全断开${NC}"
    exit 0
}
trap cleanup INT TERM

# 启动 frpc（后台运行，便于超时控制）
"$FRPC" -c "$FRP_DIR/frpc.toml" &
FRPC_PID=$!

# 2 小时超时自动断开
( sleep 7200 && kill $FRPC_PID 2>/dev/null && echo -e "\n${YELLOW}  ⏰ 已达 2 小时，自动断开${NC}" ) &
TIMEOUT_PID=$!

# 等待 frpc 退出
wait $FRPC_PID 2>/dev/null
kill $TIMEOUT_PID 2>/dev/null || true
rm -f "$FRP_DIR/frpc.toml"
