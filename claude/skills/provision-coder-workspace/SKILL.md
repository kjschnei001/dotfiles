---
name: provision-coder-workspace
description: Provision a new Coder workspace from a template, print the exact fields to add it as an Orca SSH host (Orca has no CLI for that step), then wire up an Orca project setup for it — a single-checkout, no extra git worktree, since isolation comes from the separate Coder workspace. The workspace name is entered once and mirrored as the Orca host label and project-setup display name. Use when the user wants to spin up a new remote Coder dev workspace and get it connected in Orca; also covers tearing one down via the companion decommission script.
argument-hint: <workspace-name> --template <coder-template> [--project <orca-project-id> --path <remote-path>] [--agent <name>] [--coder-arg key=value ...] — then add the host in Orca's GUI using the printed fields, then re-run with --setup-only
allowed-tools: Bash
disable-model-invocation: true  # provisions real billed cloud infra — must only run when explicitly invoked, never auto-triggered
user-invocable: true
---

# Provision Coder Workspace

Create a Coder workspace and connect it in Orca, with the workspace name typed once and
mirrored everywhere: the Coder workspace name, the Orca host label, and the Orca
project-setup display name.

## Why this is a two-step, partly-manual flow

Orca has no CLI command to add an SSH host — its own `orca project setup-existing-folder --help`
says SSH targets are GUI-only because the desktop client owns SSH connections. An earlier version
of this skill worked around that by writing directly into Orca's internal
`orca-data.json`. **Don't do that** — a live test proved two things: Orca doesn't hot-reload that
file while running (a host added this way stayed invisible for 100+ seconds and even after
focusing the app), and the only fix, quitting Orca, pops a "close this terminal with a running
process?" confirmation for every open terminal across every worktree, which would interrupt every
active session. Adding the host through the GUI instead is not just safer — it's also simpler and
just as fast: a real test confirmed the GUI-added host connects immediately, no restart needed at
all.

So: `provision.sh` creates the Coder workspace and then prints the exact fields for Orca's
"Add SSH host" dialog and stops. You add the host by hand. Then `provision.sh --setup-only`
finishes the Orca project setup, which is a real API call and works immediately once the host
shows connected.

The "no worktree, just the default path" behavior needs no special flag: an Orca project *setup*
(`orca project setup-existing-folder`) always registers a single main-worktree checkout at
exactly the path you give it — confirmed live (`isMainWorktree: true`, nothing else). Extra git
worktrees only get created if something separately runs `orca worktree create` — this skill never
does.

## Local defaults (optional)

Org-specific values (template name, default Orca project id, default remote checkout path)
aren't hardcoded here, since this dotfiles repo is public. Create a local, gitignored file at
`~/.config/provision-coder-workspace/defaults.env` to avoid retyping them:

```bash
DEFAULT_TEMPLATE=your-template-name
DEFAULT_PROJECT=github:owner/repo   # an existing `orca project list --json` id
DEFAULT_PATH=/home/dev/repo         # where that repo is already checked out in the workspace
```

Without this file, pass `--template` explicitly every time, and pass `--project`/`--path` if you
want a project wired up (omit both to just create the workspace and print the host fields, with
no project setup).

## How to provision

```bash
# Step 1: create the workspace; prints the Orca "Add SSH host" fields and stops
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/provision-coder-workspace/scripts/provision.sh" \
  "<workspace-name>" [--template <name>] [--agent <name>] [--owner <name>] [--preset <name>] \
  [--project <orca-project-id>] [--path <remote-path>] [--coder-arg key=value ...]

# ... add the printed Label/Host/Port/Username in Orca's GUI ...

# Step 2: finish the Orca project setup now that the host is connected
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/provision-coder-workspace/scripts/provision.sh" \
  "<workspace-name>" --setup-only [--project <orca-project-id>] [--path <remote-path>]
```

Run without backgrounding and with a generous timeout (workspace builds and first-agent-connect
can take a few minutes) — the script has its own bounded internal wait for the agent, but the
call needs to run to completion to report a real result. Watch for very verbose `coder
create`/`coder delete` Terraform output: the scripts redirect it to a temp file and print a short
tail rather than streaming it, specifically because streaming it once overran output capture and
killed the script mid-build with SIGPIPE (the server-side build kept going regardless — check
`coder list` if that ever happens rather than assuming the workspace wasn't created).

Step 1 does, in order: check Orca doesn't already have a host with this name; `coder create` the
workspace; wait for the target agent (`dev` by default) to actually be reachable over SSH;
compute the SSH alias as `<agent>.<workspace-name>.<owner>.coder` (owner defaults to `coder
whoami`); print the fields.

Step 2 (`--setup-only`) checks the host exists and shows `connected: true`, then runs `orca
project setup-existing-folder` and, separately, `orca worktree set --display-name` to rename and
pin the resulting worktree card to the workspace name — `setup-existing-folder`'s own
`--display-name` only names the setup/repo, not the worktree card itself (confirmed live: without
this extra step the card comes out named after the branch, e.g. "master", in Orca's "automatic"
naming mode; your existing hosts have it manually renamed and pinned, which is what this
reproduces). It then prints the resulting setup and worktree entries for you to eyeball
(confirmed live: `setup.id`, `repo.id`, and the setup's `repoId` are always the same value for
this setup method — the script relies on that for both the rename and the worktree selector).

**Known limitation:** the `dev` agent-name assumption is specific to templates shaped like the
one this was built against. A template whose SSH-relevant agent has a different name (for
example, one named `main` instead of `dev`) needs `--agent main` passed explicitly — the alias
math changes accordingly.

## How to decommission

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/provision-coder-workspace/scripts/decommission.sh" \
  "<workspace-name>" [--delete-workspace]
```

Deletes the Orca project setup (if any) via the real API. There's still no CLI to remove an SSH
host, so the script prints the host's id and tells you to remove it via the GUI — it never
touches `orca-data.json`. Only deletes the actual Coder workspace when `--delete-workspace` is
passed explicitly, since that step is genuinely destructive and billed.
