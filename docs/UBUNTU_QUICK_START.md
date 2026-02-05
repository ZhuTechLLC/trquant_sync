# Ubuntu 端快速启动指南

## 一键执行命令

### 方式 1: 使用快速配置脚本（推荐）

```bash
# 1. 下载并运行配置脚本
curl -O https://raw.githubusercontent.com/your-repo/docs/ubuntu_bullettrade_quick_start.sh
# 或者直接复制脚本内容到本地文件

# 2. 设置 Windows 机器 IP（替换为实际 IP）
export WINDOWS_IP=192.168.1.100

# 3. 运行配置脚本
chmod +x ubuntu_bullettrade_quick_start.sh
./ubuntu_bullettrade_quick_start.sh
```

### 方式 2: 手动执行（逐步操作）

```bash
# 步骤 1: 创建项目目录
mkdir -p ~/bullettrade_client
cd ~/bullettrade_client

# 步骤 2: 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 步骤 3: 安装 bullet-trade
pip install --upgrade pip
pip install bullet-trade

# 步骤 4: 创建 .env 配置文件（替换 IP 地址）
cat > .env << 'EOF'
QMT_SERVER_HOST=192.168.1.100
QMT_SERVER_PORT=58620
DEFAULT_DATA_PROVIDER=qmt-remote
EOF

# 步骤 5: 测试连接
python3 -c "
import socket
import os
from dotenv import load_dotenv
load_dotenv()
host = os.getenv('QMT_SERVER_HOST')
port = int(os.getenv('QMT_SERVER_PORT', 58620))
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(5)
result = sock.connect_ex((host, port))
sock.close()
if result == 0:
    print('✓ 连接成功')
else:
    print('✗ 连接失败')
"

# 步骤 6: 运行测试脚本
python3 ubuntu_test_connection.py
```

## 完整可执行命令序列

### 完整安装和配置（复制粘贴执行）

```bash
#!/bin/bash
# 完整安装配置脚本 - 直接复制粘贴到 Ubuntu 终端执行

# 设置 Windows 机器 IP（请修改为实际 IP）
WINDOWS_IP="192.168.1.100"
SERVER_PORT="58620"

echo "=========================================="
echo "开始配置 BulletTrade Client"
echo "=========================================="

# 1. 创建项目目录
mkdir -p ~/bullettrade_client && cd ~/bullettrade_client
echo "✓ 项目目录已创建"

# 2. 创建虚拟环境
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ 虚拟环境已创建"
fi

# 3. 激活虚拟环境
source venv/bin/activate
echo "✓ 虚拟环境已激活"

# 4. 安装 bullet-trade
pip install --upgrade pip -q
pip install bullet-trade -q
echo "✓ bullet-trade 已安装"

# 5. 创建 .env 文件
cat > .env << EOF
QMT_SERVER_HOST=$WINDOWS_IP
QMT_SERVER_PORT=$SERVER_PORT
DEFAULT_DATA_PROVIDER=qmt-remote
EOF
echo "✓ .env 文件已创建"

# 6. 测试连接
echo ""
echo "测试连接 $WINDOWS_IP:$SERVER_PORT ..."
if command -v nc &> /dev/null; then
    if nc -zv -w 5 "$WINDOWS_IP" "$SERVER_PORT" 2>&1 | grep -q "succeeded"; then
        echo "✓ 连接成功"
    else
        echo "✗ 连接失败，请检查 Windows 端服务是否运行"
    fi
else
    echo "⚠ nc 未安装，跳过网络测试"
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 创建策略文件"
echo "  2. 运行: bullet-trade live strategy.py --broker qmt-remote"
```

## 测试连接

### 方法 1: 使用测试脚本

```bash
# 下载测试脚本
curl -O ubuntu_test_connection.py

# 运行测试
python3 ubuntu_test_connection.py
```

### 方法 2: 使用 Python 快速测试

```bash
python3 << 'EOF'
import os
import socket

# 配置（从 .env 或环境变量读取）
host = os.getenv('QMT_SERVER_HOST', '192.168.1.100')
port = int(os.getenv('QMT_SERVER_PORT', 58620))

# 测试连接
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(5)
result = sock.connect_ex((host, port))
sock.close()

if result == 0:
    print(f'✓ 连接成功: {host}:{port}')
else:
    print(f'✗ 连接失败: {host}:{port}')
EOF
```

