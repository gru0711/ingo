#!/usr/bin/env bash
# Build the agent image. Network is needed only here (git clone + npm ci).
#   scripts/build-image.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"
docker build --progress=plain -t "$IMAGE" -f "$DELIVERABLES_DIR/Dockerfile" "$DELIVERABLES_DIR"
