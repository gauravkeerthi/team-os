#!/usr/bin/env bash
#
# cadence-due.sh — Evaluate team/cadence.md: what is due right now?
#
# Usage:
#   ops/cadence-due.sh                 # due items for this machine's member (prompt-friendly)
#   ops/cadence-due.sh --for <member>  # due items for a specific member
#   ops/cadence-due.sh --all           # every item with its current state (used by status)
#   ops/cadence-due.sh --tsv           # machine-readable due list: item<TAB>period<TAB>output<TAB>action<TAB>model
#
# An item is DUE iff: today matches schedule AND local team time is past
# `after:` AND the rendered output file does not exist AND no fresh claim
# (<6h) exists. Items are only surfaced within their own period — no
# backfill. See platform/conventions/cadence-format.md.
#
# Exit code is always 0 (an empty list is not an error).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

FOR="${TEAMOS_MEMBER:-}"
MODE="due"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --for) FOR="${2:-}"; shift 2 ;;
    --all) MODE="all"; shift ;;
    --tsv) MODE="tsv"; shift ;;
    -h|--help) sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

TZ_VAL="$(team_setting timezone)"
[[ -n "${TZ_VAL}" ]] || TZ_VAL="UTC"

# Clock, in the team's timezone. Only strftime formats — portable BSD/GNU.
DOW="$(TZ="${TZ_VAL}" date +%u)"                       # 1=Mon .. 7=Sun
TODAY="$(TZ="${TZ_VAL}" date +%F)"                     # YYYY-MM-DD
WEEK="$(TZ="${TZ_VAL}" date +%G-W%V)"                  # ISO week, e.g. 2026-W28
MONTH="$(TZ="${TZ_VAL}" date +%Y-%m)"
HHMM="$(TZ="${TZ_VAL}" date +%H:%M)"
DOM="$((10#$(TZ="${TZ_VAL}" date +%d)))"
DOY="$((10#$(TZ="${TZ_VAL}" date +%j)))"
WNUM="$((10#$(TZ="${TZ_VAL}" date +%V)))"
MNUM="$((10#$(TZ="${TZ_VAL}" date +%m)))"

MEMBERS_SORTED="$(team_members | sort)"
MCOUNT=0
for _m in ${MEMBERS_SORTED}; do MCOUNT=$((MCOUNT + 1)); done

dow_number() { # mon..sun -> 1..7
  case "$1" in
    mon) echo 1 ;; tue) echo 2 ;; wed) echo 3 ;; thu) echo 4 ;;
    fri) echo 5 ;; sat) echo 6 ;; sun) echo 7 ;; *) echo 0 ;;
  esac
}

nth_member() { # 1-based index into MEMBERS_SORTED
  printf '%s\n' ${MEMBERS_SORTED} | sed -n "$1p"
}

for item in $(cadence_items); do
  sched="$(cadence_field "${item}" schedule)"
  owner="$(cadence_field "${item}" owner)"
  action="$(cadence_field "${item}" action)"
  output="$(cadence_field "${item}" output)"
  model="$(cadence_field "${item}" model)"
  after="$(cadence_field "${item}" after)"
  [[ -n "${sched}" && -n "${output}" ]] || continue   # validate.sh reports these
  [[ -n "${model}" ]] || model="sonnet"
  [[ -n "${owner}" ]] || owner="any"

  # In schedule today?
  insched=0
  case "${sched}" in
    daily)     insched=1 ;;
    weekdays)  [[ "${DOW}" -le 5 ]] && insched=1 ;;
    weekly:*)  [[ "${DOW}" -eq "$(dow_number "${sched#weekly:}")" ]] && insched=1 ;;
    monthly:*) [[ "${DOM}" -eq "$((10#${sched#monthly:}))" ]] && insched=1 ;;
  esac

  # Period key from the output path.
  period=""; pnum=0
  case "${output}" in
    *"{date}"*)  period="${TODAY}";  pnum="${DOY}" ;;
    *"{week}"*)  period="${WEEK}";   pnum="${WNUM}" ;;
    *"{month}"*) period="${MONTH}";  pnum="${MNUM}" ;;
    *) continue ;;
  esac

  rendered="${output}"
  rendered="${rendered//\{date\}/${TODAY}}"
  rendered="${rendered//\{week\}/${WEEK}}"
  rendered="${rendered//\{month\}/${MONTH}}"

  # Resolve the owner.
  resolved="${owner}"
  if [[ "${owner}" == "rotate" ]]; then
    if [[ "${MCOUNT}" -gt 0 ]]; then
      resolved="$(nth_member "$(( (pnum % MCOUNT) + 1 ))")"
    else
      resolved=""
    fi
  fi

  # State machine.
  state="due"
  claimed_by=""
  if [[ "${insched}" -eq 0 ]]; then
    state="not-today"
  elif [[ -n "${after}" && "${HHMM}" < "${after}" ]]; then
    state="not-yet"
  elif [[ -e "${rendered}" ]]; then
    state="done"
  else
    claim="shared/cadence/${item}/${period}.claim.md"
    if [[ -f "${claim}" ]]; then
      if [[ -n "$(find "${claim}" -mmin -360 -print 2>/dev/null)" ]]; then
        state="claimed"
        claimed_by="$(awk '/^member:/{sub(/^member:[[:space:]]*/,""); print; exit}' "${claim}")"
      else
        state="due"   # stale claim (>6h, no output) — supersedable
      fi
    fi
  fi

  # Is it this member's to do?
  mine=0
  if [[ "${state}" == "due" ]]; then
    case "${resolved}" in
      any) mine=1 ;;
      "")  mine=0 ;;
      *)   [[ "${resolved}" == "${FOR}" ]] && mine=1 ;;
    esac
  fi

  case "${MODE}" in
    all)
      label="${state}"
      [[ "${state}" == "claimed" ]] && label="claimed by ${claimed_by:-?}"
      if [[ "${state}" == "due" && "${resolved}" != "any" && -n "${resolved}" && "${resolved}" != "${FOR}" ]]; then
        label="waiting on ${resolved}"
      fi
      [[ "${state}" == "not-yet" ]] && label="due after ${after}"
      printf '%-20s %-12s period %-12s owner %-10s %s\n' \
        "${item}" "${sched}" "${period}" "${owner}" "${label}"
      ;;
    tsv)
      [[ "${mine}" -eq 1 ]] && printf '%s\t%s\t%s\t%s\t%s\n' \
        "${item}" "${period}" "${rendered}" "${action}" "${model}"
      ;;
    due)
      if [[ "${mine}" -eq 1 ]]; then
        printf -- '- %s (period %s): run `%s`, write the result to %s [model hint: %s]' \
          "${item}" "${period}" "${action}" "${rendered}" "${model}"
        if [[ "${resolved}" == "any" ]]; then
          printf ' — owner is "any": claim it first (shared/cadence/%s/%s.claim.md), push, and back off if someone beat you.' \
            "${item}" "${period}"
        fi
        printf '\n'
      fi
      ;;
  esac
done
