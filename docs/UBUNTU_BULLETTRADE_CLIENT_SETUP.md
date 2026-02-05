# Ubuntu 工作站调用 BulletTrade Server 指南

## 概述

本指南说明如何从美国 Ubuntu 工作站连接到 Windows 机器上运行的 BulletTrade Server，实现远程调用 miniQMT 进行交易和数据获取。

## 架构图

```
┌─────────────────┐         TCP/IP          ┌──────────────────┐
│  Ubuntu 工作站   │  ←──────────────────→  │  Windows 机器     │
│  (美国)         │    Port 58620          │  (运行 miniQMT)   │
│                 │                         │                  │
│  - 运行策略      │                         │  - BulletTrade   │
│  - 回测分析      │                         │    Server        │
│  - 数据获取      │                         │  - miniQMT        │
└─────────────────┘                         └──────────────────┘
```

## 前置条件

### Windows 端（必须完成）

1. ✅ BulletTrade Server 已启动并监听 `0.0.0.0:58620`
2. ✅ miniQMT 正在运行
3. ✅ 防火墙已开放端口 58620
4. ✅ 网络可达（Ubuntu 可以访问 Windows 机器的 IP）

### Ubuntu 端（需要准备）

1. Python 3.8+ 环境
2. 安装 bullet-trade
3. 配置远程服务器地址

## 步骤 1: 安装 BulletTrade

在 Ubuntu 工作站上安装 bullet-trade：

```bash
# 创建虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate

# 安装 bullet-trade
pip install bullet-trade
```

## 步骤 2: 配置远程服务器

### 方式 1: 使用环境变量（推荐）

创建 `.env` 文件：

```bash
# .env 文件
# 配置远程 BulletTrade Server
QMT_SERVER_HOST=你的Windows机器IP地址
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token  # 如果Windows端设置了token

# 数据源配置
DEFAULT_DATA_PROVIDER=qmt-remote
```

**获取 Windows 机器 IP**：

在 Windows 机器上运行：
```powershell
ipconfig
# 查找 IPv4 地址，例如：192.168.1.100
```

### 方式 2: 在代码中配置

```python
import os

# 配置远程 QMT Server
os.environ['QMT_SERVER_HOST'] = '你的Windows机器IP'
os.environ['QMT_SERVER_PORT'] = '58620'
os.environ['QMT_SERVER_TOKEN'] = 'your_secret_token'  # 如果设置了token
```

## 步骤 3: 测试连接

### 测试 1: 检查网络连通性

```bash
# 在 Ubuntu 上测试端口是否可达
telnet 你的Windows机器IP 58620

# 或使用 nc (netcat)
nc -zv 你的Windows机器IP 58620
```

### 测试 2: 使用 Python 测试连接

创建测试脚本 `test_connection.py`：

```python
import os
import socket

# 配置
host = '你的Windows机器IP'
port = 58620

# 测试连接
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    result = sock.connect_ex((host, port))
    sock.close()
    
    if result == 0:
        print(f"✅ 连接成功: {host}:{port}")
    else:
        print(f"❌ 连接失败: {host}:{port}")
except Exception as e:
    print(f"❌ 连接错误: {e}")
```

运行测试：
```bash
python test_connection.py
```

## 步骤 4: 运行策略

### 方式 1: 使用 bullet-trade live（实盘）

```bash
# 使用 qmt-remote broker
bullet-trade live your_strategy.py --broker qmt-remote
```

### 方式 2: 在代码中使用

```python
from bullet_trade.compat.api import *

# 策略代码（聚宽格式）
def initialize(context):
    # 配置远程 QMT Server（如果未在 .env 中配置）
    import os
    os.environ['QMT_SERVER_HOST'] = '你的Windows机器IP'
    os.environ['QMT_SERVER_PORT'] = '58620'
    
    # 设置基准
    set_benchmark('000300.XSHG')
    
    # 订阅股票
    g.security = '510300.XSHG'
    run_daily(trade, 'every_bar')

def trade(context):
    # 交易逻辑
    if g.security not in context.portfolio.positions:
        order_value(g.security, context.portfolio.available_cash)
```

运行：
```bash
bullet-trade live strategy.py --broker qmt-remote
```

### 方式 3: 回测（使用远程数据）

```bash
bullet-trade backtest your_strategy.py \
    --start 2024-01-01 \
    --end 2024-12-01 \
    --data-provider qmt-remote
```

## 步骤 5: 验证连接

### 检查账户信息

创建测试脚本 `test_account.py`：

```python
import os
os.environ['QMT_SERVER_HOST'] = '你的Windows机器IP'
os.environ['QMT_SERVER_PORT'] = '58620'

from bullet_trade.compat.api import *

def initialize(context):
    # 获取账户信息
    portfolio = context.portfolio
    print(f"总资产: {portfolio.total_value}")
    print(f"可用资金: {portfolio.available_cash}")
    print(f"持仓: {portfolio.positions}")

# 运行一次初始化
class MockContext:
    def __init__(self):
        self.portfolio = type('obj', (object,), {
            'total_value': 0,
            'available_cash': 0,
            'positions': {}
        })()

ctx = MockContext()
initialize(ctx)
```

