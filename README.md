# macforge

Personal macOS bootstrap + dotfiles + shell tooling in one place.

## One command setup

```bash
cd "$HOME/Projects/macforge"
./macforge setup
```

That command orchestrates all phases, saves progress, and can pause between phases.

## Setup behavior

- Runs in phases (`xcode_clt`, `homebrew`, `stow`, `backup`, `migrate_legacy`, `apply_dotfiles`, `shell_loader`, `brew_bundle`, `macos_defaults`, `iterm2`).
- Saves state at `~/.local/state/macforge/setup.state`.
- If interrupted, re-run the same command to resume.
- Prompts before moving to the next phase (use `--yes` for non-interactive mode).

## Useful commands

```bash
./macforge help
./macforge phases
./macforge doctor
./macforge hooks
./macforge setup --yes
./macforge setup --from brew_bundle
./macforge setup --until apply_dotfiles
./macforge setup --reset-state
./macforge setup --with-optional-brew
```

## Brewfile split

- `osx-conf/Brewfile`: core baseline tools.
- `osx-conf/Brewfile.optional`: optional/legacy tools.
- Optional tools are installed only with `--with-optional-brew` (or `MACFORGE_INSTALL_OPTIONAL_BREW=1`).

## Shell loader

`./macforge setup` auto-adds and maintains the loader block in `~/.zshrc`.

If you want to target a different file:

```bash
ZSHRC_PATH="$HOME/.zshrc.local" ./macforge setup --from shell_loader --until shell_loader
```

## Optional shell modules

Aliases for stack-specific tools (for example `terraform`, `flutter`, `exercism`, `minikube`, `gigalixir`) live in `osx-conf/optional` and only load when their command exists.

## Secrets

Keep secrets out of git and out of plaintext shell exports:

```bash
mkdir -p "$HOME/.config/macforge"
touch "$HOME/.config/macforge/secrets.zsh"
chmod 600 "$HOME/.config/macforge/secrets.zsh"
```

Then place private exports in that file (for example API keys).

## Security hook

Install a pre-push hook that runs `gitleaks`:

```bash
./macforge hooks
```

The hook blocks push if potential secrets are detected in the outgoing commit range.
