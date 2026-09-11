# Pull requests

Always open pull requests as **drafts** (`gh pr create --draft`). Do not create a ready-for-review PR unless I explicitly ask for one.

Promote a PR to ready-for-review (`gh pr ready`) only when I request it.

After creating a PR, open it in the browser (`gh pr view --web`) so I can look at it right away. Don't use `gh pr create --web` — that opens the creation form instead of the finished PR.

## Updating PR descriptions

When updating an existing PR's description, always fetch the current description first (e.g. `gh pr view --json body`) and base the edit on that live content. Never reconstruct or edit it from conversation memory/context, since it may have been changed since — by someone else, or by an earlier step you don't have full context on.
