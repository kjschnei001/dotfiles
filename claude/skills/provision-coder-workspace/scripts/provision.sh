#!/usr/bin/env bash
# Create a Coder workspace and print the exact fields to add it as an Orca SSH host,
# then (once you've added it) wire up an Orca project setup for it.
# See ../SKILL.md for the full explanation of why the host-add step is manual.
set -euo pipefail

DEFAULTS_FILE="$HOME/.config/provision-coder-workspace/defaults.env"
ORCA_BIN="${ORCA_BIN:-orca}"

usage() {
  cat <<'EOF'
Usage: provision.sh <workspace-name> [options]

  --template <name>      Coder template (falls back to DEFAULT_TEMPLATE in
                          ~/.config/provision-coder-workspace/defaults.env)
  --agent <name>         Coder agent to SSH into (default: dev)
  --owner <name>         Owner segment of the SSH alias (default: `coder whoami`)
  --preset <name>        Coder template preset (default: default)
  --project <orca-id>    Orca project id to wire up on the new host
                          (falls back to DEFAULT_PROJECT; omit to skip Orca project setup)
  --path <remote-path>   Remote path of that project's checkout
                          (falls back to DEFAULT_PATH; required if a project is resolved)
  --coder-arg k=v        Extra `--parameter k=v` passed through to `coder create` (repeatable)
  --setup-only           Skip workspace creation entirely; just do the Orca project setup for
                          a host you've already added via the GUI and that now shows as
                          connected. Use this after adding the host with the fields this
                          script printed on its first run.
  -h, --help             Show this help
EOF
}

[ -f "$DEFAULTS_FILE" ] && source "$DEFAULTS_FILE"

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

NAME="$1"
shift

TEMPLATE="${DEFAULT_TEMPLATE:-}"
AGENT="dev"
OWNER=""
PRESET="default"
PROJECT="${DEFAULT_PROJECT:-}"
REMOTE_PATH="${DEFAULT_PATH:-}"
CODER_PARAMS=()
SETUP_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --path) REMOTE_PATH="$2"; shift 2 ;;
    --coder-arg) CODER_PARAMS+=("--parameter" "$2"); shift 2 ;;
    --setup-only) SETUP_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -n "$PROJECT" ] && [ -z "$REMOTE_PATH" ]; then
  echo "error: --path is required when --project is set (or set DEFAULT_PATH in $DEFAULTS_FILE)" >&2
  exit 1
fi
if $SETUP_ONLY && [ -z "$PROJECT" ]; then
  echo "error: --setup-only needs --project (and --path), or DEFAULT_PROJECT/DEFAULT_PATH set" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 1; }

# A plain PATH lookup isn't enough: in some sandboxed shells /usr/local/bin/orca is a
# root-owned symlink that resolves but can't actually be exec'd ("Unable to determine
# Orca.app path from symlink"). Confirm it actually runs before trusting it.
if ! "$ORCA_BIN" host list --json >/dev/null 2>&1; then
  if /Applications/Orca.app/Contents/Resources/bin/orca host list --json >/dev/null 2>&1; then
    ORCA_BIN="/Applications/Orca.app/Contents/Resources/bin/orca"
  else
    echo "error: '$ORCA_BIN' isn't runnable, and the app-bundle fallback isn't either" >&2
    exit 1
  fi
fi

orca_hosts_json() { "$ORCA_BIN" host list --json 2>/dev/null | jq '.result.hosts // []'; }

do_project_setup() {
  local host_id setup_id repo_id
  host_id="$(orca_hosts_json | jq -r --arg n "$NAME" '.[] | select(.name==$n) | .id')"
  if [ -z "$host_id" ]; then
    echo "error: no Orca host named '$NAME' — add it via the GUI first (see the fields from" >&2
    echo "       this script's first run, or re-run without --setup-only to print them again)" >&2
    exit 1
  fi
  if ! orca_hosts_json | jq -e --arg n "$NAME" 'any(.[]?; .name == $n and .connected == true)' >/dev/null; then
    echo "error: Orca host '$NAME' exists but isn't connected yet — check it in the Orca GUI." >&2
    exit 1
  fi

  echo "==> Setting up project '$PROJECT' on host ssh:$host_id at '$REMOTE_PATH'"
  "$ORCA_BIN" project setup-existing-folder --project "$PROJECT" --host "ssh:$host_id" --path "$REMOTE_PATH" --display-name "$NAME" --json

  echo "==> Verifying setup..."
  setup_id="$("$ORCA_BIN" project setups --project "$PROJECT" --json 2>/dev/null | jq -r --arg h "ssh:$host_id" '.result.setups[]? | select(.hostId == $h) | .id')"
  "$ORCA_BIN" project setups --project "$PROJECT" --json | jq --arg h "ssh:$host_id" '.result.setups[]? | select(.hostId == $h)'
  if [ -n "$setup_id" ]; then
    repo_id="$setup_id"  # confirmed live: repoId == setup id for an imported-existing-folder setup
    # --display-name on setup-existing-folder only names the setup/repo, not the worktree
    # card itself (confirmed live: it came out as the branch name, e.g. "master", in
    # "automatic" mode) — your existing hosts have the worktree separately renamed and
    # pinned to the workspace name, so do that here too.
    "$ORCA_BIN" worktree set --worktree "id:${repo_id}::${REMOTE_PATH}" --display-name "$NAME" --json >/dev/null
    "$ORCA_BIN" worktree list --repo "$repo_id" --json | jq --arg h "ssh:$host_id" '.result.worktrees[]? | select(.hostId == $h)'
  fi
}