## 常见问题排查

### 问题 1: 连接超时

**症状**: `Connection timeout` 或 `Connection refused`

**排查步骤**:
1. 检查 Windows 防火墙是否开放端口 58620
2. 确认 BulletTrade Server 正在运行
3. 验证 IP 地址是否正确
4. 检查网络路由是否可达

**Windows 防火墙配置**:
```powershell
# 允许端口 58620
New-NetFirewallRule -DisplayName "BulletTrade Server" -Direction Inbound -LocalPort 58620 -Protocol TCP -Action Allow
```

### 问题 2: 认证失败

**症状**: `Authentication failed` 或 `Invalid token`

**解决方案**:
1. 确认 Ubuntu 端的 `QMT_SERVER_TOKEN` 与 Windows 端启动时的 `--token` 参数一致
2. 如果 Windows 端未设置 token，Ubuntu 端也不要设置

### 问题 3: 数据获取失败

**症状**: `Data fetch failed` 或 `No data available`

**排查步骤**:
1. 确认 miniQMT 在 Windows 端正常运行
2. 检查 BulletTrade Server 日志（Windows 端）
3. 验证账户配置是否正确

### 问题 4: 交易下单失败

**症状**: `Order failed` 或 `Broker not available`

**排查步骤**:
1. 确认 BulletTrade Server 启动时使用了 `--enable-broker`
2. 检查账户配置 `--accounts` 是否正确
3. 查看 Windows 端日志

## 安全建议

### 1. 使用 Token 认证

在 Windows 端启动时设置 token：
```powershell
--token "your_strong_secret_token"
```

在 Ubuntu 端配置相同的 token：
```bash
QMT_SERVER_TOKEN=your_strong_secret_token
```

### 2. 使用 IP 白名单

在 Windows 端启动时限制允许连接的 IP：
```powershell
--allowlist "你的Ubuntu机器IP"
```

### 3. 使用 VPN 或内网

如果可能，使用 VPN 或内网连接，避免暴露在公网。

### 4. 启用 TLS（可选）

生产环境建议启用 TLS 加密：
```powershell
--tls-cert /path/to/cert.pem --tls-key /path/to/key.pem
```

## 完整示例

### Ubuntu 端完整配置示例

**1. 创建项目目录**:
```bash
mkdir ~/bullettrade_client
cd ~/bullettrade_client
```

**2. 创建虚拟环境**:
```bash
python3 -m venv venv
source venv/bin/activate
```

**3. 安装依赖**:
```bash
pip install bullet-trade
```

**4. 创建 `.env` 文件**:
```bash
cat > .env << EOF
# 远程 BulletTrade Server 配置
QMT_SERVER_HOST=192.168.1.100  # 替换为你的Windows机器IP
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token  # 如果设置了token

# 数据源
DEFAULT_DATA_PROVIDER=qmt-remote
EOF
```

**5. 创建策略文件 `strategy.py`**:
```python
from bullet_trade.compat.api import *

def initialize(context):
    set_benchmark('000300.XSHG')
    g.security = '510300.XSHG'
    run_daily(trade, 'every_bar')

def trade(context):
    if g.security not in context.portfolio.positions:
        order_value(g.security, context.portfolio.available_cash)
```

**6. 运行策略**:
```bash
# 回测
bullet-trade backtest strategy.py --start 2024-01-01 --end 2024-12-01

# 实盘（需要确保Windows端Server正在运行）
bullet-trade live strategy.py --broker qmt-remote
```

## 监控和日志

### 查看连接状态

在 Ubuntu 端，可以通过以下方式监控：

```python
import os
import requests

host = os.getenv('QMT_SERVER_HOST', 'localhost')
port = os.getenv('QMT_SERVER_PORT', '58620')

try:
    response = requests.get(f'http://{host}:{port}/health', timeout=5)
    print(f"Server状态: {response.status_code}")
except Exception as e:
    print(f"连接失败: {e}")
```

### 查看 Windows 端日志

在 Windows 机器上查看 BulletTrade Server 日志：
```powershell
Get-Content .\qmt_server.log -Tail 50 -Wait
```

## 参考资源

- [BulletTrade 官方文档](https://bullettrade.cn/docs/)
- [BulletTrade Server 启动指南](./BULLETTRADE_SERVER_SETUP.md)
- [BulletTrade GitHub](https://github.com/BulletTrade/bullet-trade)

## 快速命令参考

```bash
# 安装
pip install bullet-trade

# 测试连接
nc -zv 你的Windows机器IP 58620

# 运行回测
bullet-trade backtest strategy.py --start 2024-01-01 --end 2024-12-01

# 运行实盘
bullet-trade live strategy.py --broker qmt-remote

# 查看帮助
bullet-trade --help
bullet-trade live --help
```
