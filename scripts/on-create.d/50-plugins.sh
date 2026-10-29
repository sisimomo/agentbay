#!/usr/bin/env bash
# Claude Code plugins from GitHub marketplaces, installed at user scope.
# Safe to re-run: "already added/installed" counts as success.
set -euo pipefail

# Runs "claude plugin ..." and succeeds if the output says it is already done.
claude_plugin() {
  local output
  if output="$(claude plugin "$@" 2>&1)"; then
    printf '%s\n' "$output"
  elif grep -qi already <<< "$output"; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "$output" >&2
    return 1
  fi
}

claude_plugin marketplace add riekelt/multi-agent-review
claude_plugin install multi-agent-review@multi-agent-review --scope user
