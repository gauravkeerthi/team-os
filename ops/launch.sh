#!/usr/bin/env bash
#
# launch.sh — Launch your paired agent: pull latest, show what's waiting,
# compose the prompt, start the background sync loop, and hand off to
# `claude` on the model your plan tier calls for.
#
# Usage:
#   ops/launch.sh [--print] [--model <model>] [--no-sync]
#
#   --print     compose and print the prompt, then exit. Needs no claude
#               CLI — debugging and CI use this.
#   --model M   override the session model (precedence: this flag >
#               `model=` in the identity file / TEAMOS_MODEL > plan tier)
#   --no-sync   don't start the hourly background sync loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

PRINT=0
NOSYNC=0
MODEL_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print)   PRINT=1; shift ;;
    --no-sync) NOSYNC=1; shift ;;
    --model)   MODEL_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

require_identity
AGENT="${TEAMOS_AGENT}"
MEMBER="${TEAMOS_MEMBER}"
[[ -d "agents/${AGENT}" ]] || \
  die "agents/${AGENT}/ not found — pull latest ('git pull') or check your identity file"

PLAN="$(team_member_field "${MEMBER}" plan)"
[[ -n "${PLAN}" ]] || PLAN="pro"
MODEL="${MODEL_OVERRIDE:-${TEAMOS_MODEL:-$(tier_model "${PLAN}")}}"

if [[ "${PRINT}" -eq 1 ]]; then
  exec "${SCRIPT_DIR}/compose-prompt.sh" "${AGENT}" --tier "${PLAN}"
fi

# --- Pull latest before anything is surfaced -----------------------------------
if has_remote; then
  if git_safe_pull_rebase; then
    ok "pulled latest"
  else
    warn "pull did not complete — launching with local state (run 'tos sync' later)"
  fi
else
  warn "no git remote — running local-only"
fi

# --- Preflight: what's waiting --------------------------------------------------
INBOX_N=0
for f in "agents/${AGENT}"/tasks/inbox/*.md; do [[ -e "${f}" ]] && INBOX_N=$((INBOX_N + 1)); done
ACTIVE_N=0
for f in "agents/${AGENT}"/tasks/active/*.md; do [[ -e "${f}" ]] && ACTIVE_N=$((ACTIVE_N + 1)); done
echo
echo "  ${AGENT} — inbox: ${INBOX_N}, active: ${ACTIVE_N} (plan ${PLAN}, model ${MODEL})"
DUE="$("${SCRIPT_DIR}/cadence-due.sh" --for "${MEMBER}" 2>/dev/null || true)"
if [[ -n "${DUE}" ]]; then
  echo "  team cadence due now:"
  printf '%s\n' "${DUE}" | sed 's/^/    /'
fi
echo

command -v claude >/dev/null 2>&1 || \
  die "claude CLI not found. Install Claude Code (https://claude.com/claude-code), sign in with 'claude' + /login, or inspect the prompt with 'tos launch --print'."

# --- Ledger + heartbeat -----------------------------------------------------------
ACT_LOG="agents/${AGENT}/logs/activity.log.md"
SESS_LOG="agents/${AGENT}/logs/sessions.log.md"
printf -- "- %s  session launched (tier=%s model=%s)\n" "$(now_utc)" "${PLAN}" "${MODEL}" >> "${ACT_LOG}"
printf -- "- %s start (tier=%s model=%s)\n" "$(now_utc)" "${PLAN}" "${MODEL}" >> "${SESS_LOG}"
update_heartbeat "${AGENT}"

# --- Background sync loop -----------------------------------------------------------
SYNC_PID=""
if [[ "${NOSYNC}" -eq 0 ]]; then
  INTERVAL="${TEAMOS_SYNC_INTERVAL:-3600}"
  (
    while true; do
      sleep "${INTERVAL}"
      update_heartbeat "${AGENT}" 2>/dev/null || true
      if git_rebase_in_progress; then
        continue
      fi
      if ! "${SCRIPT_DIR}/validate.sh" --quiet >/dev/null 2>&1; then
        printf -- "- %s  background validate found issues (run 'tos validate')\n" \
          "$(now_utc)" >> "${ACT_LOG}" 2>/dev/null || true
      fi
      commit_pull_push "[sync][agent:${AGENT}] background sync" "${ACT_LOG}" >/dev/null 2>&1 || true
    done
  ) &
  SYNC_PID=$!
  # shellcheck disable=SC2064
  trap "kill ${SYNC_PID} 2>/dev/null || true" EXIT INT TERM
  ok "background sync every ${INTERVAL}s"
fi

# --- Hand off to Claude ---------------------------------------------------------------
START_TS="$(date +%s)"
"${SCRIPT_DIR}/compose-prompt.sh" "${AGENT}" --tier "${PLAN}" | claude --model "${MODEL}" || true
END_TS="$(date +%s)"
MINUTES=$(( (END_TS - START_TS + 30) / 60 ))

printf -- "- %s end (~%sm)\n" "$(now_utc)" "${MINUTES}" >> "${SESS_LOG}"
echo
ok "session ended after ~${MINUTES}m. Run 'tos done' to validate + sync."
