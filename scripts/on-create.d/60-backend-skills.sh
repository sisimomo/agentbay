#!/usr/bin/env bash
# TouchTunes backend skills and their MCP tools (touchtunes-backend-knowledge
# plugin), installed from the host checkout under ~/dev. The tt-assistant-*
# meeting/ADR skills are removed: they need audio tooling the VM doesn't have.
set -euo pipefail

BSP_SRC="${BSP_SRC:-/Users/svallieres/dev/backend-skills-plugin}"
[[ -d "$BSP_SRC" ]] || { printf '%s: missing %s\n' "$(basename "$0")" "$BSP_SRC" >&2; exit 1; }

# Copied so the installer never writes into the host repo. The host's Python
# venvs are macOS builds, so they are dropped and the installer makes Linux ones.
dest="$HOME/backend-skills-plugin"
if [[ ! -d "$dest" ]]; then
  cp -R "$BSP_SRC" "$dest"
  find "$dest" -type d -name .venv -prune -exec rm -rf {} +
fi

# SKIP_OBSIDIAN: the installer otherwise asks on /dev/tty whether to install
# Obsidian with Homebrew, which hangs `msb exec -t`.
SKIP_TT_ASSISTANT=1 SKIP_OBSIDIAN=1 DEBIAN_FRONTEND=noninteractive bash "$dest/install.sh"

plugin_dir="$HOME/.claude/plugins/local/touchtunes-backend-knowledge"
for skill in action-tracker adr-generator enroll-speaker meeting-extract meeting-transcribe; do
  rm -rf "$plugin_dir/skills/tt-assistant-$skill"
done
