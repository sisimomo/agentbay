#!/usr/bin/env bash
# Git identity, passed in from the host through sandbox.yaml.
set -euo pipefail

if [[ -n "${MICROSANDBOX_GIT_USER_NAME:-}" && -n "${MICROSANDBOX_GIT_USER_EMAIL:-}" ]]; then
  git config --global user.name "$MICROSANDBOX_GIT_USER_NAME"
  git config --global user.email "$MICROSANDBOX_GIT_USER_EMAIL"
fi
