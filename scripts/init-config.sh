#!/usr/bin/env bash
set -euo pipefail

source_dir="${MICROSANDBOX_CONFIG_SOURCE_DIR:-/usr/local/share/microsandbox}"

if [[ ! -f "$HOME/.codex/config.toml" ]]; then
  mkdir -p "$HOME/.codex"
  cp "$source_dir/codex-config.toml" "$HOME/.codex/config.toml"
  chown dev-ai-vm:dev-ai-vm "$HOME/.codex/config.toml" 2>/dev/null || true
fi

if [[ ! -f "$HOME/.config/herdr/config.toml" ]]; then
  project_root="${MICROSANDBOX_PROJECT_ROOT:-$HOME/dev}"
  escaped_project_root="${project_root//\\/\\\\}"
  escaped_project_root="${escaped_project_root//&/\\&}"
  escaped_project_root="${escaped_project_root//|/\\|}"
  mkdir -p "$HOME/.config/herdr"
  sed "s|__MSB_PROJECT_ROOT__|$escaped_project_root|g" \
    "$source_dir/herdr-config.toml" \
    > "$HOME/.config/herdr/config.toml"
  chown dev-ai-vm:dev-ai-vm "$HOME/.config/herdr/config.toml" 2>/dev/null || true
fi

name="${MICROSANDBOX_GIT_USER_NAME:-}"
email="${MICROSANDBOX_GIT_USER_EMAIL:-}"
if [[ -n "$name" && -n "$email" ]]; then
  git config --global user.name "$name"
  git config --global user.email "$email"
fi
