#!/usr/bin/env bash
# Step 9 — create a game account by sending the `account create` command to
# the running worldserver console (`stdin_open: true`, attached via -i above).
#
# Usage:
#   scripts/09-create-account.sh <username> <password> [gmlevel]
#
# gmlevel 0 = player (default), 3 = full GM. We default to 3 because this is
# a single-player local server.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

USER="${1:-test}"
PASS="${2:-test}"
GM_LEVEL="${3:-3}"

if [[ ${#PASS} -gt 16 ]]; then
    die "WoW 3.3.5 max password length is 16 characters."
fi

log "Creating account $USER (GM level $GM_LEVEL) via worldserver console..."
# Write to PID 1 (worldserver) stdin via /proc fd. `podman exec -i` runs a new
# bash inside the container, which doesn't share worldserver's stdin.
deck "
set -euo pipefail
podman exec ac-worldserver bash -c \"echo 'account create $USER $PASS' > /proc/1/fd/0\"
sleep 2
podman exec ac-worldserver bash -c \"echo 'account set gmlevel $USER $GM_LEVEL -1' > /proc/1/fd/0\"
sleep 2
"

log "Verifying via DB:"
deck "
podman exec ac-database mysql -uroot -p${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} acore_auth \
    -e \"SELECT a.id, a.username, aa.gmlevel FROM account a LEFT JOIN account_access aa ON aa.id=a.id WHERE a.username=UPPER('$USER');\"
"

log "Account ready. realmlist.wtf → set realmlist 127.0.0.1"
log "Step 9 complete."
