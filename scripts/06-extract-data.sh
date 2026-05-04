#!/usr/bin/env bash
# Step 6 — extract DBC + maps + vmaps + mmaps from the WoW client.
#
# Pre-requisite: $WOW_ROOT/client/ contains the 3.3.5a (build 12340) client
# (Wow.exe, Data/, Interface/, WTF/). See README "Copy the WoW 3.3.5a client".
#
# Output goes to $WOW_ROOT/data/. Total ~4 GB. Total wall time on a Deck:
#   map_extractor:     ~10 min
#   vmap_extractor:    ~25 min
#   vmap_assembler:    ~5 min
#   mmaps_generator:   ~30–60 min  (multi-thread)
#
# Re-running is a no-op for already-extracted layers (extractors recreate
# their output dirs from scratch). Safe to ctrl-C and resume from a step.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Sanity-checking client folder..."
deck "[ -f \"$WOW_ROOT/client/Wow.exe\" ] && [ -d \"$WOW_ROOT/client/Data\" ]" \
    || die "Client missing — copy WoW 3.3.5a 12340 to $WOW_ROOT/client/"

extract() {
    local stage="$1"; shift
    local cmd="$1"; shift
    log "Extracting $stage ..."
    deck "
podman run --rm --userns=keep-id \
    -v $WOW_ROOT/data:/work:Z \
    -v $WOW_ROOT/client/Data:/work/Data:ro,Z \
    -w /work --entrypoint /bin/bash \
    acore/ac-wotlk-tools:local \
    -c \"$cmd\" 2>&1 | tail -5
"
}

extract "DBC + maps" "/azerothcore/env/dist/bin/map_extractor"

extract "vmaps (extract + assemble)" "
mkdir -p Buildings vmaps
/azerothcore/env/dist/bin/vmap4_extractor && \
/azerothcore/env/dist/bin/vmap4_assembler Buildings vmaps && \
rm -rf Buildings
"

log "Copying mmaps-config.yaml from sources..."
deck "
cp \"$WOW_ROOT/server/ac/src/tools/mmaps_generator/mmaps-config.yaml\" \
   \"$WOW_ROOT/data/mmaps-config.yaml\"
"

extract "mmaps (slow — pathfinding mesh)" "
mkdir -p mmaps
/azerothcore/env/dist/bin/mmaps_generator --threads 6
"

log "Extraction summary:"
deck "du -sh $WOW_ROOT/data/* 2>&1"
log "Step 6 complete."
