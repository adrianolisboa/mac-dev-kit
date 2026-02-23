#!/usr/bin/env zsh

set -euo pipefail

###############################################################################
# macOS setup script                                                           #
# - Installs Xcode Command Line Tools and Homebrew                            #
# - Installs Brewfile dependencies                                             #
# - Applies sensible macOS defaults and iTerm2 preferences                    #
###############################################################################

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ This setup script only supports macOS (Darwin)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
BREWFILE_PATH="$SCRIPT_DIR/Brewfile"

info() { echo "$1"; }

ensure_xcode_clt() {
  info "📦 Checking Xcode Command Line Tools..."

  if xcode-select -p >/dev/null 2>&1; then
    info "✅ Xcode Command Line Tools already installed."
    return
  fi

  info "🧰 Installing Xcode Command Line Tools..."
  xcode-select --install || true

  # Wait for install completion with timeout so setup never hangs forever.
  local waited=0
  local timeout=1800
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
    waited=$((waited + 5))
    if (( waited >= timeout )); then
      info "❌ Timed out waiting for Xcode Command Line Tools install."
      info "   Finish install in System Settings > Software Update, then re-run setup.sh"
      exit 1
    fi
  done

  info "✅ Xcode Command Line Tools installed."
}

ensure_homebrew() {
  info "🍺 Checking Homebrew..."

  if command -v brew >/dev/null 2>&1; then
    info "✅ Homebrew already installed."
    return
  fi

  info "🍺 Installing Homebrew..."
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

  info "✅ Homebrew installed."
}

install_brew_dependencies() {
  if [[ ! -f "$BREWFILE_PATH" ]]; then
    info "⚠️ Brewfile not found at $BREWFILE_PATH. Skipping package installation."
    return
  fi

  info "📦 Installing dependencies from Brewfile..."
  brew bundle --file="$BREWFILE_PATH"
  info "✅ Brewfile dependencies installed."
}

apply_macos_preferences() {
  info "🛠 Applying macOS preferences..."

  # Appearance may fail in headless/non-GUI contexts; keep setup moving.
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

  info "✅ macOS preferences applied."
}

configure_iterm2() {
  local plist_path="$SCRIPT_DIR/iterm2/com.googlecode.iterm2.plist"

  if [[ ! -f "$plist_path" ]]; then
    info "⚠️ iTerm2 config file not found! Skipping iTerm2 setup."
    return
  fi

  info "🖥 Configuring iTerm2 with custom settings..."
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$SCRIPT_DIR/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  info "✅ iTerm2 configuration applied."
}

info "🚀 Starting macOS setup..."
ensure_xcode_clt
ensure_homebrew
install_brew_dependencies
apply_macos_preferences
configure_iterm2
info "🎉 macOS setup completed successfully!"
