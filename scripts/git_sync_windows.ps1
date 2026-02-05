# Git Sync Script - Windows
param(
    [string]$Message = "Auto sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [string]$Branch = "windows-server",
    [switch]$PullOnly = $false,
    [switch]$PushOnly = $false
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Git Sync - Windows" -ForegroundColor Green
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path .git)) {
    Write-Host "Error: Current directory is not a Git repository" -ForegroundColor Red
    exit 1
}

$currentBranch = git branch --show-current
Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan
Write-Host "Target branch: $Branch" -ForegroundColor Cyan
Write-Host ""

if (-not $PushOnly) {
    Write-Host "[1/3] Pulling remote changes..." -ForegroundColor Yellow
    $pullResult = git pull origin $Branch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Pull completed" -ForegroundColor Green
    } else {
        Write-Host "WARNING Pull had issues (remote branch may not exist)" -ForegroundColor Yellow
    }
    Write-Host ""
}

if (-not $PullOnly) {
    Write-Host "[2/3] Checking local changes..." -ForegroundColor Yellow
    $status = git status --porcelain
    
    if ($status) {
        Write-Host "Found uncommitted changes:" -ForegroundColor Yellow
        git status --short | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        
        Write-Host "[3/3] Adding and committing changes..." -ForegroundColor Yellow
        git add .
        git commit -m $Message
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK Commit completed" -ForegroundColor Green
        } else {
            Write-Host "WARNING Commit failed or no changes" -ForegroundColor Yellow
        }
        
        Write-Host "[4/4] Pushing to remote..." -ForegroundColor Yellow
        git push origin $Branch 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK Push completed" -ForegroundColor Green
        } else {
            Write-Host "WARNING Push failed (remote may not be configured)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "OK No uncommitted changes" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sync completed" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current branch: $(git branch --show-current)" -ForegroundColor Cyan
Write-Host "Latest commit: $(git log -1 --oneline --no-decorate)" -ForegroundColor Cyan
Write-Host ""
