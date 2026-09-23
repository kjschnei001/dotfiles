# Committing

Before running `git add -A` (or `git add .`), check `git status` for untracked files first. Don't let untracked credentials or secrets (`.env` files, credential JSON, API keys, etc.) get swept into the commit. Stage specific files by name instead when anything untracked looks sensitive.
