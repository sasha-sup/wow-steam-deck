#!/usr/bin/env bash
# install-autostart.sh — install systemd --user unit so the server stack
# comes up at boot (linger enabled) and after every login.
#
#   ~/.config/systemd/user/wow-server.service  → calls scripts/wow.sh
#   loginctl enable-linger deck                → user units run before login
#
# Idempotent: re-run replaces the unit file and re-enables it.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ "$DECK_LOCAL" == "1" ]]; then
    DECK_REPO="$REPO_ROOT"
else
    DECK_REPO="${DECK_REPO:-/home/deck/wow-steam-deck}"
fi

log "Installing wow-server.service (systemd --user)..."
deck "
set -e
mkdir -p \"\$HOME/.config/systemd/user\"
cat > \"\$HOME/.config/systemd/user/wow-server.service\" <<UNIT
[Unit]
Description=AzerothCore WoW 3.3.5a server stack (rootless podman)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$DECK_REPO/scripts/wow.sh
ExecStop=$DECK_REPO/scripts/stop.sh
TimeoutStartSec=600

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable wow-server.service
echo 'unit installed.'
"

log "Enabling linger so unit runs before login..."
deck "loginctl show-user \$(id -un) -p Linger | grep -q 'Linger=yes' || sudo -n loginctl enable-linger \$(id -un)"

log "Status:"
deck "systemctl --user status wow-server.service --no-pager 2>&1 | head -10 || true"

log "Start now? Use: systemctl --user start wow-server"
log "Disable: systemctl --user disable --now wow-server"
log "Done."
