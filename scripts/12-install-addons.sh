#!/usr/bin/env bash
# Step 12 (optional) — install client-side AddOns into the WoW 3.3.5a client at
# $WOW_ROOT/client/Interface/AddOns/.
#
# Default set is the "gear comparison" loadout for a fresh character:
#   - Pawn         — tooltip "+X% upgrade" using stat-weight scales
#   - RatingBuster — break combat ratings down into % (hit/crit/haste)
#
# Side-by-side compare with currently-equipped is already built into WoW 3.3.5:
# hold Shift while hovering an item. No EquipCompare addon needed.
#
# AtlasLoot for 3.3.5a is a multi-folder addon (AtlasLoot, AtlasLoot_*, etc.)
# and doesn't fit the single-folder install pattern below. To add it, clone
# https://github.com/Gescht/AtlasLoot3.3.5a manually and copy each AtlasLoot*
# subfolder into Interface/AddOns/.
#
# Usage:
#   scripts/12-install-addons.sh                # install default set
#   scripts/12-install-addons.sh --force        # re-download + overwrite
#   scripts/12-install-addons.sh --list         # print URLs and exit
#
# Override or extend by setting ADDONS in your .env, format:
#   ADDONS="<name>|<url>;<name>|<url>;..."
# URL must be a .zip with exactly one AddOn folder inside (containing <name>.toc
# with `## Interface: 30300`). GitHub branch zips work — the wrapping
# `<repo>-<branch>/` directory is unwrapped automatically.
#
# Idempotent: existing AddOn folders are skipped unless --force is passed.
# After install, in the WoW login screen click AddOns (bottom-left) and tick
# "Load out of date AddOns".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

FORCE=0
LIST_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --list)  LIST_ONLY=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *) die "unknown arg: $arg" ;;
    esac
done

# Default addon set. Override via $ADDONS in .env.
# These mirrors are community-maintained WotLK 3.3.5a builds. If a URL rots,
# replace it in your .env — the script will pick up the override.
DEFAULT_ADDONS=(
    "Pawn|https://github.com/Road-block/Pawn/archive/refs/heads/master.zip"
    "RatingBuster|https://github.com/Einherjarn/RatingBuster-3.3.5/archive/refs/heads/master.zip"
)

if [[ -n "${ADDONS:-}" ]]; then
    IFS=';' read -r -a ENTRIES <<< "$ADDONS"
else
    ENTRIES=("${DEFAULT_ADDONS[@]}")
fi

if [[ "$LIST_ONLY" == "1" ]]; then
    printf '%s\n' "${ENTRIES[@]}"
    exit 0
fi

ADDONS_DIR="$WOW_ROOT/client/Interface/AddOns"

log "Ensuring AddOns dir exists at $ADDONS_DIR ..."
deck "mkdir -p \"$ADDONS_DIR\""

# Verify the client folder actually has Interface/ — guard against running this
# before the client is copied.
deck "[ -d \"$WOW_ROOT/client/Interface\" ]" \
    || die "client not found at $WOW_ROOT/client (copy WoW 3.3.5a first, see README)"

# Check for required tools on the Deck.
deck "command -v curl >/dev/null && command -v unzip >/dev/null" \
    || die "curl + unzip required on the Deck (sudo pacman -S unzip if missing)"

install_addon() {
    local name="$1" url="$2"
    local target="$ADDONS_DIR/$name"

    if [[ "$FORCE" != "1" ]] && deck "[ -d \"$target\" ]"; then
        log "  [skip] $name (already installed; --force to overwrite)"
        return 0
    fi

    log "  [get]  $name <- $url"
    deck "
set -euo pipefail
TMP=\$(mktemp -d)
trap 'rm -rf \"\$TMP\"' EXIT
curl -fL --retry 3 -o \"\$TMP/a.zip\" \"$url\"
unzip -q \"\$TMP/a.zip\" -d \"\$TMP/extract\"

# Find the AddOn folder: directory containing a $name.toc (preferred), else any
# directory containing *.toc. Handles archives with or without a top wrapper.
SRC=\$(find \"\$TMP/extract\" -maxdepth 4 -type f -iname '$name.toc' -printf '%h\n' | head -1)
if [ -z \"\$SRC\" ]; then
    SRC=\$(find \"\$TMP/extract\" -maxdepth 4 -type f -iname '*.toc' -printf '%h\n' | head -1)
fi
[ -n \"\$SRC\" ] || { echo 'no .toc found in archive' >&2; exit 1; }

# Validate Interface version: warn but don't fail if not 30300, since some
# addons share a .toc across versions.
if grep -q '^## *Interface:' \"\$SRC\"/*.toc 2>/dev/null; then
    IFACE=\$(grep -hE '^## *Interface:' \"\$SRC\"/*.toc | head -1 | awk '{print \$NF}')
    if [ \"\$IFACE\" != \"30300\" ]; then
        echo \"  warn: $name .toc Interface=\$IFACE (expected 30300, may need 'Load out of date')\" >&2
    fi
fi

rm -rf \"$target\"
mv \"\$SRC\" \"$target\"
"
}

log "Installing ${#ENTRIES[@]} addon(s)..."
for entry in "${ENTRIES[@]}"; do
    name="${entry%%|*}"
    url="${entry#*|}"
    [[ -n "$name" && -n "$url" && "$name" != "$url" ]] \
        || die "bad ADDONS entry: $entry (expected name|url)"
    install_addon "$name" "$url"
done

log "Listing installed AddOns..."
deck "ls -1 \"$ADDONS_DIR\""

log "Step 12 complete. In the login screen tick 'Load out of date AddOns'."
log "In game: /pawn opens settings — pick a class scale (Wowhead/Icy Veins preset)."
