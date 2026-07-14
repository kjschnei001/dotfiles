#!/usr/bin/env bash
# Apply personal Claude Code resources into the Claude config dir.
# Idempotent and safe to re-run. Invoked by rdev_dotfiles/kschneider/install.sh,
# but also runnable by hand: `bash /opt/persistent/dotfiles/install.sh`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CONFIG_DIR/skills" "$CONFIG_DIR/commands" "$CONFIG_DIR/hooks"

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

# settings.json: link only if the container doesn't already have one (no clobber).
if [ -f "$ROOT/claude/settings.json" ] && [ ! -e "$CONFIG_DIR/settings.json" ]; then
  ln -sfn "$ROOT/claude/settings.json" "$CONFIG_DIR/settings.json"
fi

echo "kschneider dotfiles applied to $CONFIG_DIR"
