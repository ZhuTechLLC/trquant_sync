# GitOps 远程控制 Windows（BulletTrade/QMT）机制

目标：Linux 侧**不手动登录 Windows**，通过 git/脚本下发指令并获取 Windows 端信息（端口监听、日志尾部、health、启动/停止 server 等）。

核心思路：Windows 端常驻一个 `windows_ops_agent.ps1`：

- `git pull` 拉取 `ops/queue/*.json` 指令
- 执行 allowlist 动作（不执行任意命令，避免安全风险）
- 写入 `ops/results/<id>.json` 结果并 `git push`

## 1. 目录约定

- `ops/queue/`：Linux 侧下发请求（JSON），Windows agent 消费
- `ops/results/`：Windows agent 写回结果（JSON）

## 2. Windows 端：启动 Agent（一次性配置成开机自启）

前置：
- Windows 已 clone 本仓库并能 `git pull/push`（建议 PAT 或 SSH）
- PowerShell 可运行脚本（ExecutionPolicy 允许）

### 手动启动（验证用）

在仓库根目录运行：

```powershell
.\scripts\windows_ops_agent.ps1 -RepoDir . -Branch windows-server -PollSeconds 5
```

### 开机自启（建议用计划任务）

创建计划任务（示例思路）：
- 触发器：At startup
- 动作：`powershell.exe -ExecutionPolicy Bypass -File <repo>\scripts\windows_ops_agent.ps1 -RepoDir <repo> -Branch windows-server -PollSeconds 5`
- 账户：用有权限访问 repo 的用户

## 3. Linux 端：下发指令

Linux 侧同样 clone 本仓库，并能 push 到 `windows-server` 分支。

使用脚本下发：

```bash
./scripts/linux_enqueue_ops.sh probe
./scripts/linux_enqueue_ops.sh netstat --port 58620
./scripts/linux_enqueue_ops.sh tail_log --path .\\qmt_server.log --lines 120
./scripts/linux_enqueue_ops.sh health --port 58620
./scripts/linux_enqueue_ops.sh start_server --port 58620 --listen 0.0.0.0 --log_file .\\qmt_server.log
./scripts/linux_enqueue_ops.sh stop_server
```

脚本会输出 request_id，例如：`20260205_030000_abcd1234`

随后：
- `git pull origin windows-server`
- 查看 `ops/results/<request_id>.json`

## 4. 支持的动作（allowlist）

- `probe`：ipconfig + 关键进程快照
- `netstat`：检查端口监听（默认 58620）
- `tail_log`：读取日志末尾（默认 `.\qmt_server.log`）
- `health`：访问 `http://127.0.0.1:<port>/health`
- `start_server`：后台启动 `scripts/start_bullettrade_server.ps1`
- `stop_server`：best-effort 停止 bullet_trade server 相关进程

## 5. 安全注意事项

- **不要把 token/密码写进 queue**。建议 token 由 Windows 本地 `.env` 管理。
- agent 不执行任意命令，只有 allowlist 动作；未知 action 会返回错误。
- `ops/results/` 可能包含 Windows 网络与日志片段，注意权限与保密。

