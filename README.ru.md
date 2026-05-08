# Сервер WoW 3.3.5a на Steam Deck

Self-hosted сервер World of Warcraft (Wrath of the Lich King 3.3.5a) на
Steam Deck. Собран на AzerothCore с интегрированными Playerbots, AH-bot и
Individual Progression. Заточен под **локальную одиночную игру** с ботами,
наполняющими мир.

> English version: [README.md](README.md) (приоритетная)

## Что получаешь

- **AzerothCore** (форк liyunfan1223 со встроенным Playerbot).
- **mod-playerbots** — боты квестятся, ходят в данжи, рейды, BG с тобой.
- **mod-ah-bot** — Аукцион наполняют NPC.
- **mod-individual-progression** — прогрессия Vanilla → TBC → WotLK на каждом
  персонаже.
- Контейнеры через rootless **Podman** — переживают обновления SteamOS, ничего
  не ставится в систему.
- Все данные на microSD-карте: ~40 GB суммарно (клиент + извлечённые карты +
  БД + образы).

## Требования

- Steam Deck (LCD или OLED) на SteamOS Holo.
- microSD карта, **минимум 256 GB**, ext4 (или btrfs).
- Клиент WoW 3.3.5a (build 12340) — ~16-40 GB в зависимости от локалей.
- 14 GB RAM (стоковые) хватает на ~25-30 ботов.
- USB-клавиатура для первичной настройки. SSH к Деке сильно облегчает жизнь
  (на нём построены все скрипты).

## Структура репо

См. в `README.md` (англ) — там же.

## Пошагово

Скрипты автоматизируют этот путь. Можно делать всё руками.

### 1. На Деке — Desktop Mode

`Steam → Power → Switch to Desktop`. Открой Konsole.

### 2. Поставь пароль и включи SSH

```bash
passwd                          # пароль для пользователя deck
sudo systemctl enable --now sshd
ip addr show | grep 'inet '     # запиши IP в LAN
```

### 3. С компа — копируй SSH-ключ и клонируй репо

```bash
ssh-copy-id deck@<DECK_IP>
git clone <url-этого-репо> wow-steam-deck && cd wow-steam-deck
cp .env.example .env             # подправь, если SD карта называется иначе
```

### 4. Sudo без пароля (чтобы скрипты не задавали вопросов)

> SteamOS обрабатывает `sudoers.d` по алфавиту, **последнее правило выигрывает**.
> Дефолтное `wheel` (`%wheel ALL=(ALL) ALL`) требует пароль. Перебить можно
> файлом, который сортируется ПОСЛЕ `wheel`:

На Деке:

```bash
echo "deck ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/zz-deck-nopw
sudo chmod 440 /etc/sudoers.d/zz-deck-nopw
sudo -k && sudo -n whoami       # должно напечатать root
```

Переживёт логин-логаут, но **сбрасывается при обновлении SteamOS** — повтори
после.

### 5. Отформатируй microSD и подмонтируй

KDE Partition Manager → `ext4`, метка `SD512` (или то, что в `.env`). После
авто-маунта SteamOS на `/run/media/deck/SD512/`, скрипты подхватят `WOW_ROOT`
из `.env`.

### 6. Запусти setup-скрипты

Два варианта запуска:

- **С компа** (SSH на Деку):
  ```bash
  export DECK_HOST=deck@192.168.1.119
  ```
- **На самой Деке** (склонируй репо на Деку через Konsole):
  ```bash
  git clone <url-этого-репо> ~/wow-steam-deck && cd ~/wow-steam-deck
  ```
  Автодетект — `DECK_LOCAL=1` подставится если hostname/user совпадают.

Затем:

```bash
scripts/00-prep-deck.sh         # sudoers + podman registries + podman-compose
scripts/01-init-workspace.sh    # дирки $WOW_ROOT/{server,client,data,db,configs,logs}
scripts/02-clone-source.sh      # AzerothCore + 3 модуля
scripts/03-patch-dockerfile.sh  # фикс ARG
scripts/04-build-images.sh      # 30–60 мин на первом запуске
```

### 7. Скопируй клиент 3.3.5a на SD

Клиент **не качается** скриптами — приноси свой. `Wow.exe`, `Data/`,
`Interface/`, `WTF/` должны лежать прямо в `$WOW_ROOT/client/`.

С компа через USB-картридер:

```bash
sudo mount /dev/sdX1 /mnt/sd
sudo rsync -ah --info=progress2 ~/Downloads/WoW_3.3.5_12340/ /mnt/sd/wow/client/
sudo umount /mnt/sd
```

Возвращай SD в Деку.

### 8. Конфиги, экстракция, БД, стек

```bash
scripts/05-populate-configs.sh   # пишет *.conf, тюнит playerbots под Деку
scripts/06-extract-data.sh       # DBC + maps (~30 мин) + vmaps (~30 мин) + mmaps (~35–60 мин)
scripts/07-init-db.sh            # mariadb + db-import
scripts/08-start-stack.sh        # auth + world
scripts/09-create-account.sh test test 3   # GM-аккаунт test/test
scripts/10-install-lutris.sh     # Lutris flatpak + realmlist.wtf
scripts/11-apply-rates.sh        # опционально: kayf-пресет (x5 XP, x3 таланты, буст лута)
```

Итого ~3-5 часов. Львиную долю занимают разовая сборка и экстракция данных.
Повторный `08-start-stack.sh` — секунды.

### 9. Подключение клиентом 3.3.5a

Запусти `scripts/10-install-lutris.sh` — поставит Lutris flatpak (с Wine
внутри) и пропишет `realmlist.wtf` на `127.0.0.1` во всех локалях.

#### Лаунчер сервера: `scripts/wow.sh`

