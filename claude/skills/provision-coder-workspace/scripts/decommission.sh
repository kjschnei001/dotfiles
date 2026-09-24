#!/usr/bin/env bash
# Symmetric cleanup for provision.sh: removes the Orca project setup for a workspace
# (real API call) and tells you the host to remove via Orca's GUI (no CLI for that —
# see ../SKILL.md), and optionally deletes the Coder workspace itself.
set -euo pipefail

ORCA_BIN="${ORCA_BIN:-orca}"

usage() {
  cat <<'EOF'
Usage: decommission.sh <workspace-name> [--delete-workspace]

  --delete-workspace   Also run `coder delete <workspace-name> -y` (destructive, billed
                        infra teardown — omit to only clean up the Orca project setup).
EOF
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

NAME="$1"
shift
DELETE_WORKSPACE=false
for arg in "$@"; do
  case "$arg" in
    --delete-workspace) DELETE_WORKSPACE=true ;;
    *) echo "unknown argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 1; }

# See provision.sh for why a plain PATH lookup isn't sufficient here.
if ! "$ORCA_BIN" host list --json >/dev/null 2>&1; then
  if /Applications/Orca.app/Contents/Resources/bin/orca host list --json >/dev/null 2>&1; then
    ORCA_BIN="/Applications/Orca.app/Contents/Resources/bin/orca"
  else
    echo "error: '$ORCA_BIN' isn't runnable, and the app-bundle fallback isn't either" >&2
    exit 1
  fi
fi

HOST_ID="$("$ORCA_BIN" host list --json 2>/dev/null | jq -r --arg n "$NAME" '.result.hosts[]? | select(.name==$n) | .id')"

if [ -z "$HOST_ID" ]; then
  echo "==> No Orca host named '$NAME' found; nothing to clean up on the Orca side."
else
  SETUP_ID="$("$ORCA_BIN" project setups --host "ssh:$HOST_ID" --json 2>/dev/null | jq -r '.result.setups[0].id // empty')"
  if [ -n "$SETUP_ID" ]; then
    echo "==> Deleting Orca project setup $SETUP_ID"
    "$ORCA_BIN" project setup-delete --setup "$SETUP_ID"
  fi
  echo "==> Orca has no CLI to remove an SSH host — remove '$NAME' (id: $HOST_ID) via the GUI"
  echo "    whenever convenient. This script deliberately doesn't touch orca-data.json directly."
fi

if $DELETE_WORKSPACE; then
  echo "==> Deleting Coder workspace '$NAME' (this can take a minute or two for EC2 teardown)"
  DELETE_LOG="$(mktemp)"
  echo "    (full Terraform log: $DELETE_LOG)"
  # See provision.sh's create step for why this is redirected to a file rather than streamed.
  if ! coder delete "$NAME" -y > "$DELETE_LOG" 2>&1; then
    echo "error: 'coder delete' failed; last 40 lines of $DELETE_LOG:" >&2
    tail -n 40 "$DELETE_LOG" >&2
    exit 1
  fi
  tail -n 5 "$DELETE_LOG"
fi

echo "==> Done."
