# Windows Ops Agent (GitOps)
# - Pull command queue from Git
# - Execute allowlisted operations
# - Write results back to Git and push
#
# One-time setup:
# - Ensure this repo is cloned on Windows
# - Ensure `git` is available and authenticated (PAT/SSH)
# - Register this script as a Scheduled Task "At startup" (recommended)
#
# Security:
# - This agent DOES NOT execute arbitrary shell commands from Git.
# - It only supports a small allowlist of actions.
#
# Queue format:
# - ops/queue/<request_id>.json
#   {
#     "id": "20260205_123000_abcd",
#     "status": "pending",
#     "action": "probe",            // probe | netstat | tail_log | start_server | stop_server | health
#     "args": { ... },              // action-specific args
#     "created_at": "2026-02-05T03:00:00"
#   }
#
# Result format:
# - ops/results/<request_id>.json

param(
    [string]$RepoDir = (Get-Location).Path,
    [string]$Branch = "windows-server",
    [int]$PollSeconds = 5,
    [string]$LogFile = ".\ops_agent.log",
    [switch]$Once = $false
)

$ErrorActionPreference = "Continue"

function Write-Log([string]$msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}

function Git-Run([string[]]$args) {
    $p = Start-Process -FilePath "git" -ArgumentList $args -WorkingDirectory $RepoDir -NoNewWindow -PassThru -Wait
    return $p.ExitCode
}

function Git-Output([string[]]$args) {
    try {
        return & git @args 2>&1
    } catch {
        return "$($_.Exception.GetType().Name): $($_.Exception.Message)"
    }
}

function Ensure-Dirs() {
    $dirs = @("ops\queue", "ops\results")
    foreach ($d in $dirs) {
        $p = Join-Path $RepoDir $d
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
}

function Read-Json([string]$path) {
    try { return (Get-Content -Raw -Path $path -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Write-Json([string]$path, [object]$obj) {
    $json = $obj | ConvertTo-Json -Depth 12
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $json -Encoding UTF8
}

function Now-Iso() {
    return (Get-Date).ToString("s")
}

function Get-MachineInfo() {
    $tsOut = ""
    try {
        $tsExe = Get-Command "tailscale" -ErrorAction SilentlyContinue
        if ($tsExe) {
            $tsOut = (tailscale status 2>&1 | Out-String)
        } else {
            $tsOut = "tailscale_not_in_path"
        }
    } catch {
        $tsOut = "$($_.Exception.GetType().Name): $($_.Exception.Message)"
    }
    return @{
        computer = $env:COMPUTERNAME
        user = $env:USERNAME
        os = (Get-CimInstance Win32_OperatingSystem).Caption
        tailscale = $tsOut
    }
}

function Action-Probe([hashtable]$args) {
    # Basic probes: ipconfig + process check
    $out = @{
        ipconfig = (ipconfig | Out-String)
        processes = (Get-Process | Where-Object { $_.ProcessName -match "python|bullet|qmt|xt" } | Select-Object -First 30 | Format-Table -AutoSize | Out-String)
    }
    return $out
}

function Action-Netstat([hashtable]$args) {
    $port = 58620
    if ($args.ContainsKey("port")) { $port = [int]$args.port }
    $out = netstat -an | Select-String ":$port " | ForEach-Object { $_.Line }
    return @{ port = $port; lines = @($out) }
}

function Action-TailLog([hashtable]$args) {
    $path = ".\qmt_server.log"
    $n = 80
    if ($args.ContainsKey("path")) { $path = [string]$args.path }
    if ($args.ContainsKey("lines")) { $n = [int]$args.lines }
    if (-not (Test-Path $path)) {
        return @{ ok = $false; error = "log_not_found"; path = $path }
    }
    $tail = Get-Content -Path $path -Tail $n -ErrorAction SilentlyContinue
    return @{ ok = $true; path = $path; lines = @($tail) }
}

function Action-Health([hashtable]$args) {
    $port = 58620
    if ($args.ContainsKey("port")) { $port = [int]$args.port }
    $url = "http://127.0.0.1:$port/health"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
        return @{ ok = $true; url = $url; status = $resp.StatusCode; body = ($resp.Content | Out-String) }
    } catch {
        return @{ ok = $false; url = $url; error = "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
    }
}

function Action-StartServer([hashtable]$args) {
    $port = 58620
    $token = ""
    $listen = "0.0.0.0"
    $logFile = ".\qmt_server.log"
    $accounts = "main=8885019982:stock:D:\gjzqQMT\userdata_mini"
    $envFile = ".env"

    if ($args.ContainsKey("port")) { $port = [string]$args.port }
    if ($args.ContainsKey("token")) { $token = [string]$args.token }
    if ($args.ContainsKey("listen")) { $listen = [string]$args.listen }
    if ($args.ContainsKey("log_file")) { $logFile = [string]$args.log_file }
    if ($args.ContainsKey("accounts")) { $accounts = [string]$args.accounts }
    if ($args.ContainsKey("env_file")) { $envFile = [string]$args.env_file }

    $script = Join-Path $RepoDir "scripts\start_bullettrade_server.ps1"
    if (-not (Test-Path $script)) {
        return @{ ok = $false; error = "start_script_not_found"; path = $script }
    }

    $argList = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $script,
        "-Listen", $listen,
        "-Port", $port,
        "-LogFile", $logFile,
        "-Accounts", $accounts,
        "-EnvFile", $envFile
    )
    if ($token) {
        $argList += @("-Token", $token)
    }

    # Start in background
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WorkingDirectory $RepoDir -PassThru -WindowStyle Hidden
    return @{ ok = $true; started = $true; pid = $p.Id; port = $port; listen = $listen; log_file = $logFile }
}

function Action-StopServer([hashtable]$args) {
    # Best-effort: kill processes containing bullet_trade server signature.
    $killed = @()
    $candidates = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "python|powershell" }
    foreach ($p in $candidates) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -and ($cmd -match "bullet_trade" -and $cmd -match "server")) {
                Stop-Process -Id $p.Id -Force
                $killed += @{ pid = $p.Id; cmd = $cmd }
            }
        } catch {}
    }
    return @{ ok = $true; killed = $killed }
}

