# Committing

Before running `git add -A` (or `git add .`), check `git status` for untracked files first. Don't let untracked credentials or secrets (`.env` files, credential JSON, API keys, etc.) get swept into the commit. Stage specific files by name instead when anything untracked looks sensitive.

# Branch names

Never name a branch `claude/...`, `claude-...`, or anything else starting with `claude`. If the repo's convention is to prefix branches with the author's username, use `kschneider/` (matching the repo's separator, e.g. `kschneider/fix-login` or `kschneider-fix-login`). Otherwise, follow the repo's convention, or use a plain descriptive name.
