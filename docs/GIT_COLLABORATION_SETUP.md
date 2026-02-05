# Git 协作配置 - 中美两台机器协作方案

## 概述

使用 Git 实现 Windows（中国）和 Ubuntu（美国）两台机器之间的代码同步和协作。

## 架构

```
┌─────────────────┐         Git         ┌──────────────────┐
│  Windows 机器   │  ←──────────────→  │  Ubuntu 机器      │
│  (中国)         │   Push/Pull        │  (美国)           │
│                 │                     │                  │
│  - BulletTrade  │                     │  - BulletTrade   │
│    Server       │                     │    Client        │
│  - 策略开发      │                     │  - 策略运行       │
└─────────────────┘                     └──────────────────┘
         │                                       │
         └───────────────┬───────────────────────┘
                         │
                  ┌──────▼──────┐
                  │  Git 仓库   │
                  │ (GitHub/    │
                  │  GitLab/    │
                  │  本地服务器) │
                  └─────────────┘
```

## 方案选择

### 方案 1: GitHub/GitLab（推荐，适合公网）

**优点**:
- 无需额外服务器
- 自动备份
- 支持 PR/Issue 协作
- 免费（公开仓库）

**缺点**:
- 需要网络连接
- 敏感信息需要加密

### 方案 2: 本地 Git 服务器（适合内网）

**优点**:
- 完全控制
- 速度快
- 数据安全

**缺点**:
- 需要额外服务器
- 需要配置维护

### 方案 3: 直接 SSH 同步（简单场景）

**优点**:
- 简单直接
- 无需中间仓库

**缺点**:
- 需要 SSH 访问
- 不适合复杂协作

## 快速开始（GitHub 方案）

### 步骤 1: 创建 GitHub 仓库

```bash
# 在 GitHub 上创建新仓库（或使用现有仓库）
# 仓库名: bullettrade-collaboration
```

### 步骤 2: Windows 端配置

```powershell
# 在 Windows 机器上
cd C:\Users\Administrator\.cursor\worktrees\trq

# 初始化 git（如果还没有）
git init

# 添加远程仓库
git remote add origin https://github.com/your-username/bullettrade-collaboration.git

# 创建协作分支
git checkout -b windows-server
git checkout -b ubuntu-client

# 创建 .gitignore
cat > .gitignore << 'EOF'
# 环境配置（敏感信息）
.env
*.log
*.pkl
*.pyc
__pycache__/
venv/
.venv/

# 数据文件
data/
output/
logs/

# 但保留配置模板
!config/*.example
!*.example
EOF

# 提交初始配置
git add .gitignore
git commit -m "Initial collaboration setup"
git push -u origin windows-server
```

### 步骤 3: Ubuntu 端配置

```bash
# 在 Ubuntu 机器上
cd ~/bullettrade_client

# 克隆仓库
git clone https://github.com/your-username/bullettrade-collaboration.git
cd bullettrade-collaboration

# 切换到 Ubuntu 分支
git checkout -b ubuntu-client origin/ubuntu-client

# 创建本地配置
cp .env.example .env
# 编辑 .env 文件，填入 Windows 机器 IP
```

## 协作工作流

### 工作流 1: 代码同步

```bash
# Windows 端：推送代码
git add .
git commit -m "Update: Windows server configuration"
git push origin windows-server

# Ubuntu 端：拉取代码
git pull origin windows-server
```

### 工作流 2: 配置同步

```bash
# Windows 端：更新配置模板
git add config/*.example
git commit -m "Update: Server config template"
git push origin windows-server

# Ubuntu 端：应用配置
git pull origin windows-server
cp config/server.example .env
# 编辑 .env 填入实际配置
```

### 工作流 3: 策略同步

```bash
# Ubuntu 端：开发策略
git checkout -b feature/new-strategy
# 编辑策略文件
git add strategies/
git commit -m "Add: New trading strategy"
git push origin feature/new-strategy

# Windows 端：拉取策略
git fetch origin
git checkout feature/new-strategy
```

