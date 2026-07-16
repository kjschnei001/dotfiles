#!/usr/bin/env bash
# PreToolUse (Bash) guard: block `gh pr create` unless it opens a draft PR.
# Enforces ~/.claude/rules/pull-requests.md.
#
# Fails open: if the command isn't a `gh pr create` invocation, jq is missing,
# or parsing fails, the command is allowed (exit 0). A bug here can never wedge
# unrelated Bash commands — worst case the guard just doesn't enforce.

input=$(cat)

# Fast path: most commands never mention creating a PR — skip jq entirely.
grep -q 'pr create' <<<"$input" || exit 0

# Accurate parse requires jq; without it, fail open (no enforcement).
command -v jq >/dev/null 2>&1 || exit 0
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null <<<"$input") || exit 0

# `gh pr create` only counts as an invocation at command position: start of the
# string or right after a shell separator ( | & ; ( ). This deliberately does
# NOT match `gh pr create` sitting inside a quoted argument such as a commit
# message or an echo string.
grep -Eq '(^|[|&;(])[[:space:]]*gh[[:space:]]+pr[[:space:]]+create' <<<"$cmd" || exit 0

# A draft flag (--draft or -d) satisfies the rule.
grep -Eq '(^|[[:space:]])(--draft|-d)([[:space:]"=]|$)' <<<"$cmd" && exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Per the pull-requests rule, open PRs as drafts. Add --draft to `gh pr create` and re-run. Only create a ready-for-review PR if the user explicitly asked for one."
  }
}
JSON
exit 0
