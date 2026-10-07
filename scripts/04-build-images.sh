#!/usr/bin/env bash
# Step 4 — build all four podman images.
#
# - ac-wotlk-db-import   (~1.2 GB)
# - ac-wotlk-authserver  (~180 MB)
# - ac-wotlk-worldserver (~680 MB) — links in mod-playerbots, mod-ah-bot, mod-individual-progression
# - ac-wotlk-tools       (~700 MB) — for client data extraction
#
# First build is 1–2+ hours on the Deck, mostly compiling the worldserver. Logs
# go to $WOW_ROOT/logs/build.log.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CORE_DIR="$WOW_ROOT/server/ac"

log "Copying .env and docker-compose.override.yml from repo to AC dir on the Deck..."
if [[ "$DECK_LOCAL" == "1" ]]; then
    cp "$REPO_ROOT/.env" "$CORE_DIR/.env"
    cp "$REPO_ROOT/docker-compose.override.yml" "$CORE_DIR/docker-compose.override.yml"
else
    scp -q "$REPO_ROOT/.env" "$DECK_HOST:$CORE_DIR/.env"
    scp -q "$REPO_ROOT/docker-compose.override.yml" "$DECK_HOST:$CORE_DIR/docker-compose.override.yml"
fi

log "Validating compose config..."
deck "cd \"$CORE_DIR\" && podman-compose config >/dev/null && echo 'compose: ok'"

BUILD_LOG="$WOW_ROOT/logs/build.log"
BUILD_PID="$WOW_ROOT/logs/build.pid"
BUILD_RC="$WOW_ROOT/logs/build.rc"

log "Building images via podman-compose (db-import, authserver, worldserver). This is the long step."
deck "
set -euo pipefail
cd \"$CORE_DIR\"
mkdir -p \"$WOW_ROOT/logs\"
rm -f \"$BUILD_RC\"
nohup bash -c 'podman-compose build; echo \$? > \"$BUILD_RC\"' > \"$BUILD_LOG\" 2>&1 &
echo \$! > \"$BUILD_PID\"
echo \"build PID=\$!\"
"

# Wait on the recorded PID. `pgrep -f podman-compose` never ends here: it also
# matches this very `bash -c` / ssh command line, which contains that string.
log "Build is running in background on the Deck. Tailing progress..."
deck "
echo 'You can detach with Ctrl+C — build continues. Re-attach with:'
echo \"  ssh \$USER@<deck> 'tail -f $BUILD_LOG'\"
echo
pid=\$(cat \"$BUILD_PID\")
while kill -0 \"\$pid\" 2>/dev/null; do
    sleep 30
    echo \"--- \$(date +%H:%M:%S) tail ---\"
    tail -2 \"$BUILD_LOG\"
done
"

rc="$(deck "cat \"$BUILD_RC\" 2>/dev/null || echo missing")"
if [[ "$rc" != "0" ]]; then
    deck "tail -30 \"$BUILD_LOG\"" || true
    die "podman-compose build failed (exit code: $rc). Full log: $BUILD_LOG on the Deck. Fix the error above and re-run this step."
fi

log "Building ac-tools image (separate, profile=tools — needed for data extraction)..."
deck "
set -o pipefail
cd \"$CORE_DIR\"
podman build -f apps/docker/Dockerfile --target tools \
    -t acore/ac-wotlk-tools:local \
    --build-arg USER_ID=1000 --build-arg GROUP_ID=1000 --build-arg DOCKER_USER=acore \
    . 2>&1 | tail -10
"

log "Built images:"
deck "podman images | grep acore"
log "Step 4 complete."
