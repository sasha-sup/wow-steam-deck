#!/usr/bin/env bash
# Step 7 — start mariadb and run the one-shot db-import to create the four
# AzerothCore schemas (auth, world, characters, playerbots) plus all base data.
#
# Both run rootless on the user-defined `ac-net` network. mariadb data lives
# in a podman-managed named volume (ac-database) — survives container removal.
# First import takes ~5–10 min, re-runs are <1 min (idempotent migrations).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Creating podman network ac-net (if missing)..."
deck "podman network exists ac-net || podman network create ac-net"

log "Starting mariadb (mysql:8.4)..."
deck "
if podman ps -a --format '{{.Names}}' | grep -q '^ac-database\$'; then
    podman start ac-database >/dev/null
else
    podman run -d --name ac-database --network ac-net \
        -e MYSQL_ROOT_PASSWORD=${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} \
        -p 127.0.0.1:${DOCKER_DB_EXTERNAL_PORT:-3306}:3306 \
        -v ac-database:/var/lib/mysql \
        --restart unless-stopped --memory 2g \
        docker.io/library/mysql:8.4 \
        --innodb-buffer-pool-size=512M --max-connections=100 >/dev/null
fi
echo 'Waiting for mariadb to become healthy...'
for i in \$(seq 1 30); do
    if podman exec ac-database mysqladmin -uroot -p${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} ping >/dev/null 2>&1; then
        echo 'mariadb ok'
        break
    fi
    sleep 2
done
"

log "Pre-creating acore_playerbots database (db-import handles the rest)..."
deck "
podman exec ac-database mysql -uroot -p${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} \
    -e 'CREATE DATABASE IF NOT EXISTS acore_playerbots CHARACTER SET utf8mb4;' 2>/dev/null
"

log "Running ac-db-import (creates schemas, imports world data)..."
deck "
podman rm -f ac-db-import 2>/dev/null
podman run --rm --name ac-db-import --network ac-net --userns=keep-id \
    -e AC_LOGIN_DATABASE_INFO='ac-database;3306;root;${DOCKER_DB_ROOT_PASSWORD:-acorewotlk};acore_auth' \
    -e AC_WORLD_DATABASE_INFO='ac-database;3306;root;${DOCKER_DB_ROOT_PASSWORD:-acorewotlk};acore_world' \
    -e AC_CHARACTER_DATABASE_INFO='ac-database;3306;root;${DOCKER_DB_ROOT_PASSWORD:-acorewotlk};acore_characters' \
    -e AC_DATA_DIR=/azerothcore/env/dist/data \
    -e AC_LOGS_DIR=/azerothcore/env/dist/logs \
    -v $WOW_ROOT/configs:/azerothcore/env/dist/etc:Z \
    -v $WOW_ROOT/logs:/azerothcore/env/dist/logs:Z \
    acore/ac-wotlk-db-import:local 2>&1 | grep -E 'Applied|Halting|Error' | tail -10
"

log "Pinning realmlist to 127.0.0.1..."
deck "
podman exec ac-database mysql -uroot -p${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} acore_auth \
    -e 'UPDATE realmlist SET address=\"127.0.0.1\", localAddress=\"127.0.0.1\" WHERE id=1;'
podman exec ac-database mysql -uroot -p${DOCKER_DB_ROOT_PASSWORD:-acorewotlk} acore_auth \
    -e 'SELECT id,name,address,localAddress FROM realmlist;'
"

log "Step 7 complete."
