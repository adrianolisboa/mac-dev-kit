## Shell Config Loader

The shell loader is added automatically by:

```bash
./macforge setup
```

## Layout

- `aliases/`: always-loaded aliases.
- `common/`: shared shell defaults (`PATH`, prompt, completion, fzf).
- `functions/`: always-loaded shell functions.
- `optional/`: command-gated modules loaded only when the required command exists.
- `bin/`: helper scripts (`safe_sudo`, `git-share`) added to `PATH` by `_path`.

## Full setup

Run from repo root:

```bash
./macforge setup
```

This runs all setup phases, with checkpoints and resume support.
