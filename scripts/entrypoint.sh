#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/microsandbox-init

exec "$@"
