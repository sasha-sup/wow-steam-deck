#!/usr/bin/env bash
# Step 0 — prep the Steam Deck:
#   - sudo NOPASSWD for `deck` (file sorted after `wheel` so it actually wins)
#   - install podman-compose via pacman (after a temporary readonly disable)
#   - configure podman registries to resolve unqualified image names
#
# Idempotent. Re-run after a SteamOS update if NOPASSWD stops working.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log "Checking SSH access..."
deck 'echo "SSH ok on $(hostname)"' || die "SSH to $DECK_HOST failed"

log "Setting up sudo NOPASSWD (zz-deck-nopw)..."
deck '
if sudo -n true 2>/dev/null; then
    echo "sudo NOPASSWD already active"
    exit 0
fi
echo "Enter sudo password once to install the NOPASSWD rule:"
echo "deck ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-deck-nopw >/dev/null
sudo chmod 440 /etc/sudoers.d/zz-deck-nopw
sudo -k
sudo -n whoami >/dev/null && echo "NOPASSWD: ok"
'

log "Installing podman-compose via pacman (temporarily disabling readonly)..."
deck '
sudo -n steamos-readonly disable
sudo -n pacman-key --init >/dev/null 2>&1 || true
sudo -n pacman-key --populate >/dev/null 2>&1 || true
sudo -n pacman -Sy --needed --noconfirm podman podman-compose
sudo -n steamos-readonly enable
'

log "Configuring podman unqualified-search-registries..."
deck '
mkdir -p ~/.config/containers
cat > ~/.config/containers/registries.conf <<EOF
unqualified-search-registries = ["docker.io"]
EOF
'

log "Verifying podman..."
deck 'podman --version && podman-compose --version && podman info --format "rootless={{.Host.Security.Rootless}}"'

log "Step 0 complete."
