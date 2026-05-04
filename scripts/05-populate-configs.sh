#!/usr/bin/env bash
# Step 5 — populate $WOW_ROOT/configs/ with default *.conf files and tune
# playerbots for the Deck (lower bot count + slower spawn rate).
#
# Why a container? The fork's worldserver image entrypoint does the
# *.conf.dist → *.conf copy on first run. We use the worldserver image with
# `--userns=keep-id` so the conf files land on host owned by deck:deck.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Running worldserver entrypoint to populate $WOW_ROOT/configs/ ..."
deck "
podman run --rm --userns=keep-id \
    -v $WOW_ROOT/configs:/azerothcore/env/dist/etc:Z \
    acore/ac-wotlk-worldserver:local true 2>&1 | tail -5
"

log "Copying remaining *.conf.dist → *.conf..."
deck "
cd \"$WOW_ROOT/configs\"
for f in authserver dbimport; do
    [ -f \"\$f.conf\" ] || cp \"\$f.conf.dist\" \"\$f.conf\"
done
for f in mod_ahbot playerbots individualProgression; do
    [ -f \"modules/\$f.conf\" ] || cp \"modules/\$f.conf.dist\" \"modules/\$f.conf\"
done
"

log "Tuning playerbots.conf for Steam Deck (30 bots, slow spawn)..."
deck "
sed -i \
    -e 's/^AiPlayerbot.MinRandomBots = .*/AiPlayerbot.MinRandomBots = 30/' \
    -e 's/^AiPlayerbot.MaxRandomBots = .*/AiPlayerbot.MaxRandomBots = 30/' \
    -e 's/^AiPlayerbot.RandomBotsPerInterval = .*/AiPlayerbot.RandomBotsPerInterval = 5/' \
    \"$WOW_ROOT/configs/modules/playerbots.conf\"
grep -E '^AiPlayerbot\\.(Enabled|MinRandomBots|MaxRandomBots|RandomBotsPerInterval) ' \
    \"$WOW_ROOT/configs/modules/playerbots.conf\"
"

log "Step 5 complete."