function Execute-Request([pscustomobject]$req, [string]$reqPath) {
    $id = [string]$req.id
    $action = [string]$req.action
    $args = @{}
    try {
        if ($req.args) { $args = @{} + $req.args }
    } catch {}

    $result = @{
        id = $id
        action = $action
        status = "done"
        started_at = Now-Iso
        machine = Get-MachineInfo
        ok = $false
        output = $null
        error = $null
    }

    try {
        switch ($action) {
            "probe"       { $result.output = Action-Probe $args; $result.ok = $true }
            "netstat"     { $result.output = Action-Netstat $args; $result.ok = $true }
            "tail_log"    { $result.output = Action-TailLog $args; $result.ok = $true }
            "health"      { $result.output = Action-Health $args; $result.ok = $true }
            "start_server"{ $result.output = Action-StartServer $args; $result.ok = $true }
            "stop_server" { $result.output = Action-StopServer $args; $result.ok = $true }
            default       { throw "unsupported_action: $action" }
        }
    } catch {
        $result.ok = $false
        $result.error = "$($_.Exception.GetType().Name): $($_.Exception.Message)"
    }
    $result.ended_at = Now-Iso

    $outPath = Join-Path $RepoDir ("ops\results\{0}.json" -f $id)
    Write-Json $outPath $result

    # Mark queue item as done (update status field)
    try {
        $req.status = "done"
        $req.done_at = Now-Iso
        Write-Json $reqPath $req
    } catch {}

    return $result
}

Ensure-Dirs
Write-Log "windows_ops_agent start: repo=$RepoDir branch=$Branch poll=${PollSeconds}s once=$Once"

while ($true) {
    try {
        # Pull latest commands
        Git-Run @("checkout", $Branch) | Out-Null
        Git-Run @("pull", "origin", $Branch) | Out-Null

        $queueDir = Join-Path $RepoDir "ops\queue"
        $items = Get-ChildItem -Path $queueDir -Filter "*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime

        foreach ($it in $items) {
            $req = Read-Json $it.FullName
            if ($null -eq $req) { continue }
            if ([string]$req.status -ne "pending") { continue }
            if (-not $req.id) { continue }

            Write-Log ("execute request: {0} action={1}" -f $req.id, $req.action)
            $res = Execute-Request $req $it.FullName
            Write-Log ("result: id={0} ok={1}" -f $res.id, $res.ok)
        }

        # Push back results if any changes
        $status = Git-Output @("status", "--porcelain")
        if ($status -and $status.Trim().Length -gt 0) {
            Git-Run @("add", "ops") | Out-Null
            Git-Run @("commit", "-m", ("ops: agent update {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))) | Out-Null
            Git-Run @("push", "origin", $Branch) | Out-Null
        }
    } catch {
        Write-Log ("agent_loop_error: {0}" -f "$($_.Exception.GetType().Name): $($_.Exception.Message)")
    }

    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}

Write-Log "windows_ops_agent exit"

