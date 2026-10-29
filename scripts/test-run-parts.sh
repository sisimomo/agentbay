#!/usr/bin/env bash
# Tests for run-parts.sh: order, *.sh filter, no exec bit needed, stop on failure.
# Run: bash scripts/test-run-parts.sh
set -euo pipefail

runner="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/run-parts.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

dir="$tmp/steps"
out="$tmp/out"
mkdir "$dir"
printf 'printf b >> %q\n' "$out" > "$dir/20-b.sh"
printf 'printf a >> %q\n' "$out" > "$dir/10-a.sh"
printf 'printf c >> %q\n' "$out" > "$dir/30-c.sh"
printf 'printf x >> %q\n' "$out" > "$dir/notes.md"
chmod +x "$dir/10-a.sh" "$dir/20-b.sh"
chmod -x "$dir/30-c.sh"

bash "$runner" "$dir" || fail "runner exited $?"
[[ "$(cat "$out")" == abc ]] || fail "order/filter: got '$(cat "$out")', want 'abc'"
echo "ok: runs *.sh in filename order, skips other files, no exec bit needed"

: > "$out"
printf 'exit 3\n' > "$dir/15-fail.sh"
status=0
bash "$runner" "$dir" 2> "$tmp/err" || status=$?
[[ $status -eq 3 ]] || fail "failure: exit status $status, want 3"
grep -q '15-fail.sh failed' "$tmp/err" || fail "failure: stderr '$(cat "$tmp/err")' does not name 15-fail.sh"
[[ "$(cat "$out")" == a ]] || fail "failure: got '$(cat "$out")', want 'a' (steps after 15-fail must not run)"
echo "ok: stops at the first failure with its status and names the file"