## 自动化脚本

### Windows 端：自动同步脚本

创建 `scripts/git_sync_windows.ps1`:

```powershell
# Git 同步脚本 - Windows 端
param(
    [string]$Message = "Auto sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [string]$Branch = "windows-server"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Git 同步 - Windows 端" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 git 状态
Write-Host "[1/4] 检查 Git 状态..." -ForegroundColor Yellow
$status = git status --porcelain
if ($status) {
    Write-Host "发现未提交的更改:" -ForegroundColor Yellow
    git status --short
    
    # 添加所有更改
    Write-Host "[2/4] 添加更改..." -ForegroundColor Yellow
    git add .
    
    # 提交
    Write-Host "[3/4] 提交更改..." -ForegroundColor Yellow
    git commit -m $Message
    
    # 推送
    Write-Host "[4/4] 推送到远程..." -ForegroundColor Yellow
    git push origin $Branch
    
    Write-Host "✓ 同步完成" -ForegroundColor Green
} else {
    Write-Host "✓ 没有未提交的更改" -ForegroundColor Green
    
    # 拉取远程更改
    Write-Host "[2/2] 拉取远程更改..." -ForegroundColor Yellow
    git pull origin $Branch
    Write-Host "✓ 同步完成" -ForegroundColor Green
}

Write-Host ""
Write-Host "当前分支: $(git branch --show-current)" -ForegroundColor Cyan
Write-Host "最新提交: $(git log -1 --oneline)" -ForegroundColor Cyan
```

### Ubuntu 端：自动同步脚本

创建 `scripts/git_sync_ubuntu.sh`:

```bash
#!/bin/bash
# Git 同步脚本 - Ubuntu 端

MESSAGE="${1:-Auto sync: $(date '+%Y-%m-%d %H:%M:%S')}"
BRANCH="${2:-ubuntu-client}"

echo "========================================"
echo "Git 同步 - Ubuntu 端"
echo "========================================"
echo ""

# 检查 git 状态
echo "[1/4] 检查 Git 状态..."
if [ -n "$(git status --porcelain)" ]; then
    echo "发现未提交的更改:"
    git status --short
    
    # 添加所有更改
    echo "[2/4] 添加更改..."
    git add .
    
    # 提交
    echo "[3/4] 提交更改..."
    git commit -m "$MESSAGE"
    
    # 推送
    echo "[4/4] 推送到远程..."
    git push origin "$BRANCH"
    
    echo "✓ 同步完成"
else
    echo "✓ 没有未提交的更改"
    
    # 拉取远程更改
    echo "[2/2] 拉取远程更改..."
    git pull origin "$BRANCH"
    echo "✓ 同步完成"
fi

echo ""
echo "当前分支: $(git branch --show-current)"
echo "最新提交: $(git log -1 --oneline)"
```

## 配置文件管理

### 创建配置模板

```bash
# Windows 端：创建服务器配置模板
cat > config/server.example << 'EOF'
# BulletTrade Server 配置模板
# Windows 端使用

QMT_SERVER_LISTEN=0.0.0.0
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token_here

# 账户配置
QMT_ACCOUNT_ID=8885019982
QMT_ACCOUNT_TYPE=stock
QMT_DATA_PATH=D:\gjzqQMT\userdata_mini

# 日志配置
LOG_FILE=.\qmt_server.log
LOG_LEVEL=INFO
EOF

# Ubuntu 端：创建客户端配置模板
cat > config/client.example << 'EOF'
# BulletTrade Client 配置模板
# Ubuntu 端使用

# 远程服务器配置
QMT_SERVER_HOST=192.168.1.100  # Windows 机器 IP
QMT_SERVER_PORT=58620
QMT_SERVER_TOKEN=your_secret_token_here

# 数据源配置
DEFAULT_DATA_PROVIDER=qmt-remote

# 策略配置
STRATEGY_PATH=strategies/
BACKTEST_OUTPUT=backtest_results/
EOF
```

