# Pull requests

Always open pull requests as **drafts** (`gh pr create --draft`). Do not create a ready-for-review PR unless I explicitly ask for one.

Promote a PR to ready-for-review (`gh pr ready`) only when I request it.

After creating a PR, open it in the browser (`gh pr view --web`) so I can look at it right away. Don't use `gh pr create --web` — that opens the creation form instead of the finished PR.

## Human TL;DR

Before creating a PR, ask me for a short TL;DR in my own words and wait for my answer. Put it at the very top of the PR description, above everything else. Format it to match the rest of the description: use the same heading level and style as the other sections (e.g. `## TL;DR` if the body uses `## Summary`), or a bold `**TL;DR:**` lead-in if the body has no headings. Use my wording as given; fix only obvious typos. If I decline or say to skip it, open the PR without one.

## Updating PR descriptions

When updating an existing PR's description, always fetch the current description first (e.g. `gh pr view --json body`) and base the edit on that live content. Never reconstruct or edit it from conversation memory/context, since it may have been changed since — by someone else, or by an earlier step you don't have full context on.
