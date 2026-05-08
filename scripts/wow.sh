#!/usr/bin/env bash
# wow.sh — start the AzerothCore server stack on the Deck.
# Idempotent. The client is launched separately via Steam (Non-Steam Game →
# Wow.exe with Proton). This script does NOT touch wine/lutris.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DECK_LOCAL=1
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/common.sh"

log "Starting server stack (idempotent)..."
"$REPO_ROOT/scripts/08-start-stack.sh"

log "Stack ready. Launch the client from Steam."
