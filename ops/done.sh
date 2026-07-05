#!/usr/bin/env bash
#
# done.sh — End-of-session sync: validate everything, then commit + pull +
# push. The validation gate is the point: broken conventions stop at your
# machine instead of syncing to the whole team.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

"${SCRIPT_DIR}/validate.sh" || die "validation failed — fix the errors above, then rerun 'tos done'"

AGENT_TAG="${TEAMOS_AGENT:--}"

RC=0
commit_pull_push "[work][agent:${AGENT_TAG}] session sync" || RC=$?

if [[ "${RC}" -eq 0 ]]; then
  ok "session synced. See you next time."
elif [[ "${RC}" -eq 2 ]]; then
  err "the commit was blocked, so nothing synced — fix what the hook flagged above."
  exit 1
else
  err "validated and committed, but the pull/push needs attention."
  echo "  Run 'tos sync' for the manual-resolution recipe." >&2
  exit 1
fi
