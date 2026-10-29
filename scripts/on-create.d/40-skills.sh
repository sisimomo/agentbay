#!/usr/bin/env bash
# Agent skills for Claude Code, installed user-level into ~/.claude/skills.
set -euo pipefail

npx --yes skills add https://github.com/upstash/context7 --skill context7-mcp -g -a claude-code -y --copy
npx --yes skills add obra/superpowers --skill '*' -g -a claude-code -y --copy
npx --yes skills add dietrichgebert/ponytail --skill '*' -g -a claude-code -y --copy
npx --yes skills add mattpocock/skills --skill '*' -g -a claude-code -y --copy
