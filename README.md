# kschneider dotfiles

Personal [Claude Code](https://claude.com/claude-code) resources, cloned fresh into each rdev container.

## Usage

```
rdev new patreon_py --dotfiles kschneider
```

`Patreon/rdev_dotfiles/kschneider/install.sh` clones this repo on every container
launch and runs `install.sh`, which symlinks `claude/*` into `$CLAUDE_CONFIG_DIR`.
Because it re-clones each time, pushing to `main` here is enough — new containers
pick it up automatically.

## Layout

- `claude/skills/`      — personal, cross-repo skills (repo-specific ones live in that repo's `.ai/skills/`)
- `claude/commands/`    — slash commands
- `claude/hooks/`       — hook scripts referenced from `settings.json`
- `claude/settings.json`— Claude settings (linked only if the container has none)
- `install.sh`          — symlinks the above into `$CLAUDE_CONFIG_DIR`; idempotent

## Notes

- **No memory here.** Auto-memory is intentionally not version-controlled; durable
  guidance goes in a repo's `.ai/rules/*.mdc` instead.
- Symlinks are per-item, so these coexist with plugin- and base-image-provided
  resources, and edits take effect without re-running `install.sh`.
