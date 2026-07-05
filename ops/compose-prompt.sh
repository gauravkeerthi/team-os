#!/usr/bin/env bash
#
# compose-prompt.sh — Build an agent's effective system prompt on stdout.
#
# Usage:
#   ops/compose-prompt.sh [agent-name] [--tier <pro|max-5x|max-20x>]
#
# Defaults: the agent bound to this machine (identity file), and the tier
# from that member's team.md block. This script calls no LLM — pipe its
# output into `claude` (launch.sh does) or inspect it directly:
#
#   ops/compose-prompt.sh ajax > /tmp/prompt.md
#
# Composition order (mirrors the list in platform/base-system-prompt.md):
#   session info -> base prompt -> tier doctrine -> soul -> profile ->
#   team roster -> memory (context, routines, recent lessons/decisions) ->
#   active tasks (full) -> inbox (one-line summaries) -> due cadence items

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

NAME=""
TIER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier) TIER="${2:-}"; shift 2 ;;
    -h|--help) sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *)  NAME="$1"; shift ;;
  esac
done

[[ -n "${NAME}" ]] || NAME="${TEAMOS_AGENT:-}"
[[ -n "${NAME}" ]] || die "no agent: pass one (compose-prompt.sh <agent>) or run ops/onboard.sh first"

AGENT_DIR="agents/${NAME}"
[[ -d "${AGENT_DIR}" ]] || die "no agent at ${AGENT_DIR}"

for f in soul.md profile.md memory/context.md memory/routines.md \
         memory/lessons.md memory/decisions.md logs/activity.log.md; do
  [[ -f "${AGENT_DIR}/${f}" ]] || die "missing required file: ${AGENT_DIR}/${f}"
done

MEMBER="$(agent_member "${NAME}")"
if [[ -z "${TIER}" && -n "${MEMBER}" ]]; then
  TIER="$(team_member_field "${MEMBER}" plan)"
fi
[[ -n "${TIER}" ]] || TIER="pro"

MEM_LINES="$(tier_memory_lines "${TIER}")"

{
  echo "# ===== SESSION INFO ====="
  echo "Session started: $(date -u '+%Y-%m-%dT%H:%M:%SZ') UTC"
  echo "Local time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Day of week: $(date '+%A')"
  echo "Team timezone: $(team_setting timezone)"
  echo
  echo "For the current time during a long session, read agents/${NAME}/.heartbeat"
  echo "— the background sync refreshes it hourly. Do not guess the date or time."
  echo
  echo "# ===== BASE SYSTEM PROMPT ====="
  cat "platform/base-system-prompt.md"
  echo
  echo "# ===== PLAN TIER (${TIER}) ====="
  if [[ -f "platform/tiers/${TIER}.md" ]]; then
    cat "platform/tiers/${TIER}.md"
  else
    echo "(no tier file for '${TIER}' — apply the strictest defaults from Section 12)"
  fi
  echo
  echo "# ===== SOUL ====="
  cat "${AGENT_DIR}/soul.md"
  echo
  echo "# ===== PROFILE ====="
  cat "${AGENT_DIR}/profile.md"
  echo
  echo "# ===== TEAM ROSTER ====="
  echo "Team: $(team_setting team)"
  any_member=0
  for m in $(team_members); do
    any_member=1
    m_name="$(team_member_field "${m}" name)"
    m_agent="$(team_member_field "${m}" agent)"
    m_role="$(team_member_field "${m}" role)"
    marker=""
    [[ "${m_agent}" == "${NAME}" ]] && marker="   <-- this is you and your human"
    printf -- '- %s (member: %s, %s) — agent: %s%s\n' \
      "${m_name}" "${m}" "${m_role}" "${m_agent}" "${marker}"
  done
  [[ "${any_member}" -eq 1 ]] || echo "(no members configured yet)"
  echo
  echo "# ===== MEMORY: CONTEXT ====="
  cat "${AGENT_DIR}/memory/context.md"
  echo
  echo "# ===== MEMORY: ROUTINES ====="
  cat "${AGENT_DIR}/memory/routines.md"
  echo
  echo "# ===== MEMORY: RECENT LESSONS (newest first, head -${MEM_LINES}) ====="
  head -n "${MEM_LINES}" "${AGENT_DIR}/memory/lessons.md"
  echo
  echo "# ===== MEMORY: RECENT DECISIONS (newest first, head -${MEM_LINES}) ====="
  head -n "${MEM_LINES}" "${AGENT_DIR}/memory/decisions.md"
  echo
  echo "# ===== ACTIVE TASKS ====="
  any=0
  for t in "${AGENT_DIR}"/tasks/active/*.md; do
    [[ -e "${t}" ]] || continue
    any=1
    echo "## $(basename "${t}")"
    cat "${t}"
    echo
  done
  [[ "${any}" -eq 1 ]] || echo "(no active tasks)"
  echo
  echo "# ===== INBOX (pending — summaries only, read the full file on pickup) ====="
  any=0
  for t in "${AGENT_DIR}"/tasks/inbox/*.md; do
    [[ -e "${t}" ]] || continue
    any=1
    _id="$(md_frontmatter_field "${t}" id)"
    _title="$(md_frontmatter_field "${t}" title)"
    _req="$(md_frontmatter_field "${t}" requester)"
    _pri="$(md_frontmatter_field "${t}" priority)"
    _due="$(md_frontmatter_field "${t}" due_at)"
    printf -- '- **%s** — %s' "${_id:-$(basename "${t}" .md)}" "${_title:-untitled}"
    [[ -n "${_req}" ]] && printf ' — from %s' "${_req}"
    [[ -n "${_pri}" ]] && printf ' [%s]' "${_pri}"
    [[ -n "${_due}" ]] && printf ' — due %s' "${_due}"
    echo
  done
  [[ "${any}" -eq 1 ]] || echo "(inbox empty)"

  if [[ -n "${MEMBER}" ]]; then
    DUE="$("${SCRIPT_DIR}/cadence-due.sh" --for "${MEMBER}")"
    if [[ -n "${DUE}" ]]; then
      echo
      echo "# ===== TEAM CADENCE (due now) ====="
      echo "Offer these to your human — never auto-run them (base prompt §15):"
      printf '%s\n' "${DUE}"
    fi
  fi
}
