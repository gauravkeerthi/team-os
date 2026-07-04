#!/usr/bin/env bash
#
# add-member.sh — Add a team member and create their paired agent from the
# template. Maintainer operation (any human can run it pre-onboarding; after
# that, convention says maintainers do).
#
# Usage:
#   ops/add-member.sh <member-id> "<Full Name>" <agent-name> <plan> [role] [options]
#
#   <plan>   pro | max-5x | max-20x
#   [role]   maintainer | member          (default: member)
#
# Options:
#   --email <addr>    member email (recommended; defaults to a placeholder)
#   --title <text>    the human's job title (defaults to a placeholder)
#   --no-commit       skip the git commit (setup.sh uses this)
#
# What it does:
#   1. Validates ids, uniqueness against team/team.md and agents/
#   2. Appends the member block to team/team.md
#   3. Copies agents/_template -> agents/<agent> and substitutes placeholders
#   4. Ensures the onboarding sentinel is present
#   5. Commits ([init])

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

MEMBER="${1:-}"
FULL_NAME="${2:-}"
AGENT="${3:-}"
PLAN="${4:-}"
shift $(( $# < 4 ? $# : 4 ))

ROLE="member"
if [[ "${1:-}" == "maintainer" || "${1:-}" == "member" ]]; then
  ROLE="$1"
  shift
fi

EMAIL=""
TITLE=""
DO_COMMIT=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)     EMAIL="${2:-}"; shift 2 ;;
    --title)     TITLE="${2:-}"; shift 2 ;;
    --no-commit) DO_COMMIT=0; shift ;;
    -h|--help)   sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

[[ -n "${MEMBER}" && -n "${FULL_NAME}" && -n "${AGENT}" && -n "${PLAN}" ]] || \
  die "usage: add-member.sh <member-id> \"<Full Name>\" <agent-name> <plan> [role] [--email <addr>]"

[[ "${MEMBER}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "member id '${MEMBER}' must be lowercase kebab-case"
[[ "${AGENT}"  =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "agent name '${AGENT}' must be lowercase kebab-case"
[[ "${AGENT}" != "_template" ]] || die "agent name '_template' is reserved"

case "${PLAN}" in
  pro|max-5x|max-20x) : ;;
  *) die "plan '${PLAN}' must be pro | max-5x | max-20x" ;;
esac

# Uniqueness.
for m in $(team_members); do
  [[ "${m}" != "${MEMBER}" ]] || die "member '${MEMBER}' already exists in team/team.md"
  [[ "$(team_member_field "${m}" agent)" != "${AGENT}" ]] || \
    die "agent '${AGENT}' already belongs to member '${m}'"
done
[[ ! -d "agents/${AGENT}" ]] || die "agents/${AGENT}/ already exists"

[[ -n "${EMAIL}" ]] || EMAIL="${MEMBER}@CHANGE-ME.example"
[[ -n "${TITLE}" ]] || TITLE="(edit profile.md: the human's job title)"

TZ_VAL="$(team_setting timezone)"
[[ -n "${TZ_VAL}" ]] || TZ_VAL="UTC"

# Display name for the agent: first letter capitalized.
AGENT_DISPLAY="$(printf '%s' "${AGENT:0:1}" | tr '[:lower:]' '[:upper:]')${AGENT:1}"
AGENT_ROLE="Personal assistant to ${FULL_NAME}. Supports them on the day-to-day — task tracking, prep, drafting, follow-ups. Does not make decisions or approvals on their behalf."

# --- 2. Append the member block to team/team.md --------------------------------
{
  echo
  echo "### member: ${MEMBER}"
  echo "- name: ${FULL_NAME}"
  echo "- agent: ${AGENT}"
  echo "- email: ${EMAIL}"
  echo "- plan: ${PLAN}"
  echo "- role: ${ROLE}"
} >> team/team.md
ok "team/team.md: added member '${MEMBER}' (agent: ${AGENT}, plan: ${PLAN}, role: ${ROLE})"

# --- 3. Create the agent from the template ---------------------------------------
cp -R agents/_template "agents/${AGENT}"

substitute() { # <relative-file>
  local path="agents/${AGENT}/$1"
  [[ -f "${path}" ]] || return 0
  sed -e "s/__AGENT_NAME__/$(escape_sed "${AGENT_DISPLAY}")/g" \
      -e "s/__MEMBER_NAME__/$(escape_sed "${FULL_NAME}")/g" \
      -e "s/__MEMBER_ID__/$(escape_sed "${MEMBER}")/g" \
      -e "s/__HUMAN_TITLE__/$(escape_sed "${TITLE}")/g" \
      -e "s/__AGENT_ROLE__/$(escape_sed "${AGENT_ROLE}")/g" \
      -e "s/__TIMEZONE__/$(escape_sed "${TZ_VAL}")/g" \
      "${path}" > "${path}.tmp" && mv "${path}.tmp" "${path}"
}

for f in soul.md profile.md logs/activity.log.md logs/sessions.log.md; do
  substitute "${f}"
done

# --- 4. Onboarding sentinel + birth log -------------------------------------------
if ! head -n 1 "agents/${AGENT}/memory/context.md" | grep -q 'onboarding:pending'; then
  # Template should carry it; enforce it regardless.
  printf '<!-- onboarding:pending -->\n%s' "$(cat "agents/${AGENT}/memory/context.md")" \
    > "agents/${AGENT}/memory/context.md.tmp"
  mv "agents/${AGENT}/memory/context.md.tmp" "agents/${AGENT}/memory/context.md"
fi

printf -- "- %s  agent created for %s (%s)\n" "$(now_utc)" "${FULL_NAME}" "${MEMBER}" \
  >> "agents/${AGENT}/logs/activity.log.md"

ok "created agents/${AGENT}/ from template (onboarding interview pending)"

# --- 5. Commit ----------------------------------------------------------------------
if [[ "${DO_COMMIT}" -eq 1 ]]; then
  git add team/team.md "agents/${AGENT}"
  git commit --quiet -m "[init][agent:-] add member ${MEMBER} (agent ${AGENT})"
  ok "committed. Run 'tos sync' so ${FULL_NAME} can clone and onboard."
fi

echo
echo "Next: ${FULL_NAME} clones the repo and runs ./ops/onboard.sh on their machine."