### 方法 3: 使用命令行工具

```bash
# 使用 telnet
telnet 192.168.1.100 58620

# 使用 nc (netcat)
nc -zv 192.168.1.100 58620

# 使用 curl（如果支持）
curl -v http://192.168.1.100:58620/health
```

## 运行策略

### 创建示例策略

```bash
cat > strategy.py << 'EOF'
from bullet_trade.compat.api import *

def initialize(context):
    set_benchmark('000300.XSHG')
    g.security = '510300.XSHG'
    run_daily(trade, 'every_bar')

def trade(context):
    if g.security not in context.portfolio.positions:
        order_value(g.security, context.portfolio.available_cash)
EOF
```

### 运行回测

```bash
bullet-trade backtest strategy.py \
    --start 2024-01-01 \
    --end 2024-12-01 \
    --data-provider qmt-remote
```

### 运行实盘

```bash
bullet-trade live strategy.py --broker qmt-remote
```

## 环境变量方式（不使用 .env 文件）

```bash
# 设置环境变量
export QMT_SERVER_HOST=192.168.1.100
export QMT_SERVER_PORT=58620
export QMT_SERVER_TOKEN=your_token  # 如果设置了 token

# 运行策略
bullet-trade live strategy.py --broker qmt-remote
```

## 验证安装

```bash
# 检查 bullet-trade 版本
pip show bullet-trade

# 检查命令是否可用
bullet-trade --version

# 查看帮助
bullet-trade --help
bullet-trade live --help
```

## 常见问题

### 问题 1: 连接超时

```bash
# 检查网络连通性
ping 192.168.1.100

# 检查端口
nc -zv 192.168.1.100 58620

# 检查防火墙
sudo ufw status
```

### 问题 2: 模块未找到

```bash
# 确保虚拟环境已激活
source venv/bin/activate

# 重新安装
pip install --force-reinstall bullet-trade
```

### 问题 3: 权限问题

```bash
# 给脚本添加执行权限
chmod +x ubuntu_bullettrade_quick_start.sh
chmod +x ubuntu_test_connection.py
```

## 完整示例：从零开始

```bash
# 完整流程（复制粘贴执行，记得修改 IP）
WINDOWS_IP="192.168.1.100"  # 修改为实际 IP

# 1. 创建目录
mkdir -p ~/bullettrade_client && cd ~/bullettrade_client

# 2. 创建虚拟环境
python3 -m venv venv && source venv/bin/activate

# 3. 安装
pip install --upgrade pip bullet-trade

# 4. 配置
cat > .env << EOF
QMT_SERVER_HOST=$WINDOWS_IP
QMT_SERVER_PORT=58620
DEFAULT_DATA_PROVIDER=qmt-remote
EOF

# 5. 测试
python3 -c "
import socket, os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv()
h, p = os.getenv('QMT_SERVER_HOST'), int(os.getenv('QMT_SERVER_PORT', 58620))
s = socket.socket(); s.settimeout(5)
print('✓ 连接成功' if s.connect_ex((h, p)) == 0 else '✗ 连接失败')
s.close()
"

# 6. 创建策略
cat > strategy.py << 'PYEOF'
from bullet_trade.compat.api import *
def initialize(context):
    set_benchmark('000300.XSHG')
    g.security = '510300.XSHG'
    run_daily(trade, 'every_bar')
def trade(context):
    if g.security not in context.portfolio.positions:
        order_value(g.security, context.portfolio.available_cash)
PYEOF

# 7. 运行（回测）
bullet-trade backtest strategy.py --start 2024-01-01 --end 2024-12-01
```

## 参考

- 详细文档: [UBUNTU_BULLETTRADE_CLIENT_SETUP.md](./UBUNTU_BULLETTRADE_CLIENT_SETUP.md)
- Windows 端配置: [BULLETTRADE_SERVER_SETUP.md](./BULLETTRADE_SERVER_SETUP.md)
