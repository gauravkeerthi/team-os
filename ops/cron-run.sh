#!/usr/bin/env bash
#
# cron-run.sh — Optional headless cadence runner.
#
# This is the "always-on scheduler" module. A host OS scheduler (cron on
# Linux, launchd on macOS — see ops/cron-install.sh) invokes this on a
# timer. It closes the wall-clock gap in team-os's otherwise pull-based
# cadence: instead of waiting for a human to launch, it fires due cadence
# items itself, headlessly, on the SAME Claude subscription credits an
# interactive session uses (no API key, no metered billing).
#
# It reuses everything the interactive path uses — the cadence-due engine,
# the claim protocol, tier model selection — so a runner behaves exactly
# like a human who happens to launch on time. If the machine is off at the
# trigger, nothing breaks: the next run (or a human launch) catches up.
#
# It acts as THIS machine's member/agent (from ~/.config/team-os/identity),
# so it executes cadence items owned by that member, rotated to them, or
# `owner: any` (which it claims via the git race). Point one always-on box
# at a team of `owner: any` items and it handles the lot.
#
# Usage:
#   ops/cron-run.sh            run once: pull, fire every due item, push
#   ops/cron-run.sh --list     show what's due for this member; run nothing
#   ops/cron-run.sh --dry-run  claim nothing, invoke nothing; print the plan
#   ops/cron-run.sh --help
#
# Auth on headless machines: interactive login uses the OS keychain, which
# cron/launchd jobs can usually still reach when they run as the logged-in
# user. If not (locked-down or headless server), generate a subscription
# token with `claude setup-token` and put it in ~/.config/team-os/runner.env
# as CLAUDE_CODE_OAUTH_TOKEN=... (chmod 600). This file is loaded if present.
#
# Tuning the Claude invocation: override TEAMOS_CLAUDE_ARGS to change the
# headless flags (default: --permission-mode acceptEdits). On a trusted
# runner box handling actions that need broader tools, you may prefer
# --dangerously-skip-permissions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
load_identity

ROOT="$(repo_root)"
cd "${ROOT}"

MODE="run"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)    MODE="list"; shift ;;
    --dry-run) MODE="dry"; shift ;;
    --help|-h) sed -n '3,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

require_identity
AGENT="${TEAMOS_AGENT}"
MEMBER="${TEAMOS_MEMBER}"
[[ -d "agents/${AGENT}" ]] || die "agents/${AGENT}/ not found — pull latest or check your identity file"

CONF_DIR="${HOME}/.config/team-os"
RUNNER_LOG="${CONF_DIR}/cron.log"
LOCK_DIR="${CONF_DIR}/cron.lock.d"
LOCK_STALE_SECONDS=1800   # 30 min: a lock older than this is from a dead run
mkdir -p "${CONF_DIR}"

PLAN="$(team_member_field "${MEMBER}" plan)"; [[ -n "${PLAN}" ]] || PLAN="pro"

log() {
  local line
  line="$(now_utc) [${MEMBER}/${AGENT}] $*"
  printf '%s\n' "${line}" >&2
  printf '%s\n' "${line}" >> "${RUNNER_LOG}" 2>/dev/null || true
}

