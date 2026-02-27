#!/usr/bin/env bash

# Central setup configuration for macforge bootstrap.
MACFORGE_NAME="macforge"

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

BREWFILE_REL="osx-conf/Brewfile"
BREWFILE_OPTIONAL_REL="osx-conf/Brewfile.optional"
ITERM_PLIST_REL="osx-conf/iterm2/com.googlecode.iterm2.plist"

STATE_DIR_DEFAULT="$HOME/.local/state/macforge"
STATE_FILE_NAME="setup.state"
BACKUP_DIR_ROOT="$HOME/.dotfiles-backup"
