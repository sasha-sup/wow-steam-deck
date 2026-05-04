#!/usr/bin/env bash
# Step 8 — start authserver + worldserver as standalone rootless containers
# on the ac-net network. Bypasses podman-compose pod logic which has
# dep-graph quirks (see README "Known gotchas").
#
# All three exposed ports bind to 127.0.0.1 only:
#   3724 — authserver (login)
#   8085 — worldserver (game)
#   7878 — soap (admin RPC; not exposed remotely)
#
# Idempotent: running again will start any stopped containers but won't
# clobber a running stack.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DBPASS="${DOCKER_DB_ROOT_PASSWORD:-acorewotlk}"

log "Ensuring mariadb is up..."
deck "
podman network exists ac-net || podman network create ac-net
if ! podman ps --format '{{.Names}}' | grep -q '^ac-database\$'; then
    if podman ps -a --format '{{.Names}}' | grep -q '^ac-database\$'; then
        podman start ac-database
    else
        echo 'mariadb container missing — run scripts/07-init-db.sh first' >&2
        exit 1
    fi
fi
for i in \$(seq 1 30); do
    podman exec ac-database mysqladmin -uroot -p$DBPASS ping >/dev/null 2>&1 && break
    sleep 2
done
"

start_or_run() {
    local name="$1"; shift
    deck "
if podman ps --format '{{.Names}}' | grep -q '^${name}\$'; then
    echo '${name}: already running'
elif podman ps -a --format '{{.Names}}' | grep -q '^${name}\$'; then
    podman start $name >/dev/null && echo '${name}: started existing'
else
    $* >/dev/null && echo '${name}: created'
fi
"
}

log "Starting ac-authserver..."
start_or_run ac-authserver "podman run -d --name ac-authserver --network ac-net --userns=keep-id \
    -e AC_LOGIN_DATABASE_INFO='ac-database;3306;root;$DBPASS;acore_auth' \
    -e AC_LOGS_DIR=/azerothcore/env/dist/logs \
    -p 127.0.0.1:${DOCKER_AUTH_EXTERNAL_PORT:-3724}:3724 \
    -v $WOW_ROOT/configs:/azerothcore/env/dist/etc:Z \
    -v $WOW_ROOT/logs:/azerothcore/env/dist/logs:Z \
    --restart unless-stopped \
    acore/ac-wotlk-authserver:local"

log "Starting ac-worldserver..."
start_or_run ac-worldserver "podman run -d --name ac-worldserver --network ac-net --userns=keep-id \
    -e AC_LOGIN_DATABASE_INFO='ac-database;3306;root;$DBPASS;acore_auth' \
    -e AC_WORLD_DATABASE_INFO='ac-database;3306;root;$DBPASS;acore_world' \
    -e AC_CHARACTER_DATABASE_INFO='ac-database;3306;root;$DBPASS;acore_characters' \
    -e AC_PLAYERBOTS_DATABASE_INFO='ac-database;3306;root;$DBPASS;acore_playerbots' \
    -e AC_DATA_DIR=/azerothcore/env/dist/data \
    -e AC_LOGS_DIR=/azerothcore/env/dist/logs \
    -p 127.0.0.1:${DOCKER_WORLD_EXTERNAL_PORT:-8085}:8085 \
    -p 127.0.0.1:${DOCKER_SOAP_EXTERNAL_PORT:-7878}:7878 \
    -v $WOW_ROOT/configs:/azerothcore/env/dist/etc:Z \
    -v $WOW_ROOT/logs:/azerothcore/env/dist/logs:Z \
    -v $WOW_ROOT/data:/azerothcore/env/dist/data:ro,Z \
    -v $WOW_ROOT/server/ac/modules:/azerothcore/modules:ro,Z \
    --restart unless-stopped --memory 6g \
    -i \
    acore/ac-wotlk-worldserver:local"

log "Stack:"
deck "podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

log "Worldserver startup takes ~1–2 min. Tail logs with:"
log "  ssh \$DECK_HOST 'tail -f $WOW_ROOT/logs/Server.log'"
log "Step 8 complete."
