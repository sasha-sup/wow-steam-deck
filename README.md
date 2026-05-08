# WoW 3.3.5a Server on Steam Deck

Self-hosted World of Warcraft (Wrath of the Lich King 3.3.5a) server on a Steam
Deck — built around AzerothCore with Playerbots, AH bot, and Individual
Progression. Designed for **single-player local play** with AI bots filling the
world.

> Russian translation: [README.ru.md](README.ru.md)

## What you get

- **AzerothCore** core (liyunfan1223 fork with Playerbots integration).
- **mod-playerbots** — bots that quest, dungeon, raid, fight in BGs alongside you.
- **mod-ah-bot** — Auction House populated by NPCs.
- **mod-individual-progression** — Vanilla → TBC → WotLK content gating per
  character.
- Containerised with rootless **Podman**, so it survives SteamOS updates without
  installing anything system-wide.
- Server data on the **microSD card**: \~40 GB total (client + extracted maps +
  DB + images).

## Hardware / OS requirements

- Steam Deck (LCD or OLED) on SteamOS Holo.
- microSD card, **at least 256 GB**, formatted ext4 (or btrfs).
- WoW 3.3.5a client (build 12340) — \~16-40 GB depending on locales.
- 14 GB RAM (Deck stock) is enough for \~25-30 bots.
- USB keyboard recommended for the initial setup. SSH to the Deck makes it
  much easier (used by all the scripts).

## Repo layout

```
.
├── README.md / README.ru.md       # docs (this file + Russian)
├── .env.example                   # workspace + container env template
├── docker-compose.override.yml    # Deck-tuned resource limits
├── patches/
│   └── dockerfile-args.patch      # ARG propagation fix for fork's Dockerfile
└── scripts/                       # automation, run in numbered order
    ├── 00-prep-deck.sh            # SteamOS prep (sudo, podman registries)
    ├── 01-init-workspace.sh       # SD card workspace dirs
    ├── 02-clone-source.sh         # AC fork + 3 modules
    ├── 03-patch-dockerfile.sh     # apply patches/dockerfile-args.patch
    ├── 04-build-images.sh         # podman-compose build (+tools)
    ├── 05-populate-configs.sh     # write *.conf files, tune playerbots
    ├── 06-extract-data.sh         # DBC/maps/vmaps/mmaps from client (slow)
    ├── 07-init-db.sh              # mariadb container + db-import
    ├── 08-start-stack.sh          # auth + world + db (rootless, port-bound)
    ├── 09-create-account.sh       # GM account via worldserver console
    ├── 10-install-lutris.sh       # Lutris flatpak + realmlist.wtf pinning
    ├── 11-apply-rates.sh          # optional: x5 XP / x3 talents / boosted drops
    ├── setup-all.sh               # master runner — sequences 00→11 with checkpoints
    ├── update.sh                  # AC fork pull + rebuild + db migrate
    ├── backup.sh / restore.sh     # mysqldump → tar.zst, restore from archive
    ├── install-autostart.sh       # systemd --user wow-server.service + linger
    ├── install-watchdog.sh        # 1-min port watchdog + daily DB backup timer
    ├── install-logrotate.sh       # rotate Server.log/Auth.log daily
    ├── install-sudoers-hook.sh    # detect missing NOPASSWD + wow-fix-sudoers helper
    ├── add-steam-shortcut.sh      # add Wow.exe to shortcuts.vdf with Proton compat
    ├── install-gaming-launcher.sh # wires autostart + watchdog + logs + shortcut
    ├── wow.sh / wow-play.sh       # server-only launcher / desktop-mode play wrapper
    ├── setup-aliases.sh           # install `wow` / `wowstop` / `wowstatus` shell aliases
    ├── stop.sh / status.sh
    └── lib/common.sh
```

## One-shot install

For an opinionated full setup (after step 4 NOPASSWD + step 7 client copy):

```bash
scripts/setup-all.sh                       # sequences 00→11 with checkpoints
scripts/install-gaming-launcher.sh         # autostart + watchdog + logrotate + Steam shortcut
```

`setup-all.sh` skips already-completed steps via `.omc/state/setup.json`. Use
`--from 04` to redo from a step, `--reset` to clear, `--dry-run` to preview.

## Day-2 ops

| Task | Command |
|------|---------|
| Update AC + modules | `scripts/update.sh` (auto-backups before touching) |
| Manual DB backup | `scripts/backup.sh` (or `--quick`) |
| Restore | `scripts/restore.sh --latest` |
| Add Wow.exe to Steam | `scripts/add-steam-shortcut.sh` (close Steam first) |
| Recover after SteamOS update | `wow-fix-sudoers` (installed by `install-sudoers-hook.sh`) |
| Logs rotation | `install-logrotate.sh` once; runs daily 04:30 |
| Server autostart at boot | `install-autostart.sh` once; `systemctl --user start wow-server` |

