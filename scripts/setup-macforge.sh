#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/config/macforge.sh"

TARGET_DIR="$HOME"
BREWFILE_PATH="$REPO_ROOT/$BREWFILE_REL"
ITERM_PLIST_PATH="$REPO_ROOT/$ITERM_PLIST_REL"
STATE_DIR="${MACFORGE_STATE_DIR:-${WORKSTATION_STATE_DIR:-$STATE_DIR_DEFAULT}}"
STATE_FILE="$STATE_DIR/$STATE_FILE_NAME"

AUTO_YES=0
FROM_PHASE=""
UNTIL_PHASE=""
LIST_PHASES=0
RESET_STATE=0

PHASES=(
  "xcode_clt"
  "homebrew"
  "stow"
  "backup"
  "apply_dotfiles"
  "brew_bundle"
  "macos_defaults"
  "iterm2"
)

usage() {
  cat <<'USAGE'
Usage:
  ./macforge setup [options]

Options:
  --yes            Non-interactive mode (no prompts between phases)
  --from <phase>   Start from a specific phase
  --until <phase>  Stop after a specific phase
  --list-phases    Print available phases and exit
  --reset-state    Clear saved setup state before running
  -h, --help       Show this help
USAGE
}

log() {
  printf '%s\n' "$1"
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

ensure_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This setup targets macOS only."
  fi
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

clear_state_if_requested() {
  if (( RESET_STATE == 1 )) && [[ -f "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    log "Reset previous setup state: $STATE_FILE"
  fi
}

load_completed_phases() {
  COMPLETED=()
  if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && COMPLETED+=("$line")
    done < "$STATE_FILE"
  fi
}

phase_is_completed() {
  local phase="$1"
  local p
  for p in "${COMPLETED[@]:-}"; do
    [[ "$p" == "$phase" ]] && return 0
  done
  return 1
}

mark_phase_completed() {
  local phase="$1"
  if ! phase_is_completed "$phase"; then
    printf '%s\n' "$phase" >> "$STATE_FILE"
    COMPLETED+=("$phase")
  fi
}

phase_exists() {
  local target="$1"
  local phase
  for phase in "${PHASES[@]}"; do
    [[ "$phase" == "$target" ]] && return 0
  done
  return 1
}

prompt_continue() {
  local next_phase="$1"
  if (( AUTO_YES == 1 )); then
    return 0
  fi

  printf '\nPhase complete. Continue to "%s"? [Y/n]: ' "$next_phase"
  read -r answer
  if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
    return 0
  fi

  log "Paused. Re-run './macforge setup' to resume from saved state."
  exit 0
}

ensure_xcode_clt() {
  log "[xcode_clt] Checking Xcode Command Line Tools..."

  if xcode-select -p >/dev/null 2>&1; then
    log "[xcode_clt] Already installed."
    return
  fi

  log "[xcode_clt] Triggering install..."
  xcode-select --install || true

  local waited=0
  local timeout=1800
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    if (( waited >= timeout )); then
      die "Timed out waiting for Xcode Command Line Tools. Finish install in System Settings > Software Update, then rerun."
    fi
  done

  log "[xcode_clt] Installed."
}

ensure_homebrew() {
  log "[homebrew] Checking Homebrew..."

  if command -v brew >/dev/null 2>&1; then
    log "[homebrew] Already installed."
    return
  fi

  log "[homebrew] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -q 'eval "$\(/opt/homebrew/bin/brew shellenv\)"' "$HOME/.zprofile" 2>/dev/null || \
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    grep -q 'eval "$\(/usr/local/bin/brew shellenv\)"' "$HOME/.zprofile" 2>/dev/null || \
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi

  log "[homebrew] Installed."
}

ensure_stow() {
  log "[stow] Checking GNU Stow..."
  if command -v stow >/dev/null 2>&1; then
    log "[stow] Already installed."
    return
  fi

  log "[stow] Installing GNU Stow..."
  brew install stow
}

backup_conflicts() {
  log "[backup] Backing up conflicting files if needed..."

  local ts backup_dir did_backup=0
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$BACKUP_DIR_ROOT/$ts"

  local file target
  for file in "${MANAGED_FILES[@]}"; do
    target="$TARGET_DIR/$file"
    if [[ -e "$target" && ! -L "$target" ]]; then
      if (( did_backup == 0 )); then
        mkdir -p "$backup_dir"
      fi
      mv "$target" "$backup_dir/"
      did_backup=1
      log "[backup] Moved $target -> $backup_dir/$file"
    fi
  done

  if (( did_backup == 1 )); then
    log "[backup] Backup created at: $backup_dir"
  else
    log "[backup] No conflicts found."
  fi
}

apply_stow() {
  log "[apply_dotfiles] Applying dotfiles with stow..."
  cd "$REPO_ROOT"
  stow --restow --target "$TARGET_DIR" "${PACKAGES[@]}"
  log "[apply_dotfiles] Done."
}

install_brew_dependencies() {
  log "[brew_bundle] Installing Brewfile dependencies..."
  if [[ ! -f "$BREWFILE_PATH" ]]; then
    log "[brew_bundle] Brewfile missing at $BREWFILE_PATH. Skipping."
    return
  fi
  brew bundle --file="$BREWFILE_PATH"
  log "[brew_bundle] Done."
}

apply_macos_preferences() {
  log "[macos_defaults] Applying macOS defaults..."

  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' || true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write com.apple.dock autohide -bool true
  killall Dock >/dev/null 2>&1 || true

  log "[macos_defaults] Done."
}

configure_iterm2() {
  log "[iterm2] Configuring iTerm2 preferences..."

  if [[ ! -f "$ITERM_PLIST_PATH" ]]; then
    log "[iterm2] Missing plist at $ITERM_PLIST_PATH. Skipping."
    return
  fi

  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$REPO_ROOT/osx-conf/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false

  log "[iterm2] Done."
}

run_phase() {
  local phase="$1"
  case "$phase" in
    xcode_clt) ensure_xcode_clt ;;
    homebrew) ensure_homebrew ;;
    stow) ensure_stow ;;
    backup) backup_conflicts ;;
    apply_dotfiles) apply_stow ;;
    brew_bundle) install_brew_dependencies ;;
    macos_defaults) apply_macos_preferences ;;
    iterm2) configure_iterm2 ;;
    *) die "Unknown phase: $phase" ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        AUTO_YES=1
        shift
        ;;
      --from)
        FROM_PHASE="${2:-}"
        [[ -n "$FROM_PHASE" ]] || die "--from requires a phase"
        shift 2
        ;;
      --until)
        UNTIL_PHASE="${2:-}"
        [[ -n "$UNTIL_PHASE" ]] || die "--until requires a phase"
        shift 2
        ;;
      --list-phases)
        LIST_PHASES=1
        shift
        ;;
      --reset-state)
        RESET_STATE=1
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

