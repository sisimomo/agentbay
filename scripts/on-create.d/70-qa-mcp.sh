#!/usr/bin/env bash
# Regenerate soundwave-qa-agents' machine-specific .mcp-config for this VM.
# It lives in the shared ~/dev tree, so this retires AIVM's copy. Runs after
# 60-backend-skills.sh: it reads config that plugin writes into ~/.claude.json.
set -euo pipefail

QA_DIR="${QA_DIR:-/Users/svallieres/dev/soundwave-monorepo/repos/soundwave-qa-agents}"
[[ -d "$QA_DIR" ]] || { printf '%s: missing %s\n' "$(basename "$0")" "$QA_DIR" >&2; exit 1; }

"$QA_DIR/scripts/setup-mcp.sh" --force
