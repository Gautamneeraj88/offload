# offload — Unified Storage Manager for macOS (and Linux)

A shell-based tool that manages disk space on machines with limited internal storage by offloading developer toolchains, caches, and large data directories to an external disk via symlinks — while keeping everything transparent to your shell and tools.

Built for macOS M-series MacBooks (especially 256 GB models), but the symlink and recipe systems work on Linux too.

---

## The Problem It Solves

A 256 GB MacBook fills up fast with:
- Rust toolchain (`~/.cargo`, `~/.rustup`) — 5–10 GB
- Python versions (`~/.pyenv`) — 3–8 GB
- Go workspace (`~/go`) — varies
- Node package caches (npm, pnpm, yarn, bun) — 2–10 GB
- Android SDK — 11+ GB
- Xcode DerivedData — 5–30 GB
- Ollama/AI models — 10–50+ GB
- Podman images — varies

This tool moves those directories to an external SSD, replaces them with symlinks, and gives you a single command to check health, start/stop services, and clean recoverables.

---

## What It Does (and Doesn't Do)

**Does:**
- Migrate `~/foo` → external disk → replace with symlink (`offload add foo`)
- Reverse migration back to home (`offload remove foo`)
- Track all managed symlinks in a config file
- Start/stop services (Podman, Ollama, etc.) that depend on external disk
- Run cleanup recipes: Arduino, Android, Xcode, Homebrew, Go, pnpm, node_modules, Trash, Library/Caches, Podman
- Generate reports: Application Support breakdown, files >500 MB
- Log every destructive action to `~/.offload-log`
- Full dry-run mode (`--dry-run`) for any operation

**Does NOT:**
- Use `sudo` anywhere — ever
- Auto-delete anything without confirmation
- Touch `~/.ssh`, `~/.config`, `~/Documents`, `~/Desktop`, Keychain, Photos, Music
- Run scheduled background cleanups
- Require any external dependencies (pure zsh + standard macOS tools)

---

## Requirements

| Requirement | macOS | Linux |
|-------------|-------|-------|
| Shell | zsh | zsh |
| Standard tools | `df`, `du`, `rsync`, `diskutil` | `df`, `du`, `rsync` |
| External disk | Any USB/Thunderbolt drive | Any mounted drive |

**macOS:** zsh is the default shell since Catalina. No extras needed.

**Linux:** Install zsh (`apt install zsh` or `brew install zsh`). The `diskutil eject` command is macOS-only — the `stop` command will skip eject on Linux gracefully.

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/Gautamneeraj88/offload.git ~/scripts
```

Or if you want it somewhere else:

```bash
git clone https://github.com/Gautamneeraj88/offload.git /path/to/scripts
```

### 2. Add to PATH

Add this to your `~/.zshrc`:

```bash
export PATH="$HOME/scripts:$PATH"
```

Then reload:

```bash
source ~/.zshrc
```

### 3. Make the entry point executable

```bash
chmod +x ~/scripts/offload
```

### 4. Create your config file

Copy the example config and edit it for your setup:

```bash
cp ~/scripts/offload-config.example ~/.offload-config
```

Then edit `~/.offload-config` to match your external disk mount point and what you want to manage. See [Config File](#config-file) below.

### 5. Verify it works

```bash
offload status
```

---

## Quick Start

```bash
# See what's on your disks and what's managed
offload status

# Check health of all symlinks and services
offload doctor

# See what cleanup recipes are available and how much they'd reclaim
offload clean

# Migrate a large directory to external disk
offload add .cargo       # moves ~/.cargo → external, replaces with symlink

# Clean up recoverables (interactive)
offload clean android_trim   # removes Android emulator/system-images (~7 GB)
offload clean brew_cleanup   # runs brew cleanup
offload clean library_caches # wipes ~/Library/Caches (~5-10 GB)

# Morning / evening workflow
offload start    # verify disk, start services
offload stop     # stop services, eject disk safely
```

---

## Config File

Location: `~/.offload-config`

Plain text, pipe-delimited. Comments start with `#`. The script re-reads it on every invocation.

### Mount points

```
EXT_MOUNT=/Volumes/backup        # where the external disk mounts
EXT_HOME=/Volumes/backup/home    # where migrated home dirs live
```

**Linux example:**
```
EXT_MOUNT=/mnt/external
EXT_HOME=/mnt/external/home
```

