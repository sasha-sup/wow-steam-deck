#!/usr/bin/env bash
# Step 10 — install Lutris (flatpak) on the Deck and write realmlist.wtf in
# every client locale folder so the client always points at the local server.
#
# Lutris itself needs a GUI step to add the WoW.exe game (Wine prefix wizard).
# After this script finishes, see the README for the 5-click manual setup, or
# run scripts/play.sh which uses Wine via Lutris CLI directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Adding flathub remote (user-scoped)..."
deck '
flatpak --user remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
'

log "Installing Lutris flatpak (large download — be patient)..."
deck '
flatpak --user list | grep -q net.lutris.Lutris || \
    flatpak --user install -y --noninteractive flathub net.lutris.Lutris
flatpak --user list | grep lutris
'

log "Pinning realmlist.wtf to 127.0.0.1 in every locale..."
deck "
for L in enUS enGB enCN ruRU deDE frFR esES esMX koKR zhCN zhTW; do
    [ -d \"$WOW_ROOT/client/Data/\$L\" ] || continue
    echo 'set realmlist 127.0.0.1' > \"$WOW_ROOT/client/Data/\$L/realmlist.wtf\"
done
ls $WOW_ROOT/client/Data/*/realmlist.wtf 2>/dev/null | wc -l
"

log "Installing onboard (on-screen keyboard for Desktop Mode launches)..."
deck '
if ! command -v onboard >/dev/null 2>&1; then
    sudo -n steamos-readonly disable
    sudo -n pacman -S --needed --noconfirm onboard
    sudo -n steamos-readonly enable
fi
command -v onboard
'

log "Step 10 complete. Next: scripts/wow.sh"
