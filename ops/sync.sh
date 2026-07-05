#!/usr/bin/env bash
#
# sync.sh — Mid-session sync: commit everything, pull safely, push.
# Safe to run at any time; agents may run it (pre-approved) after filing
# tasks or claiming cadence items so the change actually reaches the team.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

AGENT_TAG="${TEAMOS_AGENT:--}"

RC=0
commit_pull_push "[sync][agent:${AGENT_TAG}] manual sync" || RC=$?

if [[ "${RC}" -eq 0 ]]; then
  ok "synced"
elif [[ "${RC}" -eq 2 ]]; then
  err "the commit was blocked, so nothing synced."
  echo "  Fix what the pre-commit hook flagged above. If the platform change is" >&2
  echo "  intentional (maintainers only): TEAMOS_ALLOW_PLATFORM_EDIT=1 tos sync" >&2
  exit 1
else
  err "sync did not complete cleanly."
  cat >&2 <<'RECIPE'

  The pull hit a conflict (it was safely aborted — your commits are intact
  locally). To resolve by hand:

    1. git pull --rebase          # re-attempt; git will stop at the conflict
    2. edit the conflicted file(s) shown by: git status
    3. git add <each resolved file>
    4. git rebase --continue
    5. tos sync                   # push the result

  Stuck? Ask a maintainer — do NOT use git reset --hard or force-push.
RECIPE
  exit 1
fi
