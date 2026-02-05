# TRQuant 中美协作同步仓库

## 用途

本仓库仅用于 Windows（中国）和 Ubuntu（美国）两台机器之间的协作同步。

**只同步协作相关文件，不包含项目代码。**

## 同步内容

### 协作脚本
- `scripts/git_sync_windows.ps1` - Windows 端同步脚本
- `scripts/git_sync_ubuntu.sh` - Ubuntu 端同步脚本
- `scripts/start_bullettrade_server.ps1` - BulletTrade Server 启动脚本

### 协作文档
- `docs/GIT_COLLABORATION_SETUP.md` - Git 协作配置指南
- `docs/BULLETTRADE_SERVER_SETUP.md` - BulletTrade Server 启动指南
- `docs/UBUNTU_BULLETTRADE_CLIENT_SETUP.md` - Ubuntu 客户端配置指南
- `docs/UBUNTU_QUICK_START.md` - Ubuntu 快速启动指南

### Ubuntu 端文件
- `docs/ubuntu_bullettrade_quick_start.sh` - Ubuntu 快速配置脚本
- `docs/ubuntu_test_connection.py` - 连接测试脚本
- `docs/ubuntu_example_strategy.py` - 示例策略

### 配置模板
- `config/*.example` - 配置模板文件

## 使用说明

### Windows 端

```powershell
# 拉取最新
git pull origin windows-server

# 提交并推送
git add .
git commit -m "更新说明"
git push origin windows-server
```

### Ubuntu 端

```bash
# 克隆仓库
git clone https://github.com/ZhuTechLLC/trquant_sync.git
cd trquant_sync

# 拉取最新
git pull origin windows-server

# 提交并推送（创建 ubuntu-client 分支）
git checkout -b ubuntu-client
git add .
git commit -m "更新说明"
git push origin ubuntu-client
```

## 注意事项

1. **不要提交项目代码**：只同步协作相关文件
2. **不要提交敏感信息**：`.env`、`*.json` 等配置文件不提交
3. **使用配置模板**：提交 `*.example` 文件作为模板