Запускается на самой Деке (клонируй репо на Деку, например в
`~/wow-steam-deck`). Поднимает только серверный стек — клиент отдельно
через Steam:

```bash
~/wow-steam-deck/scripts/wow.sh
```

Идемпотентно — повторный запуск ничего не делает если стек уже поднят.
Можно добавить в KDE автостарт чтоб сервер поднимался при входе в
Desktop Mode.

Дополнительно есть алиасы (см. секцию ниже): `wow` / `wowstop` / `wowstatus`
/ `wowlogs` для быстрого управления из любого терминала.

#### Клиент через Steam (Proton)

1. Desktop Mode → открой Steam → **Games → Add a Non-Steam Game to My Library**.
2. **Browse** → переключи фильтр "All Files" → выбери
   `$WOW_ROOT/client/Wow.exe` → Add.
3. Правой кнопкой → **Properties** → переименуй в "WoW 3.3.5a", в
   **Compatibility** включи свежий Proton (Proton Experimental ок).
4. Убедись что сервер поднят (`scripts/wow.sh` один раз на Деке).
5. Switch to Gaming Mode. Library → "WoW 3.3.5a" → Play.
6. **Steam кнопка + X** — экранная клавиатура для логина.

> Wow.exe под Proton видит `127.0.0.1` на самой Деке, поэтому `realmlist.wtf`,
> прописанный `10-install-lutris.sh`, продолжает работать без правок.

#### Алиасы для shell

`scripts/setup-aliases.sh` добавляет в `~/.bashrc` на Деке короткие команды:

```bash
wow         # старт сервера (== scripts/wow.sh)
wowstop     # остановить контейнеры
wowstatus   # podman ps
wowlogs     # tail логов worldserver
```

## Тюнинг под Деку

- `playerbots.conf`: дефолт 500 ботов — APU плавится. Скрипт
  `05-populate-configs.sh` ставит **30 ботов и 5 на спавн-интервал**. Можно
  подкрутить вверх если есть запас.
- `docker-compose.override.yml` ограничивает mariadb 2 GB RAM (InnoDB pool
  512 MB), worldserver 6 GB, authserver 256 MB.
- Все порты только на `127.0.0.1` — сервер не виден из LAN. Если хочешь
  пустить друзей через Tailscale/LAN — убери префиксы `127.0.0.1:` в
  `08-start-stack.sh` и открой порты в фаерволе.

## Подводные камни

- **`/etc/sudoers.d/zz-deck-nopw` сбрасывается при обновлении SteamOS.** Повтори шаг 4.
- **`pip` нет в SteamOS.** Скрипты ставят `podman-compose` через `pacman`
  (после временного `steamos-readonly disable`).
- **Dockerfile форка не пробрасывает `ARG DOCKER_USER` в per-app stages**, и
  сборка падает на пустом `--chown` посередине. `patches/dockerfile-args.patch`
  добавляет нужные `ARG`. Применяет `03-patch-dockerfile.sh`.
- **Сборка `ac-client-data-init` ломается** — копирует как `acore:acore` в
  stage `FROM skeleton` (где user ещё не создан). Мы пропускаем — реальный
  client extraction наполняет `$WOW_ROOT/data/` и без него. Зависимость
  убирает скрипт-патч.
- **`podman-compose` ≤ 1.2 имеет баги с pod dep-graph.** `08-start-stack.sh`
  обходит pod, использует обычный `podman network` — каждый контейнер
  независим.
- **Rootless podman + bind mounts**: configs/logs/data нужен `--userns=keep-id`
  на worldserver/authserver, иначе UID 1000 в контейнере мапится в subuid и
  не пишет в host-файлы `deck:deck` (UID 1000).
- **SQL-файлы playerbots не вшиты в worldserver image** Dockerfile-ом форка.
  Маунтим `modules/` рантаймом, чтобы worldserver мог инициализировать
  `acore_playerbots` на первом старте.

## Расход ресурсов

После полного старта, 30 random ботов залогинены:

| | RAM | CPU (idle) |
|---|---|---|
| `mariadb`     | ~700 MB | <2 % |
| `authserver`  | ~50 MB  | <1 % |
| `worldserver` | 3-5 GB | 30-60 % (1-2 ядра) |

Клиент WoW добавляет ~1 GB и 2-3 ядра. Дека тянет, но кулер шумит.

## Можно ли реально играть на Деке с сервером на ней же?

Да. С нюансами:
- **SD-карта медленная** (~50-100 MB/s read). При смене зоны worldserver
  читает mmaps/vmaps с SD → возможны микрофризы. Лечится: перенеси `data/`
  на внутренний `/home` (там 144 GB free, btrfs быстрее).
- **Батарея садится за 1.5-2 часа** под полной нагрузкой. Через док с зарядом
  — норм.
- **APU греется**, кулер крутится постоянно.
- **30 ботов** — разумный потолок. Просядет — снижай до 15-20.
- **FPS клиента** 60+ стабильно (DX9, игра 2010 года, RDNA2 справляется).

## Полезные команды

```bash
scripts/status.sh                                   # что запущено
scripts/stop.sh                                     # остановить (данные сохранятся)
ssh $DECK_HOST 'podman logs -f ac-worldserver'      # логи мира
ssh $DECK_HOST 'podman exec -it ac-worldserver worldserver'  # консоль сервера
```

## Кредиты

- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) — базовое ядро
- [liyunfan1223/azerothcore-wotlk](https://github.com/liyunfan1223/azerothcore-wotlk) — форк с интеграцией Playerbot
- [liyunfan1223/mod-playerbots](https://github.com/liyunfan1223/mod-playerbots) — AI ботов
- [azerothcore/mod-ah-bot](https://github.com/azerothcore/mod-ah-bot)
- [ZhengPeiRu21/mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression)
