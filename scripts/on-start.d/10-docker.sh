#!/usr/bin/env bash
# Start the Docker daemon (no systemd in the guest).
# Idempotent: does nothing if the Docker daemon is already up.
set -euo pipefail

if ! docker info >/dev/null 2>&1; then
  sudo -n service docker start >/dev/null
  for _ in $(seq 1 60); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  docker info >/dev/null 2>&1 || {
    cat /var/log/docker.log >&2
    exit 1
  }
fi
