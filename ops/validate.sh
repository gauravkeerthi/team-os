#!/usr/bin/env bash
#
# validate.sh — Enforce team-os conventions across the repo.
#
# Checks:
#   1. Repo structure (required dirs and files)
#   2. agents/_template contract
#   3. Every real agent folder matches the contract
#   4. Task files: filename shape, id matches filename, status agrees with folder
#   5. Duplicate task IDs repo-wide (prints the re-ID recipe)
#   6. team/team.md grammar + member/agent-dir consistency
#   7. team/cadence.md grammar
#   8. shared/knowledge promoted-by sidecars (author must be a maintainer)
#   9. Stale drafts in shared/incoming (warn only)
#
# Errors exit non-zero (CI gate, and `tos done` refuses to sync).
# Warnings do not fail the run.
#
# Usage: ops/validate.sh [--quiet]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

ERRORS=0
WARNINGS=0

fail_check() { err "$*"; ERRORS=$((ERRORS + 1)); }
warn_check() { warn "$*"; WARNINGS=$((WARNINGS + 1)); }
note() { [[ "${QUIET}" -eq 1 ]] || ok "$*"; }

# --- 1. Repo structure --------------------------------------------------------
for d in platform ops agents agents/_template shared shared/incoming \
         shared/knowledge shared/projects shared/handoffs shared/cadence \
         shared/archive team .claude; do
  [[ -d "${d}" ]] || fail_check "missing directory: ${d}/"
done
for f in platform/base-system-prompt.md platform/VERSION team/team.md \
         team/cadence.md .claude/settings.json shared/GOVERNANCE.md; do
  [[ -f "${f}" ]] || fail_check "missing file: ${f}"
done
note "repo structure"

# --- 2 & 3. Agent folder contract ----------------------------------------------
AGENT_FILES="soul.md profile.md memory/context.md memory/routines.md memory/lessons.md memory/decisions.md logs/activity.log.md logs/sessions.log.md"
AGENT_DIRS="tasks/inbox tasks/active tasks/done workspace/private"

check_agent_contract() {
  local dir="$1" name f d
  name="$(basename "${dir}")"
  for f in ${AGENT_FILES}; do
    [[ -f "${dir}/${f}" ]] || fail_check "agents/${name}: missing ${f}"
  done
  for d in ${AGENT_DIRS}; do
    [[ -d "${dir}/${d}" ]] || fail_check "agents/${name}: missing ${d}/"
  done
}

check_agent_contract "agents/_template"

AGENT_COUNT=0
for dir in agents/*/; do
  name="$(basename "${dir}")"
  [[ "${name}" == "_template" ]] && continue
  AGENT_COUNT=$((AGENT_COUNT + 1))
  check_agent_contract "${dir}"
done
note "agent contract (${AGENT_COUNT} agent(s) + template)"

# --- 4 & 5. Task files ----------------------------------------------------------
TMP_IDS="$(mktemp -t teamos-validate-ids.XXXXXX)"
trap 'rm -f "${TMP_IDS}"' EXIT

TASK_COUNT=0
for folder in inbox active done; do
  for tf in agents/*/tasks/${folder}/T-*.md; do
    [[ -e "${tf}" ]] || continue
    TASK_COUNT=$((TASK_COUNT + 1))
    base="$(basename "${tf}" .md)"

    if ! [[ "${base}" =~ ^T-[0-9]{8}-[0-9]{4}$ ]]; then
      fail_check "${tf}: filename does not match T-YYYYMMDD-NNNN.md"
      continue
    fi

    tid="$(md_frontmatter_field "${tf}" id)"
    tstatus="$(md_frontmatter_field "${tf}" status)"

    [[ "${tid}" == "${base}" ]] || \
      fail_check "${tf}: frontmatter id '${tid}' does not match filename"

    case "${folder}" in
      inbox)
        [[ "${tstatus}" == "inbox" ]] || \
          fail_check "${tf}: in inbox/ but status is '${tstatus}' (the folder IS the status)" ;;
      active)
        [[ "${tstatus}" == "active" || "${tstatus}" == "blocked" ]] || \
          fail_check "${tf}: in active/ but status is '${tstatus}' (expected active or blocked)" ;;
      done)
        [[ "${tstatus}" == "done" || "${tstatus}" == "cancelled" ]] || \
          fail_check "${tf}: in done/ but status is '${tstatus}' (expected done or cancelled)" ;;
    esac

    echo "${base}" >> "${TMP_IDS}"
  done
