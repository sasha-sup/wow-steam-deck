#!/usr/bin/env bash
# Shared helpers for wow-steam-deck setup scripts.
#
# Every script either runs locally on the workstation and SSHes to the Deck,
# or expects to be run on the Deck itself (DECK_LOCAL=1). They all source
# this file via:
#
#     SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#     source "$SCRIPT_DIR/lib/common.sh"

set -euo pipefail

# Resolve repo root (parent of scripts/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load .env if it exists; .env.example otherwise.
if [[ -f "$REPO_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -a; source "$REPO_ROOT/.env"; set +a
elif [[ -f "$REPO_ROOT/.env.example" ]]; then
    echo "[common.sh] .env not found, using .env.example. Copy and edit it." >&2
    set -a; source "$REPO_ROOT/.env.example"; set +a
else
    echo "[common.sh] missing .env and .env.example" >&2
    exit 1
fi

: "${WOW_ROOT:=/run/media/deck/SD512/wow}"
: "${DECK_HOST:=}"
: "${DECK_LOCAL:=}"

# Auto-detect: running on the Deck itself if hostname is `steamdeck` and user
# is `deck`. Otherwise we expect DECK_HOST to be set on the workstation.
if [[ -z "$DECK_LOCAL" ]]; then
    if [[ "$(hostname 2>/dev/null)" == "steamdeck" && "$(id -un)" == "deck" ]]; then
        DECK_LOCAL=1
    else
        DECK_LOCAL=0
    fi
fi

if [[ "$DECK_LOCAL" != "1" && -z "$DECK_HOST" ]]; then
    echo "[common.sh] not running on the Deck and DECK_HOST not set." >&2
    echo "  - On the Deck:        clone repo locally; scripts auto-detect." >&2
    echo "  - From a workstation: export DECK_HOST=deck@<ip>" >&2
    exit 1
fi

# Run a command on the Deck (locally or over ssh).
deck() {
    if [[ "$DECK_LOCAL" == "1" ]]; then
        bash -c "$*"
    else
        # shellcheck disable=SC2029
        ssh "$DECK_HOST" "$*"
    fi
}

# Run a script (heredoc) on the Deck.
deck_script() {
    if [[ "$DECK_LOCAL" == "1" ]]; then
        bash
    else
        ssh "$DECK_HOST" bash
    fi
}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '[%s] FATAL: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }
