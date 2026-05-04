#!/usr/bin/env bash
# Step 2 — clone the AzerothCore Playerbot fork and the 3 modules.
#
# Robust against flaky GitHub HTTP/2 streams: switches git to HTTP/1.1 with a
# 500 MB postBuffer, partial clone (--filter=blob:none) for the big core repo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CORE_DIR="$WOW_ROOT/server/ac"

log "Tuning git on Deck for big clones over wifi..."
deck '
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global core.compression 0
'

if deck "[ -d \"$CORE_DIR/.git\" ]"; then
    log "Core already cloned at $CORE_DIR — pulling latest."
    deck "cd \"$CORE_DIR\" && git pull --ff-only"
else
    log "Cloning AzerothCore (Playerbot fork)..."
    deck "
mkdir -p \"$WOW_ROOT/server\"
cd \"$WOW_ROOT/server\"
git clone --depth 1 --branch Playerbot --filter=blob:none \
    https://github.com/liyunfan1223/azerothcore-wotlk.git ac
"
fi

log "Cloning modules..."
deck "
cd \"$CORE_DIR/modules\"
[ -d mod-playerbots ]              || git clone --depth 1 https://github.com/liyunfan1223/mod-playerbots.git
[ -d mod-ah-bot ]                  || git clone --depth 1 https://github.com/azerothcore/mod-ah-bot.git
[ -d mod-individual-progression ]  || git clone --depth 1 https://github.com/ZhengPeiRu21/mod-individual-progression.git
ls
"

log "Step 2 complete."
