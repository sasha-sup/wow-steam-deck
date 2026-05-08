#!/usr/bin/env bash
# restore.sh — restore an archive made by backup.sh.
#
# Usage:
#   scripts/restore.sh <archive>          # restores DB schemas + configs
#   scripts/restore.sh --latest           # picks newest wow-full-*.tar.zst
#   scripts/restore.sh --no-configs ...   # skip configs/ overwrite
#
# DESTRUCTIVE: drops + recreates each schema from the dump. Stops worldserver
# and authserver first; restarts them at the end.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DBPASS="${DOCKER_DB_ROOT_PASSWORD:-acorewotlk}"
RESTORE_CONFIGS=1
ARCHIVE=""

while (($#)); do
    case "$1" in
        --latest)     ARCHIVE="LATEST"; shift ;;
        --no-configs) RESTORE_CONFIGS=0; shift ;;
        -h|--help)    sed -n '2,11p' "$0"; exit 0 ;;
        *)            ARCHIVE="$1"; shift ;;
    esac
done

[[ -n "$ARCHIVE" ]] || die "give an archive path or --latest"

if [[ "$ARCHIVE" == "LATEST" ]]; then
    ARCHIVE="$(deck "ls -1t $WOW_ROOT/backups/wow-full-*.tar.zst 2>/dev/null | head -1")"
    [[ -n "$ARCHIVE" ]] || die "no wow-full-*.tar.zst in $WOW_ROOT/backups/"
    log "Latest archive: $ARCHIVE"
fi

deck "[ -f \"$ARCHIVE\" ]" || die "archive not on Deck: $ARCHIVE"

read -rp "DESTRUCTIVE: restore $ARCHIVE? (yes/NO) " ans
[[ "$ans" == "yes" ]] || { log "aborted."; exit 1; }

log "Stopping worldserver + authserver (keeping DB up)..."
deck "
for c in ac-worldserver ac-authserver; do
    podman ps --format '{{.Names}}' | grep -q \"^\$c\$\" && podman stop -t 30 \$c >/dev/null || true
done
"

log "Extracting archive..."
deck "
set -euo pipefail
WORK=\"\$(mktemp -d -p \"$WOW_ROOT/backups\" restore-XXXX)\"
tar --zstd -xf \"$ARCHIVE\" -C \"\$WORK\"
cd \"\$WORK\"/staging-*
cat MANIFEST
echo \"---\"
for sql in *.sql; do
    schema=\"\${sql%.sql}\"
    echo \"--- restoring \$schema (drop + reimport)\"
    podman exec ac-database mysql -uroot -p$DBPASS \
        -e \"DROP DATABASE IF EXISTS \\\`\$schema\\\`; CREATE DATABASE \\\`\$schema\\\` CHARACTER SET utf8mb4;\"
    podman exec -i ac-database mysql -uroot -p$DBPASS \"\$schema\" < \"\$sql\"
done
if [ $RESTORE_CONFIGS = 1 ] && [ -d configs ]; then
    echo '--- restoring configs/'
    rsync -a --delete configs/ \"$WOW_ROOT/configs/\"
fi
cd /
rm -rf \"\$WORK\"
"

log "Restarting stack..."
"$SCRIPT_DIR/08-start-stack.sh"

log "Restore complete from $ARCHIVE"
