#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This setup script targets macOS."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"
BREWFILE_PATH="$SCRIPT_DIR/osx-conf/Brewfile"
PACKAGES=(git bash input tmux)
MANAGED_FILES=(
  ".gitconfig"
  ".gitconfig-personal"
  ".gitconfig-professional"
  ".gitignore"
  ".bashrc"
  ".inputrc"
  ".tmux.conf"
)

log() {
  echo "$1"
}

ensure_xcode_clt() {
  log "Checking Xcode Command Line Tools..."

  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed."
    return
  fi

  log "Installing Xcode Command Line Tools..."
  xcode-select --install || true

  local waited=0
  local timeout=1800
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    if (( waited >= timeout )); then
      log "Timed out waiting for Xcode Command Line Tools install."
      log "Finish install in System Settings > Software Update, then re-run setup.sh."
      exit 1
    fi
  done

  log "Xcode Command Line Tools installed."
}

ensure_homebrew() {
  log "Checking Homebrew..."

  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed."
    return
  fi

  log "Installing Homebrew..."
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

  log "Homebrew installed."
}

ensure_stow() {
  if command -v stow >/dev/null 2>&1; then
    return
  fi

  log "Installing GNU Stow..."
  brew install stow
}

backup_conflicts() {
  local ts backup_dir
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$HOME/.dotfiles-backup/$ts"
  local did_backup=0

  for f in "${MANAGED_FILES[@]}"; do
    local target="$TARGET_DIR/$f"
    if [[ -e "$target" && ! -L "$target" ]]; then
      if [[ $did_backup -eq 0 ]]; then
        mkdir -p "$backup_dir"
      fi
      mv "$target" "$backup_dir/"
      did_backup=1
      log "Backed up existing $target -> $backup_dir/$f"
    fi
  done

  if [[ $did_backup -eq 1 ]]; then
    log "Backups created under: $backup_dir"
  fi
}

apply_stow() {
  cd "$SCRIPT_DIR"
  log "Applying dotfiles with Stow into $TARGET_DIR..."
  stow --restow --target "$TARGET_DIR" "${PACKAGES[@]}"
  log "Dotfiles applied."
}

install_brew_dependencies() {
  if [[ ! -f "$BREWFILE_PATH" ]]; then
    log "Brewfile not found at $BREWFILE_PATH. Skipping dependency install."
    return
  fi

  log "Installing dependencies from Brewfile..."
  brew bundle --file="$BREWFILE_PATH"
  log "Brewfile dependencies installed."
}

apply_macos_preferences() {
  log "Applying macOS preferences..."

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

  log "macOS preferences applied."
}

configure_iterm2() {
  local plist_path="$SCRIPT_DIR/osx-conf/iterm2/com.googlecode.iterm2.plist"

  if [[ ! -f "$plist_path" ]]; then
    log "iTerm2 plist not found at $plist_path. Skipping iTerm2 setup."
    return
  fi

  log "Configuring iTerm2 custom preferences..."
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$SCRIPT_DIR/osx-conf/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  log "iTerm2 configured."
}

log "Starting macOS setup..."
ensure_xcode_clt
ensure_homebrew
ensure_stow
backup_conflicts
apply_stow
install_brew_dependencies
apply_macos_preferences
configure_iterm2
log "Setup completed."