## 状态同步

### 创建状态文件

```bash
# Windows 端：服务器状态
cat > .git/status_windows.json << 'EOF'
{
  "server": {
    "running": true,
    "port": 58620,
    "started_at": "2026-02-05T15:00:00Z",
    "connections": 0
  },
  "miniqmt": {
    "running": true,
    "process_id": 40096
  },
  "last_update": "2026-02-05T15:00:00Z"
}
EOF

# Ubuntu 端：客户端状态
cat > .git/status_ubuntu.json << 'EOF'
{
  "client": {
    "connected": true,
    "server_host": "192.168.1.100",
    "server_port": 58620,
    "last_connection": "2026-02-05T15:00:00Z"
  },
  "strategies": {
    "running": 0,
    "last_run": "2026-02-05T14:50:00Z"
  },
  "last_update": "2026-02-05T15:00:00Z"
}
EOF
```

## 协作检查清单

### 日常协作流程

```bash
# 1. 开始工作前
git pull origin main  # 拉取最新代码

# 2. 开发/修改
# ... 进行开发工作 ...

# 3. 提交更改
git add .
git commit -m "描述你的更改"
git push origin your-branch

# 4. 通知对方（通过 Issue 或 PR）
# 创建 Pull Request 或 Issue
```

### 冲突解决

```bash
# 如果出现冲突
git pull origin main
# 解决冲突
git add .
git commit -m "Resolve conflicts"
git push origin your-branch
```

## 安全建议

### 1. 敏感信息处理

```bash
# 使用 git-secret 加密敏感文件
# 安装
pip install git-secret

# 初始化
git-secret init

# 添加要加密的文件
git-secret add .env
git-secret hide

# 解密（在另一台机器）
git-secret reveal
```

### 2. 使用环境变量

```bash
# 不在代码中硬编码敏感信息
# 使用环境变量或配置文件（不提交到 git）
```

### 3. 使用 GitHub Secrets（GitHub Actions）

```yaml
# .github/workflows/sync.yml
name: Sync Status
on:
  schedule:
    - cron: '*/5 * * * *'  # 每5分钟
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Sync
        env:
          SERVER_TOKEN: ${{ secrets.SERVER_TOKEN }}
        run: |
          # 同步脚本
```

## 完整示例

### Windows 端完整设置

```powershell
# 1. 初始化仓库
cd C:\Users\Administrator\.cursor\worktrees\trq
git init
git remote add origin https://github.com/your-username/bullettrade-collaboration.git

# 2. 创建分支
git checkout -b windows-server

# 3. 创建配置模板
New-Item -ItemType Directory -Force -Path config
Copy-Item .env config\server.example -Force
# 编辑 server.example，移除敏感信息

# 4. 提交
git add .
git commit -m "Initial Windows server setup"
git push -u origin windows-server

# 5. 设置自动同步（可选）
# 添加到计划任务，每小时同步一次
```

### Ubuntu 端完整设置

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/bullettrade-collaboration.git
cd bullettrade-collaboration

# 2. 创建分支
git checkout -b ubuntu-client

# 3. 创建本地配置
cp config/client.example .env
# 编辑 .env，填入实际配置

# 4. 提交（不提交 .env）
git add .
git commit -m "Initial Ubuntu client setup"
git push -u origin ubuntu-client

# 5. 设置自动同步（可选）
# 添加到 crontab，每小时同步一次
# 0 * * * * cd ~/bullettrade-collaboration && ./scripts/git_sync_ubuntu.sh
```

## 参考

- [Git 官方文档](https://git-scm.com/doc)
- [GitHub 协作指南](https://docs.github.com/en/get-started/quickstart)
- [Git 工作流](https://www.atlassian.com/git/tutorials/comparing-workflows)
