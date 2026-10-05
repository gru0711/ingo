#!/usr/bin/env bash
# Run the documented baseline checks in a throwaway container with networking disabled.
#   scripts/run-baseline-tests.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"
docker run --rm --network none "$IMAGE" bash -c '
  set -e
  echo "HEAD $(git rev-parse HEAD)"
  npm run build
  npm run test:unit
  npm run lint
  npx tsd && echo "tsd: ok"
'
