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

# settings.json: link only if the container doesn't already have one (no clobber).
if [ -f "$ROOT/claude/settings.json" ] && [ ! -e "$CONFIG_DIR/settings.json" ]; then
  ln -sfn "$ROOT/claude/settings.json" "$CONFIG_DIR/settings.json"
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
