# GitOps 状态说明（Linux ↔ Windows）

## 0. PAT / Token 是什么？和 Git 怎么配合？

- **PAT** = **Personal Access Token**（个人访问令牌），就是你在 GitHub 里生成的那一串 token。**你给过的那串就是 PAT**，不需要再搞一个“新 PAT”；我说“新 PAT”是指：如果你担心旧 token 泄露过，可以在 GitHub 里撤销旧的、再生成一个新的替换用。
- **和 Git 的关系**：用 HTTPS 克隆/推送时，Git 要验证身份。把 token 填进 remote 的 URL 里，Git 就会用这个 token 去访问 GitHub，不需要再输密码。

## 1. 用你已有的 Token 在 Linux 正确 push（推荐步骤）

在 **Linux** 上打开终端，按顺序执行（把 `你的token` 换成你真实的那串，不要有空格）：

```bash
cd /home/taotao/.cursor/worktrees/trq/workspace/trquant_sync

# 1）把 token 写进 origin 的 URL（这样 push 时就会用这个 token）
git remote set-url origin "https://你的token@github.com/ZhuTechLLC/trquant_sync.git"

# 2）推送当前分支到远程
git push origin windows-server

# 3）推送完成后，把 URL 改回不含 token（安全，避免 token 被 git config 存着）
git remote set-url origin "https://github.com/ZhuTechLLC/trquant_sync.git"
```

- 若第 2 步报错 `Authentication failed`，说明 token 无效或已过期，需到 GitHub → Settings → Developer settings → Personal access tokens 检查/重新生成。
- 若第 2 步报错 `could not read Username`，多半是第 1 步没执行或路径不对，确保在 `trquant_sync` 目录下执行。

## 2. 其他 Git 凭据方式（可选）

- **已执行过的操作**：之前用你提供的 token 临时设置了 `trquant_sync` 的 remote URL 并完成了一次 push，**push 后已从 URL 中移除 token**。
- **当前**：若在 Linux 上再次执行 `git push`，按上面「1」把 token 设进 URL 再 push 即可。
- 若不想把 token 写进 URL，可用 Git 凭据存储：`git config credential.helper store`，然后第一次 push 时输入用户名（任意）和 token（当密码），之后会本地保存。

## 3. 两侧开发是否完成

| 端 | 状态 | 说明 |
|----|------|------|
| **Linux** | ✅ 已完成 | `scripts/linux_enqueue_ops.sh` 可投递 netstat / tail_log / health / start_server / stop_server 等指令；已投递过 netstat、tail_log、health，以及 start_server（见下方）。 |
| **Windows** | ⏳ 需你本地执行一次 | 脚本和目录已通过 Git 推到 `windows-server` 分支；需在 **Windows 本机** 做一次拉取并运行 Agent。 |

## 4. Windows 端必须执行的一次性步骤

在 **Windows** 上打开 PowerShell，进入 **trquant_sync** 仓库目录后执行：

1. **拉取最新代码（含 ops/queue 和 Agent 脚本）**
   ```powershell
   cd D:\path\to\trquant_sync   # 换成你的实际路径
   git fetch origin
   git checkout windows-server
   git pull origin windows-server
   ```

2. **启动 Windows 运维 Agent（轮询执行 queue 中的指令并把结果写到 ops/results）**
   ```powershell
   .\scripts\windows_ops_agent.ps1 -RepoDir . -Branch windows-server -PollSeconds 5
   ```
   - 保持该窗口运行，Agent 会每 5 秒检查 `ops/queue`，执行新任务并把结果写入 `ops/results/*.json`。
   - 若希望开机自动执行，可将上述命令加入计划任务（Task Scheduler）。

3. **（可选）提交并推送 results 回远程**
   - Agent 只会在本地写入 `ops/results/*.json`；若要让 Linux 端看到结果，需在 Windows 上手动执行：
     ```powershell
     git add ops/results/*.json
     git commit -m "ops: results from agent"
     git push origin windows-server
     ```
   - 之后在 Linux 上 `git pull origin windows-server` 即可看到 `ops/results/` 下的诊断结果。

## 5. 已入队指令与 start_server

- 已入队并随上次 push 推送到 `windows-server` 的指令包括：
  - `netstat`（port 58620）
  - `tail_log`（qmt_server.log）
  - `health`（port 58620）
- 本次会再入队一条 **start_server** 指令：用于在 Windows 上启动 BulletTrade QMT 服务（脚本会调用 `scripts/start_bullettrade_server.ps1`）。  
- **执行顺序**：Windows 上先拉取再启动 Agent 后，Agent 会按 queue 中文件顺序依次执行；若希望先看诊断再决定是否启动服务，可先只拉取、运行 Agent 处理 netstat/tail_log/health，再在 Linux 上入队 start_server 并 push。

## 6. 当前 Linux 端 push 状态

- 最近一次在 Linux 上执行 `./scripts/linux_enqueue_ops.sh start_server` 时，**push 失败**（`fatal: could not read Username for 'https://github.com'`），说明当前环境**未配置 Git 凭据**。
- **start_server 已在本机入队**，对应文件：`ops/queue/20260205_034030_6f4b941c.json`。
- 你在 Linux 上配置好 token 后，在 trquant_sync 目录执行：
  ```bash
  git add ops/queue/20260205_034030_6f4b941c.json docs/GITOPS_STATUS.md
  git commit -m "ops: enqueue start_server; update status doc"
  git push origin windows-server
  ```
  即可把 start_server 指令推到远程，Windows 拉取后 Agent 会执行。

## 7. 小结

- **Git Token**：曾用于一次 push，已从 URL 中移除；当前 Linux 上未配置凭据，需按上文「1」配置后再 push。
- **两侧开发**：Linux 侧 enqueue + push 流程已就绪；Windows 侧需你在本机完成一次 `git pull` 并运行 `windows_ops_agent.ps1`，之后即可通过 Git 机制在 Windows 上执行指令并（可选）把结果推回供 Linux 使用。
