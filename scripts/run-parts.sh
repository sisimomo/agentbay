#!/usr/bin/env bash
# Runs every *.sh in a directory with bash, in filename order, and stops at the
# first failure. The numeric prefix (10-, 20-, ...) is the only ordering.
# Usage: run-parts.sh <dir>
set -euo pipefail
export LC_ALL=C
shopt -s nullglob

dir="${1:?usage: run-parts.sh <dir>}"
for file in "$dir"/*.sh; do
  status=0
  bash "$file" || status=$?
  if (( status != 0 )); then
    printf 'run-parts: %s failed\n' "$file" >&2
    exit "$status"
  fi
done
