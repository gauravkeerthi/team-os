#!/usr/bin/env bash
#
# setup.sh — One-time team bootstrap. Run by the founder on a fresh copy of
# the team-os template.
#
# Interactive by default. Non-interactive (CI / testing):
#   ops/setup.sh --team "Acme" --tz Asia/Singapore \
#     --member alice --name "Alice Wong" --agent ajax \
#     --email alice@example.com --plan max-5x --yes
#
# What it does:
#   1. Sanity: git repo present (offers `git init` if not), team.md still
#      has the placeholder (refuses to re-run on a configured team)
#   2. Fills team/team.md frontmatter (team name, timezone)
#   3. Adds the first member (always role: maintainer) via add-member.sh
#   4. Installs the pre-commit hook
#   5. Validates, commits
#
# After this, run ops/onboard.sh to bind YOUR machine to the member you just
# created.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

TEAM_NAME=""
TZ_VAL=""
MEMBER=""
FULL_NAME=""
AGENT=""
EMAIL=""
PLAN=""
UPSTREAM=""
YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team)     TEAM_NAME="${2:-}"; shift 2 ;;
    --tz)       TZ_VAL="${2:-}"; shift 2 ;;
    --member)   MEMBER="${2:-}"; shift 2 ;;
    --name)     FULL_NAME="${2:-}"; shift 2 ;;
    --agent)    AGENT="${2:-}"; shift 2 ;;
    --email)    EMAIL="${2:-}"; shift 2 ;;
    --plan)     PLAN="${2:-}"; shift 2 ;;
    --upstream) UPSTREAM="${2:-}"; shift 2 ;;
    --yes)      YES=1; shift ;;
    -h|--help)  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

ask() { # ask <prompt> <varname> [default]
  local prompt="$1" var="$2" def="${3:-}" val=""
  if [[ "${YES}" -eq 1 ]]; then
    eval "val=\${${var}}"
    [[ -n "${val}" || -n "${def}" ]] || die "--yes given but ${var} has no value and no default"
    [[ -n "${val}" ]] || eval "${var}=\"\${def}\""
    return 0
  fi
  eval "val=\${${var}}"
  [[ -z "${val}" ]] || return 0
  if [[ -n "${def}" ]]; then
    printf '%s [%s]: ' "${prompt}" "${def}"
  else
    printf '%s: ' "${prompt}"
  fi
  IFS= read -r val
  [[ -n "${val}" ]] || val="${def}"
  [[ -n "${val}" ]] || die "a value is required"
  eval "${var}=\"\${val}\""
}

echo "== team-os setup =="
echo

# --- 1. Sanity ---------------------------------------------------------------
# Portable "init on main" — works on git older than 2.28 (no `init -b`).
git_init_main() { git init --quiet >/dev/null && git symbolic-ref HEAD refs/heads/main; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ "${YES}" -eq 1 ]]; then
    git_init_main
    ok "initialized git repo (main)"
  else
    printf 'This folder is not a git repo. Initialize one now? [Y/n]: '
    IFS= read -r ans
    if [[ -z "${ans}" || "${ans}" =~ ^[Yy] ]]; then
      git_init_main
      ok "initialized git repo (main)"
    else
      die "team-os needs git — it is the sync layer."
    fi
  fi
fi

if [[ "$(team_setting team)" != "YOUR-TEAM-NAME" ]]; then
  die "team/team.md is already configured for '$(team_setting team)'. setup.sh runs once per team; use add-member.sh to grow it."
fi

# --- 2. Team frontmatter -------------------------------------------------------
ask "Team name" TEAM_NAME
ask "Team timezone (IANA, e.g. Asia/Singapore)" TZ_VAL "UTC"

if [[ ! -f "/usr/share/zoneinfo/${TZ_VAL}" ]]; then
  warn "'${TZ_VAL}' not found in /usr/share/zoneinfo — double-check the spelling (continuing anyway)"
fi

replace_frontmatter_line() { # <key> <value>
  local key="$1" value="$2"
  awk -v key="${key}" -v val="${value}" '
    !seen && index($0, key ":") == 1 { print key ": " val; seen = 1; next }
    { print }
  ' team/team.md > team/team.md.tmp && mv team/team.md.tmp team/team.md
}

replace_frontmatter_line team "${TEAM_NAME}"
replace_frontmatter_line timezone "${TZ_VAL}"
if [[ -n "${UPSTREAM}" ]]; then
  replace_frontmatter_line upstream "${UPSTREAM}"
fi
ok "team/team.md frontmatter set (team: ${TEAM_NAME}, timezone: ${TZ_VAL})"

# --- 3. First member (always a maintainer) --------------------------------------
echo
echo "-- First member (you). This member will be a maintainer. --"
ask "Your member id (lowercase, e.g. alice)" MEMBER
ask "Your full name" FULL_NAME
ask "Your agent's name (lowercase, e.g. ajax)" AGENT
ask "Your email" EMAIL
ask "Your Claude plan (pro | max-5x | max-20x)" PLAN "pro"

# Ensure git has an identity on this machine (needed to commit; common on
# fresh machines and CI). Repo-local only — never touches global config.
if [[ -z "$(git config user.email 2>/dev/null || true)" ]]; then
  git config user.name "${FULL_NAME}"
  git config user.email "${EMAIL}"
  ok "set repo-local git identity (${FULL_NAME} <${EMAIL}>)"
fi

# If this repo has no commits yet (fresh `git init` rather than a template
# clone), commit the pristine tree now — BEFORE hooks are installed — so the
# protected-path guard only ever sees team-owned changes.
if ! git rev-parse HEAD >/dev/null 2>&1; then
  git add -A
  git commit --quiet -m "[init][agent:-] import team-os template"
  ok "baseline commit of the template tree"
fi

"${SCRIPT_DIR}/add-member.sh" "${MEMBER}" "${FULL_NAME}" "${AGENT}" "${PLAN}" \
  maintainer --email "${EMAIL}" --no-commit

# --- 4. Hooks --------------------------------------------------------------------
"${SCRIPT_DIR}/install-hooks.sh"

# --- 5. Validate + commit ----------------------------------------------------------
"${SCRIPT_DIR}/validate.sh" --quiet || die "validation failed — fix the errors above before committing"

git add -A
git commit --quiet -m "[init][agent:-] team-os configured for ${TEAM_NAME}"
ok "committed team configuration"

echo
ok "setup complete."
echo
echo "Next steps:"
echo "  1. ./ops/onboard.sh          # bind THIS machine to '${MEMBER}'"
echo "  2. git remote add origin <your-private-repo-url>   # if not already set"
echo "     git push -u origin main"
echo "  3. Add teammates:  tos add-member <id> \"<Name>\" <agent> <plan>"
echo "  4. Launch:         tos"
