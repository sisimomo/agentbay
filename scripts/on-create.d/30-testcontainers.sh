#!/usr/bin/env bash
# Let Testcontainers reuse containers across test runs (opt-in per container
# with withReuse(true)), so integration tests don't restart databases each run.
set -euo pipefail

file="$HOME/.testcontainers.properties"
printf 'testcontainers.reuse.enable=true\n' > "$file"
chmod 600 "$file"
