#!/usr/bin/env bash
# Show stack health: container status, listening ports, last log lines.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

deck "
echo '=== containers ==='
podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'ac-|NAMES' || echo '(none)'

echo
echo '=== listening ports (127.0.0.1) ==='
ss -tnlp 2>/dev/null | grep -E '127.0.0.1:(3724|8085|7878|3306)' || echo '(none)'

echo
echo '=== world server tail ==='
tail -5 $WOW_ROOT/logs/Server.log 2>/dev/null || echo '(no Server.log)'

echo
echo '=== auth server tail ==='
tail -3 $WOW_ROOT/logs/Auth.log 2>/dev/null || echo '(no Auth.log)'

echo
echo '=== resource use ==='
podman stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null | grep -E 'ac-|NAME' || echo '(none)'
"
