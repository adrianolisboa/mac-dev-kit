## Zsh and macOS configurations

### Load shell configurations

Add this to your `.zshrc`:

```zsh
LOAD_ROOT="$HOME/mac-dev-kit/osx-conf"
. ${LOAD_ROOT}/load
```

`load` recursively sources the folders configured in the file.

## macOS setup

For a fresh macOS machine:

```zsh
cd "$HOME/mac-dev-kit"
./setup.sh
```

The top-level `setup.sh` handles dotfiles, Homebrew dependencies, and macOS preferences.