done

DUPES="$(sort "${TMP_IDS}" | uniq -d)"
if [[ -n "${DUPES}" ]]; then
  for d in ${DUPES}; do
    fail_check "duplicate task id ${d} — two machines minted the same id between syncs."
    err "  Fix: keep the OLDER file's id; rename the NEWER file to the next free"
    err "  NNNN for that date, update its 'id:' frontmatter to match, commit."
    grep -l -- "" agents/*/tasks/*/"${d}.md" 2>/dev/null | sed 's/^/    -> /' >&2 || true
  done
fi
note "task files (${TASK_COUNT} task(s))"

# --- 6. team/team.md ------------------------------------------------------------
for key in team timezone; do
  v="$(team_setting "${key}")"
  [[ -n "${v}" ]] || fail_check "team/team.md: frontmatter missing '${key}:'"
done

MEMBERS="$(team_members || true)"
MEMBER_COUNT=0
MAINTAINERS=0

if [[ -n "${MEMBERS}" ]]; then
  for m in ${MEMBERS}; do
    MEMBER_COUNT=$((MEMBER_COUNT + 1))

    [[ "${m}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
      fail_check "team.md member '${m}': id must be lowercase kebab-case"

    for key in name agent email plan role; do
      v="$(team_member_field "${m}" "${key}")"
      [[ -n "${v}" ]] || fail_check "team.md member '${m}': missing '- ${key}:'"
    done

    agent="$(team_member_field "${m}" agent)"
    plan="$(team_member_field "${m}" plan)"
    role="$(team_member_field "${m}" role)"

    if [[ -n "${agent}" ]]; then
      [[ "${agent}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
        fail_check "team.md member '${m}': agent '${agent}' must be lowercase kebab-case"
      [[ "${agent}" != "_template" ]] || \
        fail_check "team.md member '${m}': agent name '_template' is reserved"
      [[ -d "agents/${agent}" ]] || \
        fail_check "team.md member '${m}': agent dir agents/${agent}/ does not exist (run tos add-member)"
    fi

    case "${plan}" in
      pro|max-5x|max-20x) : ;;
      *) fail_check "team.md member '${m}': plan '${plan}' not one of pro|max-5x|max-20x" ;;
    esac

    case "${role}" in
      maintainer) MAINTAINERS=$((MAINTAINERS + 1)) ;;
      member) : ;;
      *) fail_check "team.md member '${m}': role '${role}' not one of maintainer|member" ;;
    esac
  done

  # Uniqueness of member ids and agent names.
  DUP_M="$(printf '%s\n' ${MEMBERS} | sort | uniq -d)"
  [[ -z "${DUP_M}" ]] || fail_check "team.md: duplicate member id(s): ${DUP_M}"
  DUP_A="$(for m in ${MEMBERS}; do team_member_field "${m}" agent; done | sort | uniq -d)"
  [[ -z "${DUP_A}" ]] || fail_check "team.md: duplicate agent name(s): ${DUP_A}"

  [[ "${MAINTAINERS}" -ge 1 ]] || \
    fail_check "team.md: no maintainer — at least one member needs 'role: maintainer'"

  # Every agent dir should belong to a member (warn — may be mid-offboarding).
  for dir in agents/*/; do
    name="$(basename "${dir}")"
    [[ "${name}" == "_template" ]] && continue
    owner="$(agent_member "${name}")"
    [[ -n "${owner}" ]] || \
      warn_check "agents/${name}/ has no member in team.md (offboarded? archive it)"
  done
fi
note "team.md (${MEMBER_COUNT} member(s), ${MAINTAINERS} maintainer(s))"

# --- 7. team/cadence.md ----------------------------------------------------------
CADENCE_COUNT=0
for item in $(cadence_items); do
  CADENCE_COUNT=$((CADENCE_COUNT + 1))

  [[ "${item}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
    fail_check "cadence '${item}': name must be lowercase kebab-case"

  for key in schedule owner action output; do
    v="$(cadence_field "${item}" "${key}")"
    [[ -n "${v}" ]] || fail_check "cadence '${item}': missing '- ${key}:'"
  done

  sched="$(cadence_field "${item}" schedule)"
  if [[ -n "${sched}" ]] && \
     ! [[ "${sched}" =~ ^(daily|weekdays|weekly:(mon|tue|wed|thu|fri|sat|sun)|monthly:([1-9]|1[0-9]|2[0-8]))$ ]]; then
    fail_check "cadence '${item}': schedule '${sched}' invalid (daily | weekdays | weekly:<mon..sun> | monthly:<1-28>)"
  fi

  after="$(cadence_field "${item}" after)"
  if [[ -n "${after}" ]] && ! [[ "${after}" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    fail_check "cadence '${item}': after '${after}' invalid (HH:MM, 24h)"
  fi

  output="$(cadence_field "${item}" output)"
  if [[ -n "${output}" ]]; then
    nkeys="$(printf '%s' "${output}" | grep -o '{date}\|{week}\|{month}' | wc -l | tr -d ' ')"
    [[ "${nkeys}" == "1" ]] || \
      fail_check "cadence '${item}': output must contain exactly one of {date} {week} {month} (found ${nkeys})"
  fi

  owner="$(cadence_field "${item}" owner)"
  case "${owner}" in
    ""|any|rotate) : ;;
    *)
      if [[ -n "${MEMBERS}" ]]; then
        found=0
        for m in ${MEMBERS}; do
          [[ "${m}" == "${owner}" ]] && found=1
        done
        [[ "${found}" -eq 1 ]] || \
          fail_check "cadence '${item}': owner '${owner}' is not any|rotate|<member-id>"
      fi
      ;;
  esac
done
note "cadence.md (${CADENCE_COUNT} item(s))"

# --- 8. shared/knowledge provenance (informational — any human may promote) --------
KNOWLEDGE_COUNT=0
while IFS= read -r kf; do
  [[ -n "${kf}" ]] || continue
  KNOWLEDGE_COUNT=$((KNOWLEDGE_COUNT + 1))
  sidecar="${kf}.promoted-by"
  # Sidecars are optional provenance, not permission. If one exists, its
  # author should at least be a known member.
  if [[ -f "${sidecar}" && -n "${MEMBERS}" ]]; then
    author="$(awk '/^promoted_by:/{sub(/^promoted_by:[[:space:]]*/,""); print; exit}' "${sidecar}")"
    if [[ -n "${author}" ]]; then
      FOUND_AUTHOR=0
      for m in ${MEMBERS}; do
        [[ "${m}" == "${author}" ]] && FOUND_AUTHOR=1
      done
      [[ "${FOUND_AUTHOR}" -eq 1 ]] || \
        warn_check "${sidecar}: author '${author}' is not a member in team.md"
    fi
  fi
done < <(find shared/knowledge -type f -name '*.md' ! -name '*.promoted-by' 2>/dev/null)
note "shared/knowledge (${KNOWLEDGE_COUNT} file(s))"

# --- 9. Stale drafts in shared/incoming (warn only) --------------------------------
while IFS= read -r sf; do
  [[ -n "${sf}" ]] || continue
  warn_check "stale draft (>14 days): ${sf} — promote it or archive it"
done < <(find shared/incoming -type f -name '*.md' -mtime +14 2>/dev/null)

# --- Summary -----------------------------------------------------------------------
echo
if [[ "${ERRORS}" -gt 0 ]]; then
  err "validate: ${ERRORS} error(s), ${WARNINGS} warning(s)"
  exit 1
fi
if [[ "${WARNINGS}" -gt 0 ]]; then
  warn "validate: clean with ${WARNINGS} warning(s)"
else
  ok "validate: clean"
fi
