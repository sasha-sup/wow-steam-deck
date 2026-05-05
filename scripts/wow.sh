#!/usr/bin/env bash
# wow.sh — universal one-shot launcher.
# Starts the server stack (idempotent), then runs the WoW 3.3.5a client via
# Wine. Use it from a terminal in Desktop Mode, OR add it as a Non-Steam
# Game in Steam (then Steam's overlay + virtual keyboard work in Gaming Mode).
#
# This script must run ON the Deck (Konsole or Steam-launched). It auto-
# detects the Plasma session env so the WoW window appears on the Deck
# screen no matter how it was invoked.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DECK_LOCAL=1

# Capture everything to a log so Steam-launched failures are debuggable.
exec > >(tee -a /tmp/wow.log) 2>&1
echo "=== wow.sh start $(date '+%F %T') PPID=$PPID ==="
echo "ENV: DISPLAY=${DISPLAY:-} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-} XAUTHORITY=${XAUTHORITY:-}"
echo "ENV: SteamAppId=${SteamAppId:-} SteamGameId=${SteamGameId:-}"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/common.sh"

WINE_PREFIX_PATH="${WINE_PREFIX_PATH:-$WOW_ROOT/wine-prefix}"
WOW_EXE="$WOW_ROOT/client/Wow.exe"
LUTRIS_APP="net.lutris.Lutris"

[[ -f "$WOW_EXE" ]] || die "Client missing at $WOW_EXE"

log "Starting server stack (idempotent)..."
"$REPO_ROOT/scripts/08-start-stack.sh" >/tmp/wow-stack.log 2>&1 || {
    cat /tmp/wow-stack.log >&2
    die "stack failed to start (see /tmp/wow-stack.log)"
}

# Pull DISPLAY / XAUTHORITY from the live Plasma session if not set. Steam
# sets them itself in Gaming Mode; we only need this when Steam invokes us
# under gamescope or when running from a fresh login shell.
if [[ -z "${DISPLAY:-}" || -z "${XAUTHORITY:-}" ]]; then
    PLASMA_PID=$(pgrep -u "$(id -u)" -x kwin_x11 2>/dev/null | head -1 || true)
    if [[ -n "$PLASMA_PID" ]]; then
        # shellcheck disable=SC2046
        export $(tr '\0' '\n' < "/proc/$PLASMA_PID/environ" | grep -E '^(DISPLAY|XAUTHORITY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | xargs)
    fi
fi

log "Launching WoW (DISPLAY=${DISPLAY:-?})..."
mkdir -p "$WINE_PREFIX_PATH"

# When NOT launched from Steam (no $SteamAppId), bring up Onboard so the
# touchscreen virtual keyboard is available for the login form. Steam Input
# (Gaming Mode) provides its own keyboard via Steam+X — don't duplicate.
if [[ -z "${SteamAppId:-}${SteamGameId:-}" ]] && command -v onboard >/dev/null 2>&1; then
    pgrep -u "$(id -u)" -x onboard >/dev/null 2>&1 || onboard >/dev/null 2>&1 &
fi

exec env \
    WINEPREFIX="$WINE_PREFIX_PATH" \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES='mscoree=;mshtml=' \
    DXVK_HUD="${DXVK_HUD:-}" \
    flatpak run --command=wine "$LUTRIS_APP" "$WOW_EXE"
