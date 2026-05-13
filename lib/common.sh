#!/usr/bin/env zsh
# Shared helpers for offload scripts

# Colors
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'
C=$'\e[36m'; M=$'\e[35m'; D=$'\e[2m'; BOLD=$'\e[1m'; N=$'\e[0m'

CONFIG_FILE="${HOME}/.offload-config"
STATE_FILE="${HOME}/.offload-state"

# Set from config; no hardcoded defaults
EXT_MOUNT=""
EXT_HOME=""

# Read config — sets globals plus arrays
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "${R}✗${N} Config not found: $CONFIG_FILE"
    echo "  Run: offload init"
    return 1
  fi

  SYMLINKS=()
  SERVICES=()
  NEVER=()

  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue

    case "$line" in
      SYMLINK\|*) SYMLINKS+=("$line") ;;
      SERVICE\|*) SERVICES+=("$line") ;;
      NEVER\|*) NEVER+=("$line") ;;
      EXT_MOUNT=*) EXT_MOUNT="${line#EXT_MOUNT=}" ;;
      EXT_HOME=*) EXT_HOME="${line#EXT_HOME=}" ;;
    esac
  done < "$CONFIG_FILE"
}

# UI helpers
header()  { echo "\n${BOLD}${B}━━ $1 ━━${N}"; }
ok()      { echo "${G}✓${N} $1"; }
warn()    { echo "${Y}⚠${N} $1"; }
err()     { echo "${R}✗${N} $1"; }
info()    { echo "${C}ℹ${N} $1"; }
step()    { echo "${Y}…${N} $1"; }
dim()     { echo "${D}$1${N}"; }

confirm() {
  $AUTO_YES && return 0
  echo -n "${Y}? $1 [y/N]:${N} "
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Human-readable size
human() { du -sh "$1" 2>/dev/null | awk '{print $1}'; }

# Mount check — sets MOUNT_OK
mount_check() {
  if [[ -d "$EXT_MOUNT" && -d "$EXT_HOME" ]]; then
    MOUNT_OK=true
    return 0
  fi
  MOUNT_OK=false
  return 1
}

# Parse a SYMLINK|... line into globals: SL_SRC, SL_DST, SL_DESC
parse_symlink() {
  local line="$1"
  local rest="${line#SYMLINK|}"
  SL_SRC="${rest%%|*}"; rest="${rest#*|}"
  SL_DST="${rest%%|*}"; rest="${rest#*|}"
  SL_DESC="$rest"
}

# Parse a SERVICE|... line into globals: SV_NAME, SV_START, SV_STOP, SV_CHECK
parse_service() {
  local line="$1"
  local rest="${line#SERVICE|}"
  SV_NAME="${rest%%|*}"; rest="${rest#*|}"
  SV_START="${rest%%|*}"; rest="${rest#*|}"
  SV_STOP="${rest%%|*}"; rest="${rest#*|}"
  SV_CHECK="$rest"
}

# Check a single symlink's health: returns 0 healthy, 1 broken, 2 not symlink, 3 missing
symlink_status() {
  local src="$HOME/$1"
  if [[ ! -e "$src" && ! -L "$src" ]]; then return 3; fi
  if [[ ! -L "$src" ]]; then return 2; fi
  [[ -e "$src" ]] && return 0 || return 1
}

# Run service check command
service_running() {
  local check="$1"
  eval "$check" >/dev/null 2>&1
}

log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')|$USER|$1" >> ~/.offload-log
}

safe_to_delete() {
  local path="$1"
  case "$path" in
    "$HOME"|"$HOME/"|/) return 1 ;;
    "$HOME/.ssh"*|"$HOME/.config"*|"$HOME/Documents"*|"$HOME/Desktop"*) return 1 ;;
    "$HOME/Library/Keychains"*) return 1 ;;
    "$HOME/Pictures"*|"$HOME/Movies"*|"$HOME/Music"*) return 1 ;;
    *) return 0 ;;
  esac
}
