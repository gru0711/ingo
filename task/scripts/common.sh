# Shared settings for the host-side Docker wrappers (sourced, not executed).
IMAGE=${IMAGE:-cron-parser-w-task:baseline}
SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DELIVERABLES_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)