# --- Optional headless auth token ------------------------------------------------
if [[ -f "${CONF_DIR}/runner.env" ]]; then
  _tok="$(awk -F= '/^CLAUDE_CODE_OAUTH_TOKEN=/{sub(/^CLAUDE_CODE_OAUTH_TOKEN=/,""); print; exit}' "${CONF_DIR}/runner.env")"
  if [[ -n "${_tok}" && -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    export CLAUDE_CODE_OAUTH_TOKEN="${_tok}"
  fi
fi

# --- Single-runner lock (portable: atomic mkdir, epoch file for staleness) --------
acquire_lock() {
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    date +%s > "${LOCK_DIR}/epoch"
    echo "$$" > "${LOCK_DIR}/pid"
    return 0
  fi
  # Lock exists — reclaim if stale.
  local started now age
  started="$(cat "${LOCK_DIR}/epoch" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  age=$(( now - started ))
  if [[ "${age}" -ge "${LOCK_STALE_SECONDS}" ]]; then
    log "reclaiming stale lock (age ${age}s)"
    rm -rf "${LOCK_DIR}"
    if mkdir "${LOCK_DIR}" 2>/dev/null; then
      date +%s > "${LOCK_DIR}/epoch"; echo "$$" > "${LOCK_DIR}/pid"
      return 0
    fi
  fi
  return 1
}
release_lock() { rm -rf "${LOCK_DIR}" 2>/dev/null || true; }

# --- Build the headless prompt for one cadence action ------------------------------
build_prompt() {
  local item="$1" period="$2" rendered="$3" action="$4"
  cat <<EOF
You are the team-os automated cadence runner, acting as agent '${AGENT}'.
No human is watching this session — do the work and stop.

Run this recurring team cadence item now:
  item:   ${item}
  period: ${period}
  action: ${action}

Write the finished result to this exact file (create parent directories if
needed): ${rendered}

Rules:
- The file ${rendered} MUST exist with the completed content when you finish.
- Do NOT git commit or git push — the runner handles version control.
- Do NOT touch any other cadence item, any teammate's files, or platform/ops files.
- Be concise; you are spending shared plan credits.
EOF
}

# --- Run one due item: claim -> execute -> commit output -> push -------------------
run_item() {
  local item="$1" period="$2" rendered="$3" action="$4" model="$5"
  [[ -n "${model}" ]] || model="$(tier_model "${PLAN}")"

  local claim="shared/cadence/${item}/${period}.claim.md"

  # 1. Claim (uniform: protects against a second machine as the same member,
  #    and is the race arbiter for owner: any). Commit the claim itself with
  #    the [cadence] message, then push.
  mkdir -p "$(dirname "${claim}")"
  {
    echo "member: ${MEMBER}"
    echo "agent: ${AGENT}"
    echo "claimed_at: $(now_utc)"
  } > "${claim}"
  git add "${claim}"
  if ! git commit --quiet -m "[cadence][agent:${AGENT}] claim ${item} ${period}" 2>/dev/null; then
    log "could not commit claim for ${item} ${period} (nothing staged?) — skipping"
    return 0
  fi

  if has_remote; then
    if ! git push --quiet 2>/dev/null; then
      # Lost the race (or transient). Back off with the documented resolver;
      # if the surviving claim isn't ours, someone else owns this period.
      git -c rebase.empty=drop pull --rebase --quiet -X ours 2>/dev/null || {
        log "claim push+rebase failed for ${item} ${period} — skipping this run"; return 0; }
      local winner
      winner="$(awk '/^member:/{sub(/^member:[[:space:]]*/,""); print; exit}' "${claim}" 2>/dev/null || echo '')"
      if [[ "${winner}" != "${MEMBER}" ]]; then
        log "claim for ${item} ${period} won by '${winner}' — backing off"
        return 0
      fi
      git push --quiet 2>/dev/null || { log "re-push after rebase failed — skipping ${item}"; return 0; }
    fi
  fi
  log "claimed ${item} ${period}"

  # 2. Execute the action headlessly on subscription credits.
  local claude_args
  read -ra claude_args <<< "${TEAMOS_CLAUDE_ARGS:---permission-mode acceptEdits}"
  local prompt; prompt="$(build_prompt "${item}" "${period}" "${rendered}" "${action}")"
  log "executing ${item} via claude (model ${model})"
  if ! printf '%s' "${prompt}" | claude -p --model "${model}" "${claude_args[@]}" >/dev/null 2>>"${RUNNER_LOG}"; then
    log "claude exited non-zero for ${item} ${period}"
  fi

  # 3. Verify the output the action was supposed to produce.
  if [[ ! -s "${rendered}" ]]; then
    log "FAILED: ${item} ${period} produced no output at ${rendered} (claim stands; goes stale in 6h and is retried)"
    return 0
  fi

  # 4. Commit the output and push.
  git add "${rendered}"
  if git commit --quiet -m "[cadence][agent:${AGENT}] ${item} ${period}" 2>/dev/null; then
    if has_remote; then
      git push --quiet 2>/dev/null || log "output push failed for ${item} — will retry on next sync"
    fi
    log "DONE: ${item} ${period} -> ${rendered}"
  else
    log "nothing to commit for ${item} output (already committed?)"
  fi
}

# --- Main -------------------------------------------------------------------------
if ! acquire_lock; then
  log "another runner holds the lock — exiting"
  exit 0
fi
trap release_lock EXIT INT TERM

# Pull first so due-detection and claims see the team's latest state.
if has_remote; then
  git_safe_pull_rebase "${RUNNER_LOG}" || log "pull did not complete — proceeding with local state"
fi

# What is due for this member right now? (tab-separated: item period rendered action model)
DUE_TSV="$("${SCRIPT_DIR}/cadence-due.sh" --tsv --for "${MEMBER}" 2>/dev/null || true)"

if [[ -z "${DUE_TSV}" ]]; then
  [[ "${MODE}" == "run" ]] || echo "(nothing due for ${MEMBER})"
  log "nothing due"
  exit 0
fi

if [[ "${MODE}" != "run" ]]; then
  echo "Due for ${MEMBER} (plan ${PLAN}):"
  while IFS="$(printf '\t')" read -r item period rendered action model; do
    [[ -n "${item}" ]] || continue
    printf '  - %s (%s) -> %s   [%s]\n' "${item}" "${period}" "${rendered}" "${action}"
  done <<< "${DUE_TSV}"
  [[ "${MODE}" == "dry" ]] && echo "(dry-run: nothing claimed, nothing executed)"
  exit 0
fi

command -v claude >/dev/null 2>&1 || { log "claude CLI not found — cannot run cadence; install Claude Code"; exit 1; }

COUNT=0
while IFS="$(printf '\t')" read -r item period rendered action model; do
  [[ -n "${item}" ]] || continue
  COUNT=$((COUNT + 1))
  run_item "${item}" "${period}" "${rendered}" "${action}" "${model}" || log "run_item errored for ${item} (continuing)"
done <<< "${DUE_TSV}"

log "run complete (${COUNT} item(s) considered)"