if $SETUP_ONLY; then
  do_project_setup
  echo "==> Done."
  exit 0
fi

command -v coder >/dev/null 2>&1 || { echo "error: coder CLI not found on PATH" >&2; exit 1; }
[ -n "$TEMPLATE" ] || { echo "error: --template is required (or set DEFAULT_TEMPLATE in $DEFAULTS_FILE)" >&2; exit 1; }

resolve_owner() {
  local out
  if out="$(coder whoami --output json 2>/dev/null)" && jq -e . >/dev/null 2>&1 <<<"$out"; then
    jq -r '(if type == "array" then .[0] else . end) | (.username // .Username // empty)' <<<"$out"
    return
  fi
  coder whoami 2>/dev/null | grep -oE 'authenticated as [^,!]+' | sed -E 's/authenticated as //'
}

if [ -z "$OWNER" ]; then
  OWNER="$(resolve_owner)"
  [ -n "$OWNER" ] || { echo "error: couldn't determine owner from 'coder whoami'; pass --owner explicitly" >&2; exit 1; }
fi

echo "==> Checking Orca doesn't already have a host named '$NAME'..."
if orca_hosts_json | jq -e --arg n "$NAME" 'any(.[]?; .name == $n)' >/dev/null; then
  echo "error: Orca already has a host named '$NAME' — pick a different workspace name" >&2
  exit 1
fi

echo "==> Creating Coder workspace '$NAME' from template '$TEMPLATE' (preset: $PRESET)"
CREATE_LOG="$(mktemp)"
echo "    (full Terraform log: $CREATE_LOG)"
# Redirect straight to a file rather than streaming: the build's Terraform output is huge
# and streaming it can overrun the caller's output capture, killing this process with
# SIGPIPE mid-build even though the build itself keeps going server-side.
# ${arr[@]+...} guards against bash 3.2's "unbound variable" on an empty array under `set -u`
# (macOS ships bash 3.2 by default).
if ! coder create "$NAME" --template "$TEMPLATE" --preset "$PRESET" --use-parameter-defaults -y "${CODER_PARAMS[@]+"${CODER_PARAMS[@]}"}" > "$CREATE_LOG" 2>&1; then
  echo "error: 'coder create' failed; last 40 lines of $CREATE_LOG:" >&2
  tail -n 40 "$CREATE_LOG" >&2
  exit 1
fi
tail -n 10 "$CREATE_LOG"

wait_for_agent() {
  local name="$1" agent="$2" timeout="${3:-300}" start
  start=$(date +%s)
  echo "==> Waiting for agent '$agent' on workspace '$name' to become reachable..."
  while ! coder ssh "${name}.${agent}" -- true >/dev/null 2>&1; do
    if [ $(( $(date +%s) - start )) -gt "$timeout" ]; then
      echo "error: timed out waiting for agent '$agent' on '$name'" >&2
      return 1
    fi
    sleep 5
  done
}
wait_for_agent "$NAME" "$AGENT" || exit 1

ALIAS="${AGENT}.${NAME}.${OWNER}.coder"

cat <<FIELDS

==> Workspace created. Add it as a new SSH host in Orca (desktop app) with these fields:

    Label:    $NAME
    Host:     $ALIAS
    Port:     22
    Username: $AGENT

    Confirmed live: adding it this way connects immediately, no Orca restart needed.
FIELDS

if [ -n "$PROJECT" ]; then
  cat <<NEXT
    Then finish the Orca project setup with:

        bash "$0" "$NAME" --setup-only --project "$PROJECT" --path "$REMOTE_PATH"
NEXT
else
  echo "    (no --project was given, so there's nothing further to wire up)"
fi

echo
echo "SSH alias for reference: $ALIAS  (try: ssh $ALIAS)"
