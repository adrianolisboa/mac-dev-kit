## Zsh and macOS configurations

### Load shell configurations

Add this to your `.zshrc`:

```zsh
LOAD_ROOT="$HOME/Projects/osx-conf"
. ${LOAD_ROOT}/load
```

`load` recursively sources the folders configured in the file.

## macOS setup (2026-ready)

For a fresh macOS machine:

```zsh
cd "$HOME/Projects/osx-conf"
./setup.sh
```

What `setup.sh` does:
- Ensures Xcode Command Line Tools are installed (with timeout protection).
- Installs Homebrew for Apple Silicon (`/opt/homebrew`) or Intel (`/usr/local`).
- Installs packages from `Brewfile`.
- Applies macOS defaults (safe in headless sessions).
- Configures iTerm2 custom preferences if plist is present.
