#!/bin/bash
# Ubuntu 端 BulletTrade Server 快速启动脚本
# 用于从 Ubuntu 工作站连接到 Windows 机器上的 BulletTrade Server

set -e  # 遇到错误立即退出

echo "=========================================="
echo "Ubuntu BulletTrade Client 快速配置"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置变量（请根据实际情况修改）
WINDOWS_IP="${WINDOWS_IP:-192.168.1.100}"  # Windows 机器 IP，可通过环境变量设置
SERVER_PORT="${SERVER_PORT:-58620}"
SERVER_TOKEN="${SERVER_TOKEN:-}"  # 如果 Windows 端设置了 token，在这里配置

echo -e "${YELLOW}配置信息:${NC}"
echo "  Windows IP: $WINDOWS_IP"
echo "  端口: $SERVER_PORT"
echo "  Token: ${SERVER_TOKEN:-未设置}"
echo ""

# 步骤 1: 检查 Python
echo -e "${YELLOW}[1/6] 检查 Python 环境...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}错误: 未找到 python3${NC}"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ Python: $PYTHON_VERSION${NC}"

# 步骤 2: 创建虚拟环境
echo -e "${YELLOW}[2/6] 创建虚拟环境...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✓ 虚拟环境已创建${NC}"
else
    echo -e "${GREEN}✓ 虚拟环境已存在${NC}"
fi

# 步骤 3: 激活虚拟环境
echo -e "${YELLOW}[3/6] 激活虚拟环境...${NC}"
source venv/bin/activate
echo -e "${GREEN}✓ 虚拟环境已激活${NC}"

# 步骤 4: 安装 bullet-trade
echo -e "${YELLOW}[4/6] 安装 bullet-trade...${NC}"
if ! pip show bullet-trade &> /dev/null; then
    pip install --upgrade pip
    pip install bullet-trade
    echo -e "${GREEN}✓ bullet-trade 已安装${NC}"
else
    echo -e "${GREEN}✓ bullet-trade 已安装（跳过）${NC}"
fi

# 步骤 5: 创建 .env 配置文件
echo -e "${YELLOW}[5/6] 创建 .env 配置文件...${NC}"
cat > .env << EOF
# BulletTrade Server 远程配置
QMT_SERVER_HOST=$WINDOWS_IP
QMT_SERVER_PORT=$SERVER_PORT
${SERVER_TOKEN:+QMT_SERVER_TOKEN=$SERVER_TOKEN}

# 数据源配置
DEFAULT_DATA_PROVIDER=qmt-remote
EOF
echo -e "${GREEN}✓ .env 文件已创建${NC}"
echo ""
echo "配置文件内容:"
cat .env
echo ""

# 步骤 6: 测试连接
echo -e "${YELLOW}[6/6] 测试连接...${NC}"
if command -v nc &> /dev/null; then
    if nc -zv -w 5 "$WINDOWS_IP" "$SERVER_PORT" 2>&1 | grep -q "succeeded"; then
        echo -e "${GREEN}✓ 网络连接成功: $WINDOWS_IP:$SERVER_PORT${NC}"
    else
        echo -e "${RED}✗ 网络连接失败: $WINDOWS_IP:$SERVER_PORT${NC}"
        echo "请检查:"
        echo "  1. Windows 端 BulletTrade Server 是否正在运行"
        echo "  2. Windows 防火墙是否开放端口 $SERVER_PORT"
        echo "  3. IP 地址是否正确"
    fi
else
    echo -e "${YELLOW}⚠ nc (netcat) 未安装，跳过网络测试${NC}"
    echo "可以手动测试: telnet $WINDOWS_IP $SERVER_PORT"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}配置完成！${NC}"
echo "=========================================="
echo ""
echo "下一步操作:"
echo "  1. 创建策略文件（见下方示例）"
echo "  2. 运行回测: bullet-trade backtest strategy.py --start 2024-01-01 --end 2024-12-01"
echo "  3. 运行实盘: bullet-trade live strategy.py --broker qmt-remote"
echo ""
