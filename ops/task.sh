#!/usr/bin/env bash
#
# task.sh — Create a task file in an agent's inbox.
#
# Usage:
#   ops/task.sh --title "Review the Q3 draft" --to bob [options]
#
# Options:
#   --title <text>        (required) one-line imperative title
#   --to <member|agent>   recipient — member id or agent name (default: your own agent)
#   --priority <p>        low | normal | high | urgent   (default: normal)
#   --due <ISO-8601>      optional due date
#   --description <text>  optional body text
#   --tags <a,b,c>        optional comma-separated tags
#   --requester <id>      defaults to this machine's member id
#
# IDs are scan-based (see platform/conventions/task-id.md): highest existing
# NNNN for today's UTC date across all agents' task folders, plus one. No
# counter file, nothing to merge-conflict.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

TITLE=""
TO=""
PRIORITY="normal"
DUE=""
DESCRIPTION=""
TAGS=""
REQUESTER="${TEAMOS_MEMBER:-}"

usage() { sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)       TITLE="${2:-}"; shift 2 ;;
    --to)          TO="${2:-}"; shift 2 ;;
    --priority)    PRIORITY="${2:-}"; shift 2 ;;
    --due)         DUE="${2:-}"; shift 2 ;;
    --description) DESCRIPTION="${2:-}"; shift 2 ;;
    --tags)        TAGS="${2:-}"; shift 2 ;;
    --requester)   REQUESTER="${2:-}"; shift 2 ;;
    -h|--help)     usage ;;
    *)             die "unknown flag: $1 (see ops/task.sh --help)" ;;
  esac
done

[[ -n "${TITLE}" ]] || { err "--title is required"; usage; }

case "${PRIORITY}" in
  low|normal|high|urgent) : ;;
  *) die "--priority must be low|normal|high|urgent (got '${PRIORITY}')" ;;
esac

# Resolve the recipient to an agent directory. --to accepts an agent name or
# a member id; default is this machine's own agent.
if [[ -z "${TO}" ]]; then
  require_identity
  AGENT="${TEAMOS_AGENT}"
elif [[ -d "agents/${TO}" && "${TO}" != "_template" ]]; then
  AGENT="${TO}"
else
  AGENT="$(member_agent "${TO}")"
  [[ -n "${AGENT}" ]] || die "no agent or member named '${TO}' (check team/team.md)"
  [[ -d "agents/${AGENT}" ]] || die "member '${TO}' maps to agents/${AGENT}/ which does not exist"
fi

[[ -n "${REQUESTER}" ]] || REQUESTER="unknown"

# Scan-based ID allocation.
TODAY="$(date -u +%Y%m%d)"
MAX=0
for tf in agents/*/tasks/inbox/T-"${TODAY}"-*.md \
          agents/*/tasks/active/T-"${TODAY}"-*.md \
          agents/*/tasks/done/T-"${TODAY}"-*.md; do
  [[ -e "${tf}" ]] || continue
  n="$(basename "${tf}" .md)"
  n="${n##*-}"
  # Strip leading zeros to avoid octal interpretation.
  n="$((10#${n}))"
  [[ "${n}" -gt "${MAX}" ]] && MAX="${n}"
done
NEXT="$(printf '%04d' "$((MAX + 1))")"
ID="T-${TODAY}-${NEXT}"

DEST="agents/${AGENT}/tasks/inbox/${ID}.md"
[[ ! -e "${DEST}" ]] || die "collision at ${DEST} — pull latest and retry"

NOW="$(now_utc)"

{
  echo "---"
  echo "id: ${ID}"
  echo "title: ${TITLE}"
  echo "requester: ${REQUESTER}"
  echo "assigned_to: ${AGENT}"
  echo "status: inbox"
  echo "priority: ${PRIORITY}"
  echo "created_at: ${NOW}"
  echo "updated_at: ${NOW}"
  if [[ -n "${DUE}" ]]; then
    echo "due_at: ${DUE}"
  fi
  if [[ -n "${TAGS}" ]]; then
    echo "tags: [$(printf '%s' "${TAGS}" | sed 's/,/, /g')]"
  fi
  echo "hop_count: 0"
  echo "---"
  echo
  echo "## Description"
  if [[ -n "${DESCRIPTION}" ]]; then
    echo "${DESCRIPTION}"
  else
    echo "<fill in>"
  fi
  echo
  echo "## Acceptance Criteria"
  echo "- [ ] <fill in>"
  echo
  echo "## Notes"
  echo
  echo "## Activity"
  echo "- ${NOW}  ${REQUESTER}  created via task.sh"
} > "${DEST}"

ok "created ${DEST}"
if [[ "${AGENT}" != "${TEAMOS_AGENT:-}" ]]; then
  echo "  -> assigned to ${AGENT}. Run 'tos sync' so it reaches them on their next pull."
fi
