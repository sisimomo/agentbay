#!/usr/bin/env bash
# Render config templates (*.tmpl -> same path without the suffix). Only the
# listed variables are substituted, so other $vars in the files are untouched.
set -euo pipefail

export MICROSANDBOX_PROJECT_ROOT="${MICROSANDBOX_PROJECT_ROOT:-$HOME/dev}"
while IFS= read -r -d '' template; do
  # shellcheck disable=SC2016 # literal variable list for envsubst
  envsubst '${MICROSANDBOX_PROJECT_ROOT}' < "$template" > "${template%.tmpl}"
  rm "$template"
done < <(find "$HOME/.config" "$HOME/.claude" -name '*.tmpl' -print0)
