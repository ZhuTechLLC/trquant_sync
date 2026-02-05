#!/bin/bash
# Git 同步 - Linux 端（拉取 windows-server，保持与 Windows 一致）
#
# 使用：在 trquant_sync 仓库根目录执行
#   ./scripts/linux_sync_ops.sh
#
# 建议：入队指令前先执行一次，确保拿到 Windows 端推送的 ops/results。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${BRANCH:-windows-server}"

cd "${ROOT}"
echo "branch: ${BRANCH}"
git fetch origin
git checkout "${BRANCH}" 2>/dev/null || true
git pull origin "${BRANCH}" || true
echo "---"
git status -sb
echo "---"
echo "ops/queue: $(ls -1 ops/queue 2>/dev/null | grep -v '^\.gitkeep$' | wc -l) files"
echo "ops/results: $(ls -1 ops/results 2>/dev/null | grep -v '^\.gitkeep$' | wc -l) files"
if [ -d "ops/results" ] && ls ops/results/*.json 2>/dev/null | head -1 >/dev/null; then
  echo "latest result: $(ls -t ops/results/*.json 2>/dev/null | head -1)"
fi
echo "sync done."
