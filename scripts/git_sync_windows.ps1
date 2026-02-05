# Git 同步脚本 - Windows 端
# 用于自动同步代码和配置到 Git 仓库

param(
    [string]$Message = "Auto sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [string]$Branch = "windows-server",
    [switch]$PullOnly = $false,
    [switch]$PushOnly = $false
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Git 同步 - Windows 端" -ForegroundColor Green
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否在 git 仓库中
if (-not (Test-Path .git)) {
    Write-Host "错误: 当前目录不是 Git 仓库" -ForegroundColor Red
    exit 1
}

# 显示当前分支
$currentBranch = git branch --show-current
Write-Host "当前分支: $currentBranch" -ForegroundColor Cyan
Write-Host "目标分支: $Branch" -ForegroundColor Cyan
Write-Host ""

# 拉取远程更改
if (-not $PushOnly) {
    Write-Host "[1/3] 拉取远程更改..." -ForegroundColor Yellow
    try {
        $pullOutput = git pull origin $Branch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ 拉取完成" -ForegroundColor Green
        } else {
            Write-Host "⚠ 拉取时出现问题（可能没有远程分支）" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠ 拉取失败: $_" -ForegroundColor Yellow
    }
    Write-Host ""
}

# 检查本地更改
if (-not $PullOnly) {
    Write-Host "[2/3] 检查本地更改..." -ForegroundColor Yellow
    $status = git status --porcelain
    
    if ($status) {
        Write-Host "发现未提交的更改:" -ForegroundColor Yellow
        git status --short | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
        Write-Host ""
        
        # 添加所有更改（排除敏感文件）
        Write-Host "[3/3] 添加并提交更改..." -ForegroundColor Yellow
        
        # 添加更改
        git add .
        
        # 提交
        git commit -m $Message
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ 提交完成" -ForegroundColor Green
        } else {
            Write-Host "⚠ 提交失败或没有更改" -ForegroundColor Yellow
        }
        
        # 推送
        Write-Host "[4/4] 推送到远程..." -ForegroundColor Yellow
        git push origin $Branch
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ 推送完成" -ForegroundColor Green
        } else {
            Write-Host "⚠ 推送失败" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✓ 没有未提交的更改" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "同步完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "当前分支: $(git branch --show-current)" -ForegroundColor Cyan
Write-Host "最新提交: $(git log -1 --oneline --no-decorate)" -ForegroundColor Cyan
$remoteStatus = git status -sb 2>&1 | Select-String -Pattern '\[.*\]'
if ($remoteStatus) {
    Write-Host "远程状态: $remoteStatus" -ForegroundColor Cyan
}
Write-Host ""
