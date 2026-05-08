#!/usr/bin/env bash
# setup-all.sh — master runner. Sequences 00→11 with checkpoint state so a
# re-run skips already-completed steps. Hard-gates step 06 on client/Wow.exe.
#
# Usage:
#   scripts/setup-all.sh                # run remaining steps
#   scripts/setup-all.sh --from 04      # force start at step 04
#   scripts/setup-all.sh --only 11      # run a single step
#   scripts/setup-all.sh --reset        # clear checkpoint state
#   scripts/setup-all.sh --dry-run      # print what would run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

STATE_DIR="$REPO_ROOT/.omc/state"
STATE_FILE="$STATE_DIR/setup.json"
mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{"completed":[]}' > "$STATE_FILE"

# Ordered step list. Optional steps (10, 11) included — toggle below.
STEPS=(
    "00:00-prep-deck.sh:SteamOS prep"
    "01:01-init-workspace.sh:workspace dirs"
    "02:02-clone-source.sh:clone AC + modules"
    "03:03-patch-dockerfile.sh:apply Dockerfile patch"
    "04:04-build-images.sh:build images (long)"
    "05:05-populate-configs.sh:populate configs"
    "06:06-extract-data.sh:extract client data (long)"
    "07:07-init-db.sh:db init + import"
    "08:08-start-stack.sh:start stack"
    "09:09-create-account.sh:create GM account"
    "10:10-install-lutris.sh:install Lutris"
    "11:11-apply-rates.sh:apply rate preset (optional)"
)

DRY=0; RESET=0; FROM=""; ONLY=""
ACCT_USER="${ACCT_USER:-test}"; ACCT_PASS="${ACCT_PASS:-test}"; ACCT_GM="${ACCT_GM:-3}"

while (($#)); do
    case "$1" in
        --from)    FROM="$2"; shift 2 ;;
        --only)    ONLY="$2"; shift 2 ;;
        --reset)   RESET=1; shift ;;
        --dry-run) DRY=1; shift ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) die "unknown arg: $1" ;;
    esac
done

if (( RESET )); then
    echo '{"completed":[]}' > "$STATE_FILE"
    log "state cleared: $STATE_FILE"
    exit 0
fi

is_done() {
    grep -q "\"$1\"" "$STATE_FILE"
}
mark_done() {
    python3 - "$STATE_FILE" "$1" <<'PY'
import json, sys
p, step = sys.argv[1], sys.argv[2]
d = json.load(open(p))
if step not in d["completed"]:
    d["completed"].append(step)
json.dump(d, open(p, "w"), indent=2)
PY
}

run_step() {
    local id="$1" script="$2" desc="$3"
    if [[ -n "$FROM" && "$id" < "$FROM" ]]; then
        log "[skip $id] before --from $FROM"
        return
    fi
    if [[ -n "$ONLY" && "$id" != "$ONLY" ]]; then
        return
    fi
    if is_done "$id" && [[ -z "$ONLY" && -z "$FROM" ]]; then
        log "[skip $id] $desc — already completed (use --from $id to redo)"
        return
    fi

    if [[ "$id" == "06" ]]; then
        if ! deck "[ -f \"$WOW_ROOT/client/Wow.exe\" ] && [ -d \"$WOW_ROOT/client/Data\" ]"; then
            die "step 06 gated: copy WoW 3.3.5a 12340 to $WOW_ROOT/client/ first (see README §7)"
        fi
    fi

    if (( DRY )); then
        log "[DRY $id] $script — $desc"
        return
    fi

    log "===== step $id: $desc ====="
    if [[ "$id" == "09" ]]; then
        "$SCRIPT_DIR/$script" "$ACCT_USER" "$ACCT_PASS" "$ACCT_GM"
    else
        "$SCRIPT_DIR/$script"
    fi
    mark_done "$id"
    log "===== step $id done ====="
}

for entry in "${STEPS[@]}"; do
    IFS=":" read -r id script desc <<<"$entry"
    run_step "$id" "$script" "$desc"
done

log "all done. status:"
cat "$STATE_FILE"
