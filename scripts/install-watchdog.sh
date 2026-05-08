#!/usr/bin/env bash
# install-watchdog.sh — install two systemd --user timers:
#
#   wow-watchdog.timer   every 1 min   port 8085 dead → podman restart ac-worldserver
#   wow-backup.timer     daily 04:00   scripts/backup.sh
#
# Idempotent. Uninstall: systemctl --user disable --now wow-watchdog.timer wow-backup.timer

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ "$DECK_LOCAL" == "1" ]]; then
    DECK_REPO="$REPO_ROOT"
else
    DECK_REPO="${DECK_REPO:-/home/deck/wow-steam-deck}"
fi

log "Writing watchdog check script..."
deck "
mkdir -p \"\$HOME/.local/bin\"
cat > \"\$HOME/.local/bin/wow-watchdog.sh\" <<'CHECK'
#!/usr/bin/env bash
# fail-fast watchdog: if ac-worldserver is up but port 8085 isn't listening
# inside the container netns, restart it.
set -euo pipefail
podman ps --format '{{.Names}}' | grep -q '^ac-worldserver\$' || exit 0
if podman exec ac-worldserver bash -c 'exec 3<>/dev/tcp/127.0.0.1/8085' 2>/dev/null; then
    exit 0
fi
echo \"[\$(date -Is)] worldserver port dead — restarting\" >&2
podman restart ac-worldserver
CHECK
chmod +x \"\$HOME/.local/bin/wow-watchdog.sh\"
"

log "Installing wow-watchdog.{service,timer}..."
deck "
UDIR=\"\$HOME/.config/systemd/user\"
mkdir -p \"\$UDIR\"

cat > \"\$UDIR/wow-watchdog.service\" <<UNIT
[Unit]
Description=WoW worldserver port watchdog
After=wow-server.service

[Service]
Type=oneshot
ExecStart=%h/.local/bin/wow-watchdog.sh
UNIT

cat > \"\$UDIR/wow-watchdog.timer\" <<UNIT
[Unit]
Description=Run wow-watchdog every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
Unit=wow-watchdog.service

[Install]
WantedBy=timers.target
UNIT
"

log "Installing wow-backup.{service,timer}..."
deck "
UDIR=\"\$HOME/.config/systemd/user\"
cat > \"\$UDIR/wow-backup.service\" <<UNIT
[Unit]
Description=WoW DB backup

[Service]
Type=oneshot
ExecStart=$DECK_REPO/scripts/backup.sh
UNIT

cat > \"\$UDIR/wow-backup.timer\" <<UNIT
[Unit]
Description=Daily WoW DB backup at 04:00

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true
Unit=wow-backup.service

[Install]
WantedBy=timers.target
UNIT
"

log "Reloading + enabling timers..."
deck "
systemctl --user daemon-reload
systemctl --user enable --now wow-watchdog.timer wow-backup.timer
systemctl --user list-timers wow-* --no-pager
"

log "Watchdog + backup timer installed."
