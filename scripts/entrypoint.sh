#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/agentbay-on-start

exec "$@"
