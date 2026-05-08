#!/usr/bin/env bash
# add-steam-shortcut.sh — add Wow.exe (or any exe) as a Non-Steam Game with
# Proton Experimental compat tool. Skips Steam UI entirely.
#
# Steam MUST be closed while we rewrite shortcuts.vdf — the script checks.
#
# Usage:
#   scripts/add-steam-shortcut.sh                                # WoW.exe @ defaults
#   scripts/add-steam-shortcut.sh --name "WoW Server" --exe /path/to/wow-play.sh
#   scripts/add-steam-shortcut.sh --proton "proton_experimental"
#
# Idempotent: matching name+exe entries are updated in place, not duplicated.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

NAME="WoW 3.3.5a"
EXE="$WOW_ROOT/client/Wow.exe"
PROTON="proton_experimental"

while (($#)); do
    case "$1" in
        --name)   NAME="$2"; shift 2 ;;
        --exe)    EXE="$2"; shift 2 ;;
        --proton) PROTON="$2"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) die "unknown arg: $1" ;;
    esac
done

log "Ensuring Steam is not running on the Deck..."
deck "
if pgrep -x steam >/dev/null 2>&1; then
    echo 'Steam is running — close it first (Steam → Exit). Aborting.' >&2
    exit 1
fi
"

log "Ensuring Python vdf module is available..."
deck "
python3 -c 'import vdf' 2>/dev/null || pip3 install --user --quiet vdf
"

log "Writing/updating shortcuts.vdf + config.vdf..."
deck "python3 - '$NAME' '$EXE' '$PROTON' <<'PY'
import os, sys, glob, binascii, vdf

name, exe, proton = sys.argv[1], sys.argv[2], sys.argv[3]
home = os.path.expanduser('~')

userdata = sorted(glob.glob(f'{home}/.steam/steam/userdata/*'))
userdata = [u for u in userdata if os.path.basename(u).isdigit() and os.path.basename(u) != '0']
if not userdata:
    sys.exit('no Steam userdata dir found — run Steam at least once first')

start_dir = os.path.dirname(exe) or '/'

# Steam's appid algorithm for non-Steam games.
def shortcut_appid(exe_path, appname):
    key = (exe_path + appname).encode('utf-8')
    crc = binascii.crc32(key) | 0x80000000
    # signed 32-bit for VDF storage
    return crc - 0x100000000 if crc >= 0x80000000 else crc

for udir in userdata:
    cfg = f'{udir}/config'
    os.makedirs(cfg, exist_ok=True)
    sf = f'{cfg}/shortcuts.vdf'
    if os.path.exists(sf):
        with open(sf, 'rb') as f:
            data = vdf.binary_load(f)
    else:
        data = {'shortcuts': {}}
    shortcuts = data.setdefault('shortcuts', {})

    # Find existing entry by (AppName, Exe)
    found_idx = None
    for k, v in shortcuts.items():
        if v.get('AppName') == name and v.get('Exe', '').strip('\"') == exe:
            found_idx = k
            break
    if found_idx is None:
        found_idx = str(len(shortcuts))

    appid = shortcut_appid(exe, name)
    shortcuts[found_idx] = {
        'appid': appid,
        'AppName': name,
        'Exe': f'\"{exe}\"',
        'StartDir': f'\"{start_dir}\"',
        'icon': '',
        'ShortcutPath': '',
        'LaunchOptions': '',
        'IsHidden': 0,
        'AllowDesktopConfig': 1,
        'AllowOverlay': 1,
        'OpenVR': 0,
        'Devkit': 0,
        'DevkitGameID': '',
        'LastPlayTime': 0,
        'tags': {},
    }
    bak = sf + '.bak'
    if os.path.exists(sf) and not os.path.exists(bak):
        import shutil; shutil.copy(sf, bak)
    with open(sf, 'wb') as f:
        vdf.binary_dump(data, f)
    print(f'shortcuts.vdf: {sf} entry={found_idx} appid={appid}')

    # Compat tool mapping (text VDF in ~/.steam/steam/config/config.vdf)
    cv = f'{home}/.steam/steam/config/config.vdf'
    if os.path.exists(cv):
        with open(cv) as f:
            conf = vdf.load(f)
        # Steam's positive 32-bit unsigned form for the compat mapping key.
        unsigned = appid + 0x100000000 if appid < 0 else appid
        valve = conf.setdefault('InstallConfigStore', {}).setdefault('Software', {}).setdefault('Valve', {})
        steam_node = valve.setdefault('Steam', {})
        ctm = steam_node.setdefault('CompatToolMapping', {})
        ctm[str(unsigned)] = {'name': proton, 'config': '', 'priority': '250'}
        cv_bak = cv + '.bak'
        if not os.path.exists(cv_bak):
            import shutil; shutil.copy(cv, cv_bak)
        with open(cv, 'w') as f:
            vdf.dump(conf, f, pretty=True)
        print(f'config.vdf: mapped appid={unsigned} → {proton}')
PY
"

log "Done. Restart Steam — entry '$NAME' should appear in Library."
