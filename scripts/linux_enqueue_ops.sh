#!/bin/bash
# Enqueue a Windows ops request via Git (GitOps).
#
# Usage:
#   ./scripts/linux_enqueue_ops.sh probe
#   ./scripts/linux_enqueue_ops.sh netstat --port 58620
#   ./scripts/linux_enqueue_ops.sh tail_log --path .\\qmt_server.log --lines 120
#   ./scripts/linux_enqueue_ops.sh health --port 58620
#
# Requires:
# - This repo cloned on Linux
# - Git remote configured and authenticated

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${BRANCH:-windows-server}"

action="${1:-}"
shift || true

if [[ -z "${action}" ]]; then
  echo "missing action"
  exit 2
fi

id="$(date '+%Y%m%d_%H%M%S')_$(python3 - <<'PY'
import secrets
print(secrets.token_hex(4))
PY
)"

queue_dir="${ROOT}/ops/queue"
mkdir -p "${queue_dir}"

# Parse args into a tiny JSON object: --k v pairs only (pass via stdin to avoid $@ in subshell)
args_json="$(printf '%s\n' "$@" | python3 -c '
import json, sys
lines = [ L.strip() for L in sys.stdin.read().splitlines() if L.strip() ]
out = {}
i = 0
while i < len(lines):
    s = lines[i]
    if s.startswith("--"):
        key = s[2:]
        val = True
        if i + 1 < len(lines) and not lines[i+1].startswith("--"):
            val = lines[i+1]
            i += 1
        out[key] = val
    i += 1
print(json.dumps(out, ensure_ascii=False))
')"

cat > "${queue_dir}/${id}.json" <<EOF
{
  "id": "${id}",
  "status": "pending",
  "action": "${action}",
  "args": ${args_json},
  "created_at": "$(date -Iseconds)"
}
EOF

cd "${ROOT}"
git checkout "${BRANCH}" >/dev/null 2>&1 || true
git pull origin "${BRANCH}" >/dev/null 2>&1 || true
git add "ops/queue/${id}.json"
git commit -m "ops: enqueue ${action} ${id}" >/dev/null
git push origin "${BRANCH}" >/dev/null

echo "enqueued: ${id}"
echo "next: wait for ops/results/${id}.json to appear (agent will write it)"