main() {
  parse_args "$@"
  ensure_macos

  if (( LIST_PHASES == 1 )); then
    printf '%s\n' "${PHASES[@]}"
    exit 0
  fi

  if [[ -n "$FROM_PHASE" ]] && ! phase_exists "$FROM_PHASE"; then
    die "Unknown phase for --from: $FROM_PHASE"
  fi
  if [[ -n "$UNTIL_PHASE" ]] && ! phase_exists "$UNTIL_PHASE"; then
    die "Unknown phase for --until: $UNTIL_PHASE"
  fi

  ensure_state_dir
  clear_state_if_requested
  load_completed_phases

  log "Starting ${MACFORGE_NAME:-macforge} setup..."

  local phase
  local started=0
  local idx next_phase
  for idx in "${!PHASES[@]}"; do
    phase="${PHASES[$idx]}"

    if [[ -n "$FROM_PHASE" && $started -eq 0 ]]; then
      if [[ "$phase" == "$FROM_PHASE" ]]; then
        started=1
      else
        continue
      fi
    fi

    if [[ -z "$FROM_PHASE" ]]; then
      started=1
    fi

    if phase_is_completed "$phase"; then
      log "[$phase] Already completed in previous run. Skipping."
    else
      run_phase "$phase"
      mark_phase_completed "$phase"
    fi

    if [[ -n "$UNTIL_PHASE" && "$phase" == "$UNTIL_PHASE" ]]; then
      log "Reached --until phase: $UNTIL_PHASE"
      break
    fi

    if (( idx + 1 < ${#PHASES[@]} )); then
      next_phase="${PHASES[$((idx + 1))]}"
      prompt_continue "$next_phase"
    fi
  done

  log "Setup completed."
  log "State file: $STATE_FILE"
  log "If needed, rerun './macforge setup' to resume/continue."
}

main "$@"
