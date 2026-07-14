# kschneider dotfiles

Personal [Claude Code](https://claude.com/claude-code) resources and shell (zsh) config, cloned fresh into each rdev container.

## Usage

```
rdev new patreon_py --dotfiles kschneider
```

`Patreon/rdev_dotfiles/kschneider/install.sh` clones this repo on every container
launch and runs `install.sh`, which symlinks `claude/*` into `$CLAUDE_CONFIG_DIR`
and sets up zsh (installs zsh + oh-my-zsh, links `~/.zshrc`, makes zsh the login shell).
Because it re-clones each time, pushing to `main` here is enough — new containers
pick it up automatically.

## Layout

- `claude/skills/`      — personal, cross-repo skills (repo-specific ones live in that repo's `.ai/skills/`)
- `claude/rules/`       — user-level rules auto-loaded into every session (cross-cutting coding conventions)
- `claude/commands/`    — slash commands
- `claude/hooks/`       — hook scripts referenced from `settings.json`
- `claude/settings.json`— Claude settings (linked only if the container has none)
- `zsh/zshrc`            — shared, sanitized `.zshrc`; linked to `~/.zshrc` (existing file backed up to `~/.zshrc.pre-dotfiles.bak`)
- `install.sh`           — symlinks the above and sets up zsh; idempotent

## Notes

- **No secrets here.** This repo is public. Tokens and machine/work-specific shell bits
  live in `~/.zshrc.local` (gitignored, chmod 600), which `zsh/zshrc` sources if present.
  Each machine/container keeps its own; nothing sensitive is committed.
- **No memory here.** Auto-memory is intentionally not version-controlled. Cross-cutting
  conventions that apply everywhere go in `claude/rules/`; repo-specific durable guidance
  goes in that repo's `.ai/rules/*.mdc` instead.
- Symlinks are per-item, so these coexist with plugin- and base-image-provided
  resources, and edits take effect without re-running `install.sh`.
