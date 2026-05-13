#!/usr/bin/env zsh
# Migration helpers — symlink state machine for offload add/remove

# migrate_path <name> <target> [description]
# Detects state of $HOME/<name> and migrates to <target> accordingly.
migrate_path() {
  local name="$1"
  local target="$2"
  local src="$HOME/$name"

  # State detection
  local state
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    state=missing
  elif [[ -L "$src" ]]; then
    if [[ "$(readlink "$src")" == "$target" ]]; then
      state=correct-symlink
    else
      state=wrong-symlink
    fi
  elif [[ -d "$src" ]]; then
    state=local-dir
  elif [[ -f "$src" ]]; then
    state=local-file
  else
    state=weird
  fi

  case "$state" in
    correct-symlink)
      ok "$name already correctly linked"
      return 0
      ;;

    missing)
      mkdir -p "$(dirname "$target")" "$target"
      ln -s "$target" "$src"
      ok "Linked $name (was missing)"
      log_action "migrate: created symlink $src -> $target"
      return 0
      ;;

    wrong-symlink)
      local existing
      existing=$(readlink "$src")
      warn "$name points to $existing, expected $target"
      confirm "Replace symlink?" || return 1
      rm "$src"
      ln -s "$target" "$src"
      ok "Re-linked $name"
      log_action "migrate: replaced symlink $src ($existing -> $target)"
      return 0
      ;;

    local-dir)
      local sz
      sz=$(human "$src")
      info "Will migrate ~/$name ($sz) to external"
      confirm "Proceed?" || { info "Cancelled."; return 1; }
      mkdir -p "$(dirname "$target")"
      step "Making writable..."
      chmod -R u+w "$src" 2>/dev/null
      step "Copying to $target..."
      rsync -a "$src/" "$target/" 2>/dev/null || {
        err "rsync failed"
        return 1
      }
      step "Removing local..."
      rm -rf "$src" 2>/dev/null
      if [[ -e "$src" ]]; then
        err "Could not remove $src (read-only files?). Try manually."
        return 1
      fi
      ln -s "$target" "$src"
      ok "Migrated and linked $name"
      log_action "migrate: dir->symlink $src -> $target ($sz)"
      return 0
      ;;

    local-file)
      err "$name is a regular file, not a directory. Refusing to auto-migrate."
      return 1
      ;;

    weird)
      err "$name is in an unexpected state. Inspect manually: ls -la $src"
      return 1
      ;;
  esac
}
