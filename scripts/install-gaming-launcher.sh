#!/usr/bin/env bash
# install-gaming-launcher.sh — wire the full "click and play" experience:
#
#   1. Server autostart at boot     → install-autostart.sh
#   2. Watchdog + daily backup      → install-watchdog.sh
#   3. Log rotation                 → install-logrotate.sh
#   4. Sudoers self-heal hint       → install-sudoers-hook.sh
#   5. Wow.exe Steam shortcut       → add-steam-shortcut.sh (Proton Experimental)
#   6. Desktop launcher (.desktop)  → ~/.local/share/applications/wow-play.desktop
#
# After this: Gaming Mode → Library → "WoW 3.3.5a" → Play. Done.
#
# Skip a sub-installer:
#   SKIP_AUTOSTART=1 SKIP_WATCHDOG=1 ... scripts/install-gaming-launcher.sh
#
# Steam must be CLOSED (the shortcut step rewrites shortcuts.vdf).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

run_step() {
    local var="$1" cmd="$2"
    if [[ "${!var:-0}" == "1" ]]; then
        log "[skip] $var=1 → $cmd"
        return
    fi
    log "===== $cmd ====="
    bash -c "$cmd"
}

run_step SKIP_AUTOSTART  "$SCRIPT_DIR/install-autostart.sh"
run_step SKIP_WATCHDOG   "$SCRIPT_DIR/install-watchdog.sh"
run_step SKIP_LOGROTATE  "$SCRIPT_DIR/install-logrotate.sh"
run_step SKIP_SUDOHOOK   "$SCRIPT_DIR/install-sudoers-hook.sh"
run_step SKIP_SHORTCUT   "$SCRIPT_DIR/add-steam-shortcut.sh"

log "===== writing desktop launcher ====="
if [[ "$DECK_LOCAL" == "1" ]]; then
    DECK_REPO="$REPO_ROOT"
else
    DECK_REPO="${DECK_REPO:-/home/deck/wow-steam-deck}"
fi

deck "
mkdir -p \"\$HOME/.local/share/applications\"
cat > \"\$HOME/.local/share/applications/wow-play.desktop\" <<DESK
[Desktop Entry]
Type=Application
Name=WoW 3.3.5a (auto-start server)
Comment=Start AzerothCore stack and launch WoW client
Exec=$DECK_REPO/scripts/wow-play.sh
Icon=applications-games
Terminal=false
Categories=Game;
DESK
update-desktop-database \"\$HOME/.local/share/applications\" 2>/dev/null || true
"

log "All done. Reboot once so wow-server.service kicks in at boot, then:"
log "  Gaming Mode → Library → 'WoW 3.3.5a'"
log "  or Desktop → 'WoW 3.3.5a (auto-start server)' launcher"
