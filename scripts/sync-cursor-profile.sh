#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/config/macforge.sh"

PROFILE_ROOT="$REPO_ROOT/$CURSOR_PROFILE_REL"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
SETTINGS_SOURCE="$PROFILE_ROOT/User/settings.json"
KEYBINDINGS_SOURCE="$PROFILE_ROOT/User/keybindings.json"
EXTENSIONS_SOURCE="$PROFILE_ROOT/extensions.txt"

SKIP_SETTINGS=0
SKIP_KEYBINDINGS=0
SKIP_EXTENSIONS=0

usage() {
  cat <<'USAGE'
Usage:
  ./macforge cursor-profile [options]

Options:
  --skip-settings      Do not update Cursor settings.json
  --skip-keybindings   Do not update Cursor keybindings.json
  --skip-extensions    Do not install/update Cursor extensions
  -h, --help           Show this help
USAGE
}

log() {
  printf '%s\n' "$1"
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-settings)
        SKIP_SETTINGS=1
        shift
        ;;
      --skip-keybindings)
        SKIP_KEYBINDINGS=1
        shift
        ;;
      --skip-extensions)
        SKIP_EXTENSIONS=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

ensure_profile_exists() {
  [[ -d "$PROFILE_ROOT" ]] || die "Cursor profile directory is missing: $PROFILE_ROOT"
}

apply_settings() {
  if (( SKIP_SETTINGS == 1 )); then
    log "[cursor_profile] Skipping settings.json."
    return
  fi

  if [[ ! -f "$SETTINGS_SOURCE" ]]; then
    log "[cursor_profile] Missing settings.json at $SETTINGS_SOURCE. Skipping."
    return
  fi

  mkdir -p "$CURSOR_USER_DIR"
  cp "$SETTINGS_SOURCE" "$CURSOR_USER_DIR/settings.json"
  log "[cursor_profile] Updated $CURSOR_USER_DIR/settings.json"
}

apply_keybindings() {
  if (( SKIP_KEYBINDINGS == 1 )); then
    log "[cursor_profile] Skipping keybindings.json."
    return
  fi

  if [[ ! -f "$KEYBINDINGS_SOURCE" ]]; then
    log "[cursor_profile] Missing keybindings.json at $KEYBINDINGS_SOURCE. Skipping."
    return
  fi

  mkdir -p "$CURSOR_USER_DIR"
  cp "$KEYBINDINGS_SOURCE" "$CURSOR_USER_DIR/keybindings.json"
  log "[cursor_profile] Updated $CURSOR_USER_DIR/keybindings.json"
}

resolve_cursor_cli() {
  if command -v cursor >/dev/null 2>&1; then
    command -v cursor
    return
  fi

  if [[ -x /Applications/Cursor.app/Contents/Resources/app/bin/cursor ]]; then
    printf '%s\n' "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    return
  fi

  return 1
}

apply_extensions() {
  if (( SKIP_EXTENSIONS == 1 )); then
    log "[cursor_profile] Skipping extensions."
    return
  fi

  if [[ ! -f "$EXTENSIONS_SOURCE" ]]; then
    log "[cursor_profile] Missing extensions list at $EXTENSIONS_SOURCE. Skipping."
    return
  fi

  local cursor_cli installed extension requested current_match base_id
  if ! cursor_cli="$(resolve_cursor_cli)"; then
    log "[cursor_profile] Cursor CLI not found. Skipping extension install."
    return
  fi

  installed="$("$cursor_cli" --list-extensions --show-versions)"

  while IFS= read -r extension; do
    extension="${extension%%#*}"
    extension="${extension%"${extension##*[![:space:]]}"}"
    extension="${extension#"${extension%%[![:space:]]*}"}"
    [[ -n "$extension" ]] || continue

    if printf '%s\n' "$installed" | grep -Fxq "$extension"; then
      log "[cursor_profile] Extension already installed: $extension"
      continue
    fi

    base_id="${extension%@*}"
    current_match="$(printf '%s\n' "$installed" | awk -F'@' -v id="$base_id" '$1 == id {print $0; exit}')"
    if [[ -n "$current_match" ]]; then
      log "[cursor_profile] Updating $base_id from $current_match to $extension"
      "$cursor_cli" --install-extension "$extension" --force
    else
      log "[cursor_profile] Installing $extension"
      "$cursor_cli" --install-extension "$extension"
    fi
  done < "$EXTENSIONS_SOURCE"
}

main() {
  parse_args "$@"
  ensure_profile_exists

  log "Applying macforge Cursor profile..."
  apply_settings
  apply_keybindings
  apply_extensions
  log "Cursor profile sync completed."
}

main "$@"
