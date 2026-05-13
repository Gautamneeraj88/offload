#!/usr/bin/env zsh
# ─── HOW TO ADD A NEW RECIPE ──────────────────────────────────────
#
# 1. Find the bloat. Use these commands to discover space hogs:
#       offload clean app_support_report
#       offload clean big_files_report
#       du -sh ~/Library/* 2>/dev/null | sort -hr | head -20
#
# 2. RESEARCH THE APP before deleting anything. Search:
#       "<app name> safe to delete <folder>"
#       "<app name> cache location"
#    Check the app's preferences for a "Clear cache" option first.
#
# 3. Copy the template below into a new function:
#       recipe_myapp_cache() { ... }
#
# 4. Fill in all six operations: name, describe, applicable, size, preview, apply.
#    - name: short title
#    - describe: 2-4 lines, mention reclaim size and whether reversible
#    - applicable: only return 0 when this recipe makes sense
#    - size: estimate, or "unknown"
#    - preview: show exactly what will be touched, no changes
#    - apply: do the work; MUST check $DRY_RUN; MUST log via log_action
#
# 5. Add the name to ALL_RECIPES array at the bottom.
#
# 6. Test:
#       offload clean myapp_cache --dry-run
#       offload clean myapp_cache
#
# 7. Commit your recipes.sh somewhere safe (git, dotfiles repo, external disk).
#
# RULES every recipe MUST follow:
#   - NEVER use sudo
#   - NEVER touch ~/.ssh, ~/.config, ~/Library/Keychains, ~/Documents, ~/Desktop
#   - NEVER delete user data (notes, mail, todos, photos, music)
#   - NEVER use "rm -rf /" or wildcards that could resolve to /
#   - ALWAYS respect $DRY_RUN in apply phase
#   - ALWAYS log destructive actions via log_action
#   - PREFER reversibility — if the app can regenerate it, it's a candidate
# ──────────────────────────────────────────────────────────────────

recipe_arduino_trim() {
  case "$1" in
    name)
      echo "Trim Arduino IDE"
      ;;
    describe)
      cat <<EOF
Removes Arduino15/staging, AVR core, and regenerable index files.
Keeps ESP32 core and other non-AVR boards.
Reclaims approximately 3-4 GB. Reversible via Boards Manager.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Arduino15 ]] && return 0 || return 1
      ;;
    size)
      local total=0
      for p in ~/Library/Arduino15/staging ~/Library/Arduino15/packages/arduino \
                ~/Library/Arduino15/library_index.json ~/Library/Arduino15/library_index.json.sig; do
        [[ -e "$p" ]] && total=$((total + $(du -sk "$p" 2>/dev/null | awk '{print $1}')))
      done
      (( total > 0 )) && echo "$((total / 1024))M" || echo "0B"
      ;;
    preview)
      echo "Would delete:"
      du -sh ~/Library/Arduino15/staging \
             ~/Library/Arduino15/packages/arduino \
             ~/Library/Arduino15/library_index.json \
             ~/Library/Arduino15/library_index.json.sig 2>/dev/null
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rm -rf ~/Library/Arduino15/staging"
        echo "[dry-run] would rm -rf ~/Library/Arduino15/packages/arduino"
        echo "[dry-run] would rm -f ~/Library/Arduino15/library_index.json*"
        return 0
      fi
      local base=~/Library/Arduino15
      safe_to_delete "$base/staging" && { step "Removing staging..."; rm -rf "$base/staging"; log_action "recipe_arduino_trim: removed $base/staging"; }
      safe_to_delete "$base/packages/arduino" && { step "Removing AVR core..."; rm -rf "$base/packages/arduino"; log_action "recipe_arduino_trim: removed $base/packages/arduino"; }
      rm -f "$base/library_index.json" "$base/library_index.json.sig" 2>/dev/null
      log_action "recipe_arduino_trim: removed library index files"
      ok "Done — reinstall AVR core via Boards Manager if needed"
      ;;
  esac
}

recipe_android_nuke() {
  case "$1" in
    name)
      echo "Remove Android SDK entirely"
      ;;
    describe)
      cat <<EOF
