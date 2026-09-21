#!/usr/bin/env bash
set -euo pipefail

if ! docker info >/dev/null 2>&1; then
  sudo -n rm -f /var/run/docker.pid
  # The VM's overlayfs cannot be nested by Docker's default overlay2 driver.
  # vfs is slower but works reliably with the named /var/lib/docker volume.
  sudo -n dockerd --storage-driver=vfs --host=unix:///var/run/docker.sock >/tmp/dockerd.log 2>&1 &
  for _ in $(seq 1 60); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  docker info >/dev/null 2>&1 || {
    cat /tmp/dockerd.log >&2
    exit 1
  }
fi
