#!/usr/bin/env bash
# Start an interactive, offline agent workspace. The container is kept (named) so the
# candidate's work can be extracted afterwards with extract-patch.sh.
#   scripts/agent-shell.sh [container-name]
set -euo pipefail
source "$(dirname "$0")/common.sh"
NAME=${1:-cron-parser-agent}
docker run -it --name "$NAME" --network none -w /workspace/cron-parser "$IMAGE" bash
