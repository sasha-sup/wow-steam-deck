#!/usr/bin/env bash
# wow-play.sh — desktop-mode one-shot: ensure server up, then launch the
# WoW Steam shortcut via steam:// URI. Works from Konsole and KRunner.
#
# Gaming Mode users don't need this — wow-server.service keeps the server up
# at boot, then they click the "WoW 3.3.5a" shortcut directly.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

NAME="${WOW_SHORTCUT_NAME:-WoW 3.3.5a}"
EXE="${WOW_SHORTCUT_EXE:-$WOW_ROOT/client/Wow.exe}"

log "Ensuring server stack is up (idempotent)..."
"$SCRIPT_DIR/wow.sh"

log "Waiting for worldserver port 8085 (max 60 s)..."
for _ in $(seq 1 30); do
    if deck "ss -tnl 2>/dev/null | grep -q '127.0.0.1:8085'"; then
        log "worldserver ready."
        break
    fi
    sleep 2
done

log "Computing shortcut appid for '$NAME' + '$EXE' ..."
APPID=$(python3 -c "
import binascii
key = ('$EXE' + '$NAME').encode()
crc = binascii.crc32(key) | 0x80000000
# Steam URI uses upper-32 form for non-Steam games:
print((crc << 32) | 0x02000000)
")

log "Launching Steam URI: steam://rungameid/$APPID"
if command -v steam >/dev/null 2>&1; then
    steam "steam://rungameid/$APPID" >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "steam://rungameid/$APPID" >/dev/null 2>&1 &
else
    die "no steam / xdg-open on PATH — open Steam manually and click '$NAME'"
fi

log "Launched. Server stays up after exit (stop with: wowstop)."