### Symlinks

```
SYMLINK|<source-in-home>|<absolute-target>|<description>
```

Examples:

```
SYMLINK|.cargo|/Volumes/backup/home/.cargo|Rust toolchain
SYMLINK|.rustup|/Volumes/backup/home/.rustup|Rust versions
SYMLINK|.pyenv|/Volumes/backup/home/.pyenv|Python versions
SYMLINK|go|/Volumes/backup/home/go|Go workspace
SYMLINK|.npm|/Volumes/backup/home/.npm|npm cache
SYMLINK|.ollama|/Volumes/backup/home/.ollama|Ollama models
SYMLINK|.local/share/containers|/Volumes/backup/containers/containers|Podman storage
```

Source is relative to `$HOME`. Target is the full path on the external disk.

### Services

```
SERVICE|<name>|<start-command>|<stop-command>|<check-command>
```

Check command should exit 0 if running, non-zero if not.

Examples:

```
SERVICE|podman|podman machine start|podman machine stop|podman machine list --format '{{.Running}}' | grep -q true
SERVICE|ollama|ollama serve > /tmp/ollama.log 2>&1 &|pkill -x ollama|pgrep -x ollama
```

### Never-symlink list

Prevents `offload scan` from suggesting these as candidates, and `offload add` from migrating them:

```
NEVER|.ssh|Permissions sensitive
NEVER|.config|Shell startup dependency
NEVER|Documents|iCloud sync
NEVER|Desktop|User intent
NEVER|Library|macOS-managed
```

### Full example config

```
# Mount config
EXT_MOUNT=/Volumes/backup
EXT_HOME=/Volumes/backup/home

# Symlinks
SYMLINK|.cargo|/Volumes/backup/home/.cargo|Rust toolchain
SYMLINK|.rustup|/Volumes/backup/home/.rustup|Rust versions
SYMLINK|.pyenv|/Volumes/backup/home/.pyenv|Python versions
SYMLINK|go|/Volumes/backup/home/go|Go workspace
SYMLINK|.npm|/Volumes/backup/home/.npm|npm cache
SYMLINK|.yarn|/Volumes/backup/home/.yarn|yarn cache
SYMLINK|.bun|/Volumes/backup/home/.bun|bun runtime
SYMLINK|.gradle|/Volumes/backup/home/.gradle|Gradle cache
SYMLINK|.ollama|/Volumes/backup/home/.ollama|Ollama models

# Services
SERVICE|podman|podman machine start|podman machine stop|podman machine list --format '{{.Running}}' | grep -q true

# Never symlink
NEVER|.ssh|Permissions sensitive
NEVER|.config|Shell startup dependency
NEVER|Documents|iCloud sync
NEVER|Desktop|User intent
NEVER|Downloads|User intent
```

---

## All Commands

```
offload                              # alias for: offload status
offload status                       # overview: disk, mount, symlinks, services
offload start                        # work-start: verify disk, start services
offload stop [--force]               # work-stop: stop services, eject disk
offload verify                       # full symlink + service health check
offload doctor                       # diagnose + suggest fixes
offload scan                         # find new symlink candidates
offload add <name>                   # migrate ~/<name> to external, add to config
offload remove <name>                # un-symlink, move data back to home
offload clean                        # list applicable cleanup recipes with sizes
offload clean <recipe>               # run one recipe (interactive)
offload clean <recipe> --dry-run     # preview only, no changes
offload clean <recipe> --yes         # skip confirmations
offload clean all [--yes]            # walk every applicable recipe
offload clean --list-all             # show all recipes including inapplicable ones
offload log                          # show audit log of all destructive operations
offload log --tail 20                # last N entries
offload help                         # full help text
offload help <command>               # detailed help for one command
```

**Global flags** (work with any command):
- `--yes` — skip all confirmation prompts
- `--dry-run` — preview only, no destructive changes

---

## Command Reference

### `offload status`

Overview of everything:

```
━━ Disk usage ━━
Filesystem   Size   Used  Avail  ...
/dev/disk3   228Gi  12Gi  80Gi   ...
/dev/disk5   238Gi  84Gi  154Gi  ...

━━ External disk ━━
✓ /Volumes/backup mounted — 154Gi free
  Migrated data: 47G

━━ Symlinks (43 tracked) ━━
  43 healthy  0 broken  0 not-linked  0 missing

━━ Services ━━
✓ podman running
  ollama stopped

━━ Top 10 $HOME folders ━━
...
```

