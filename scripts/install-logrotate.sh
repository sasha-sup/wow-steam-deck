#!/usr/bin/env bash
# install-logrotate.sh — rotate worldserver / authserver logs daily so they
# don't fill the SD card. Uses user-scoped logrotate triggered by a systemd
# --user timer (no system-level config touched).
#
# Config:    ~/.config/wow/logrotate.conf
# State:     ~/.cache/wow/logrotate.state
# Trigger:   wow-logrotate.timer (daily 04:30)
#
# Idempotent.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

LOGS_DIR="${DOCKER_VOL_LOGS:-$WOW_ROOT/logs}"

log "Verifying logrotate is on PATH..."
deck "command -v logrotate >/dev/null || { echo 'logrotate missing — install via pacman'; exit 1; }"

log "Writing $HOME/.config/wow/logrotate.conf ..."
deck "
mkdir -p \"\$HOME/.config/wow\" \"\$HOME/.cache/wow\"
cat > \"\$HOME/.config/wow/logrotate.conf\" <<CONF
$LOGS_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d
}
CONF
"

log "Installing wow-logrotate.{service,timer}..."
deck "
UDIR=\"\$HOME/.config/systemd/user\"
mkdir -p \"\$UDIR\"

cat > \"\$UDIR/wow-logrotate.service\" <<UNIT
[Unit]
Description=Rotate WoW server logs

[Service]
Type=oneshot
ExecStart=/usr/bin/logrotate -s %h/.cache/wow/logrotate.state %h/.config/wow/logrotate.conf
UNIT

cat > \"\$UDIR/wow-logrotate.timer\" <<UNIT
[Unit]
Description=Daily WoW log rotation at 04:30

[Timer]
OnCalendar=*-*-* 04:30:00
Persistent=true
Unit=wow-logrotate.service

[Install]
WantedBy=timers.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now wow-logrotate.timer
systemctl --user list-timers wow-logrotate --no-pager
"

log "Test once: systemctl --user start wow-logrotate.service"
log "Done."
