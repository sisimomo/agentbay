#!/usr/bin/env bash
# Tests for on-create steps that wrap host installers, with stub installers.
# Run: bash scripts/test-on-create-steps.sh
set -euo pipefail

steps="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/on-create.d"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# 60-backend-skills: no interactive prompts, host .venv dirs not copied.
bsp="$tmp/bsp"
mkdir -p "$bsp/mcp-servers/tools/.venv" "$bsp/mcp-servers/tools/src" "$tmp/home60" "$tmp/home70"
cat > "$bsp/install.sh" <<'STUB'
[[ "${SKIP_OBSIDIAN:-}" == 1 ]] || { echo "install.sh would prompt for Obsidian" >&2; exit 1; }
STUB
HOME="$tmp/home60" BSP_SRC="$bsp" bash "$steps/60-backend-skills.sh" || fail "60: exit $?"
[[ -d "$tmp/home60/backend-skills-plugin/mcp-servers/tools/src" ]] || fail "60: source not copied"
[[ ! -e "$tmp/home60/backend-skills-plugin/mcp-servers/tools/.venv" ]] || fail "60: host .venv copied into the VM"
echo "ok: 60-backend-skills skips Obsidian prompt and host .venv"

# 70-qa-mcp: replaces an existing .venv instead of prompting/failing.
qa="$tmp/qa"
mkdir -p "$qa/scripts"
uv venv -q "$qa/.venv"
cat > "$qa/scripts/setup-mcp.sh" <<'STUB'
#!/usr/bin/env bash
# Same call as setup-mcp.sh step 3, on a venv that already exists.
uv venv -q "$(dirname "$0")/../.venv" --python python3
STUB
chmod +x "$qa/scripts/setup-mcp.sh"
HOME="$tmp/home70" QA_DIR="$qa" bash "$steps/70-qa-mcp.sh" </dev/null || fail "70: exit $?"
echo "ok: 70-qa-mcp replaces an existing .venv"