Deletes ~/Library/Android completely (~11 GB).
Reinstall via Android Studio if needed.
This is the nuclear option — use android_trim to keep build tools.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Android ]] && [[ ! -f /tmp/.offload-android-trimmed ]] && return 0 || return 1
      ;;
    size)
      [[ -d ~/Library/Android ]] && human ~/Library/Android || echo "0B"
      ;;
    preview)
      echo "Would delete:"
      du -sh ~/Library/Android/* 2>/dev/null
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rm -rf ~/Library/Android"
        return 0
      fi
      safe_to_delete ~/Library/Android || { err "Path blocked by safe_to_delete"; return 1; }
      step "Removing ~/Library/Android..."
      rm -rf ~/Library/Android
      log_action "recipe_android_nuke: removed ~/Library/Android"
      touch /tmp/.offload-android-nuked
      ok "Android SDK removed"
      ;;
  esac
}

recipe_android_trim() {
  case "$1" in
    name)
      echo "Trim Android SDK (keep build-tools)"
      ;;
    describe)
      cat <<EOF
Removes system-images, emulator, and old platform versions.
Keeps latest platform and all build-tools.
Reclaims approximately 7-9 GB. Re-download via SDK Manager.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Android/sdk ]] && [[ ! -f /tmp/.offload-android-nuked ]] && return 0 || return 1
      ;;
    size)
      local total=0
      for p in ~/Library/Android/sdk/system-images ~/Library/Android/sdk/emulator; do
        [[ -d "$p" ]] && total=$((total + $(du -sk "$p" 2>/dev/null | awk '{print $1}')))
      done
      local platforms=($(ls -1d ~/Library/Android/sdk/platforms/android-* 2>/dev/null | sort -V))
      local n=${#platforms[@]}
      if (( n > 1 )); then
        for p in "${platforms[@]:0:$((n-1))}"; do
          [[ -d "$p" ]] && total=$((total + $(du -sk "$p" 2>/dev/null | awk '{print $1}')))
        done
      fi
      (( total > 0 )) && echo "$((total / 1024))M" || echo "0B"
      ;;
    preview)
      echo "Would delete:"
      du -sh ~/Library/Android/sdk/system-images ~/Library/Android/sdk/emulator 2>/dev/null
      local platforms=($(ls -1d ~/Library/Android/sdk/platforms/android-* 2>/dev/null | sort -V))
      local n=${#platforms[@]}
      if (( n > 1 )); then
        echo "Old platform versions (keeping newest):"
        for p in "${platforms[@]:0:$((n-1))}"; do
          du -sh "$p" 2>/dev/null
        done
      fi
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rm -rf ~/Library/Android/sdk/system-images"
        echo "[dry-run] would rm -rf ~/Library/Android/sdk/emulator"
        echo "[dry-run] would remove old platform versions (keep newest)"
        return 0
      fi
      local sdk=~/Library/Android/sdk
      if [[ -d "$sdk/system-images" ]]; then
        step "Removing system-images..."
        rm -rf "$sdk/system-images"
        log_action "recipe_android_trim: removed system-images"
      fi
      if [[ -d "$sdk/emulator" ]]; then
        step "Removing emulator..."
        rm -rf "$sdk/emulator"
        log_action "recipe_android_trim: removed emulator"
      fi
      local platforms=($(ls -1d "$sdk/platforms/android-"* 2>/dev/null | sort -V))
      local n=${#platforms[@]}
      if (( n > 1 )); then
        step "Removing old platform versions..."
        for p in "${platforms[@]:0:$((n-1))}"; do
          rm -rf "$p"
          log_action "recipe_android_trim: removed old platform $p"
        done
      fi
      touch /tmp/.offload-android-trimmed
      ok "Android SDK trimmed — use SDK Manager to re-download if needed"
      ;;
  esac
}

recipe_library_caches() {
  case "$1" in
    name)
      echo "Wipe ~/Library/Caches"
      ;;
    describe)
      cat <<EOF
Removes all contents of ~/Library/Caches.
Apps regenerate their caches on next launch.
May slow first launch of Chrome, Slack, etc. Reclaims ~5-10 GB.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Caches ]] && return 0 || return 1
      ;;
    size)
      human ~/Library/Caches
      ;;
    preview)
      echo "Top 10 subdirectories by size:"
      du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rm -rf ~/Library/Caches/*"
        return 0
      fi
      step "Wiping ~/Library/Caches..."
      rm -rf ~/Library/Caches/* 2>/dev/null
      log_action "recipe_library_caches: wiped ~/Library/Caches"
      ok "Done"
      ;;
  esac
}

recipe_pnpm_migrate() {
  case "$1" in
    name)
      echo "Migrate pnpm store to external"
      ;;
    describe)
      cat <<EOF
Moves ~/Library/pnpm to external disk, updates pnpm config, creates symlink.
Frees ~/Library/pnpm space from internal disk.
Requires external disk to be mounted (EXT_HOME must be set in config).
EOF
      ;;
    applicable)
      [[ -d ~/Library/pnpm && ! -L ~/Library/pnpm && -d "$EXT_MOUNT" ]] && return 0 || return 1
      ;;
    size)
      human ~/Library/pnpm
      ;;
    preview)
      local sz
      sz=$(human ~/Library/pnpm)
      echo "Source: ~/Library/pnpm ($sz)"
      echo "Target: $EXT_HOME/Library/pnpm"
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rsync ~/Library/pnpm → $EXT_HOME/Library/pnpm"
        echo "[dry-run] would rm -rf ~/Library/pnpm"
        echo "[dry-run] would ln -s $EXT_HOME/Library/pnpm ~/Library/pnpm"
        return 0
      fi
      step "Creating target directory..."
      mkdir -p "$EXT_HOME/Library"
      step "Copying pnpm store to external..."
      rsync -a ~/Library/pnpm/ "$EXT_HOME/Library/pnpm/" 2>/dev/null || {
        err "rsync failed"
        return 1
      }
      step "Removing local copy..."
      rm -rf ~/Library/pnpm
      step "Creating symlink..."
      ln -s "$EXT_HOME/Library/pnpm" ~/Library/pnpm
      if command -v pnpm >/dev/null; then
        pnpm config set store-dir "$EXT_HOME/Library/pnpm/store" 2>/dev/null
      fi
      log_action "recipe_pnpm_migrate: moved ~/Library/pnpm to $EXT_HOME/Library/pnpm"
      ok "pnpm store migrated to external disk"
      ;;
  esac
}

recipe_xcode_derived() {
  case "$1" in
    name)
      echo "Wipe Xcode caches"
      ;;
    describe)
      cat <<EOF
Clears DerivedData, CoreSimulator caches, and removes unavailable simulators.
Safe — Xcode rebuilds everything as needed.
Reclaims ~5-30 GB depending on project history.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Developer/Xcode ]] && return 0 || return 1
      ;;
    size)
      local total=0
      for p in ~/Library/Developer/Xcode/DerivedData ~/Library/Developer/CoreSimulator/Caches; do
        [[ -d "$p" ]] && total=$((total + $(du -sk "$p" 2>/dev/null | awk '{print $1}')))
      done
      (( total > 0 )) && echo "$((total / 1024))M" || echo "0B"
      ;;
    preview)
      echo "Would clear:"
      du -sh ~/Library/Developer/Xcode/DerivedData \
             ~/Library/Developer/CoreSimulator/Caches 2>/dev/null
      command -v xcrun >/dev/null && echo "Would run: xcrun simctl delete unavailable"
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would rm -rf ~/Library/Developer/Xcode/DerivedData/*"
        echo "[dry-run] would rm -rf ~/Library/Developer/CoreSimulator/Caches/*"
        echo "[dry-run] would xcrun simctl delete unavailable"
        return 0
      fi
      step "Clearing DerivedData..."
      rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
      log_action "recipe_xcode_derived: cleared DerivedData"
      step "Clearing CoreSimulator caches..."
      rm -rf ~/Library/Developer/CoreSimulator/Caches/* 2>/dev/null
      log_action "recipe_xcode_derived: cleared CoreSimulator/Caches"
      if command -v xcrun >/dev/null; then
        step "Removing unavailable simulators..."
        xcrun simctl delete unavailable 2>/dev/null
        log_action "recipe_xcode_derived: deleted unavailable simulators"
      fi
      ok "Done"
      ;;
  esac
}

recipe_go_module_cache() {
  case "$1" in
    name)
      echo "Clean Go build & test cache"
      ;;
    describe)
      cat <<EOF
Runs 'go clean -cache -testcache'. Does NOT touch module downloads.
Safe — Go rebuilds caches as needed on next build.
EOF
      ;;
    applicable)
      command -v go >/dev/null && return 0 || return 1
      ;;
    size)
      local gc
      gc=$(go env GOCACHE 2>/dev/null)
      [[ -d "$gc" ]] && human "$gc" || echo "0B"
      ;;
    preview)
      local gc
      gc=$(go env GOCACHE 2>/dev/null)
      echo "Go build cache: $gc"
      [[ -d "$gc" ]] && du -sh "$gc" 2>/dev/null || echo "(not found)"
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would: go clean -cache -testcache"
        return 0
      fi
      step "Cleaning Go build and test cache..."
      go clean -cache -testcache 2>/dev/null
      log_action "recipe_go_module_cache: go clean -cache -testcache"
      ok "Done"
      ;;
  esac
}

recipe_brew_cleanup() {
  case "$1" in
    name)
      echo "Homebrew cleanup"
      ;;
    describe)
      cat <<EOF
Runs 'brew cleanup -s --prune=all' and wipes Homebrew cache.
Removes old formula versions and partial downloads. Reversible via reinstall.
EOF
      ;;
    applicable)
      command -v brew >/dev/null && return 0 || return 1
      ;;
    size)
      local cache
      cache=$(brew --cache 2>/dev/null)
      [[ -d "$cache" ]] && human "$cache" || echo "0B"
      ;;
    preview)
      echo "Brew cleanup dry-run (may take a moment):"
      brew cleanup -n 2>/dev/null | head -30
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would: brew cleanup -s --prune=all"
        echo "[dry-run] would: rm -rf ~/Library/Caches/Homebrew/*"
        return 0
      fi
      step "Running brew cleanup..."
      brew cleanup -s --prune=all
      step "Wiping Homebrew cache..."
      rm -rf ~/Library/Caches/Homebrew/* 2>/dev/null
      log_action "recipe_brew_cleanup: brew cleanup + cache wipe"
      ok "Done"
      ;;
  esac
}

recipe_podman_prune() {
  case "$1" in
    name)
      echo "Prune Podman"
      ;;
    describe)
      cat <<EOF
Removes unused images, stopped containers, and dangling volumes.
Requires external disk mounted (Podman storage lives there).
EOF
      ;;
    applicable)
      command -v podman >/dev/null && [[ -d "$EXT_MOUNT" ]] && return 0 || return 1
      ;;
    size)
      podman system df 2>/dev/null | awk 'NR>1 && $NF~/\(/ {gsub(/[()%]/,"",$NF); sum+=$NF} END {print (sum>0 ? sum"%" " reclaimable" : "unknown")}' 2>/dev/null || echo "unknown"
      ;;
    preview)
      echo "Podman disk usage:"
      podman system df 2>/dev/null || echo "(podman not running)"
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would: podman system prune -a --volumes -f"
        return 0
      fi
      step "Pruning Podman..."
      podman system prune -a --volumes -f 2>/dev/null
      log_action "recipe_podman_prune: podman system prune -a --volumes -f"
      ok "Done"
      ;;
  esac
}

recipe_trash_empty() {
  case "$1" in
    name)
      echo "Empty Trash"
      ;;
    describe)
      cat <<EOF
Empties ~/.Trash. Irreversible — files cannot be recovered after this.
EOF
      ;;
    applicable)
      [[ -d ~/.Trash ]] && [[ -n "$(ls -A ~/.Trash 2>/dev/null)" ]] && return 0 || return 1
      ;;
    size)
      human ~/.Trash
      ;;
    preview)
      echo "Top 10 items in Trash:"
      ls -1 ~/.Trash 2>/dev/null | head -10
      echo ""
      echo "Total: $(human ~/.Trash)"
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] would: rm -rf ~/.Trash/* ~/.Trash/.[!.]*"
        return 0
      fi
      step "Emptying Trash..."
      rm -rf ~/.Trash/* ~/.Trash/.[!.]* 2>/dev/null
      log_action "recipe_trash_empty: emptied ~/.Trash"
      ok "Trash emptied"
      ;;
  esac
}

recipe_node_modules_orphans() {
  case "$1" in
    name)
      echo "Delete large node_modules folders"
      ;;
    describe)
      cat <<EOF
Finds node_modules folders >100MB in home and external disk.
Lets you choose which to delete. Recoverable via 'pnpm install' / 'npm install'.
EOF
      ;;
    applicable)
      return 0
      ;;
    size)
      echo "scan to compute"
      ;;
    preview)
      echo "Scanning for node_modules >100MB (may take a moment)..."
      local kb mb proj_nm
      find ~ ${EXT_HOME:+"$EXT_HOME"} -maxdepth 6 -name node_modules -type d -prune 2>/dev/null | while read -r d; do
        kb=$(du -sk "$d" 2>/dev/null | awk '{print $1}')
        if (( kb > 102400 )); then
          mb=$(( kb / 1024 ))
          proj_nm="${d:h:t}"
          printf "  %6dM  %s  (%s)\n" "$mb" "$d" "$proj_nm"
        fi
      done
      ;;
    apply)
      if $DRY_RUN; then
        echo "[dry-run] scanning node_modules >100MB..."
        recipe_node_modules_orphans preview
        return 0
      fi
      echo "Scanning for node_modules >100MB..."
      local found=() kb
      while IFS= read -r d; do
        kb=$(du -sk "$d" 2>/dev/null | awk '{print $1}')
        (( kb > 102400 )) && found+=("$d:$kb")
      done < <(find ~ ${EXT_HOME:+"$EXT_HOME"} -maxdepth 6 -name node_modules -type d -prune 2>/dev/null)

      if (( ${#found[@]} == 0 )); then
        info "No node_modules folders >100MB found."
        return 0
      fi

      local d kb_val mb proj_nm
      for entry in "${found[@]}"; do
        d="${entry%%:*}"
        kb_val="${entry##*:}"
        mb=$(( kb_val / 1024 ))
        proj_nm="${d:h:t}"
        if $AUTO_YES; then
          if (( mb > 500 )); then
            step "Auto-deleting $d (${mb}MB)..."
            safe_to_delete "$d" && rm -rf "$d" && log_action "recipe_node_modules_orphans: removed $d (${mb}MB)"
          else
            dim "Skipping $d (${mb}MB < 500MB threshold for auto-mode)"
          fi
        else
          echo ""
          echo "  ${C}${mb}MB${N}  $d  ${D}(project: $proj_nm)${N}"
          if confirm "Delete?"; then
            safe_to_delete "$d" && rm -rf "$d" && log_action "recipe_node_modules_orphans: removed $d (${mb}MB)" && ok "Deleted"
          else
            dim "Skipped"
          fi
        fi
      done
      ok "Done"
      ;;
  esac
}

recipe_app_support_report() {
  case "$1" in
    name)
      echo "Report: Application Support breakdown"
      ;;
    describe)
      cat <<EOF
Read-only. Shows top 15 space hogs in ~/Library/Application Support.
Suggests next steps. Does not delete anything.
EOF
      ;;
    applicable)
      [[ -d ~/Library/Application\ Support ]] && return 0 || return 1
      ;;
    size)
      human ~/Library/Application\ Support
      ;;
    preview)
      du -sh ~/Library/Application\ Support/* 2>/dev/null | sort -hr | head -15
      ;;
    apply)
      du -sh ~/Library/Application\ Support/* 2>/dev/null | sort -hr | head -15
      echo ""
      cat <<EOF
To clean a specific app's Application Support data, do not run blanket commands.
Open the app, look for "Clear cache" in its preferences, or research that app's
specific data layout before deleting. Many apps store user data here that is
NOT regenerable (Anki collections, Bear notes, Things3 todos, etc.).
EOF
      ;;
  esac
}

recipe_big_files_report() {
  case "$1" in
    name)
      echo "Report: Files larger than 500MB"
      ;;
    describe)
      cat <<EOF
Read-only. Finds files >500MB in \$HOME and reports them.
Does not delete anything.
EOF
      ;;
    applicable)
      return 0
      ;;
    size)
      echo "scan to compute"
      ;;
    preview)
      recipe_big_files_report apply
      ;;
    apply)
      echo "Scanning... (may take 30s)"
      local sz_f
      find ~ -type f -size +500M 2>/dev/null | head -50 | while read -r f; do
        sz_f=$(du -h "$f" 2>/dev/null | awk '{print $1}')
        echo "  $sz_f  $f"
      done
      ;;
  esac
}

# ─── Master recipe list ─────────────────────────────────────────────
ALL_RECIPES=(
  arduino_trim
  android_nuke
  android_trim
  library_caches
  pnpm_migrate
  xcode_derived
  go_module_cache
  brew_cleanup
  podman_prune
  trash_empty
  node_modules_orphans
  app_support_report
  big_files_report
)
