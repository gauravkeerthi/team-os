#!/usr/bin/env bash
#
# onboard.sh — Bind THIS machine to one team member. Run once per machine,
# after the member exists in team/team.md (founder: run setup.sh first;
# everyone else: clone, then run this).
#
# Usage:
#   ops/onboard.sh                      # interactive
#   ops/onboard.sh --member alice --yes # non-interactive
#
# Steps:
#   1. Dependency check (bash, git, awk; claude CLI — warn only)
#   2. Repo sanity (git repo, members exist, remote configured — warn only)
#   3. Pick which member this machine is
#   4. Write ~/.config/team-os/identity (chmod 600)
#   5. Install the pre-commit hook
#   6. Install the `tos` shell alias
#   7. Print the Claude login step

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

MEMBER=""
YES=0
NO_ALIAS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --member)   MEMBER="${2:-}"; shift 2 ;;
    --yes)      YES=1; shift ;;
    --no-alias) NO_ALIAS=1; shift ;;
    -h|--help)  sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

echo "== team-os onboarding (this machine) =="
echo

# --- 1. Dependencies -----------------------------------------------------------
[[ "${BASH_VERSINFO[0]}" -ge 3 ]] || die "bash >= 3.2 required"
command -v git >/dev/null 2>&1 || die "git is required"
command -v awk >/dev/null 2>&1 || die "awk is required"

GIT_VER="$(git --version | awk '{print $3}')"
GIT_MAJ="${GIT_VER%%.*}"
GIT_REST="${GIT_VER#*.}"
GIT_MIN="${GIT_REST%%.*}"
if [[ "${GIT_MAJ}" -lt 2 || ( "${GIT_MAJ}" -eq 2 && "${GIT_MIN}" -lt 20 ) ]]; then
  warn "git ${GIT_VER} is old (< 2.20) — upgrade recommended"
else
  ok "git ${GIT_VER}"
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI found ($(claude --version 2>/dev/null | head -n 1 || echo 'version unknown'))"
else
  warn "claude CLI not found — install Claude Code before launching (https://claude.com/claude-code)"
fi

# --- 2. Repo sanity --------------------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die "not inside a git repo — clone your team's copy of team-os first"

MEMBERS="$(team_members || true)"
[[ -n "${MEMBERS}" ]] || \
  die "team/team.md has no members yet. Founder runs ./ops/setup.sh first; teammates are added with 'tos add-member'."

if ! has_remote; then
  warn "no 'origin' remote — sync will be local-only until you add one"
fi

# --- 3. Which member is this machine? ----------------------------------------------
if [[ -z "${MEMBER}" ]]; then
  [[ "${YES}" -eq 0 ]] || die "--yes requires --member <id>"
  echo
  echo "Team roster:"
  for m in ${MEMBERS}; do
    printf '  %-14s %s (agent: %s)\n' "${m}" "$(team_member_field "${m}" name)" "$(team_member_field "${m}" agent)"
  done
  printf 'Which member are you?: '
  IFS= read -r MEMBER
fi

FOUND=0
for m in ${MEMBERS}; do
  [[ "${m}" == "${MEMBER}" ]] && FOUND=1
done
[[ "${FOUND}" -eq 1 ]] || die "no member '${MEMBER}' in team/team.md"

AGENT="$(member_agent "${MEMBER}")"
[[ -n "${AGENT}" && -d "agents/${AGENT}" ]] || \
  die "member '${MEMBER}' has no agent directory (run 'tos add-member' / 'tos sync' first)"

# --- 4. Identity file ----------------------------------------------------------------
CONF_DIR="${HOME}/.config/team-os"
mkdir -p "${CONF_DIR}"
ID_FILE="${CONF_DIR}/identity"
{
  echo "# team-os identity — this machine only. Not committed anywhere."
  echo "# Optional overrides: model=<sonnet|opus|haiku>, sync_interval=<seconds>,"
  echo "#   remote_control=false (opt this machine out of Remote Control)"
  echo "member=${MEMBER}"
  echo "agent=${AGENT}"
} > "${ID_FILE}"
chmod 600 "${ID_FILE}"
ok "wrote ${ID_FILE} (member=${MEMBER}, agent=${AGENT})"

# --- 5. Hooks ---------------------------------------------------------------------------
"${SCRIPT_DIR}/install-hooks.sh"

# --- 6. Shell alias -----------------------------------------------------------------------
if [[ "${NO_ALIAS}" -eq 0 ]]; then
  case "${SHELL:-}" in
    */zsh)  RC_FILE="${HOME}/.zshrc" ;;
    */bash) RC_FILE="${HOME}/.bashrc" ;;
    *)      RC_FILE="${HOME}/.profile" ;;
  esac
  ALIAS_LINE="alias tos='${ROOT}/ops/tos.sh'"
  if [[ -f "${RC_FILE}" ]] && grep -qF "alias tos=" "${RC_FILE}"; then
    ok "'tos' alias already present in ${RC_FILE}"
  else
    {
      echo ""
      echo "# team-os"
      echo "${ALIAS_LINE}"
    } >> "${RC_FILE}"
    ok "added 'tos' alias to ${RC_FILE}"
  fi
fi

# --- 7. Done ----------------------------------------------------------------------------------
PLAN="$(team_member_field "${MEMBER}" plan)"
echo
ok "onboarding complete: this machine is ${MEMBER} / agent ${AGENT} (plan: ${PLAN})"
echo
echo "Next steps:"
echo "  1. Reload your shell:   source ${RC_FILE:-your shell profile}"
echo "  2. Sign in to Claude once with your subscription:"
echo "       claude        # then /login, then /exit"
echo "  3. Launch your agent:   tos"
echo "     (first launch runs a ten-minute onboarding interview)"
