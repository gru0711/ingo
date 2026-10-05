#!/usr/bin/env bash
# Show that the container has no network access and that build + tests still work.
#   scripts/verify-offline.sh
set -uo pipefail
source "$(dirname "$0")/common.sh"
docker run --rm --network none "$IMAGE" bash -c '
  echo "network interfaces: $(ls /sys/class/net | tr "\n" " ")"
  if getent hosts registry.npmjs.org >/dev/null; then echo "DNS: registry.npmjs.org resolves (UNEXPECTED)"; else echo "DNS: registry.npmjs.org does not resolve"; fi
  if timeout 15 git ls-remote https://github.com/harrisiirak/cron-parser.git >/dev/null 2>&1; then echo "github.com: reachable (UNEXPECTED)"; else echo "github.com: unreachable"; fi
  npm ls --depth=0 >/dev/null && echo "npm ls: dependency tree complete"
  rm -rf dist && npm run build >/dev/null && echo "offline build: ok"
  TZ=UTC npx jest --ci 2>&1 | grep -E "^Tests:"
'
