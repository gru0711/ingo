#!/usr/bin/env bash
# Export everything the agent changed in its container (including new files) as a patch
# against the baseline SHA.
#   scripts/extract-patch.sh <container-name> <output.patch>
set -euo pipefail
NAME=$1; OUTPUT=$2
docker start "$NAME" >/dev/null
docker exec "$NAME" bash -c 'cd /workspace/cron-parser && git add -A && git diff --cached --binary "$BASE_SHA"' > "$OUTPUT"
echo "wrote $OUTPUT ($(wc -l < "$OUTPUT") lines)"
