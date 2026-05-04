#!/usr/bin/env bash
# Step 1 — create the workspace tree on the SD card.
#
# Layout (under $WOW_ROOT):
#   server/    AC source clone + compose files
#   client/    WoW 3.3.5a client (you copy it in manually — see README)
#   data/      extracted DBC/maps/vmaps/mmaps  (~4 GB)
#   db/        reserved (named volumes hold the actual mariadb data)
#   logs/      authserver / worldserver logs
#   configs/   *.conf files mounted into containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Verifying SD card mount at $WOW_ROOT ..."
deck "[ -d \"$(dirname "$WOW_ROOT")\" ]" \
    || die "$(dirname "$WOW_ROOT") not present — is the SD card inserted and auto-mounted?"

log "Creating workspace dirs under $WOW_ROOT ..."
deck "mkdir -p \"$WOW_ROOT\"/{server,client,data,db,logs,configs}"

log "Probing write access ..."
deck "touch \"$WOW_ROOT/.write_test\" && rm \"$WOW_ROOT/.write_test\""

log "Workspace tree:"
deck "ls -la \"$WOW_ROOT\""

log "Step 1 complete."
