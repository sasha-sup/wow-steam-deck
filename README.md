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
    ├── wow.sh                     # universal launcher (stack + client)
    ├── stop.sh / status.sh
    └── lib/common.sh
```

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
```

Total wall time: \~3-5 hours, dominated by the build (1×) and the data
extraction (1×). Re-runs of `08-start-stack.sh` are seconds.

### 9. Connect from a WoW 3.3.5a client

Use `scripts/10-install-lutris.sh` — it installs the Lutris flatpak (which
bundles a working Wine) and pins `realmlist.wtf` to `127.0.0.1` in every
locale folder.

#### Universal launcher: `scripts/wow.sh`

Run on the Deck itself (clone this repo to the Deck first, e.g.
`~/wow-steam-deck`). It starts the server stack and launches the client:

```bash
~/wow-steam-deck/scripts/wow.sh
```

#### Steam Gaming Mode (recommended — gives you the Steam virtual keyboard)

1. Desktop Mode → open Steam → **Games → Add a Non-Steam Game to My Library**.
2. **Browse** → set the file filter to "All Files" → pick
   `~/wow-steam-deck/scripts/wow.sh` → Add.
3. Right-click the entry → **Properties** → rename it to "WoW 3.3.5a", set an
   icon if you like. **Do NOT** force a Proton compat tool — `wow.sh` is a
   Linux script that wraps Wine itself.
4. Switch to Gaming Mode. Library → "WoW 3.3.5a" → Play.
5. **Steam button + X** brings up the on-screen keyboard for the login.

> Why not add `Wow.exe` directly with Proton compat? You'd get the keyboard,
> but Proton spawns its own prefix and you'd lose the server-start hook.
> Wrapping `wow.sh` keeps the stack and client glued together.

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

## Credits

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) — base server
- [liyunfan1223/azerothcore-wotlk](https://github.com/liyunfan1223/azerothcore-wotlk) — Playerbot integration fork
- [liyunfan1223/mod-playerbots](https://github.com/liyunfan1223/mod-playerbots) — bot AI module
- [azerothcore/mod-ah-bot](https://github.com/azerothcore/mod-ah-bot)
- [ZhengPeiRu21/mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression)