## Walkthrough

This is the path the scripts automate. You can run each step manually if you
prefer.

### 1. On the Steam Deck — switch to Desktop Mode

`Steam → Power → Switch to Desktop`. Open Konsole.

### 2. Set a password and enable SSH

```bash
passwd                          # set a password for `deck`
sudo systemctl enable --now sshd
ip addr show | grep 'inet '     # note the LAN IP
```

### 3. From your workstation — copy SSH key + clone this repo

```bash
ssh-copy-id deck@<DECK_IP>
git clone <this-repo-url> wow-steam-deck && cd wow-steam-deck
cp .env.example .env             # tweak if your microSD label differs
```

### 4. Sudo without password (so scripts don't prompt mid-run)

> SteamOS evaluates `sudoers.d` alphabetically and the **last matching rule
> wins**. The default `wheel` rule (`%wheel ALL=(ALL) ALL`) requires a
> password. Override it with a file that sorts after `wheel`:

On the Deck:

```bash
echo "deck ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-deck-nopw
sudo chmod 440 /etc/sudoers.d/zz-deck-nopw
sudo -k && sudo -n whoami       # should print `root`
```

This survives login but **resets on a SteamOS update** — re-apply afterwards.

### 5. Format the microSD card and mount it

Use KDE Partition Manager — `ext4`, label `SD512` (or whatever you put in
`.env`). After SteamOS auto-mounts it at `/run/media/deck/SD512/`, every
script reads `WOW_ROOT` from `.env`.

### 6. Run the setup scripts

You can run the scripts in either mode:

- **From your workstation** (SSH to the Deck):
  ```bash
  export DECK_HOST=deck@192.168.1.119
  ```
- **On the Deck itself** (clone this repo on the Deck first via Konsole):
  ```bash
  git clone <this-repo-url> ~/wow-steam-deck && cd ~/wow-steam-deck
  ```
  Auto-detected — `DECK_LOCAL=1` is implied when hostname/user match.

Then:

```bash
scripts/00-prep-deck.sh         # sudoers + podman registries + podman-compose
scripts/01-init-workspace.sh    # create $WOW_ROOT/{server,client,data,db,configs,logs}
scripts/02-clone-source.sh      # AzerothCore + mod-playerbots + mod-ah-bot + mod-individual-progression
scripts/03-patch-dockerfile.sh  # ARG fix
scripts/04-build-images.sh      # 30–60 min on first run
```

### 7. Copy the WoW 3.3.5a client to the SD card

The client is **not** downloaded by the scripts — bring your own. `Wow.exe`,
`Data/`, `Interface/`, `WTF/` should land directly inside `$WOW_ROOT/client/`.

If you have a card reader on your workstation:

```bash
sudo mount /dev/sdX1 /mnt/sd
sudo rsync -ah --info=progress2 ~/Downloads/WoW_3.3.5_12340/ /mnt/sd/wow/client/
sudo umount /mnt/sd
```

Plug the card back in.

### 8. Configs, extraction, DB, and stack

```bash
scripts/05-populate-configs.sh   # writes *.conf, tunes playerbots for Deck
scripts/06-extract-data.sh       # DBC + maps (~30 min) + vmaps (~30 min) + mmaps (~35–60 min)
scripts/07-init-db.sh            # mariadb + db-import
scripts/08-start-stack.sh        # auth + world
scripts/09-create-account.sh test test 3   # GM-level test/test
scripts/10-install-lutris.sh     # Lutris flatpak + realmlist.wtf
scripts/11-apply-rates.sh        # optional: kayf preset (x5 XP, x3 talents, boosted drops)
```

Total wall time: \~3-5 hours, dominated by the build (1×) and the data
extraction (1×). Re-runs of `08-start-stack.sh` are seconds.

### 9. Connect from a WoW 3.3.5a client

Use `scripts/10-install-lutris.sh` — it installs the Lutris flatpak (which
bundles a working Wine) and pins `realmlist.wtf` to `127.0.0.1` in every
locale folder.

#### Server launcher: `scripts/wow.sh`

Run on the Deck itself (clone this repo to the Deck first, e.g.
`~/wow-steam-deck`). It starts the server stack only — the client is launched
separately via Steam:

```bash
~/wow-steam-deck/scripts/wow.sh
```

