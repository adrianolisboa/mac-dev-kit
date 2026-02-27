# macforge

Personal macOS bootstrap + dotfiles + shell tooling in one place.

## One command setup

```bash
cd "$HOME/Projects/macforge"
./macforge setup
```

That command orchestrates all phases, saves progress, and can pause between phases.

## Setup behavior

- Runs in phases (`xcode_clt`, `homebrew`, `stow`, `backup`, `apply_dotfiles`, `brew_bundle`, `macos_defaults`, `iterm2`).
- Saves state at `~/.local/state/macforge/setup.state`.
- If interrupted, re-run the same command to resume.
- Prompts before moving to the next phase (use `--yes` for non-interactive mode).

## Useful commands

```bash
./macforge help
./macforge phases
./macforge setup --yes
./macforge setup --from brew_bundle
./macforge setup --until apply_dotfiles
./macforge setup --reset-state
```

## Compatibility

- `./setup.sh` still works and forwards to `./macforge setup`.

## Shell loader

Add this to your `.zshrc`:

```zsh
LOAD_ROOT="$HOME/Projects/macforge/osx-conf"
. ${LOAD_ROOT}/load
```
