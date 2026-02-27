## Shell Config Loader

Add this to your `.zshrc`:

```zsh
LOAD_ROOT="$HOME/Projects/macforge/osx-conf"
. ${LOAD_ROOT}/load
```

## Full setup

Run from repo root:

```bash
./macforge setup
```

This runs all setup phases, with checkpoints and resume support.