---

### `offload start` / `offload stop`

**start:** Checks disk is mounted, verifies no broken symlinks, starts configured services. Safe to run every morning.

**stop:** Stops services, checks no processes are still holding the disk open, then ejects. If something is holding the disk:
```
✗ Processes still using /Volumes/backup:
    Finder (12345)
```

Use `offload stop --force` to eject anyway (may cause data corruption — only if you know what you're doing).

---

### `offload add <name>`

Migrates `~/<name>` to the external disk and replaces it with a symlink.

Handles all cases:
- **Already correctly linked** → reports success, does nothing
- **Local directory** → rsync to external, remove local, create symlink
- **Missing** → creates empty directory on external, creates symlink
- **Wrong symlink** → asks before re-linking to correct target
- **Regular file / weird state** → refuses, asks you to inspect manually

After successful migration, adds a `SYMLINK` line to `~/.offload-config`.

```bash
offload add .cargo        # migrate Rust toolchain
offload add .pyenv        # migrate Python versions
offload add go            # migrate Go workspace
```

---

### `offload remove <name>`

Reverses a migration. Copies data from external back to `~/<name>`, removes the symlink, removes the config entry.

Keeps the external copy until you explicitly confirm deletion — so you can verify the restore before losing the copy.

---

### `offload verify`

Checks every symlink in config and reports status:

| Status | Meaning |
|--------|---------|
| ✓ healthy | Symlink exists, target accessible |
| ✗ broken | Symlink exists but target missing (disk not mounted?) |
| ⚠ local | Real directory exists, not symlinked (needs `offload add`) |
| - missing | Neither symlink nor directory exists |

---

### `offload doctor`

Full health check. Reports issues and suggests fix commands:

- Config file present
- External disk mounted
- External disk <10% free → warns
- Internal disk <10% free → warns + suggests `offload clean`
- Every symlink state
- Services running/stopped
- `~/Library/pnpm` not symlinked → suggests `offload clean pnpm_migrate`
- Stale `/tmp/.offload-*` sentinels older than 30 days → auto-cleans them

---

### `offload scan`

Finds directories in `$HOME` that aren't yet managed and aren't in the NEVER list. Shows each candidate with its size:

```
  FOLDER                           SIZE  STATUS
  ------                           ----  ------
  .gradle                          2.1G  candidate
  .cocoapods                       890M  candidate
  .pub-cache                       450M  candidate
```

Use `offload add <name>` on anything you want to move.

---

### `offload clean`

Lists all cleanup recipes applicable to your system with estimated reclaim sizes:

```
  RECIPE                      SIZE  DESCRIPTION
  ------                      ----  -----------
  android_trim               3.9G  Trim Android SDK (keep build-tools)
  library_caches             7.1G  Wipe ~/Library/Caches
  pnpm_migrate               1.9G  Migrate pnpm store to external
  go_module_cache            222M  Clean Go build & test cache
  brew_cleanup                52M  Homebrew cleanup
  podman_prune         21% recl.   Prune Podman
  node_modules_orphans  scan...    Delete large node_modules folders
  app_support_report         24G   Report: Application Support breakdown
  big_files_report       scan...   Report: Files larger than 500MB
```

For any recipe:

```bash
offload clean <recipe> --dry-run   # see what would be touched, no changes
offload clean <recipe>             # interactive: shows preview, asks confirm
offload clean <recipe> --yes       # skip confirmation
offload clean all                  # walk all applicable recipes interactively
offload clean all --yes            # walk all, skip all confirmations
```

---

## Cleanup Recipes

### `arduino_trim`
Removes `~/Library/Arduino15/staging`, `packages/arduino` (AVR core), and library index files. Keeps ESP32 and other non-AVR cores. **~3–4 GB.** Reversible via Boards Manager.

### `android_nuke`
Deletes `~/Library/Android` entirely. **~11 GB.** Reinstall via Android Studio. Mutually exclusive with `android_trim` (sentinel prevents both showing after one runs).

### `android_trim`
Removes `system-images`, `emulator`, and all-but-newest `platforms/android-*`. Keeps latest platform and all build-tools. **~7–9 GB.** Re-download via SDK Manager.

### `library_caches`
Wipes `~/Library/Caches`. Apps regenerate caches on next launch. May slow first launch of Chrome, Slack, etc. **~5–10 GB.**

### `pnpm_migrate`
Moves `~/Library/pnpm` (pnpm store) to the external disk, creates symlink, updates pnpm config. Only applicable when disk is mounted and store isn't already symlinked. Frees internal disk permanently.

### `xcode_derived`
Clears `DerivedData`, `CoreSimulator/Caches`, and removes unavailable simulators (`xcrun simctl delete unavailable`). Xcode rebuilds everything as needed. **~5–30 GB.**

### `go_module_cache`
Runs `go clean -cache -testcache`. Does NOT touch module downloads (`GOPATH/pkg/mod`). Safe — Go rebuilds caches on next build.

### `brew_cleanup`
Runs `brew cleanup -s --prune=all` and wipes `~/Library/Caches/Homebrew`. Removes old formula versions and partial downloads.

### `podman_prune`
Runs `podman system prune -a --volumes -f`. Removes unused images, stopped containers, dangling volumes. Only applicable when external disk is mounted (Podman storage lives there).

### `trash_empty`
Empties `~/.Trash`. Only applicable when Trash is non-empty. **Irreversible.**

### `node_modules_orphans`
Scans `$HOME` and external disk for `node_modules` folders >100 MB. For each found:
- Interactive mode: shows project name, size, path — asks per-folder
- `--yes` mode: auto-deletes >500 MB, skips 100–500 MB (conservative for automation)

Recoverable via `pnpm install` / `npm install` in the project directory.

### `app_support_report` *(read-only)*
Shows top 15 largest entries in `~/Library/Application Support` sorted by size. Does not delete anything. Includes a warning about irreplaceable data (Anki, Bear, Things3, etc.).

### `big_files_report` *(read-only)*
Scans `$HOME` for files >500 MB. Lists them with sizes. Does not delete anything. Takes ~30 seconds.

---

## Audit Log

Every destructive operation is logged to `~/.offload-log`:

```
2025-05-13 14:32:01|alice|clean: library_caches reclaimed 7234MB
2025-05-13 14:33:10|alice|recipe_trash_empty: emptied ~/.Trash
2025-05-13 14:45:22|alice|migrate: dir->symlink /Users/alice/.cargo -> /Volumes/MyDrive/home/.cargo (4.2G)
```

View it:
```bash
offload log            # all entries
offload log --tail 20  # last 20 entries
```

---

## Adding Your Own Recipes

Open `~/scripts/lib/recipes.sh`. The file starts with a full how-to comment. Template:

```bash
recipe_myapp_cache() {
  case "$1" in
    name)
      echo "Short human title"
      ;;
    describe)
      cat <<EOF
What this recipe does, in 2-4 lines.
Reclaims approximately X GB.
Notes about reversibility or side effects.
EOF
      ;;
    applicable)
      [[ -d ~/Library/MyApp ]] && return 0 || return 1
      ;;
    size)
      [[ -d ~/Library/MyApp/Cache ]] && human ~/Library/MyApp/Cache || echo "0B"
      ;;
    preview)
      echo "Would delete:"
      du -sh ~/Library/MyApp/Cache 2>/dev/null
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would: rm -rf ~/Library/MyApp/Cache"
        return 0
      fi
      safe_to_delete ~/Library/MyApp/Cache || { err "Path blocked"; return 1; }
      step "Removing cache..."
      rm -rf ~/Library/MyApp/Cache
      log_action "recipe_myapp_cache: removed ~/Library/MyApp/Cache"
      ok "Done"
      ;;
  esac
}
```

Then add it to `ALL_RECIPES` at the bottom of `recipes.sh`:

```bash
ALL_RECIPES=(
  ...existing entries...
  myapp_cache
)
```

Test it:
```bash
offload clean myapp_cache --dry-run
offload clean myapp_cache
```

**Rules every recipe must follow:**
- NEVER use `sudo`
- NEVER touch `~/.ssh`, `~/.config`, `~/Library/Keychains`, `~/Documents`, `~/Desktop`
- NEVER delete user data (notes, mail, todos, photos, music)
- ALWAYS check `$DRY_RUN` in the `apply` case
- ALWAYS call `log_action` for every destructive operation
- ALWAYS call `safe_to_delete "$path"` before any `rm -rf`
- Prefer reversibility — if the app can regenerate it, it's a candidate

---

## Shell Integration (optional)

Add to `~/.zshrc` to get a warning when the external disk isn't mounted at shell start:

```bash
# ─── offload system integration ──────────────────────────────────
if [[ ! -d /Volumes/backup/home ]]; then
  for link in ~/.cargo ~/go ~/GitHub ~/.claude ~/.pyenv; do
    if [[ -L "$link" ]]; then
      echo "\e[33m⚠  External disk not mounted — symlinked tools will fail\e[0m"
      echo "\e[2m   Run: offload start\e[0m"
      break
    fi
  done
fi
```

Adjust the path `/Volumes/backup/home` and the symlink list to match your config.

**Powerlevel10k segment** (optional — shows disk status in prompt):

```bash
function prompt_ext_disk() {
  if [[ -d /Volumes/backup/home ]]; then
    p10k segment -f 2 -i '●' -t 'ext'
  else
    p10k segment -f 1 -i '●' -t 'no-disk'
  fi
}
```

Add `ext_disk` to `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` in your p10k config.

---

## File Layout

```
~/scripts/
├── offload                  # main entry point (executable)
├── lib/
│   ├── common.sh            # shared helpers, colors, config parser
│   ├── recipes.sh           # cleanup recipes
│   └── migration.sh         # symlink state machine (add/remove)
└── README.md                # this file

~/.offload-config            # your config (symlinks, services, never list)
~/.offload-state             # runtime state (last start timestamp)
~/.offload-log               # append-only audit log of destructive operations
```

---

## Safety Model

1. **No `sudo`** — anywhere, ever. If something needs root, this tool won't do it.
2. **`safe_to_delete()` guard** — any `rm -rf` goes through a path check that rejects `$HOME`, `~/.ssh`, `~/.config`, `~/Documents`, `~/Desktop`, `~/Library/Keychains`, `~/Pictures`, `~/Movies`, `~/Music`.
3. **`--dry-run` always works** — every recipe checks `$DRY_RUN` before touching anything. Run `offload clean all --dry-run` to preview everything safely.
4. **Audit log** — every destructive operation is timestamped and logged to `~/.offload-log`.
5. **No auto-cleanup** — nothing runs in the background. Every cleanup is a conscious decision.
6. **Confirm prompts** — every destructive recipe asks before applying. Use `--yes` only when you understand what it does.
7. **`migrate_path` state machine** — `offload add` detects existing symlinks, local copies, missing targets, and wrong symlink targets before touching anything.

---

## Linux Notes

The tool works on Linux with minor differences:

- `EXT_MOUNT` / `EXT_HOME` should point to your mounted drive (e.g., `/mnt/external`, `/media/user/drive`)
- `offload stop` skips the `diskutil eject` step (macOS-only) and just stops services
- Recipes that check `~/Library/...` paths will show "not applicable" correctly since those paths won't exist
- The recipes `brew_cleanup`, `go_module_cache`, `podman_prune`, `node_modules_orphans` work on Linux without modification
- `offload scan` works on any POSIX system

---

## Troubleshooting

### "External disk not mounted"
```bash
diskutil list                    # find the disk
diskutil mount /dev/diskNs2      # mount it
offload start                    # verify + start services
```

### Symlink broken after disk ejected
Expected — symlinked tools require the disk. Mount the disk and run `offload start`.

### `offload add` fails at rsync step
The source directory may have read-only files (common with `~/.cargo`). The tool runs `chmod -R u+w` before rsync. If it still fails:
```bash
chmod -R u+w ~/foo
offload add foo
```

### Recipe says "not applicable"
The recipe's `applicable` check returned false. Use `--list-all` to see all recipes:
```bash
offload clean --list-all
```

### Want to see what a recipe does before running
```bash
offload clean <recipe> --dry-run
```

### Log shows unexpected deletions
```bash
offload log
```
Every destructive operation is recorded with timestamp and username.

---

## Contributing

1. Fork the repo
2. Add your recipe in `lib/recipes.sh` following the template
3. Test: `offload clean <yourrecipe> --dry-run` then `offload clean <yourrecipe>`
4. PR with a brief description of what the recipe targets and how much it reclaims

Recipe contributions for common apps (VS Code caches, JetBrains, Docker, etc.) are especially welcome.

---

## License

MIT
