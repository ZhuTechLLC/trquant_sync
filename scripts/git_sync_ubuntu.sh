#!/bin/bash
# Git 同步脚本 - Ubuntu 端
# 用于自动同步代码和配置到 Git 仓库

set -e

MESSAGE="${1:-Auto sync: $(date '+%Y-%m-%d %H:%M:%S')}"
BRANCH="${2:-ubuntu-client}"
PULL_ONLY="${3:-false}"
PUSH_ONLY="${4:-false}"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Git 同步 - Ubuntu 端${NC}"
echo -e "${YELLOW}时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检查是否在 git 仓库中
if [ ! -d .git ]; then
    echo -e "${RED}错误: 当前目录不是 Git 仓库${NC}"
    exit 1
fi

# 显示当前分支
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${CYAN}当前分支: $CURRENT_BRANCH${NC}"
echo -e "${CYAN}目标分支: $BRANCH${NC}"
echo ""

# 拉取远程更改
if [ "$PUSH_ONLY" != "true" ]; then
    echo -e "${YELLOW}[1/3] 拉取远程更改...${NC}"
    if git pull origin "$BRANCH" 2>&1; then
        echo -e "${GREEN}✓ 拉取完成${NC}"
    else
        echo -e "${YELLOW}⚠ 拉取时出现问题（可能没有远程分支）${NC}"
    fi
    echo ""
fi

# 检查本地更改
if [ "$PULL_ONLY" != "true" ]; then
    echo -e "${YELLOW}[2/3] 检查本地更改...${NC}"
    STATUS=$(git status --porcelain)
    
    if [ -n "$STATUS" ]; then
        echo -e "${YELLOW}发现未提交的更改:${NC}"
        git status --short | while read line; do
            echo -e "  ${line}"
        done
        echo ""
        
        # 添加所有更改
        echo -e "${YELLOW}[3/3] 添加并提交更改...${NC}"
        
        # 添加更改
        git add .
        
        # 提交
        if git commit -m "$MESSAGE"; then
            echo -e "${GREEN}✓ 提交完成${NC}"
        else
            echo -e "${YELLOW}⚠ 提交失败或没有更改${NC}"
        fi
        
        # 推送
        echo -e "${YELLOW}[4/4] 推送到远程...${NC}"
        if git push origin "$BRANCH"; then
            echo -e "${GREEN}✓ 推送完成${NC}"
        else
            echo -e "${YELLOW}⚠ 推送失败${NC}"
        fi
    else
        echo -e "${GREEN}✓ 没有未提交的更改${NC}"
    fi
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}同步完成${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${CYAN}当前分支: $(git branch --show-current)${NC}"
echo -e "${CYAN}最新提交: $(git log -1 --oneline --no-decorate)${NC}"
echo -e "${CYAN}远程状态: $(git status -sb | grep -o '\[.*\]')${NC}"
echo ""
