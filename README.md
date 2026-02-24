# mac-dev-kit

Single repository for:
- Dotfiles managed with GNU Stow.
- macOS bootstrap/setup scripts and shell environment (`osx-conf/`).

### Install on a fresh macOS machine

```bash
git clone git@github.com:adrianolisboa/dotfiles.git ~/mac-dev-kit
cd ~/mac-dev-kit
./setup.sh
```

`setup.sh` will:
- Ensure Xcode Command Line Tools are installed.
- Ensure Homebrew is installed.
- Install GNU Stow if needed.
- Back up conflicting existing files to `~/.dotfiles-backup/<timestamp>/`.
- Symlink all managed packages (`git`, `bash`, `input`, `tmux`) into `$HOME`.
- Install dependencies from `osx-conf/Brewfile`.
- Apply macOS and iTerm2 preferences.

### Manual dotfiles usage

```bash
cd ~/mac-dev-kit
stow --target "$HOME" git bash input tmux
```

### Shell loader

Add this to your `.zshrc`:

```zsh
LOAD_ROOT="$HOME/mac-dev-kit/osx-conf"
. ${LOAD_ROOT}/load
```

`setup.sh` already includes macOS setup from `osx-conf`.
