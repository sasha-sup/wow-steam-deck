#!/usr/bin/env bash
# Stop the stack cleanly. Data persists (named volume + bind mounts).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Stopping ac-worldserver, ac-authserver, ac-database (in that order)..."
deck "
for c in ac-worldserver ac-authserver ac-database; do
    if podman ps --format '{{.Names}}' | grep -q \"^\$c\$\"; then
        echo \"stopping \$c\"
        podman stop -t 30 \"\$c\" >/dev/null
    fi
done
podman ps --format 'table {{.Names}}\t{{.Status}}'
"
log "Stopped. Data persists; 'scripts/08-start-stack.sh' brings it back."
