#!/usr/bin/env bash
# The VM's workload, started by `msb run -d` (see create_vm in ./agentbay).
# microsandbox only runs the image ENTRYPOINT through `msb run`; `create`,
# `start` and `exec` ignore it. Shells are opened separately with `msb exec`.
set -euo pipefail

/usr/local/bin/agentbay-on-start

# Keep the workload alive so the detached VM keeps running.
exec sleep infinity
