#!/usr/bin/env bash
# setup-aliases.sh — install short shell aliases on the Deck so the server
# is one keystroke away from any terminal.
#
#   wow         — start server stack (idempotent)
#   wowstop     — stop the stack
#   wowstatus   — podman ps
#   wowlogs     — follow worldserver logs
#
# Idempotent: re-running rewrites the marked block, never duplicates lines.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DECK_LOCAL=1
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/common.sh"

# Where the repo lives on the Deck. Defaults to ~/wow-steam-deck unless the
# script is being run from a clone in a different path on the Deck itself.
if [[ "$DECK_LOCAL" == "1" ]]; then
    DECK_REPO="$REPO_ROOT"
else
    DECK_REPO="${DECK_REPO:-/home/deck/wow-steam-deck}"
fi

BLOCK_BEGIN='# >>> wow-steam-deck aliases >>>'
BLOCK_END='# <<< wow-steam-deck aliases <<<'

read -r -d '' BLOCK <<EOF || true
$BLOCK_BEGIN
alias wow='$DECK_REPO/scripts/wow.sh'
alias wowstop='$DECK_REPO/scripts/stop.sh'
alias wowstatus='$DECK_REPO/scripts/status.sh'
alias wowlogs='tail -f \$(grep -E "^DOCKER_VOL_LOGS=" "$DECK_REPO/.env" | cut -d= -f2)/Server.log'
$BLOCK_END
EOF

log "Installing aliases on the Deck (~/.bashrc)..."
deck "
set -e
RC=\"\$HOME/.bashrc\"
touch \"\$RC\"
# Strip any previous block, then append the fresh one.
sed -i '/$BLOCK_BEGIN/,/$BLOCK_END/d' \"\$RC\"
cat >> \"\$RC\" <<'BLOCK'
$BLOCK
BLOCK
"

log "Done. Open a new shell or run: source ~/.bashrc"
log "Then: wow | wowstop | wowstatus | wowlogs"
