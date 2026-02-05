# BulletTrade Server 启动指南

## 概述

BulletTrade Server 允许从远程机器（如美国 Ubuntu 工作站）调用本地 Windows 机器上的 miniQMT 进行交易和数据获取。

## 快速启动

### 方式1：使用启动脚本（推荐）

```powershell
# 基本启动（使用默认配置）
.\scripts\start_bullettrade_server.ps1

# 自定义端口和 token
.\scripts\start_bullettrade_server.ps1 -Port 58620 -Token "your_secret_token"

# 自定义账户配置
.\scripts\start_bullettrade_server.ps1 -Accounts "main=8885019982:stock:D:\gjzqQMT\userdata_mini"
```

### 方式2：直接使用 Python 命令

```powershell
.\.venv\Scripts\python.exe -m bullet_trade server `
    --server-type qmt `
    --listen 0.0.0.0 `
    --port 58620 `
    --enable-data `
    --enable-broker `
    --access-log `
    --log-file .\qmt_server.log `
    --accounts "main=8885019982:stock:D:\gjzqQMT\userdata_mini" `
    --env-file .env
```

### 方式3：使用环境变量

在 `.env` 文件中配置：

```env
DEFAULT_DATA_PROVIDER=qmt
QMT_SERVER_LISTEN=0.0.0.0
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token
```

然后运行：

```powershell
.\.venv\Scripts\python.exe -m bullet_trade server --env-file .env
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--server-type` | 服务器类型 | `qmt` |
| `--listen` | 监听地址 | `0.0.0.0` (所有网络接口) |
| `--port` | 监听端口 | `58620` |
| `--token` | 访问令牌（可选，但建议设置） | 无 |
| `--enable-data` | 启用数据服务 | 启用 |
| `--enable-broker` | 启用券商服务 | 启用 |
| `--access-log` | 启用访问日志 | 启用 |
| `--log-file` | 日志文件路径 | `.\qmt_server.log` |
| `--accounts` | 账户配置 | `main=8885019982:stock:D:\gjzqQMT\userdata_mini` |
| `--env-file` | 环境变量文件 | `.env` |

## 账户配置格式

`--accounts` 参数的格式：

```
账户名=账户号:市场类型:数据目录
```

示例：

```
main=8885019982:stock:D:\gjzqQMT\userdata_mini
```

多个账户用逗号分隔：

```
main=8885019982:stock:D:\gjzqQMT\userdata_mini,hedge=8885019983:stock:D:\gjzqQMT\userdata_mini
```

## 远程连接配置

### 在 Ubuntu 工作站上配置

1. **安装 bullet-trade**：

```bash
pip install bullet-trade
```

2. **配置远程连接**：

在策略代码中或 `.env` 文件中：

```python
# 方式1：在代码中配置
from bullet_trade.compat.api import *

# 配置远程 QMT Server
os.environ['QMT_SERVER_HOST'] = '你的Windows机器IP'
os.environ['QMT_SERVER_PORT'] = '58620'
os.environ['QMT_SERVER_TOKEN'] = 'your_secret_token'  # 如果设置了token
```

```env
# 方式2：在 .env 文件中配置
QMT_SERVER_HOST=192.168.1.100
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token
```

3. **运行策略**：

```bash
bullet-trade live your_strategy.py --broker qmt-remote
```

## 安全建议

1. **设置 Token**：强烈建议设置 `--token` 参数，防止未授权访问
2. **防火墙配置**：只开放必要的端口（58620）
3. **IP 白名单**：使用 `--allowlist` 参数限制允许连接的 IP
4. **使用 TLS**：生产环境建议使用 `--tls-cert` 和 `--tls-key` 启用 HTTPS

示例（带安全配置）：

```powershell
.\.venv\Scripts\python.exe -m bullet_trade server `
    --server-type qmt `
    --listen 0.0.0.0 `
    --port 58620 `
    --token "your_strong_secret_token" `
    --allowlist "192.168.1.0/24,10.0.0.0/8" `
    --enable-data `
    --enable-broker `
    --access-log `
    --log-file .\qmt_server.log `
    --accounts "main=8885019982:stock:D:\gjzqQMT\userdata_mini"
```

## 验证服务运行

### 检查服务状态

```powershell
# 检查端口是否监听
netstat -an | findstr 58620

# 查看日志
Get-Content .\qmt_server.log -Tail 50
```

### 测试连接

在 Ubuntu 工作站上：

```python
import requests

# 测试连接（如果设置了token，需要在header中传递）
response = requests.get(f'http://你的Windows机器IP:58620/health')
print(response.json())
```

## 常见问题

### 1. 找不到 bullet-trade 命令

**问题**：`bullet-trade.exe` 不存在

**解决**：使用 Python 模块方式运行：

```powershell
.\.venv\Scripts\python.exe -m bullet_trade server ...
```

### 2. 端口被占用

**问题**：`Address already in use`

**解决**：更换端口或关闭占用端口的程序：

```powershell
# 查找占用端口的进程
netstat -ano | findstr 58620

# 关闭进程（替换 PID）
taskkill /PID <PID> /F
```

### 3. 无法从远程连接

**问题**：Ubuntu 工作站无法连接到 Windows 机器

**解决**：
1. 检查 Windows 防火墙是否允许端口 58620
2. 确认 `--listen` 参数设置为 `0.0.0.0`（不是 `127.0.0.1`）
3. 检查网络连接和 IP 地址

### 4. miniQMT 未启动

**问题**：Server 启动但无法连接 QMT

**解决**：确保 miniQMT 已启动并正常运行：

```powershell
# 检查 miniQMT 进程
Get-Process | Where-Object {$_.ProcessName -like "*QMT*"}
```

## 日志查看

日志文件位置：`.\qmt_server.log`

查看实时日志：

```powershell
Get-Content .\qmt_server.log -Wait -Tail 50
```

## 后台运行（Windows）

使用 PowerShell 后台运行：

```powershell
Start-Process powershell -ArgumentList "-File .\scripts\start_bullettrade_server.ps1" -WindowStyle Hidden
```

或使用 `nssm`（Non-Sucking Service Manager）将其注册为 Windows 服务。

## 参考资源

- [BulletTrade 官方文档](https://bullettrade.cn/docs/)
- [BulletTrade GitHub](https://github.com/BulletTrade/bullet-trade)
