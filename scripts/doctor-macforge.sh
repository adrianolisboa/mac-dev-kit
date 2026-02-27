#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/config/macforge.sh"

ZSHRC_PATH="${ZSHRC_PATH:-$HOME/.zshrc}"
LOAD_ROOT_PATH="$REPO_ROOT/osx-conf"
SHELL_LOADER_MARKER_BEGIN="# >>> macforge shell loader >>>"
SHELL_LOADER_MARKER_END="# <<< macforge shell loader <<<"
SECRETS_FILE="${HOME}/.config/macforge/secrets.zsh"

FAILURES=0
WARNINGS=0

pass() {
  printf 'PASS  %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf 'WARN  %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL  %s\n' "$1"
}

managed_source_path() {
  local file="$1"
  case "$file" in
    .gitconfig) printf '%s\n' "$REPO_ROOT/git/.gitconfig" ;;
    .gitconfig-personal) printf '%s\n' "$REPO_ROOT/git/.gitconfig-personal" ;;
    .gitconfig-professional) printf '%s\n' "$REPO_ROOT/git/.gitconfig-professional" ;;
    .gitignore) printf '%s\n' "$REPO_ROOT/git/.gitignore" ;;
    .bashrc) printf '%s\n' "$REPO_ROOT/bash/.bashrc" ;;
    .inputrc) printf '%s\n' "$REPO_ROOT/input/.inputrc" ;;
    .tmux.conf) printf '%s\n' "$REPO_ROOT/tmux/.tmux.conf" ;;
    *) return 1 ;;
  esac
}

resolve_abs_file() {
  local path="$1"
  printf '%s/%s\n' "$(CDPATH= cd "$(dirname "$path")" && pwd -P)" "$(basename "$path")"
}

