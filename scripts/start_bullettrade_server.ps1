# BulletTrade Server 启动脚本
# 用于从美国 Ubuntu 工作站远程调用 miniQMT

param(
    [string]$Port = "58620",
    [string]$Token = "",
    [string]$Listen = "0.0.0.0",
    [string]$LogFile = ".\qmt_server.log",
    [string]$Accounts = "main=8885019982:stock:D:\gjzqQMT\userdata_mini",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "启动 BulletTrade Server (QMT)" -ForegroundColor Green
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Python 环境
$pythonExe = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $pythonExe)) {
    Write-Host "错误: 找不到 Python 可执行文件: $pythonExe" -ForegroundColor Red
    Write-Host "请确保已激活虚拟环境" -ForegroundColor Yellow
    exit 1
}

# 检查 bullet-trade 是否安装
$btCheck = & $pythonExe -m pip show bullet-trade 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: bullet-trade 未安装" -ForegroundColor Red
    Write-Host "正在安装 bullet-trade..." -ForegroundColor Yellow
    & $pythonExe -m pip install bullet-trade
    if ($LASTEXITCODE -ne 0) {
        Write-Host "安装失败，请手动执行: pip install bullet-trade" -ForegroundColor Red
        exit 1
    }
}

# 检查 .env 文件
if (-not (Test-Path $EnvFile)) {
    Write-Host "警告: 未找到 .env 文件，将使用默认配置" -ForegroundColor Yellow
    Write-Host "如需配置，请创建 .env 文件，例如:" -ForegroundColor Yellow
    Write-Host "  DEFAULT_DATA_PROVIDER=qmt" -ForegroundColor Gray
    Write-Host "  QMT_SERVER_LISTEN=0.0.0.0" -ForegroundColor Gray
    Write-Host "  QMT_SERVER_PORT=58620" -ForegroundColor Gray
    Write-Host ""
}

# 构建命令参数
$cmdArgs = @(
    "-m", "bullet_trade", "server",
    "--server-type", "qmt",
    "--listen", $Listen,
    "--port", $Port,
    "--enable-data",
    "--enable-broker",
    "--access-log",
    "--log-file", $LogFile,
    "--accounts", $Accounts
)

# 如果提供了 token，添加 token 参数
if ($Token) {
    $cmdArgs += "--token"
    $cmdArgs += $Token
}

# 如果提供了 .env 文件，添加 --env-file 参数
if (Test-Path $EnvFile) {
    $cmdArgs += "--env-file"
    $cmdArgs += $EnvFile
}

Write-Host "启动参数:" -ForegroundColor Cyan
Write-Host "  监听地址: $Listen" -ForegroundColor White
Write-Host "  端口: $Port" -ForegroundColor White
Write-Host "  账户: $Accounts" -ForegroundColor White
Write-Host "  日志文件: $LogFile" -ForegroundColor White
if ($Token) {
    Write-Host "  Token: $Token" -ForegroundColor White
}
Write-Host ""

Write-Host "执行命令:" -ForegroundColor Cyan
Write-Host "  $pythonExe $($cmdArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "启动 Server..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 启动 server
& $pythonExe $cmdArgs
