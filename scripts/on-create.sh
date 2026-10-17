#!/usr/bin/env bash
# Runs once, right after the VM is created (see create_vm in ./agentbay).
# $HOME starts fresh from the image, so there is nothing to guard against.
set -euo pipefail

# Render config templates (*.tmpl -> same path without the suffix). Only the
# listed variables are substituted, so other $vars in the files are untouched.
export MICROSANDBOX_PROJECT_ROOT="${MICROSANDBOX_PROJECT_ROOT:-$HOME/dev}"
while IFS= read -r -d '' template; do
  envsubst '${MICROSANDBOX_PROJECT_ROOT}' < "$template" > "${template%.tmpl}"
  rm "$template"
done < <(find "$HOME/.config" "$HOME/.claude" -name '*.tmpl' -print0)

# Git identity, passed in from the host through sandbox.yaml.
if [[ -n "${MICROSANDBOX_GIT_USER_NAME:-}" && -n "${MICROSANDBOX_GIT_USER_EMAIL:-}" ]]; then
  git config --global user.name "$MICROSANDBOX_GIT_USER_NAME"
  git config --global user.email "$MICROSANDBOX_GIT_USER_EMAIL"
fi