resolve_link_target_abs() {
  local link_path="$1"
  local raw_target
  raw_target="$(readlink "$link_path")"
  if [[ "$raw_target" == /* ]]; then
    printf '%s\n' "$raw_target"
  else
    printf '%s/%s\n' "$(CDPATH= cd "$(dirname "$link_path")" && CDPATH= cd "$(dirname "$raw_target")" && pwd -P)" "$(basename "$raw_target")"
  fi
}

check_loader_block() {
  if [[ ! -f "$ZSHRC_PATH" ]]; then
    fail "$ZSHRC_PATH does not exist."
    return
  fi

  if grep -Fxq "$SHELL_LOADER_MARKER_BEGIN" "$ZSHRC_PATH" &&
    grep -Fxq "$SHELL_LOADER_MARKER_END" "$ZSHRC_PATH" &&
    grep -Fq "LOAD_ROOT=\"$LOAD_ROOT_PATH\"" "$ZSHRC_PATH"; then
    pass "macforge loader block is present in $ZSHRC_PATH."
  else
    fail "macforge loader block missing or outdated in $ZSHRC_PATH. Run './macforge setup --from shell_loader --until shell_loader'."
  fi
}

check_resolvable_tools() {
  if zsh -lc "LOAD_ROOT=\"$LOAD_ROOT_PATH\"; source \"$LOAD_ROOT_PATH/load\"; command -v safe_sudo >/dev/null && command -v git-share >/dev/null"; then
    pass "safe_sudo and git-share resolve after loading macforge shell config."
  else
    fail "safe_sudo/git-share are not resolvable after loading macforge shell config."
  fi
}

check_alias_duplicates() {
  local dupes
  dupes="$(
    awk -F'[ =]+' '/^alias[[:space:]]+[A-Za-z0-9_.-]+=/ {print $2}' \
      "$REPO_ROOT"/osx-conf/aliases/*.aliases \
      "$REPO_ROOT"/osx-conf/optional/*.zsh 2>/dev/null | \
      sort | uniq -d
  )"

  if [[ -n "$dupes" ]]; then
    fail "Duplicate aliases found: $(echo "$dupes" | tr '\n' ' ')."
  else
    pass "No duplicate alias keys detected."
  fi
}

check_optional_modules() {
  local module_file req_cmd sample_alias
  local loaded
  local status_ok=1

  while IFS= read -r module_file; do
    req_cmd="$(awk -F': *' '/^# macforge-requires:/ {print $2; exit}' "$module_file")"
    sample_alias="$(awk -F'[ =]+' '/^alias[[:space:]]+[A-Za-z0-9_.-]+=/ {print $2; exit}' "$module_file")"
    [[ -n "$req_cmd" && -n "$sample_alias" ]] || continue

    loaded=0
    if zsh -lc "LOAD_ROOT=\"$LOAD_ROOT_PATH\"; source \"$LOAD_ROOT_PATH/load\"; alias $sample_alias >/dev/null 2>&1"; then
      loaded=1
    fi

    if command -v "$req_cmd" >/dev/null 2>&1; then
      if (( loaded == 1 )); then
        pass "Optional module $(basename "$module_file") loads when '$req_cmd' is installed."
      else
        fail "Optional module $(basename "$module_file") did not load even though '$req_cmd' exists."
        status_ok=0
      fi
    else
      if (( loaded == 0 )); then
        pass "Optional module $(basename "$module_file") is skipped when '$req_cmd' is missing."
      else
        fail "Optional module $(basename "$module_file") loaded even though '$req_cmd' is missing."
        status_ok=0
      fi
    fi
  done < <(find "$REPO_ROOT/osx-conf/optional" -maxdepth 1 -type f | LC_ALL=C sort)

  if (( status_ok == 1 )); then
    pass "Optional module command gates are healthy."
  fi
}

check_iterm_path() {
  local expected current
  expected="$REPO_ROOT/osx-conf/iterm2"
  current="$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true)"

  if [[ "$current" == "$expected" ]]; then
    pass "iTerm2 PrefsCustomFolder points to macforge."
  else
    fail "iTerm2 PrefsCustomFolder mismatch: expected '$expected', got '${current:-<unset>}'."
  fi
}

check_stale_symlinks() {
  local file target source source_abs current_abs
  local stale=0

  for file in "${MANAGED_FILES[@]}"; do
    target="$HOME/$file"
    source="$(managed_source_path "$file" || true)"
    [[ -n "$source" && -e "$source" ]] || continue
    source_abs="$(resolve_abs_file "$source")"

    if [[ -L "$target" ]]; then
      current_abs="$(resolve_link_target_abs "$target")"
      if [[ "$current_abs" != "$source_abs" ]]; then
        stale=1
        fail "Stale symlink: $target -> $current_abs (expected $source_abs)."
      fi
    fi
  done

  if (( stale == 0 )); then
    pass "No stale managed symlinks detected."
  fi
}

check_secrets_hygiene() {
  if [[ -f "$ZSHRC_PATH" ]] && grep -Eq '^[[:space:]]*export[[:space:]]+OPENAI_API_KEY=' "$ZSHRC_PATH"; then
    fail "Plaintext OPENAI_API_KEY export found in $ZSHRC_PATH."
  else
    pass "No plaintext OPENAI_API_KEY export in $ZSHRC_PATH."
  fi

  if [[ -f "$ZSHRC_PATH" ]] && grep -Eq '^[[:space:]]*export[[:space:]]+CLAUDE_CODE_ACCEPT_DANGEROUS=1' "$ZSHRC_PATH"; then
    fail "CLAUDE_CODE_ACCEPT_DANGEROUS=1 is set globally in $ZSHRC_PATH."
  else
    pass "No global CLAUDE_CODE_ACCEPT_DANGEROUS=1 export in $ZSHRC_PATH."
  fi

  if [[ -f "$SECRETS_FILE" ]]; then
    local perms
    perms="$(stat -f '%OLp' "$SECRETS_FILE")"
    if [[ "$perms" != "600" ]]; then
      fail "$SECRETS_FILE permissions are $perms (expected 600)."
    else
      pass "$SECRETS_FILE permissions are 600."
    fi
  else
    warn "$SECRETS_FILE not found (optional)."
  fi
}

main() {
  echo "macforge doctor"
  echo "Repo: $REPO_ROOT"
  echo

  check_loader_block
  check_resolvable_tools
  check_alias_duplicates
  check_optional_modules
  check_iterm_path
  check_stale_symlinks
  check_secrets_hygiene

  echo
  echo "Summary: $FAILURES failure(s), $WARNINGS warning(s)"
  if (( FAILURES > 0 )); then
    exit 1
  fi
}

main "$@"
