#!/usr/bin/env bash
# Step 3 — patch the fork's Dockerfile so the build doesn't bail with an empty
# $DOCKER_USER, and remove the broken `ac-client-data-init` dependency from
# the worldserver service in the base compose file (the client-data target
# fails to build, and we extract data ourselves from the real client).
#
# Idempotent: skips if changes already applied. Originals saved as `.bak`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CORE_DIR="$WOW_ROOT/server/ac"
DOCKERFILE="$CORE_DIR/apps/docker/Dockerfile"

log "Patching Dockerfile (ARG propagation in per-app stages)..."
# Idempotence: original Dockerfile has 1 occurrence of ARG DOCKER_USER=acore
# (in the runtime stage). Patched version has 6 (runtime + 5 child stages).
deck "
set -euo pipefail
cd \"$CORE_DIR\"
ARG_COUNT=\$(grep -c 'ARG DOCKER_USER=acore' apps/docker/Dockerfile || true)
if [ \"\$ARG_COUNT\" -ge 6 ]; then
    echo 'Dockerfile already patched.'
else
    [ -f apps/docker/Dockerfile.bak ] || cp apps/docker/Dockerfile apps/docker/Dockerfile.bak
    python3 - <<'PY'
import re
p = 'apps/docker/Dockerfile'
src = open(p).read()
inject = '\nARG USER_ID=1000\nARG GROUP_ID=1000\nARG DOCKER_USER=acore'
out = re.sub(
    r'^FROM (runtime|skeleton) AS (authserver|worldserver|db-import|client-data|tools)$',
    lambda m: m.group(0) + inject,
    src, flags=re.M)
open(p, 'w').write(out)
print('patched stages:', out.count('ARG DOCKER_USER=acore'))
PY
fi
"

log "Removing ac-client-data-init dependency from worldserver in base compose..."
deck "
set -euo pipefail
cd \"$CORE_DIR\"
if grep -qE '^      ac-client-data-init:\$' docker-compose.yml; then
    [ -f docker-compose.yml.bak ] || cp docker-compose.yml docker-compose.yml.bak
    # delete the 2-line block under depends_on:
    python3 - <<'PY'
import re
p = 'docker-compose.yml'
src = open(p).read()
out = re.sub(
    r'\n      ac-client-data-init:\n        condition: service_completed_successfully',
    '',
    src)
open(p, 'w').write(out)
print('client-data-init dep removed')
PY
else
    echo 'Compose already patched.'
fi
"

log "Verifying..."
deck "grep -n '^FROM\|^ARG DOCKER_USER' \"$DOCKERFILE\" | head -20"

log "Step 3 complete."
