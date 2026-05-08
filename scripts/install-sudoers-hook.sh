#!/usr/bin/env bash
# install-sudoers-hook.sh — robust handling of the NOPASSWD sudoers file
# that SteamOS updates wipe along with the rest of /etc.
#
# We can't survive an update without root persistence (impossible on SteamOS
# without an immutable-overlay hack), so the strategy is:
#
#   1. Install ~/.local/bin/wow-fix-sudoers — single-command repair.
#   2. Install a systemd --user oneshot at login that detects missing rule
#      and notifies via notify-send + writes a marker to ~/.cache/wow.
#   3. Append a small ~/.bashrc check that prints a warning at shell start.
#
# Re-running rewrites everything in place.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Writing wow-fix-sudoers helper..."
deck "
mkdir -p \"\$HOME/.local/bin\"
cat > \"\$HOME/.local/bin/wow-fix-sudoers\" <<'FIX'
#!/usr/bin/env bash
# Re-apply NOPASSWD rule (prompts for sudo password once).
set -euo pipefail
RULE='/etc/sudoers.d/zz-deck-nopw'
if sudo -n true 2>/dev/null; then
    echo 'NOPASSWD already active.'; exit 0
fi
echo 'Re-installing NOPASSWD rule (prompts for password once)...'
echo 'deck ALL=(ALL) NOPASSWD: ALL' | sudo tee \"\$RULE\" >/dev/null
sudo chmod 440 \"\$RULE\"
sudo -k
sudo -n whoami >/dev/null && echo 'NOPASSWD: ok'
FIX
chmod +x \"\$HOME/.local/bin/wow-fix-sudoers\"
"

log "Installing systemd --user check unit..."
deck "
UDIR=\"\$HOME/.config/systemd/user\"
mkdir -p \"\$UDIR\"
mkdir -p \"\$HOME/.cache/wow\"

cat > \"\$UDIR/wow-sudoers-check.service\" <<UNIT
[Unit]
Description=Detect missing wow-steam-deck NOPASSWD sudoers rule
After=default.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if ! sudo -n true 2>/dev/null; then \
    touch \$HOME/.cache/wow/sudoers-missing; \
    command -v notify-send >/dev/null && notify-send -u critical \"WoW server\" \"NOPASSWD sudo rule missing — run: wow-fix-sudoers\" || true; \
else \
    rm -f \$HOME/.cache/wow/sudoers-missing; \
fi'

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now wow-sudoers-check.service
"

log "Installing ~/.bashrc warning block..."
BLOCK_BEGIN='# >>> wow-steam-deck sudoers check >>>'
BLOCK_END='# <<< wow-steam-deck sudoers check <<<'
deck "
RC=\"\$HOME/.bashrc\"
touch \"\$RC\"
sed -i '/$BLOCK_BEGIN/,/$BLOCK_END/d' \"\$RC\"
cat >> \"\$RC\" <<'BLOCK'
$BLOCK_BEGIN
if [ -f \"\$HOME/.cache/wow/sudoers-missing\" ]; then
    echo \"[wow] NOPASSWD sudo rule missing (likely after a SteamOS update). Run: wow-fix-sudoers\" >&2
fi
$BLOCK_END
BLOCK
"

log "Done. Manual repair after a SteamOS update: wow-fix-sudoers"
