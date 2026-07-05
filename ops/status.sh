#!/usr/bin/env bash
#
# status.sh — Read-only dashboard. Costs zero Claude usage; run it instead
# of asking your agent "what's my status".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

count_md() {
  local d="$1" n=0 f
  for f in "${d}"/*.md; do
    [[ -e "${f}" ]] && n=$((n + 1))
  done
  echo "${n}"
}

echo "== team-os status =="
VER="$(cat platform/VERSION 2>/dev/null | head -n 1 || echo '?')"
echo "team: $(team_setting team)  |  platform v${VER}  |  timezone: $(team_setting timezone)"

if [[ -n "${TEAMOS_MEMBER:-}" ]]; then
  PLAN="$(team_member_field "${TEAMOS_MEMBER}" plan)"
  [[ -n "${PLAN}" ]] || PLAN="pro"
  MODEL="${TEAMOS_MODEL:-$(tier_model "${PLAN}")}"
  echo "you:  ${TEAMOS_MEMBER} — agent ${TEAMOS_AGENT:-?} (plan ${PLAN}, session model ${MODEL})"
else
  warn "this machine is not onboarded (run ops/onboard.sh)"
fi

echo
echo "-- git --"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
DIRTY="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
LINE="branch ${BRANCH}, ${DIRTY} uncommitted change(s)"
if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  # left = upstream-only commits (we're behind), right = ours (we're ahead)
  COUNTS="$(git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || echo '0	0')"
  BEHIND="$(printf '%s' "${COUNTS}" | awk '{print $1}')"
  AHEAD="$(printf '%s' "${COUNTS}" | awk '{print $2}')"
  LINE="${LINE}, ahead ${AHEAD}, behind ${BEHIND}"
else
  LINE="${LINE}, no upstream tracking (push once with: git push -u origin main)"
fi
echo "  ${LINE}"
if git_rebase_in_progress; then
  warn "a rebase is in progress — finish or abort it before syncing"
fi

echo
echo "-- agents --"
ANY=0
printf '  %-14s %-14s %7s %7s %6s\n' "member" "agent" "inbox" "active" "done"
for m in $(team_members); do
  ANY=1
  a="$(member_agent "${m}")"
  [[ -d "agents/${a}" ]] || { printf '  %-14s %-14s %s\n' "${m}" "${a}" "(agent dir missing)"; continue; }
  printf '  %-14s %-14s %7s %7s %6s\n' "${m}" "${a}" \
    "$(count_md "agents/${a}/tasks/inbox")" \
    "$(count_md "agents/${a}/tasks/active")" \
    "$(count_md "agents/${a}/tasks/done")"
done
[[ "${ANY}" -eq 1 ]] || echo "  (no members yet — run ops/setup.sh)"

echo
echo "-- cadence --"
CAD="$("${SCRIPT_DIR}/cadence-due.sh" --all 2>/dev/null || true)"
if [[ -n "${CAD}" ]]; then
  printf '%s\n' "${CAD}" | sed 's/^/  /'
else
  echo "  (no cadence items configured — see team/cadence.md)"
fi

if [[ -n "${TEAMOS_AGENT:-}" && -f "agents/${TEAMOS_AGENT}/logs/sessions.log.md" ]]; then
  echo
  echo "-- recent sessions (${TEAMOS_AGENT}) --"
  RECENT="$(grep '^- ' "agents/${TEAMOS_AGENT}/logs/sessions.log.md" | tail -n 10 || true)"
  if [[ -n "${RECENT}" ]]; then
    printf '%s\n' "${RECENT}" | sed 's/^/  /'
  else
    echo "  (no sessions yet)"
  fi
fi