The script is idempotent — re-running it does nothing if the stack is already
up. Add it to your KDE autostart if you want the server up the moment you
boot into Desktop Mode.

#### Client via Steam (Proton)

1. Desktop Mode → open Steam → **Games → Add a Non-Steam Game to My Library**.
2. **Browse** → set the file filter to "All Files" → pick
   `$WOW_ROOT/client/Wow.exe` → Add.
3. Right-click the entry → **Properties** → rename it to "WoW 3.3.5a",
   under **Compatibility** force a recent Proton (Proton Experimental works).
4. Make sure the server is up (`scripts/wow.sh` once on the Deck).
5. Switch to Gaming Mode. Library → "WoW 3.3.5a" → Play.
6. **Steam button + X** brings up the on-screen keyboard for the login.

> Wow.exe under Proton sees `127.0.0.1` on the Deck so the `realmlist.wtf`
> pinned by `10-install-lutris.sh` keeps working without modification.

#### Shell aliases

`scripts/setup-aliases.sh` appends short commands to `~/.bashrc` on the Deck:

```bash
wow         # start server stack (== scripts/wow.sh)
wowstop     # stop containers
wowstatus   # podman ps
wowlogs     # tail worldserver log
```

## Tuning notes (Steam Deck specific)

- `playerbots.conf`: defaults are 500 bots which will melt the APU.
  `05-populate-configs.sh` lowers this to **30 bots, 5 per spawn interval**.
  Push it up if you have headroom.
- `docker-compose.override.yml` caps mariadb at 2 GB RAM with a 512 MB InnoDB
  buffer pool, worldserver at 6 GB, authserver at 256 MB.
- All ports bind to `127.0.0.1` only — the server is not reachable from your
  LAN. If you want to invite a friend over Tailscale or LAN, edit
  `08-start-stack.sh` and remove the `127.0.0.1:` prefixes (and unblock the
  ports in your firewall).

## Known gotchas

- **`sudoers.d/zz-deck-nopw` resets on SteamOS update.** Re-apply step 4.
- **`pip` doesn't ship on SteamOS.** Scripts install `podman-compose` via
  `pacman` (after `steamos-readonly disable`).
- **The fork's `Dockerfile` doesn't propagate `ARG DOCKER_USER` into the
  per-app stages**, so the build fails halfway with an empty `--chown` value.
  `patches/dockerfile-args.patch` adds the missing `ARG` lines. Already
  applied by `03-patch-dockerfile.sh`.
- **`ac-client-data-init` build fails** because it copies as `acore:acore`
  while running under `FROM skeleton` (no user yet). We skip it — the real
  client extraction is what populates `$WOW_ROOT/data/` anyway. Dependency on
  it is removed from the base compose by the patch script.
- **`podman-compose` ≤ 1.2 has dep-graph quirks** with named pods. The
  `08-start-stack.sh` script bypasses the pod and uses a plain
  `podman network` so each container is independent.
- **Rootless podman + bind mounts**: configs / logs / data dirs need
  `--userns=keep-id` on the worldserver/authserver containers, otherwise the
  in-container `acore` (UID 1000) maps to a subuid range and can't write back
  to host files owned by `deck:deck` (UID 1000).
- **Playerbots SQL files aren't included in the worldserver image** by the
  fork's Dockerfile. We mount the `modules/` directory at runtime so the
  worldserver can populate `acore_playerbots` on first start.

## Resource baseline

After everything is up, with 30 random bots logged in:

| | RAM | CPU (idle) |
|---|---|---|
| `mariadb`     | \~700 MB | <2 % |
| `authserver`  | \~50 MB  | <1 % |
| `worldserver` | 3-5 GB | 30–60 % (1-2 cores) |

WoW client adds \~1 GB and 2-3 cores. The Deck handles it but the fans run.

## Useful commands

```bash
scripts/status.sh                      # which containers are up
scripts/stop.sh                        # stop the stack (data persists)
ssh $DECK_HOST 'podman logs -f ac-worldserver'
ssh $DECK_HOST 'podman exec -it ac-worldserver worldserver'  # live console
```

## License

[MIT](LICENSE) — do whatever you want, no warranty. Note: AzerothCore and the
modules listed below are licensed separately by their respective authors.

## Credits

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) — base server
- [liyunfan1223/azerothcore-wotlk](https://github.com/liyunfan1223/azerothcore-wotlk) — Playerbot integration fork
- [liyunfan1223/mod-playerbots](https://github.com/liyunfan1223/mod-playerbots) — bot AI module
- [azerothcore/mod-ah-bot](https://github.com/azerothcore/mod-ah-bot)
- [ZhengPeiRu21/mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression)
