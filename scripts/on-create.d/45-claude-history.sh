#!/usr/bin/env bash
# Prompt history (Ctrl+R) is a single file, so keep it on the agentbay-claude-history
# volume and symlink it into place; it then survives recreate.
set -euo pipefail

touch "$HOME/.local/share/claude-history/history.jsonl"
ln -sf "$HOME/.local/share/claude-history/history.jsonl" "$HOME/.claude/history.jsonl"
