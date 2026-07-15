#!/usr/bin/env bash
# Apply personal dotfiles: Claude Code resources into the Claude config dir,
# plus zsh + oh-my-zsh and a shared .zshrc.
# Idempotent and safe to re-run. Invoked by rdev_dotfiles/kschneider/install.sh,
# but also runnable by hand: `bash /opt/persistent/dotfiles/install.sh`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CONFIG_DIR/skills" "$CONFIG_DIR/commands" "$CONFIG_DIR/hooks" "$CONFIG_DIR/rules"

# Per-item symlinks: personal resources coexist with plugin/base-image ones,
# and edits in this repo take effect without re-running.
link_items() { # <src_dir> <dest_dir>
  local src="$1" dest="$2"
  [ -d "$src" ] || return 0
  shopt -s nullglob
  local item
  for item in "$src"/*; do
    ln -sfn "$item" "$dest/$(basename "$item")"
  done
  shopt -u nullglob
}

link_items "$ROOT/claude/skills" "$CONFIG_DIR/skills"
link_items "$ROOT/claude/commands" "$CONFIG_DIR/commands"
link_items "$ROOT/claude/hooks" "$CONFIG_DIR/hooks"
link_items "$ROOT/claude/rules" "$CONFIG_DIR/rules"

# settings.json: rdev (and other setups) already ship a settings.json with plugins and
# hooks, so don't clobber it — merge ours in. Union our permissions (allow/deny) and fill
# our prefs (model/effort/theme/skipAutoPermissionPrompt) only where unset, preserving
# their plugins/hooks/marketplaces. Idempotent: re-running only unions. Falls back to a
# no-clobber copy when there's nothing there, or a link if jq is unavailable.
REPO_SETTINGS="$ROOT/claude/settings.json"
DEST_SETTINGS="$CONFIG_DIR/settings.json"
if [ -f "$REPO_SETTINGS" ]; then
  if [ -f "$DEST_SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp "${DEST_SETTINGS}.XXXXXX")"
    if jq -s '
        .[0] as $e | .[1] as $o | $e
        | .permissions = (($e.permissions // {}) * {
            allow: (($e.permissions.allow // []) + (($o.permissions.allow // []) - ($e.permissions.allow // []))),
            deny:  (($e.permissions.deny  // []) + (($o.permissions.deny  // []) - ($e.permissions.deny  // [])))
          })
        | .model = ($e.model // $o.model)
        | .effortLevel = ($e.effortLevel // $o.effortLevel)
        | .theme = ($e.theme // $o.theme)
        | .skipAutoPermissionPrompt = ($e.skipAutoPermissionPrompt // $o.skipAutoPermissionPrompt)
      ' "$DEST_SETTINGS" "$REPO_SETTINGS" > "$tmp" && [ -s "$tmp" ]; then
      chmod 644 "$tmp"
      mv "$tmp" "$DEST_SETTINGS"
      echo "merged settings.json into $DEST_SETTINGS"
    else
      rm -f "$tmp"
      echo "settings.json merge failed; left existing file untouched" >&2
    fi
  elif [ ! -e "$DEST_SETTINGS" ]; then
    cp "$REPO_SETTINGS" "$DEST_SETTINGS"
    echo "installed settings.json at $DEST_SETTINGS"
  fi
fi

echo "kschneider Claude Code dotfiles applied to $CONFIG_DIR"

# ---------------------------------------------------------------------------
# zsh + oh-my-zsh + shared .zshrc
# Best-effort and idempotent. Real secrets live in ~/.zshrc.local (gitignored),
# which the tracked zsh/zshrc sources if present — never committed here.
# ---------------------------------------------------------------------------

# Install zsh if it isn't already available.
if ! command -v zsh >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y zsh
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y zsh
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y zsh
  elif command -v apk >/dev/null 2>&1; then
    sudo apk add zsh
  elif command -v brew >/dev/null 2>&1; then
    brew install zsh
  else
    echo "zsh missing and no known package manager found; skipping zsh install" >&2
  fi
fi

# Install oh-my-zsh if missing. --unattended + these env vars stop the installer
# from overwriting .zshrc, running chsh, or launching a nested zsh.
if [ ! -d "$HOME/.oh-my-zsh" ] && command -v curl >/dev/null 2>&1; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    || echo "oh-my-zsh install failed; continuing" >&2
fi

# Link the tracked .zshrc, backing up any pre-existing real file once.
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.pre-dotfiles.bak"
  echo "backed up existing ~/.zshrc -> ~/.zshrc.pre-dotfiles.bak"
fi
ln -sfn "$ROOT/zsh/zshrc" "$HOME/.zshrc"

# Make zsh the login shell (best-effort; skip if already zsh).
zsh_path="$(command -v zsh || true)"
if [ -n "$zsh_path" ] && [ "${SHELL:-}" != "$zsh_path" ]; then
  grep -qxF "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
  chsh -s "$zsh_path" 2>/dev/null || echo "could not set default shell; run 'chsh -s $zsh_path' manually" >&2
fi

echo "zsh dotfiles applied (~/.zshrc -> $ROOT/zsh/zshrc)"
